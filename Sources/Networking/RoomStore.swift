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
    @Published var leftLock = false          // this device gave up on / finished the current lock
    @Published private(set) var connecting = false
    @Published private(set) var reconnecting = false
    @Published private(set) var joinFailed = false

    private(set) var me = ""
    private var net: PeerSession?
    private var hostPeer: MCPeerID?
    private var used = Set<String>()         // prompts already shown this session (host only)

    var isHost: Bool { role == .host }
    var lockActive: Bool { state.lock?.isActive == true }
    var myBails: Int { state.members.first { $0.id == me }?.bails ?? 0 }

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
        guard net == nil || role == .none, !connecting else { return }
        boot(name: name)
        net?.browse()
    }

    func join(_ room: NearbyRoom) {
        guard !connecting else { return }
        hostPeer = room.peer
        connecting = true
        joinFailed = false
        net?.invite(room.peer)
        // Invitations time out silently; don't leave the spinner up forever.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(16))
            guard let self, self.connecting, self.role == .none else { return }
            self.connecting = false
            self.joinFailed = true
        }
    }

    /// Called when the app comes back to the foreground mid-lock.
    func reconnectIfNeeded() {
        guard role == .guest, reconnecting, let hostPeer else { return }
        net?.invite(hostPeer)
    }

    func leave() {
        shutdown()
        role = .none
        state = RoomState()
        leftLock = false
        connecting = false
        reconnecting = false
        joinFailed = false
        used = []
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
            var members = state.members
            // During a lock, keep people who dropped (iOS suspends backgrounded apps) so their
            // peek count survives. Outside a lock, drop them.
            if !lockActive { members = members.filter { $0.id == me || ids.contains($0.id) } }
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
                reconnecting = false
            } else if role == .guest {
                if lockActive {
                    reconnecting = true       // keep the lock screen up and retry on foreground
                    net?.invite(hostPeer!)
                } else {
                    leave()                   // host went away
                }
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

    private func award(_ id: String, _ points: Int) {
        state.scores[id, default: 0] += points
    }

    private func apply(_ action: Action, from id: String) {
        let who = state.name(of: id)
        let count = state.members.count
        switch action {
        case .startLock(let minutes):
            guard id == me else { break }   // only the host starts a lock
            let now = Date()
            state.lock = LockInfo(startedAt: now, endsAt: now.addingTimeInterval(Double(minutes) * 60))
            for i in state.members.indices { state.members[i].bails = 0 }
            leftLock = false
            log("Lock started: \(minutes) min 🔒")

        case .endLock:
            guard id == me else { break }
            state.lock = nil
            log("\(who) ended the lock early")

        case .bail:
            guard lockActive, let i = state.members.firstIndex(where: { $0.id == id }) else { break }
            state.members[i].bails += 1
            log("\(who) peeked at their phone 👀")

        case .startGame(let kind):
            guard count >= kind.minPlayers else { break }
            state.game = newGame(kind, seat: id)
            log("\(who) started \(kind.title) \(kind.emoji)")

        case .stopGame:
            state.game = nil

        case .vote(let choice):
            guard case .wyr(var g) = state.game, !g.revealed, (0...1).contains(choice) else { break }
            g.votes[id] = choice
            if g.votes.count >= count { g.revealed = true }
            state.game = .wyr(g)

        case .voteFor(let target):
            guard state.members.contains(where: { $0.id == target }) else { break }
            switch state.game {
            case .mostLikely(var g) where !g.revealed:
                g.votes[id] = target
                if g.votes.count >= count { g.revealed = true }
                state.game = .mostLikely(g)
            case .imposter(var g) where g.phase == .voting:
                g.votes[id] = target
                state.game = .imposter(g)
                if g.votes.count >= count { finishImposter() }
            default: break
            }

        case .answerHave(let have):
            guard case .neverHave(var g) = state.game, !g.revealed else { break }
            g.haves[id] = have
            if g.haves.count >= count { g.revealed = true }
            state.game = .neverHave(g)

        case .reveal:
            switch state.game {
            case .wyr(var g): g.revealed = true; state.game = .wyr(g)
            case .mostLikely(var g): g.revealed = true; state.game = .mostLikely(g)
            case .neverHave(var g): g.revealed = true; state.game = .neverHave(g)
            case .twoTruths(let g) where g.phase == .guessing: finishTwoTruths(g)
            case .imposter(let g) where g.phase == .voting: _ = g; finishImposter()
            case .actItOut(var g) where g.phase == .running: g.phase = .done; state.game = .actItOut(g)
            default: break
            }

        case .next:
            guard let game = state.game else { break }
            state.game = newGame(game.kind, seat: nextSeat(after: game))

        case .reroll:
            switch state.game {
            case .hotSeat(var g):
                g.question = fresh(Prompts.hotSeat)
                state.game = .hotSeat(g)
            case .actItOut(var g) where g.phase == .ready:
                g.word = fresh(Prompts.actWords)
                state.game = .actItOut(g)
            default: break
            }

        case .submitTruths(let statements, let lie):
            guard case .twoTruths(var g) = state.game, g.author == id, g.phase == .writing,
                  statements.count == 3, (0..<3).contains(lie) else { break }
            g.statements = statements.map { String($0.prefix(120)) }
            g.lie = lie; g.phase = .guessing
            state.game = .twoTruths(g)

        case .guess(let i):
            guard case .twoTruths(var g) = state.game, g.phase == .guessing, g.author != id, (0..<3).contains(i) else { break }
            g.guesses[id] = i
            state.game = .twoTruths(g)
            if g.guesses.count >= count - 1 { finishTwoTruths(g) }

        case .startRound:
            guard case .actItOut(var g) = state.game, g.actor == id, g.phase == .ready else { break }
            g.phase = .running
            g.endsAt = Date().addingTimeInterval(Double(g.seconds))
            state.game = .actItOut(g)

        case .gotIt, .skipWord:
            guard case .actItOut(var g) = state.game, g.actor == id, g.phase == .running,
                  let end = g.endsAt, Date() < end else { break }
            if case .gotIt = action { g.got += 1 } else { g.passed += 1 }
            g.word = fresh(Prompts.actWords)
            state.game = .actItOut(g)

        case .startVoting:
            guard case .imposter(var g) = state.game, g.phase == .clues else { break }
            g.phase = .voting
            state.game = .imposter(g)
        }
        broadcast()
    }

    private func finishTwoTruths(_ game: TwoTruths) {
        var g = game
        for (guesser, guess) in g.guesses {
            if guess == g.lie { award(guesser, 1) } else { award(g.author, 1) }
        }
        g.phase = .revealed
        state.game = .twoTruths(g)
    }

    private func finishImposter() {
        guard case .imposter(var g) = state.game else { return }
        let tally = Dictionary(grouping: g.votes.values, by: { $0 }).mapValues(\.count)
        let top = tally.values.max() ?? 0
        let leaders = tally.filter { $0.value == top }.map(\.key)
        g.caught = leaders.count == 1 && leaders.first == g.imposter
        if g.caught {
            for m in state.members where m.id != g.imposter { award(m.id, 1) }
            log("\(state.name(of: g.imposter)) was the imposter. Caught! 🎯")
        } else {
            award(g.imposter, 2)
            log("\(state.name(of: g.imposter)) fooled everyone 😈")
        }
        g.phase = .revealed
        state.game = .imposter(g)
    }

    private func nextSeat(after game: Game) -> String {
        let current: String
        switch game {
        case .hotSeat(let g): current = g.seat
        case .twoTruths(let g): current = g.author
        case .actItOut(let g): current = g.actor
        default: current = state.members.first?.id ?? me
        }
        let ids = state.members.map(\.id)
        guard let i = ids.firstIndex(of: current) else { return me }
        return ids[(i + 1) % ids.count]
    }

    /// Random element that hasn't been shown yet this session (resets when the list runs out).
    private func fresh(_ list: [String]) -> String {
        var pool = list.filter { !used.contains($0) }
        if pool.isEmpty { list.forEach { used.remove($0) }; pool = list }
        let pick = pool.randomElement() ?? list[0]
        used.insert(pick)
        return pick
    }

    private func talk() -> String { Prompts.talkBacks.randomElement()! }

    private func newGame(_ kind: GameKind, seat: String) -> Game {
        switch kind {
        case .wouldYouRather:
            let pairs = Prompts.wouldYouRather
            let key = fresh(pairs.map { $0.0 })
            let p = pairs.first { $0.0 == key } ?? pairs[0]
            return .wyr(WYR(a: p.0, b: p.1, talk: talk()))
        case .mostLikely:
            return .mostLikely(MostLikely(prompt: fresh(Prompts.mostLikely), talk: talk()))
        case .neverHave:
            return .neverHave(NeverHave(prompt: fresh(Prompts.neverHave), talk: talk()))
        case .hotSeat:
            return .hotSeat(HotSeat(question: fresh(Prompts.hotSeat), seat: seat))
        case .twoTruths:
            return .twoTruths(TwoTruths(author: seat))
        case .actItOut:
            return .actItOut(ActItOut(actor: seat, word: fresh(Prompts.actWords)))
        case .imposter:
            let (category, words) = Prompts.imposter.randomElement()!
            let ids = state.members.map(\.id)
            return .imposter(Imposter(category: category, word: words.randomElement()!,
                                      imposter: ids.randomElement() ?? me, order: ids.shuffled()))
        }
    }
}
