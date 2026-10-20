import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var stats: FocusStats
    @AppStorage("displayName") private var name = ""
    @State private var browsing = false
    @FocusState private var nameFocused: Bool

    private var nameOK: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 28, weight: .light, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("🫂").font(.system(size: 64))
                    Text("Huddle")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Theme.yellow, Theme.pink, Theme.cyan], startPoint: .leading, endPoint: .trailing))
                    Text("Put the phones down. Together.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                HStack {
                    stat("\(stats.score)", "focus score", Theme.cyan)
                    stat("\(stats.streak)", "day streak", Theme.pink)
                    stat("\(stats.totalMinutes)", "min focused", Theme.lime)
                }

                TextField("Your name", text: $name)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .frame(minHeight: 52)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.violet.opacity(0.5), lineWidth: 1))

                if !browsing {
                    Button("Start a huddle") {
                        nameFocused = false
                        store.host(name: name)
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(!nameOK)

                    Button("Join friends nearby") {
                        nameFocused = false
                        browsing = true
                        store.findRooms(name: name)
                    }
                    .buttonStyle(PrimaryButton(tint: Theme.cyan, secondary: Theme.violet))
                    .disabled(!nameOK)

                    if !nameOK {
                        Text("Add your name so friends know who you are.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    nearbyList
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby huddles").font(.headline)
                if store.connecting || store.nearby.isEmpty { ProgressView().padding(.leading, 4) }
                Spacer()
                Button("Cancel") {
                    browsing = false
                    store.leave()          // stops browsing and resets
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            if store.nearby.isEmpty {
                Text("Looking… ask a friend to tap Start a huddle. Make sure Bluetooth and Wi‑Fi are on, and allow Local Network access if asked.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if store.joinFailed {
                Text("Couldn't join that huddle. Try again.")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.pink)
            }
            ForEach(store.nearby) { room in
                Button {
                    store.join(room)
                } label: {
                    HStack {
                        Text(room.name).fontWeight(.semibold)
                        Spacer()
                        if store.connecting { ProgressView() } else { Image(systemName: "arrow.right.circle.fill") }
                    }
                    .frame(minHeight: 44)
                    .card(tint: Theme.violet)
                }
                .buttonStyle(.plain)
                .disabled(store.connecting)
            }
        }
    }
}
