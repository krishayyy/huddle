import DeviceActivity
import ManagedSettings

/// Runs in the background (separate process). Lifts the full lock when the huddle timer ends,
/// so friends are never stuck locked out if Huddle was closed.
final class HuddleMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        ManagedSettingsStore().clearAllSettings()
    }
}
