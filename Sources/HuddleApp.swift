import SwiftUI

@main
struct HuddleApp: App {
    @StateObject private var store = RoomStore()
    @StateObject private var shield = ShieldController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(shield)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: RoomStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if store.role == .none {
                HomeView()
            } else if store.lockActive && !store.leftLock {
                LockView()
            } else {
                RoomView()
            }
        }
        .animation(.easeInOut, value: store.role)
        .animation(.easeInOut, value: store.lockActive)
    }
}

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.10, green: 0.07, blue: 0.22), Color(red: 0.03, green: 0.10, blue: 0.20)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.35)
    static let card = Color.white.opacity(0.08)
}

struct PrimaryButton: ButtonStyle {
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.black)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
