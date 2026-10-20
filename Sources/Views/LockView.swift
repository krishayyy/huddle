import SwiftUI

/// Shown on every phone while the group lock is running.
/// Leaving the app counts as a "peek" and the whole group sees it.
struct LockView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var shield: ShieldController
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
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 260, height: 260)
                        .scaleEffect(breathe ? 1.08 : 0.92)
                    VStack(spacing: 4) {
                        Text(format(remaining))
                            .font(.system(size: 54, weight: .bold, design: .rounded))
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
                    Text(m.name)
                    Spacer()
                    Text(m.bails == 0 ? "✅ locked in" : "👀 peeked ×\(m.bails)")
                        .foregroundStyle(m.bails == 0 ? .green : .orange)
                }
            }
        }
        .card()
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
