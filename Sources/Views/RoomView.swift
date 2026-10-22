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
            VStack(alignment: .leading, spacing: 32) {
                header
                members
                lockSection
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Play")
                    GamesView()
                }
                if !store.state.feed.isEmpty { feed }
                Button(store.isHost ? "End huddle" : "Leave huddle") { confirmLeave = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
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

    private var hostName: String { store.state.members.first?.name ?? "Your" }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.isHost ? "Your huddle" : "\(hostName)'s huddle")
                .font(Theme.display(36, weight: .medium))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            if store.state.lock != nil && !store.lockActive {
                Label(store.myBails == 0 ? "You stayed locked in the whole time" : "Lock complete",
                      systemImage: store.myBails == 0 ? "checkmark.seal" : "checkmark")
                    .font(.subheadline).foregroundStyle(store.myBails == 0 ? Theme.moss : Theme.muted)
            } else if let theme = store.state.dailyTheme {
                // Drop a leading emoji from the daily theme so the header stays typographic.
                Text(theme.split(separator: " ").drop { !$0.contains(where: \.isLetter) }.joined(separator: " ")).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Here now · \(store.state.members.count)")
            FlowRow(items: store.state.members) { m in
                HStack(spacing: 8) {
                    Monogram(id: m.id, size: 28)
                    Text(m.id == store.me ? "\(m.name) (you)" : m.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                }
                .padding(.leading, 4).padding(.trailing, 14).padding(.vertical, 4)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .accessibilityElement(children: .combine)
            }
            if store.state.members.count < 2 {
                Text(store.isHost ? "Friends open Huddle and tap Join friends nearby, or tap the same coaster."
                                  : "Waiting on the host…")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
        }
    }

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Lock in together")
            if store.isHost {
                // Duration as large serif numbers instead of a segmented control.
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { m in
                        Button { withAnimation(.snappy) { minutes = m } } label: {
                            VStack(spacing: 2) {
                                Text("\(m)").font(Theme.display(26, weight: minutes == m ? .medium : .light))
                                    .monospacedDigit()
                                Text("min").font(.caption2).foregroundStyle(Theme.muted)
                            }
                            .foregroundStyle(minutes == m ? Theme.text : Theme.faint)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(minutes == m ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(m) minutes")
                        .accessibilityAddTraits(minutes == m ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
                .sensoryFeedback(.selection, trigger: minutes)

                Button {
                    store.send(.startLock(minutes: minutes))   // LockView engages the app shield
                } label: {
                    Label("Lock in for \(minutes) minutes", systemImage: "lock.fill")
                }
                .buttonStyle(PrimaryButton.ember)
                .disabled(store.state.members.count < 2)
            } else {
                Text("The host picks the time. Everyone locks at once.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }

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
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lock my other apps").font(.body.weight(.medium)).foregroundStyle(Theme.text)
                    Text("Everything except calls, emergency and Huddle is blocked until the timer ends.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.ember)
            .padding(.top, 4)
        }
    }

    private var feed: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Activity")
            ForEach(Array(store.state.feed.suffix(4).reversed().enumerated()), id: \.offset) { _, line in
                Text(line).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
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
