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
                case .mostLikely(let g): MostLikelyView(game: g)
                case .neverHave(let g): NeverHaveView(game: g)
                case .hotSeat(let g): HotSeatView(game: g)
                case .twoTruths(let g): TwoTruthsView(game: g)
                case .actItOut(let g): ActItOutView(game: g)
                case .imposter(let g): ImposterView(game: g)
                }
                HStack(spacing: 10) {
                    Button("Next round") { store.send(.next) }.buttonStyle(PrimaryButton())
                    Button("End game") { store.send(.stopGame) }.buttonStyle(PrimaryButton.light)
                }
                .padding(.top, 4)
                Leaderboard()
            } else {
                picker
                Leaderboard()
            }
        }
        // A light tap on every phone whenever the game changes: you feel it when a friend acts.
        .sensoryFeedback(.impact(weight: .light), trigger: store.state.game)
    }

    private var picker: some View {
        let count = store.state.members.count
        let featured = store.state.featured ?? GameKind.mostLikely
        let rest = GameKind.allCases.filter { $0 != featured }
        return VStack(spacing: 14) {
            // Today's pick, big.
            Button { store.send(.startGame(featured)) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(store.state.dailyTheme.map { "Tonight · \($0)" } ?? "Tonight's pick")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        Spacer()
                        Image(systemName: featured.symbol).font(.title3).foregroundStyle(Theme.ember)
                    }
                    Text(featured.title).font(Theme.display(32)).foregroundStyle(Theme.text)
                    Text(count >= featured.minPlayers ? featured.blurb : "Needs \(featured.minPlayers) or more people")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                .card()
            }
            .buttonStyle(.plain)
            .disabled(count < featured.minPlayers)

            // Everything else as one quiet list.
            VStack(spacing: 0) {
                ForEach(Array(rest.enumerated()), id: \.element) { idx, kind in
                    let ok = count >= kind.minPlayers
                    Button { store.send(.startGame(kind)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: kind.symbol)
                                .font(.body).foregroundStyle(Theme.muted)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(.body.weight(.medium)).foregroundStyle(Theme.text)
                                Text(ok ? kind.blurb : "Needs \(kind.minPlayers) or more people")
                                    .font(.footnote).foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.faint)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!ok)
                    .opacity(ok ? 1 : 0.4)
                    if idx < rest.count - 1 { Divider().overlay(Theme.hairline).padding(.leading, 42) }
                }
            }
            .padding(.horizontal, 18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        }
    }
}

// MARK: - Shared pieces

struct Leaderboard: View {
    @EnvironmentObject var store: RoomStore
    var body: some View {
        let rows = store.state.members
            .map { ($0, store.state.scores[$0.id] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Leaderboard")
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(Theme.display(20)).foregroundStyle(i == 0 ? Theme.ember : Theme.faint)
                            .frame(width: 22)
                        Monogram(id: row.0.id, size: 28)
                        Text(row.0.id == store.me ? "\(row.0.name) (you)" : row.0.name)
                        Spacer()
                        Text("\(row.1)").font(.body.monospacedDigit().weight(.semibold))
                        Text(row.1 == 1 ? "pt" : "pts").font(.footnote).foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .padding(.vertical, 2)
                }
            }
            .card()
        }
    }
}

private struct TalkNudge: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "bubble.left.and.bubble.right")
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private struct RoundTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }
}

private struct ProgressDots: View {
    let done: Int, total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle().fill(i < done ? Theme.lime : .white.opacity(0.2)).frame(width: 9, height: 9)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring, value: done)
    }
}

// MARK: - Would You Rather

private struct WYRView: View {
    @EnvironmentObject var store: RoomStore
    let game: WYR

    var body: some View {
        VStack(spacing: 12) {
            RoundTitle(text: "Would you rather…")
            option(0, game.a)
            Text("or").foregroundStyle(.secondary)
            option(1, game.b)
            ProgressDots(done: game.votes.count, total: store.state.members.count)
            if game.revealed {
                TalkNudge(text: game.talk)
            } else if !game.votes.isEmpty {
                Button("Reveal now") { store.send(.reveal) }.font(.footnote)
            }
        }
    }

    private func option(_ i: Int, _ text: String) -> some View {
        let mine = game.votes[store.me] == i
        let voters = store.state.members.filter { game.votes[$0.id] == i }.map(\.name)
        return Button { store.send(.vote(i)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(text).font(Theme.display(22)).multilineTextAlignment(.leading)
                if game.revealed {
                    Text(voters.isEmpty ? "Nobody 😬" : "\(voters.count): \(voters.joined(separator: ", "))")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if mine {
                    Text("Your pick · tap the other to change").font(.footnote.bold())
                }
            }
            .frame(minHeight: 64, alignment: .leading)
            .card(tint: i == 0 ? Theme.cyan : Theme.pink)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(mine ? .white : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .disabled(game.revealed)
    }
}

// MARK: - Most Likely To

private struct MostLikelyView: View {
    @EnvironmentObject var store: RoomStore
    let game: MostLikely

    var body: some View {
        let tally = Dictionary(grouping: game.votes.values, by: { $0 }).mapValues(\.count)
        let top = tally.values.max() ?? 0
        VStack(spacing: 10) {
            Text(game.prompt)
                .font(Theme.display(26))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .card(tint: Theme.yellow)
            RoundTitle(text: game.revealed ? "Results" : "Tap who it's most likely to be")
            ForEach(store.state.members) { m in
                let n = tally[m.id] ?? 0
                Button { store.send(.voteFor(m.id)) } label: {
                    HStack {
                        Monogram(id: m.id, size: 30)
                        Text(m.id == store.me ? "\(m.name) (you)" : m.name).fontWeight(.semibold)
                        Spacer()
                        if game.revealed {
                            Text("\(n)").fontWeight(.bold)
                        } else if game.votes[store.me] == m.id {
                            Text("✓")
                        }
                    }
                    .frame(minHeight: 44)
                    .card()
                    .overlay(RoundedRectangle(cornerRadius: 22)
                        .stroke(game.votes[store.me] == m.id ? .white : .clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .disabled(game.revealed)
            }
            ProgressDots(done: game.votes.count, total: store.state.members.count)
            if game.revealed {
                TalkNudge(text: game.talk)
            } else if !game.votes.isEmpty {
                Button("Reveal now") { store.send(.reveal) }.font(.footnote)
            }
        }
    }
}

// MARK: - Never Have I Ever

private struct NeverHaveView: View {
    @EnvironmentObject var store: RoomStore
    let game: NeverHave

    var body: some View {
        let mine = game.haves[store.me]
        let haveNames = store.state.members.filter { game.haves[$0.id] == true }.map(\.name)
        VStack(spacing: 12) {
            Text(game.prompt)
                .font(Theme.display(26))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .card(tint: Theme.lime)
            if game.revealed {
                Text(haveNames.isEmpty ? "Nobody has! Angels 😇" : "I have: \(haveNames.joined(separator: ", "))")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                TalkNudge(text: game.talk)
            } else {
                RoundTitle(text: "Answers stay secret until everyone's in")
                HStack(spacing: 10) {
                    answer("I have 🙋", true, mine == true)
                    answer("Never 😇", false, mine == false)
                }
                ProgressDots(done: game.haves.count, total: store.state.members.count)
                if !game.haves.isEmpty { Button("Reveal now") { store.send(.reveal) }.font(.footnote) }
            }
        }
    }

    private func answer(_ title: String, _ have: Bool, _ selected: Bool) -> some View {
        Button { store.send(.answerHave(have)) } label: {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .card(tint: have ? Theme.pink : Theme.cyan)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? .white : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hot Seat

private struct HotSeatView: View {
    @EnvironmentObject var store: RoomStore
    let game: HotSeat

    var body: some View {
        let mine = game.seat == store.me
        VStack(spacing: 12) {
            RoundTitle(text: "🔥 \(mine ? "You're" : "\(store.state.name(of: game.seat)) is") in the hot seat")
            Text(game.question)
                .font(Theme.display(26))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .card(tint: Theme.pink)
            if mine {
                TalkNudge(text: "Answer out loud. Everyone else will ask follow-ups.")
                Button("Different question") { store.send(.reroll) }.font(.footnote)
            } else {
                RoundTitle(text: "Ask a follow-up:")
                FlowLayout(spacing: 8) {
                    ForEach(["Why?", "Then what?", "Be honest 👀", "Tell the story", "Who else?"], id: \.self) {
                        Text($0).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                }
            }
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
            RoundTitle(text: "🤥 \(isAuthor ? "Your turn" : "\(author)'s turn")")
            switch game.phase {
            case .writing:
                if isAuthor { writing } else {
                    Text("\(author) is writing two truths and a lie…").foregroundStyle(.secondary).card()
                }
            case .guessing:
                statements(isAuthor: isAuthor)
                ProgressDots(done: game.guesses.count, total: max(1, store.state.members.count - 1))
                Text(isAuthor ? "Poker face. Don't react 😐" : "Tap the one you think is the lie.")
                    .font(.footnote).foregroundStyle(.secondary)
                if isAuthor && !game.guesses.isEmpty {
                    Button("Reveal now") { store.send(.reveal) }.font(.footnote)
                }
            case .revealed:
                statements(isAuthor: isAuthor)
                let right = store.state.members.filter { game.guesses[$0.id] == game.lie }.map(\.name)
                Text(right.isEmpty ? "Nobody caught the lie! 😈 (+1 each for \(author))" : "Caught it: \(right.joined(separator: ", ")) 🎯")
                    .font(.subheadline.weight(.medium))
                TalkNudge(text: "Ask \(author) for the full story behind one of them.")
            }
        }
        .onChange(of: game.phase) { _, new in
            if new == .writing { drafts = ["", "", ""]; lie = 0 }
        }
        .onChange(of: game.author) { _, _ in drafts = ["", "", ""]; lie = 0 }
    }

    private var writing: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                HStack {
                    TextField("Statement \(i + 1)", text: $drafts[i], axis: .vertical)
                        .submitLabel(.done)
                    Button { lie = i } label: {
                        Text(lie == i ? "Lie" : "Truth").font(.footnote.bold()).frame(minWidth: 52, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(lie == i ? .orange : .gray)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            Text("Tap \"truth\" on the one that's the lie.").font(.footnote).foregroundStyle(.secondary)
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
                        if revealed { Text(i == game.lie ? "Lie" : "True").font(.footnote.bold()) }
                        else if game.guesses[store.me] == i { Text("your guess").font(.footnote.bold()) }
                    }
                    .frame(minHeight: 40)
                    .card()
                    .overlay(RoundedRectangle(cornerRadius: 22)
                        .stroke(game.guesses[store.me] == i && !revealed ? .white : .clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .disabled(isAuthor || revealed)
            }
        }
    }
}

// MARK: - Act It Out

private struct ActItOutView: View {
    @EnvironmentObject var store: RoomStore
    let game: ActItOut

    var body: some View {
        let isActor = game.actor == store.me
        let actor = store.state.name(of: game.actor)
        VStack(spacing: 12) {
            RoundTitle(text: "🎭 \(isActor ? "You're acting" : "\(actor) is acting")")
            switch game.phase {
            case .ready:
                Text(isActor ? "No talking, no sounds. Act it out and your friends shout guesses."
                             : "Get ready to guess! \(actor) acts, no talking.")
                    .multilineTextAlignment(.center).card(tint: Theme.orange)
                if isActor {
                    Button("Start 60 seconds") { store.send(.startRound) }.buttonStyle(PrimaryButton())
                }
            case .running:
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    let left = max(0, Int((game.endsAt ?? .now).timeIntervalSince(ctx.date).rounded(.up)))
                    VStack(spacing: 12) {
                        Text("\(left)s")
                            .font(Theme.display(56, weight: .light)).monospacedDigit()
                            .foregroundStyle(left <= 10 ? Theme.pink : .white)
                        if isActor {
                            Text(game.word)
                                .font(Theme.display(36, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 90)
                                .card(tint: Theme.orange)
                            HStack(spacing: 10) {
                                Button("Got it") { store.send(.gotIt) }.buttonStyle(PrimaryButton(tint: Theme.lime, secondary: Theme.cyan))
                                Button("Skip ➜") { store.send(.skipWord) }.buttonStyle(PrimaryButton.light)
                            }
                        } else {
                            Text("Shout your guesses").font(.title3.weight(.semibold)).card()
                        }
                        Text("Got \(game.got) · Skipped \(game.passed)").font(.footnote).foregroundStyle(.secondary)
                    }
                    .onChange(of: left == 0) { _, over in
                        if over && (isActor || store.isHost) { store.send(.reveal) }
                    }
                }
            case .done:
                Text("Time! \(game.got) word\(game.got == 1 ? "" : "s") guessed")
                    .font(Theme.display(26)).card(tint: Theme.orange)
                TalkNudge(text: "Best/worst acting moment? Roast gently.")
            }
        }
    }
}

// MARK: - Imposter

private struct ImposterView: View {
    @EnvironmentObject var store: RoomStore
    let game: Imposter
    @State private var peek = false

    private var amImposter: Bool { game.imposter == store.me }

    var body: some View {
        VStack(spacing: 12) {
            RoundTitle(text: "🕵️ Category: \(game.category)")
            roleCard
            switch game.phase {
            case .clues:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Say ONE word clue out loud, in this order:").font(.footnote).foregroundStyle(.secondary)
                    ForEach(Array(game.order.enumerated()), id: \.offset) { i, id in
                        Text("\(i + 1). \(store.state.name(of: id))")
                            .fontWeight(id == store.me ? .bold : .regular)
                    }
                }
                .card()
                TalkNudge(text: "Not too obvious, not too vague. Then argue about who's faking.")
                Button("Time to vote") { store.send(.startVoting) }.buttonStyle(PrimaryButton())
            case .voting:
                RoundTitle(text: "Who's the imposter?")
                ForEach(store.state.members.filter { $0.id != store.me }) { m in
                    Button { store.send(.voteFor(m.id)) } label: {
                        HStack {
                            Monogram(id: m.id, size: 30)
                            Text(m.name).fontWeight(.semibold)
                            Spacer()
                            if game.votes[store.me] == m.id { Text("✓") }
                        }
                        .frame(minHeight: 44)
                        .card()
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(game.votes[store.me] == m.id ? .white : .clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
                ProgressDots(done: game.votes.count, total: store.state.members.count)
                if !game.votes.isEmpty { Button("Reveal now") { store.send(.reveal) }.font(.footnote) }
            case .revealed:
                VStack(spacing: 6) {
                    Text("\(store.state.name(of: game.imposter)) was the imposter")
                        .font(.title3.weight(.semibold))
                    Text("The word was \(game.word)")
                    Text(game.caught ? "Caught! +1 for everyone else 🎯" : "Fooled you all! +2 for the imposter 😈")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).card(tint: Theme.pink)
                TalkNudge(text: "Imposter: how did you decide what to say?")
            }
        }
        .onChange(of: game) { old, new in
            if old.word != new.word || old.imposter != new.imposter { peek = false }   // hide role each new round
        }
    }

    /// Hidden until tapped so nobody sees your role over your shoulder.
    private var roleCard: some View {
        Button { peek.toggle() } label: {
            VStack(spacing: 4) {
                if peek {
                    Text(amImposter ? "You're the IMPOSTER" : game.word)
                        .font(Theme.display(30, weight: .semibold))
                    Text(amImposter ? "You don't know the word. Blend in." : "Don't say it. Give a clue.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("tap to hide").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Tap to see your role").font(.title3.weight(.semibold))
                    Text("Keep your screen private").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .card(tint: peek && amImposter ? Theme.pink : Theme.violet)
        }
        .buttonStyle(.plain)
    }
}
