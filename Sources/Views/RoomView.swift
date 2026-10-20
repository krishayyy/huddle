import SwiftUI

/// The lobby: who's here, start a lock together, or just play a game.
struct RoomView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var shield: ShieldController
    @State private var minutes = 30
    @State private var confirmLeave = false

    private let options = [15, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                membersCard
                lockCard
                Text("Play").font(.title3.bold())
                GamesView()
                Button("Leave huddle", role: .destructive) { confirmLeave = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .overlay(alignment: .top) {
            if store.state.lock != nil && !store.lockActive && store.myBails == 0 { Confetti() }
        }
        .confirmationDialog(store.isHost ? "End this huddle for everyone?" : "Leave this huddle?",
                            isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(store.isHost ? "End huddle" : "Leave", role: .destructive) { store.leave() }
            Button("Stay", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Text("Your huddle").font(.system(size: 34, weight: .bold, design: .rounded))
            Spacer()
            if store.state.lock != nil && !store.lockActive {
                Text(store.myBails == 0 ? "🎉 Locked in the whole time" : "Lock complete").font(.subheadline)
            }
        }
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Here now (\(store.state.members.count))").font(.headline)
            FlowRow(items: store.state.members) { m in
                Text(m.id == store.me ? "\(m.name) (you)" : m.name)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.color(for: m.id).opacity(0.9), in: Capsule())
                    .foregroundStyle(.black)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            if store.state.members.count < 2 {
                Text(store.isHost ? "Friends: open Huddle → Join friends nearby."
                                  : "Waiting on the host…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card(tint: Theme.violet)
    }

    private var lockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔒 Lock phones together").font(.headline)
            if store.isHost {
                Picker("Minutes", selection: $minutes) {
                    ForEach(options, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                Button("Lock in for \(minutes) min") {
                    store.send(.startLock(minutes: minutes))   // LockView engages the app shield
                }
                .buttonStyle(PrimaryButton())
                .disabled(store.state.members.count < 2)
                if store.state.members.count < 2 {
                    Text("Waiting for at least one friend…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("The host picks the time. You'll all lock at once.")
                    .foregroundStyle(.secondary)
            }
            Divider().overlay(.white.opacity(0.2))
            Toggle(isOn: Binding(
                get: { shield.wantsFullLock },
                set: { on in
                    if on {
                        Task {
                            await shield.requestAccess()           // system Screen Time prompt
                            shield.wantsFullLock = shield.authorized
                        }
                    } else {
                        shield.wantsFullLock = false
                    }
                })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock all my other apps").fontWeight(.semibold)
                    Text("Every other app and site is blocked until the timer ends. Calls and emergency stay on. Huddle stays open for games.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .tint(Theme.violet)
            if !store.state.feed.isEmpty {
                Divider().overlay(.white.opacity(0.2))
                ForEach(store.state.feed.suffix(3), id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .card(tint: Theme.pink)
    }
}

/// Minimal wrapping row so name chips flow onto multiple lines.
struct FlowRow<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { content($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 300, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, p) in result.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var points: [CGPoint] = []
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowH = max(rowH, size.height)
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowH), points)
    }
}
