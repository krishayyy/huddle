import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: RoomStore
    @AppStorage("displayName") private var name = ""
    @State private var browsing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("🫂").font(.system(size: 64))
                    Text("Huddle").font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("Put the phones down. Together.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

                Button("Start a huddle") { store.host(name: name) }
                    .buttonStyle(PrimaryButton())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Join friends nearby") {
                    browsing = true
                    store.findRooms(name: name)
                }
                .buttonStyle(PrimaryButton(tint: .white.opacity(0.9)))
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
