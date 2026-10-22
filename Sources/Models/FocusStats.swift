import Foundation

/// Personal focus stats, stored on-device only: total minutes, a daily streak, and the time
/// spent phone-free together with friends. Only locks finished without peeking count.
@MainActor
final class FocusStats: ObservableObject {
    @Published private(set) var totalMinutes: Int
    @Published private(set) var streak: Int
    @Published private(set) var togetherMinutes: Int    // minutes × friends in the room
    @Published private(set) var huddles: Int
    @Published private(set) var friends: Set<String>    // display names only, never leaves the phone
    private var lastDay: Date?
    private let defaults = UserDefaults.standard

    init() {
        totalMinutes = defaults.integer(forKey: "focus.total")
        streak = defaults.integer(forKey: "focus.streak")
        togetherMinutes = defaults.integer(forKey: "focus.together")
        huddles = defaults.integer(forKey: "focus.huddles")
        friends = Set(defaults.stringArray(forKey: "focus.friends") ?? [])
        lastDay = defaults.object(forKey: "focus.lastDay") as? Date
    }

    /// Friendly score out of 100 that grows with focused time.
    var score: Int { min(100, totalMinutes / 6) }

    /// "6.5 hrs" / "45 min": the headline number on Home.
    var togetherLabel: String {
        togetherMinutes < 60 ? "\(togetherMinutes) min"
            : String(format: togetherMinutes < 600 ? "%.1f hrs" : "%.0f hrs", Double(togetherMinutes) / 60)
    }

    func recordCompletedLock(minutes: Int, with others: [String] = []) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if let last = lastDay.map({ cal.startOfDay(for: $0) }) {
            let gap = cal.dateComponents([.day], from: last, to: today).day ?? 0
            if gap == 1 { streak += 1 } else if gap > 1 { streak = 1 }
        } else {
            streak = 1
        }
        lastDay = today
        totalMinutes += minutes
        togetherMinutes += minutes * max(1, others.count)
        huddles += 1
        friends.formUnion(others)
        defaults.set(totalMinutes, forKey: "focus.total")
        defaults.set(streak, forKey: "focus.streak")
        defaults.set(togetherMinutes, forKey: "focus.together")
        defaults.set(huddles, forKey: "focus.huddles")
        defaults.set(Array(friends), forKey: "focus.friends")
        defaults.set(lastDay, forKey: "focus.lastDay")
    }
}
