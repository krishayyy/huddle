import Foundation
import MultipeerConnectivity
import SwiftUI

struct NearbyRoom: Identifiable {
    let peer: MCPeerID
    let name: String
    var id: String { peer.displayName }
}

/// One object the whole UI observes. The host owns the truth: guests send `Action`s,
/// the host applies them and broadcasts the new `RoomState` to everyone.
@MainActor
final class RoomStore: ObservableObject {
    enum Role { case none, host, guest }

    @Published private(set) var role: Role = .none
    @Published private(set) var state = RoomState()
    @Published private(set) var nearby: [NearbyRoom] = []
    @Published var leftLock = false          // this device gave up on the current lock
    @Published var connecting = false

    private(set) var me = ""
    private var net: PeerSession?
    private var hostPeer: MCPeerID?

    var isHost: Bool { role == .host }
    var lockActive: Bool { state.lock?.isActive == true }

    // MARK: Lifecycle

    private func boot(name: String) {
        shutdown()
        let clean = name.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        me = "\(clean.isEmpty ? "Friend" : clean)#\(String(UUID().uuidString.prefix(4)).lowercased())"
        let n = PeerSession(peerID: me)
        n.onReceive = { [weak self] data, peer in
            Task { @MainActor in self?.receive(data, from: peer) }
        }
        n.onPeersChanged = { [weak self] peers in
            Task { @MainActor in self?.peersChanged(peers) }
        }
        n.onRoomsChanged = { [weak self] rooms in
            Task { @MainActor in
                self?.nearby = rooms.map { NearbyRoom(peer: $0.key, name: $0.value) }
                    .sorted { $0.name < $1.name }
            }
        }
        net = n
    }

    func host(name: String) {
        boot(name: name)
        role = .host
        state = RoomState(members: [Member(id: me)])
        net?.advertise(roomName: "\(state.name(of: me))'s huddle")
    }

    func findRooms(name: String) {
        boot(name: name)
        net?.browse()
    }

    func join(_ room: NearbyRoom) {
        hostPeer = room.peer
        connecting = true
        net?.invite(room.peer)
    }

    func leave() {
        shutdown()
        role = .none
        state = RoomState()
        leftLock = false
        connecting = false
    }

    private func shutdown() {
        net?.stop(); net = nil
        hostPeer = nil
        nearby = []
    }

    // MARK: Networking

    private func peersChanged(_ peers: [MCPeerID]) {
        switch role {
        case .host:
            let ids = Set(peers.map(\.displayName))
            var members = state.members.filter { $0.id == me || ids.contains($0.id) }
            for id in ids where !members.contains(where: { $0.id == id }) {
                members.append(Member(id: id))
                log("\(Member(id: id).name) joined 👋")
            }
            if members != state.members { state.members = members }
            broadcast()
        case .none, .guest:
            if let hostPeer, peers.contains(hostPeer) {
                role = .guest
                connecting = false
            } else if role == .guest {
                leave()   // host went away
            }
        }
    }

    private func receive(_ data: Data, from peer: MCPeerID) {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return }
        switch wire {
        case .state(let s) where role != .host:
            // New lock started by the host? Reset our local "gave up" flag.
            if s.lock?.startedAt != state.lock?.startedAt { leftLock = false }
            state = s
        case .action(let a) where role == .host:
            apply(a, from: peer.displayName)
        default: break
        }
    }

    private func broadcast() {
        guard role == .host, let net, let data = try? JSONEncoder().encode(Wire.state(state)) else { return }
        net.send(data, to: net.connectedPeers)
    }

    func send(_ action: Action) {
        switch role {
        case .host: apply(action, from: me)
        case .guest:
            guard let net, let hostPeer, let data = try? JSONEncoder().encode(Wire.action(action)) else { return }
            net.send(data, to: [hostPeer])
        case .none: break
        }
    }

    // MARK: Host logic

    private func log(_ line: String) {
        state.feed.append(line)
        if state.feed.count > 20 { state.feed.removeFirst(state.feed.count - 20) }
    }

    private func apply(_ action: Action, from id: String) {
        let who = state.name(of: id)
        switch action {
        case .startLock(let minutes):
            let now = Date()
            state.lock = LockInfo(startedAt: now, endsAt: now.addingTimeInterval(Double(minutes) * 60))
            for i in state.members.indices { state.members[i].bails = 0 }
            leftLock = false
            log("Lock started: \(minutes) min 🔒")

        case .endLock:
            state.lock = nil
            log("\(who) ended the lock")

        case .bail:
            guard lockActive, let i = state.members.firstIndex(where: { $0.id == id }) else { break }
            state.members[i].bails += 1
            log("\(who) peeked at their phone 👀")

        case .startGame(let kind):
            state.game = newGame(kind, seat: id)
            log("\(who) started \(kind.title) \(kind.emoji)")

        case .stopGame:
            state.game = nil

        case .vote(let choice):
            guard case .wyr(var g) = state.game, !g.revealed else { break }
            g.votes[id] = choice
            if g.votes.count >= state.members.count { g.revealed = true }
            state.game = .wyr(g)

        case .reveal:
            switch state.game {
            case .wyr(var g): g.revealed = true; state.game = .wyr(g)
            case .twoTruths(var g) where g.phase == .guessing: g.phase = .revealed; state.game = .twoTruths(g)
            default: break
            }

        case .next:
            guard let game = state.game else { break }
            state.game = newGame(game.kind, seat: nextSeat(after: game))

        case .submitTruths(let statements, let lie):
            guard case .twoTruths(var g) = state.game, g.author == id, g.phase == .writing,
                  statements.count == 3, (0..<3).contains(lie) else { break }
            g.statements = statements; g.lie = lie; g.phase = .guessing
            state.game = .twoTruths(g)

        case .guess(let i):
            guard case .twoTruths(var g) = state.game, g.phase == .guessing, g.author != id else { break }
            g.guesses[id] = i
            if g.guesses.count >= state.members.count - 1 { g.phase = .revealed }
            state.game = .twoTruths(g)
        }
        broadcast()
    }

    private func nextSeat(after game: Game) -> String {
        let current: String
        switch game {
        case .hotSeat(let g): current = g.seat
        case .twoTruths(let g): current = g.author
        case .wyr: current = state.members.first?.id ?? me
        }
        let ids = state.members.map(\.id)
        guard let i = ids.firstIndex(of: current) else { return me }
        return ids[(i + 1) % ids.count]
    }

    private func newGame(_ kind: GameKind, seat: String) -> Game {
        switch kind {
        case .wouldYouRather:
            let p = Prompts.wouldYouRather.randomElement()!
            return .wyr(WYR(a: p.0, b: p.1))
        case .hotSeat:
            return .hotSeat(HotSeat(question: Prompts.hotSeat.randomElement()!, seat: seat))
        case .twoTruths:
            return .twoTruths(TwoTruths(author: seat))
        }
    }
}
