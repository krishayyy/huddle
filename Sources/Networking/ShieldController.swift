import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings

/// Optional "hard lock": blocks the apps the teen picks while a huddle lock is running,
/// using Apple's Screen Time API. Needs the Family Controls entitlement (see README).
/// Without it, Huddle still works as a social-pressure lock (friends see if you peek).
@MainActor
final class ShieldController: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var authorized = false
    private let store = ManagedSettingsStore()

    func requestAccess() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            authorized = false
        }
    }

    func engage() {
        guard authorized else { return }
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    func release() {
        store.clearAllSettings()
    }
}

#else

@MainActor
final class ShieldController: ObservableObject {
    var authorized: Bool { false }
    func requestAccess() async {}
    func engage() {}
    func release() {}
}

#endif
