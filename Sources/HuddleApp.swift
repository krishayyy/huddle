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
                .tint(Theme.text)
                #if DEBUG
                .onAppear { if CommandLine.arguments.contains("-demoLock") { store.demoLock() } }
                #endif
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: RoomStore
    @EnvironmentObject var shield: ShieldController
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
                Label("Reconnecting…", systemImage: "wifi.exclamationmark")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.text)
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
        // Whenever this phone is no longer in a running lock (host ended it for everyone, the host
        // left, or we bailed), lift the Screen Time block and the Live Activity right away.
        .onChange(of: store.lockActive && !store.leftLock) { _, locked in
            if !locked { shield.release() }
        }
    }
}

/// A short, restrained burst for finishing a lock together: a few ember and cream flecks.
struct Confetti: View {
    @State private var go = false
    private let pieces = (0..<28).map { _ in
        (x: CGFloat.random(in: -170...170), delay: Double.random(in: 0...0.4),
         w: CGFloat.random(in: 3...6), h: CGFloat.random(in: 8...14),
         spin: Double.random(in: -200...200),
         color: [Theme.ember, Theme.text, Theme.sand].randomElement()!)
    }

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 1).fill(p.color).frame(width: p.w, height: p.h)
                    .rotationEffect(.degrees(go ? p.spin : 0))
                    .offset(x: go ? p.x * 1.3 : p.x * 0.15, y: go ? 460 : -30)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 2.4).delay(p.delay), value: go)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { go = true }
    }
}

/// Huddle's design system. Warm near-black, cream type, one ember accent reserved for the lock.
enum Theme {
    // Surfaces
    static let ink = Color(red: 0.047, green: 0.043, blue: 0.039)          // #0C0B0A
    static let surface = Color(red: 0.086, green: 0.082, blue: 0.075)      // #161513
    static let raised = Color(red: 0.118, green: 0.110, blue: 0.102)       // #1E1C1A
    static let hairline = Color.white.opacity(0.08)

    // Type
    static let text = Color(red: 0.953, green: 0.937, blue: 0.906)         // #F3EFE7
    static let muted = Color(red: 0.604, green: 0.580, blue: 0.541)        // #9A948A
    static let faint = Color(red: 0.373, green: 0.353, blue: 0.325)        // #5F5A53

    // Accent + states
    static let ember = Color(red: 1.0, green: 0.353, blue: 0.122)          // #FF5A1F, the lock
    static let moss = Color(red: 0.710, green: 0.851, blue: 0.612)         // #B5D99C, locked in / success
    static let sand = Color(red: 0.831, green: 0.773, blue: 0.541)

    // Muted, earthy person colors for monograms.
    static let people: [Color] = [
        Color(red: 0.910, green: 0.659, blue: 0.486),   // clay
        Color(red: 0.647, green: 0.769, blue: 0.831),   // slate
        Color(red: 0.788, green: 0.714, blue: 0.894),   // lilac
        sand,
        Color(red: 0.624, green: 0.788, blue: 0.659),   // sage
        Color(red: 0.898, green: 0.596, blue: 0.608),   // rose
    ]

    // Older names the game screens use, mapped onto the new palette.
    static let pink = ember
    static let orange = people[0]
    static let yellow = sand
    static let cyan = people[1]
    static let lime = moss
    static let violet = people[2]
    static let accent = ember
    static let card = surface
    static let palette = people

    /// Stable color per person so everyone keeps their own color everywhere.
    static func color(for id: String) -> Color {
        people[id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 997 } % people.count]
    }

    /// Serif display type for big moments: the wordmark, the countdown, the headline stat.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static var background: some View {
        ZStack {
            ink
            // A faint warm glow from the top, like a lamp over the table.
            RadialGradient(colors: [Color(red: 0.25, green: 0.14, blue: 0.08).opacity(0.35), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
        }
    }
}

/// Small uppercase label used to head sections.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A person's initial in their color. Used everywhere a friend appears.
struct Monogram: View {
    let id: String
    var size: CGFloat = 36
    var dimmed = false
    private var name: String { String(id.split(separator: "#").first ?? "?") }

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .background(Theme.color(for: id).opacity(dimmed ? 0.35 : 1), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Primary: solid cream pill. Pass a tint (e.g. Theme.ember) for the one action that matters most.
struct PrimaryButton: ButtonStyle {
    var tint: Color = Theme.text
    var secondary: Color = .clear          // kept for older call sites; unused
    var textColor: Color = Theme.ink
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(style: self, configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let style: PrimaryButton
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(style.tint, in: Capsule())
                .foregroundStyle(style.textColor)
                .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.3)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
                .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
        }
    }
}

extension PrimaryButton {
    /// Secondary: quiet raised pill with a hairline.
    static var light: PrimaryButton { PrimaryButton(tint: Theme.raised, textColor: Theme.text) }
    static var ember: PrimaryButton { PrimaryButton(tint: Theme.ember, textColor: Theme.ink) }
}

extension View {
    /// A quiet grouped surface. The tint only adds a whisper of color so games stay distinct
    /// without turning into a rainbow.
    func card(tint: Color? = nil) -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background((tint ?? .clear).opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
