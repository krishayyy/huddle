import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import DeviceActivity

/// "Full lock": while a huddle lock runs, every other app and website on this phone is blocked
/// (calls, Messages-to-emergency and Settings stay available because iOS never shields them).
/// Huddle stays usable, so you can still play the games together.
///
/// Uses Apple's Screen Time API, which needs the Family Controls entitlement (see README).
/// A DeviceActivity monitor extension (HuddleMonitor) lifts the lock when the timer ends,
/// even if Huddle was closed or killed in the meantime.
@MainActor
final class ShieldController: ObservableObject {
    @Published private(set) var status: AuthorizationStatus
    @Published private(set) var engaged = false
    @Published var wantsFullLock: Bool {
        didSet { UserDefaults.standard.set(wantsFullLock, forKey: "fullLock") }
    }

    var authorized: Bool { status == .approved }

    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private let activity = DeviceActivityName("huddle.lock")

    init() {
        status = AuthorizationCenter.shared.authorizationStatus
        wantsFullLock = UserDefaults.standard.bool(forKey: "fullLock")
    }

    func requestAccess() async {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) } catch {}
        status = AuthorizationCenter.shared.authorizationStatus
        if !authorized { wantsFullLock = false }
    }

    /// Block everything except Huddle until `end`.
    func engage(until end: Date) {
        guard wantsFullLock, authorized, !engaged else { return }
        store.shield.applicationCategories = .all(except: [])
        store.shield.webDomainCategories = .all(except: [])
        store.application.denyAppRemoval = true                 // can't delete Huddle to escape
        store.dateAndTime.requireAutomaticDateAndTime = true    // can't change the clock to escape
        engaged = true

        // Safety net: the monitor extension clears the lock at `end` even if the app is gone.
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: .now),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false)
        try? center.startMonitoring(activity, during: schedule)   // iOS needs >= 15 min; our shortest lock is 15
    }

    func release() {
        store.clearAllSettings()
        center.stopMonitoring([activity])
        engaged = false
    }
}

#else

@MainActor
final class ShieldController: ObservableObject {
    @Published var wantsFullLock = false
    @Published private(set) var engaged = false
    var authorized: Bool { false }
    func requestAccess() async {}
    func engage(until end: Date) {}
    func release() {}
}

#endif
