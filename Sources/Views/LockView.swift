import SwiftUI

/// Shown on every phone while the group lock is running.
/// Leaving the app counts as a "peek" and the whole group sees it.
struct LockView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var shield: ShieldController
    @EnvironmentObject var stats: FocusStats
    @Environment(\.scenePhase) private var scenePhase
    @State private var showGames = false
    @State private var breathe = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let lock = store.state.lock
            let remaining = max(0, (lock?.endsAt ?? .now).timeIntervalSince(context.date))
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.violet.opacity(0.55), Theme.cyan.opacity(0.18), .clear], center: .center, startRadius: 10, endRadius: 150))
                        .frame(width: 290, height: 290)
                        .scaleEffect(breathe ? 1.08 : 0.92)
                    Circle()
                        .trim(from: 0, to: progress(remaining))
                        .stroke(AngularGradient(colors: [Theme.pink, Theme.orange, Theme.yellow, Theme.lime, Theme.cyan, Theme.pink], center: .center),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 240, height: 240)
                    VStack(spacing: 4) {
                        Text(format(remaining))
                            .font(.system(size: 60, weight: .light, design: .rounded))
                            .monospacedDigit()
                        Text("phones down, heads up")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true }
                }

                scoreboard

                Spacer()
                Button("Play a game 🎲") { showGames = true }
                    .buttonStyle(PrimaryButton())
                Button("I need my phone", role: .destructive) {
                    store.send(.bail)
                    store.leftLock = true
                    shield.release()
                }
                .font(.footnote)
            }
            .padding(24)
            .onChange(of: remaining <= 0) { _, done in
                if done {
                    shield.release()
                    if let l = store.state.lock,
                       store.state.members.first(where: { $0.id == store.me })?.bails == 0, !store.leftLock {
                        stats.recordCompletedLock(minutes: Int(l.endsAt.timeIntervalSince(l.startedAt) / 60))
                    }
                    store.leftLock = true   // lock finished: drop back to the lobby
                }
            }
        }
        .sheet(isPresented: $showGames) {
            ScrollView { GamesView().padding(20) }
                .background(Theme.background)
                .presentationDetents([.large])
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app mid-lock = a peek. Everyone sees it.
            if phase == .background { store.send(.bail) }
        }
        .onAppear {
            shield.engage()
            UIApplication.shared.isIdleTimerDisabled = true   // keep the screen awake on the table
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.state.members) { m in
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.color(for: m.id)).frame(width: 12, height: 12)
                        Text(m.name).fontWeight(.semibold)
                    }
                    Spacer()
                    Text(m.bails == 0 ? "✅ locked in" : "👀 peeked ×\(m.bails)")
                        .foregroundStyle(m.bails == 0 ? .green : .orange)
                }
            }
        }
        .card(tint: Theme.cyan)
    }

    private func progress(_ remaining: TimeInterval) -> Double {
        guard let l = store.state.lock else { return 0 }
        let total = l.endsAt.timeIntervalSince(l.startedAt)
        return total > 0 ? min(1, max(0, remaining / total)) : 0
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
