import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var stats: FocusStats
    @StateObject private var coaster = CoasterReader()
    @AppStorage("displayName") private var name = ""
    @State private var browsing = false
    @FocusState private var nameFocused: Bool

    private var nameOK: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title, design: .rounded, weight: .light)).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("🫂").font(.system(size: 64)).accessibilityHidden(true)
                    Text("Huddle")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Theme.yellow, Theme.pink, Theme.cyan], startPoint: .leading, endPoint: .trailing))
                    Text("Put the phones down. Together.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                togetherCard

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

                if store.lookingForSpot != nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding your friends at this coaster…").font(.subheadline)
                    }
                    .card(tint: Theme.lime)
                } else if !browsing {
                    if coaster.isAvailable {
                        Button {
                            nameFocused = false
                            coaster.scan { spot in store.tapSpot(spot, name: name) }
                        } label: {
                            Label("Tap a Huddle coaster", systemImage: "wave.3.right")
                        }
                        .buttonStyle(PrimaryButton(tint: Theme.lime, secondary: Theme.cyan))
                        .disabled(!nameOK)
                        .accessibilityHint("Hold your phone on the NFC coaster in the middle of the table to join everyone there.")
                        if let err = coaster.lastError {
                            Text(err).font(.footnote).foregroundStyle(Theme.pink)
                        }
                    }

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

                privacyNote
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// The headline number: time spent phone-free with friends.
    private var togetherCard: some View {
        VStack(spacing: 6) {
            Text(stats.togetherMinutes == 0 ? "0 min" : stats.togetherLabel)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Theme.lime, Theme.cyan], startPoint: .leading, endPoint: .trailing))
                .contentTransition(.numericText())
            Text(stats.togetherMinutes == 0
                 ? "phone-free with friends. Start your first huddle!"
                 : "phone-free with friends · \(stats.friends.count) \(stats.friends.count == 1 ? "friend" : "friends") · \(stats.huddles) \(stats.huddles == 1 ? "huddle" : "huddles")")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.lime.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var privacyNote: some View {
        Label {
            Text("No accounts. Nothing collected. Huddle talks phone to phone and works without internet.")
        } icon: {
            Image(systemName: "hand.raised.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
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
