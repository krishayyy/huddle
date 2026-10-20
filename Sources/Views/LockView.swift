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
    @State private var confirmBail = false
    @State private var confirmEnd = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    if !reduceMotion {
                        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true }
                    }
                }

                scoreboard

                Spacer()
                Button("Play a game 🎲") { showGames = true }
                    .buttonStyle(PrimaryButton())
                HStack(spacing: 24) {
                    Button("I need my phone", role: .destructive) { confirmBail = true }
                    if store.isHost {
                        Button("End for everyone", role: .destructive) { confirmEnd = true }
                    }
                }
                .font(.footnote)
                .frame(minHeight: 44)
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
            NavigationStack {
                ScrollView { GamesView().padding(20) }
                    .scrollDismissesKeyboard(.interactively)
                    .background(Theme.background.ignoresSafeArea())
                    .navigationTitle("Play together")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showGames = false } }
                    }
            }
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Give up on the lock?", isPresented: $confirmBail, titleVisibility: .visible) {
            Button("I need my phone", role: .destructive) {
                store.send(.bail)       // your friends will see this
                store.leftLock = true
                shield.release()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your friends will see that you peeked.")
        }
        .confirmationDialog("End the lock for everyone?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End lock", role: .destructive) {
                store.send(.endLock)
                shield.release()
            }
            Button("Keep going", role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app mid-lock = a peek. iOS only gives us a moment before it suspends
            // the app, so ask for a short background task to get the message out.
            if phase == .background && !store.leftLock {
                var task = UIBackgroundTaskIdentifier.invalid
                task = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(task) }
                store.send(.bail)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { UIApplication.shared.endBackgroundTask(task) }
            }
        }
        // Buzz when a friend peeks so the group feels it.
        .sensoryFeedback(.warning, trigger: store.state.members.map(\.bails))
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
