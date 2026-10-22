import ActivityKit
import Foundation

/// Starts, updates and ends the lock-screen countdown for the current huddle lock.
@MainActor
enum LiveActivityController {
    private static var current: Activity<HuddleActivityAttributes>?

    static func start(group: String, lock: LockInfo, lockedIn: Int, total: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let current, current.attributes.startedAt == lock.startedAt { return }
        end()
        let state = HuddleActivityAttributes.ContentState(endsAt: lock.endsAt, lockedIn: lockedIn, total: total)
        current = try? Activity.request(
            attributes: HuddleActivityAttributes(startedAt: lock.startedAt, groupName: group),
            content: .init(state: state, staleDate: lock.endsAt))
    }

    static func update(lockedIn: Int, total: Int) {
        guard let current else { return }
        var state = current.content.state
        guard state.lockedIn != lockedIn || state.total != total else { return }
        state.lockedIn = lockedIn
        state.total = total
        Task { await current.update(.init(state: state, staleDate: state.endsAt)) }
    }

    static func end() {
        let ending = current ?? Activity<HuddleActivityAttributes>.activities.first
        current = nil
        for a in Activity<HuddleActivityAttributes>.activities where a.id != ending?.id {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        if let ending { Task { await ending.end(nil, dismissalPolicy: .immediate) } }
    }
}
