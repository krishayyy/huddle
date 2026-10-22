import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var stats: FocusStats
    @StateObject private var coaster = CoasterReader()
    @AppStorage("displayName") private var name = ""
    @State private var browsing = false
    @FocusState private var nameFocused: Bool

    private var nameOK: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 28)

                together
                    .padding(.top, 44)

                nameField
                    .padding(.top, 40)

                Group {
                    if store.lookingForSpot != nil {
                        findingAtCoaster
                    } else if browsing {
                        nearbyList
                    } else {
                        actions
                    }
                }
                .padding(.top, 16)
                .animation(.snappy, value: browsing)

                privacyNote
                    .padding(.top, 36)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("huddle")
                .font(Theme.display(44, weight: .medium))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text("Phones down, together.")
                .font(.body)
                .foregroundStyle(Theme.muted)
        }
    }

    /// The one number that matters: time spent phone-free with friends.
    private var together: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Phone-free with friends")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(stats.togetherMinutes == 0 ? "0" : headlineNumber)
                    .font(Theme.display(72, weight: .light))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text(headlineUnit)
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.muted)
            }
            Text(statLine)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Your name")
            TextField("", text: $name, prompt: Text("What friends call you").foregroundStyle(Theme.faint))
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.title3)
                .foregroundStyle(Theme.text)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(nameFocused ? Theme.text.opacity(0.6) : Theme.hairline).frame(height: 1)
                }
                .accessibilityLabel("Your name")
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if coaster.isAvailable {
                Button {
                    nameFocused = false
                    coaster.scan { spot in store.tapSpot(spot, name: name) }
                } label: {
                    Label("Tap the coaster", systemImage: "wave.3.right")
                }
                .buttonStyle(PrimaryButton.ember)
                .disabled(!nameOK)
                .accessibilityHint("Hold your phone on the NFC coaster in the middle of the table to join everyone there.")
            }

            Button("Start a huddle") {
                nameFocused = false
                store.host(name: name)
            }
            .buttonStyle(coaster.isAvailable ? PrimaryButton() : PrimaryButton.ember)
            .disabled(!nameOK)

            Button("Join friends nearby") {
                nameFocused = false
                browsing = true
                store.findRooms(name: name)
            }
            .buttonStyle(PrimaryButton.light)
            .disabled(!nameOK)

            if let err = coaster.lastError {
                Text(err).font(.footnote).foregroundStyle(Theme.ember)
            } else if !nameOK {
                Text("Add your name so friends know it's you.")
                    .font(.footnote).foregroundStyle(Theme.faint)
                    .padding(.top, 4)
            }
        }
    }

    private var findingAtCoaster: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.ember)
            Text("Finding everyone at this coaster…").font(.subheadline).foregroundStyle(Theme.text)
            Spacer()
        }
        .card()
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Nearby")
                Spacer()
                Button("Cancel") {
                    browsing = false
                    store.leave()          // stops browsing and resets
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44)
            }

            if store.nearby.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ProgressView().tint(Theme.muted)
                    Text("Looking for huddles. Ask a friend to start one, and keep Bluetooth and Wi‑Fi on.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 8)
            }
            if store.joinFailed {
                Text("Couldn't join that huddle. Try again.")
                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.ember)
            }

            VStack(spacing: 0) {
                ForEach(Array(store.nearby.enumerated()), id: \.element.id) { idx, room in
                    Button {
                        store.join(room)
                    } label: {
                        HStack(spacing: 12) {
                            Monogram(id: room.peer.displayName, size: 34)
                            Text(room.name).font(.body.weight(.medium)).foregroundStyle(Theme.text)
                            Spacer()
                            if store.connecting {
                                ProgressView().tint(Theme.muted)
                            } else {
                                Image(systemName: "arrow.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.connecting)
                    if idx < store.nearby.count - 1 { Divider().overlay(Theme.hairline) }
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield").foregroundStyle(Theme.faint)
            Text("No accounts. Nothing collected. Huddle talks phone to phone and works without internet.")
                .font(.caption)
                .foregroundStyle(Theme.faint)
        }
    }

    // MARK: Copy

    private var headlineNumber: String {
        let m = stats.togetherMinutes
        if m < 60 { return "\(m)" }
        let h = Double(m) / 60
        return h < 10 ? String(format: "%.1f", h) : String(format: "%.0f", h)
    }

    private var headlineUnit: String {
        let m = stats.togetherMinutes
        if m < 60 { return m == 1 ? "minute" : "minutes" }
        return m == 60 ? "hour" : "hours"
    }

    private var statLine: String {
        guard stats.huddles > 0 else { return "Start a huddle to begin counting." }
        let f = stats.friends.count, h = stats.huddles
        return "\(f) \(f == 1 ? "friend" : "friends") · \(h) \(h == 1 ? "huddle" : "huddles") · \(stats.streak) day streak"
    }
}
