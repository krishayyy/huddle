import Foundation

/// Personal focus stats, stored on-device only: total minutes and a daily streak.
/// Only locks finished without peeking count.
@MainActor
final class FocusStats: ObservableObject {
    @Published private(set) var totalMinutes: Int
    @Published private(set) var streak: Int
    private var lastDay: Date?
    private let defaults = UserDefaults.standard

    init() {
        totalMinutes = defaults.integer(forKey: "focus.total")
        streak = defaults.integer(forKey: "focus.streak")
        lastDay = defaults.object(forKey: "focus.lastDay") as? Date
    }

    /// Friendly score out of 100 that grows with focused time.
    var score: Int { min(100, totalMinutes / 6) }

    func recordCompletedLock(minutes: Int) {
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
        defaults.set(totalMinutes, forKey: "focus.total")
        defaults.set(streak, forKey: "focus.streak")
        defaults.set(lastDay, forKey: "focus.lastDay")
    }
}
