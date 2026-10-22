import ActivityKit
import Foundation

/// Shared by the app and the widget extension: what the lock screen / Dynamic Island shows
/// while a huddle lock is running.
struct HuddleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endsAt: Date
        var lockedIn: Int      // people who haven't peeked
        var total: Int
    }

    var startedAt: Date
    var groupName: String      // "Maya's huddle"
}
