import SwiftUI

@main
struct HuddleApp: App {
    @StateObject private var store = RoomStore()
    @StateObject private var shield = ShieldController()
    @StateObject private var stats = FocusStats()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(shield)
                .environmentObject(stats)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: RoomStore
    @Environment(\.scenePhase) private var scenePhase

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
        .overlay(alignment: .top) {
            if store.reconnecting {
                Label("Reconnecting to your huddle…", systemImage: "wifi.exclamationmark")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut, value: store.role)
        .animation(.easeInOut, value: store.lockActive)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reconnectIfNeeded() }
        }
    }
}

/// A short burst of pastel confetti for finishing a lock together.
struct Confetti: View {
    @State private var go = false
    private let pieces = (0..<36).map { _ in
        (x: CGFloat.random(in: -170...170), delay: Double.random(in: 0...0.5),
         size: CGFloat.random(in: 6...12), color: Theme.palette.randomElement()!)
    }

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                Circle().fill(p.color).frame(width: p.size, height: p.size)
                    .offset(x: go ? p.x * 1.4 : p.x * 0.2, y: go ? 420 : -40)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 2.2).delay(p.delay), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}

enum Theme {
    static let pink = Color(red: 1.0, green: 0.72, blue: 0.88)
    static let orange = Color(red: 1.0, green: 0.80, blue: 0.70)
    static let yellow = Color(red: 1.0, green: 0.95, blue: 0.76)
    static let cyan = Color(red: 0.62, green: 0.86, blue: 1.0)
    static let lime = Color(red: 0.66, green: 0.96, blue: 0.84)
    static let violet = Color(red: 0.76, green: 0.68, blue: 1.0)

    static let accent = pink
    static let card = Color.white.opacity(0.10)
    static let palette: [Color] = [pink, cyan, yellow, lime, violet, orange]

    /// Stable color per person so everyone keeps their own color everywhere.
    static func color(for id: String) -> Color {
        palette[id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 997 } % palette.count]
    }

    static var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.12), Color(red: 0.03, green: 0.04, blue: 0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(violet.opacity(0.35)).frame(width: 340).blur(radius: 110).offset(x: -140, y: -280)
            Circle().fill(cyan.opacity(0.22)).frame(width: 320).blur(radius: 110).offset(x: 160, y: 320)
            Circle().fill(pink.opacity(0.14)).frame(width: 240).blur(radius: 100).offset(x: 150, y: -80)
        }
    }
}

struct PrimaryButton: ButtonStyle {
    var tint: Color = Theme.violet
    var secondary: Color = Theme.cyan
    var textColor: Color = Color(red: 0.08, green: 0.07, blue: 0.16)
    func makeBody(configuration: Configuration) -> some View {
        Body(style: self, configuration: configuration)
    }

    private struct Body: View {
        let style: PrimaryButton
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)      // 48pt+ tap target
                .padding(.vertical, 4)
                .background(
                    LinearGradient(colors: [style.tint, style.secondary], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(style.textColor)
                .shadow(color: style.tint.opacity(enabled ? 0.35 : 0), radius: 16, y: 4)   // soft glow
                .opacity(enabled ? 1 : 0.4)                    // disabled must look disabled
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(duration: 0.18), value: configuration.isPressed)
                .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
        }
    }
}

extension PrimaryButton {
    static var light: PrimaryButton { PrimaryButton(tint: .white.opacity(0.9), secondary: .white.opacity(0.7)) }
}

extension View {
    func card(tint: Color? = nil) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((tint ?? .white).opacity(tint == nil ? 0.06 : 0.12),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((tint ?? .white).opacity(tint == nil ? 0.12 : 0.35), lineWidth: 1))
    }
}
