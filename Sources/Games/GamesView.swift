import SwiftUI

/// Game picker + the live game. Everything shown here is driven by the shared RoomState,
/// so every phone updates in real time.
struct GamesView: View {
    @EnvironmentObject var store: RoomStore

    var body: some View {
        VStack(spacing: 14) {
            if let game = store.state.game {
                switch game {
                case .wyr(let g): WYRView(game: g)
                case .hotSeat(let g): HotSeatView(game: g)
                case .twoTruths(let g): TwoTruthsView(game: g)
                }
                HStack {
                    Button("Next ➜") { store.send(.next) }.buttonStyle(PrimaryButton())
                    Button("End game") { store.send(.stopGame) }
                        .buttonStyle(PrimaryButton.light)
                }
            } else {
                ForEach(GameKind.allCases) { kind in
                    Button { store.send(.startGame(kind)) } label: {
                        HStack(spacing: 14) {
                            Text(kind.emoji).font(.system(size: 44))
                            VStack(alignment: .leading) {
                                Text(kind.title).font(.system(.title3, design: .rounded, weight: .heavy))
                                Text(kind.blurb).font(.footnote).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .card(tint: kind.color)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.state.members.count < 2)
                }
            }
        }
    }
}

// MARK: - Would You Rather

private struct WYRView: View {
    @EnvironmentObject var store: RoomStore
    let game: WYR

    var body: some View {
        VStack(spacing: 12) {
            Text("Would you rather…").font(.headline).foregroundStyle(.secondary)
            option(0, game.a)
            Text("or").foregroundStyle(.secondary)
            option(1, game.b)
            Text("\(game.votes.count)/\(store.state.members.count) voted")
                .font(.footnote).foregroundStyle(.secondary)
            if !game.revealed && game.votes.count > 0 {
                Button("Reveal now") { store.send(.reveal) }.font(.footnote)
            }
        }
    }

    private func option(_ i: Int, _ text: String) -> some View {
        let mine = game.votes[store.me] == i
        let voters = store.state.members.filter { game.votes[$0.id] == i }.map(\.name)
        return Button { store.send(.vote(i)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(text).font(.title3.weight(.semibold)).multilineTextAlignment(.leading)
                if game.revealed {
                    Text(voters.isEmpty ? "Nobody 😬" : voters.joined(separator: ", "))
                        .font(.footnote).foregroundStyle(.secondary)
                } else if mine {
                    Text("Your pick ✓").font(.footnote.bold())
                }
            }
            .card(tint: i == 0 ? Theme.cyan : Theme.pink)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(mine ? .white : .clear, lineWidth: 4))
        }
        .buttonStyle(.plain)
        .disabled(game.revealed)
    }
}

// MARK: - Hot Seat

private struct HotSeatView: View {
    @EnvironmentObject var store: RoomStore
    let game: HotSeat

    var body: some View {
        let mine = game.seat == store.me
        VStack(spacing: 12) {
            Text("🔥 \(mine ? "You're" : "\(store.state.name(of: game.seat)) is") in the hot seat")
                .font(.headline)
            Text(game.question)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .card()
            Text(mine ? "Answer out loud. Everyone else: ask a follow-up!"
                      : "Listen up, then ask a follow-up question.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Two Truths & a Lie

private struct TwoTruthsView: View {
    @EnvironmentObject var store: RoomStore
    let game: TwoTruths
    @State private var drafts = ["", "", ""]
    @State private var lie = 0

    var body: some View {
        let author = store.state.name(of: game.author)
        let isAuthor = game.author == store.me
        VStack(alignment: .leading, spacing: 12) {
            Text("🕵️ \(isAuthor ? "Your turn" : "\(author)'s turn")").font(.headline)
            switch game.phase {
            case .writing:
                if isAuthor { writing } else {
                    Text("\(author) is writing two truths and a lie…").foregroundStyle(.secondary).card()
                }
            case .guessing:
                statements(isAuthor: isAuthor)
                Text(isAuthor ? "\(game.guesses.count) guesses in…" : "Tap the one you think is the lie.")
                    .font(.footnote).foregroundStyle(.secondary)
                if isAuthor && !game.guesses.isEmpty {
                    Button("Reveal now") { store.send(.reveal) }.font(.footnote)
                }
            case .revealed:
                statements(isAuthor: isAuthor)
                let right = store.state.members.filter { game.guesses[$0.id] == game.lie }.map(\.name)
                Text(right.isEmpty ? "Nobody caught the lie! 😈" : "Caught it: \(right.joined(separator: ", ")) 🎯")
                    .font(.subheadline)
            }
        }
    }

    private var writing: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                HStack {
                    TextField("Statement \(i + 1)", text: $drafts[i], axis: .vertical)
                    Button {
                        lie = i
                    } label: {
                        Text(lie == i ? "🤥 lie" : "truth").font(.footnote.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(lie == i ? .orange : .gray)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            Button("Lock it in") { store.send(.submitTruths(statements: drafts, lie: lie)) }
                .buttonStyle(PrimaryButton())
                .disabled(drafts.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    private func statements(isAuthor: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(game.statements.enumerated()), id: \.offset) { i, text in
                let revealed = game.phase == .revealed
                Button { store.send(.guess(i)) } label: {
                    HStack {
                        Text(text).multilineTextAlignment(.leading)
                        Spacer()
                        if revealed { Text(i == game.lie ? "🤥 LIE" : "✅ true").font(.footnote.bold()) }
                        else if game.guesses[store.me] == i { Text("your guess").font(.footnote).foregroundStyle(Theme.accent) }
                    }
                    .card()
                }
                .buttonStyle(.plain)
                .disabled(isAuthor || revealed)
            }
        }
    }
}
