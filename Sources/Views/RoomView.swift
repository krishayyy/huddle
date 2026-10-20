import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

/// The lobby: who's here, start a lock together, or just play a game.
struct RoomView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var shield: ShieldController
    @State private var minutes = 30
    @State private var pickingApps = false

    private let options = [15, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                membersCard
                lockCard
                Text("Play").font(.title3.bold())
                GamesView()
                Button("Leave huddle", role: .destructive) { store.leave() }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack {
            Text("Your huddle").font(.system(size: 34, weight: .bold, design: .rounded))
            Spacer()
            if store.state.lock != nil && !store.lockActive {
                Text("🎉 Lock complete").font(.subheadline)
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
            if store.isHost {
                Text("Friends: open Huddle → Join friends nearby.")
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
                    shield.engage()
                    store.send(.startLock(minutes: minutes))
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
            #if canImport(FamilyControls)
            Divider().overlay(.white.opacity(0.2))
            Button {
                Task {
                    if !shield.authorized { await shield.requestAccess() }
                    pickingApps = shield.authorized
                }
            } label: {
                Label("Also block my distracting apps", systemImage: "shield.lefthalf.filled")
            }
            .familyActivityPicker(isPresented: $pickingApps, selection: $shield.selection)
            #endif
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
