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
            VStack(spacing: 0) {
                HStack {
                    Label(shield.engaged ? "Phone locked" : "Locked in", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ember)
                    Spacer()
                    Text(store.state.members.first.map { "\($0.name)'s huddle" } ?? "")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(.top, 8)

                Spacer(minLength: 24)

                ZStack {
                    // Track + progress: one thin ember line, nothing else.
                    Circle().stroke(Theme.hairline, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: progress(remaining))
                        .stroke(Theme.ember, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    // A soft ember glow that breathes very slowly.
                    Circle()
                        .fill(RadialGradient(colors: [Theme.ember.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 150))
                        .scaleEffect(breathe ? 1.0 : 0.86)
                        .opacity(breathe ? 1 : 0.6)
                    VStack(spacing: 8) {
                        Text(format(remaining))
                            .font(Theme.display(76, weight: .light))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText(countsDown: true))
                        Text("phones down, heads up")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 290, height: 290)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Int(remaining) / 60) minutes \(Int(remaining) % 60) seconds left")
                .onAppear {
                    if !reduceMotion {
                        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { breathe = true }
                    }
                }

                Spacer(minLength: 24)

                scoreboard

                if !shield.engaged {
                    Text("Other apps aren't blocked on this phone. Turn on Lock my other apps in the lobby next time.")
                        .font(.caption).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
                        .padding(.top, 14)
                }

                Spacer(minLength: 24)

                Button { showGames = true } label: {
                    Label("Play a game", systemImage: "die.face.five")
                }
                .buttonStyle(PrimaryButton())

                HStack(spacing: 28) {
                    Button("I need my phone") { confirmBail = true }
                    if store.isHost {
                        Button("End for everyone") { confirmEnd = true }
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
                .padding(.top, 6)
            }
            .padding(24)
            .onChange(of: remaining <= 0) { _, done in
                if done {
                    shield.release()
                    if let l = store.state.lock,
                       store.state.members.first(where: { $0.id == store.me })?.bails == 0, !store.leftLock {
                        stats.recordCompletedLock(minutes: Int(l.endsAt.timeIntervalSince(l.startedAt) / 60),
                                                  with: store.state.members.filter { $0.id != store.me }.map(\.name))
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
                    .toolbarBackground(Theme.ink, for: .navigationBar)
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
        .onChange(of: store.state.members) { _, members in
            LiveActivityController.update(lockedIn: lockedIn, total: members.count)
        }
        .onAppear {
            if let end = store.state.lock?.endsAt { shield.engage(until: end) }
            if let lock = store.state.lock {
                let host = store.state.members.first.map { "\($0.name)'s huddle" } ?? "Your huddle"
                LiveActivityController.start(group: host, lock: lock, lockedIn: lockedIn, total: store.state.members.count)
            }
            UIApplication.shared.isIdleTimerDisabled = true   // keep the screen awake on the table
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// Everyone's face, green ring if they're still locked in, ember if they peeked.
    private var scoreboard: some View {
        HStack(spacing: 18) {
            ForEach(store.state.members) { m in
                VStack(spacing: 8) {
                    Monogram(id: m.id, size: 44, dimmed: m.bails > 0)
                        .padding(3)
                        .overlay(Circle().strokeBorder(m.bails == 0 ? Theme.moss : Theme.ember, lineWidth: 1.5))
                    Text(m.id == store.me ? "You" : m.name)
                        .font(.caption.weight(.medium)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(m.bails == 0 ? "locked in" : "peeked \(m.bails)×")
                        .font(.caption2).foregroundStyle(m.bails == 0 ? Theme.moss : Theme.ember)
                }
                .frame(maxWidth: 76)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var lockedIn: Int { store.state.members.filter { $0.bails == 0 }.count }

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
