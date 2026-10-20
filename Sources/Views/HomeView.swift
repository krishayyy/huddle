import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var stats: FocusStats
    @AppStorage("displayName") private var name = ""

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 28, weight: .light, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
    @State private var browsing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("🫂").font(.system(size: 64))
                    Text("Huddle")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Theme.yellow, Theme.pink, Theme.cyan], startPoint: .leading, endPoint: .trailing))
                    Text("Put the phones down. Together.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                HStack {
                    stat("\(stats.score)", "focus score", Theme.cyan)
                    stat("\(stats.streak)", "day streak", Theme.pink)
                    stat("\(stats.totalMinutes)", "min focused", Theme.lime)
                }

                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.violet.opacity(0.5), lineWidth: 1))

                Button("Start a huddle") { store.host(name: name) }
                    .buttonStyle(PrimaryButton())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Join friends nearby") {
                    browsing = true
                    store.findRooms(name: name)
                }
                .buttonStyle(PrimaryButton(tint: Theme.cyan, secondary: Theme.violet))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                if browsing { nearbyList }
            }
            .padding(24)
        }
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Nearby huddles").font(.headline)
                if store.connecting || store.nearby.isEmpty { ProgressView().padding(.leading, 4) }
            }
            if store.nearby.isEmpty {
                Text("Looking… ask a friend to start a huddle.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.nearby) { room in
                Button {
                    store.join(room)
                } label: {
                    HStack {
                        Text(room.name)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
