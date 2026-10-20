import Foundation

/// One day's worth of fresh content: a theme, a featured game, and extra prompts that get
/// mixed in ahead of the built-in ones.
///
/// Where it comes from:
///  1. A small JSON file you update (see content/daily.json). The host's phone downloads it once a
///     day. It's data only, never code, and every string is length-checked and filtered below.
///  2. If the file is missing, offline, or not dated today, Huddle falls back to a built-in
///     weekday rotation, so a stale "trend" is never shown as today's.
///
/// Why curated instead of auto-scraped trends: raw trending content isn't safe or kind enough
/// for teens, and slang goes cringe fast. A human (or you, with Claude's help) approves the file.
struct DailyDrop: Codable, Equatable {
    var date: String                    // yyyy-MM-dd, device-local
    var theme: String
    var emoji: String?
    var featured: GameKind
    var wouldYouRather: [[String]]?     // each item is [a, b]
    var mostLikely: [String]?
    var neverHave: [String]?
    var hotSeat: [String]?
    var actWords: [String]?

    var label: String { "\(emoji ?? "✨") \(theme)" }
}

enum DailyContent {
    /// Your repo's raw file. Change this if you host the JSON somewhere else.
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/kushDCFS/huddle/main/content/daily.json")!

    private static let cacheKey = "daily.cache"

    static func key(for date: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Cached copy if it's for today, else try the network, else the built-in rotation.
    static func load() async -> DailyDrop {
        let today = key()
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(DailyDrop.self, from: data), cached.date == today {
            return cached
        }
        if let fetched = await fetchRemote(today: today) {
            if let data = try? JSONEncoder().encode(fetched) { UserDefaults.standard.set(data, forKey: cacheKey) }
            return fetched
        }
        return fallback()
    }

    private static func fetchRemote(today: String) async -> DailyDrop? {
        var req = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        req.httpMethod = "GET"
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              data.count < 100_000,
              let drop = try? JSONDecoder().decode(DailyDrop.self, from: data),
              drop.date == today else { return nil }
        return sanitized(drop)
    }

    // MARK: Built-in rotation (works offline)

    static func fallback(for date: Date = .now) -> DailyDrop {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)          // 1 = Sunday
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let themes: [Int: (String, String)] = [
            1: ("Deep talk Sunday", "🌙"), 2: ("Fresh start Monday", "🚀"), 3: ("Hot takes Tuesday", "🌶️"),
            4: ("Wild card Wednesday", "🃏"), 5: ("Throwback Thursday", "📼"), 6: ("Friday chaos", "🎉"),
            7: ("Squad night", "🛋️")
        ]
        let t = themes[weekday] ?? ("Huddle day", "✨")
        let kinds = GameKind.allCases
        return DailyDrop(date: key(for: date), theme: t.0, emoji: t.1,
                         featured: kinds[dayOfYear % kinds.count])
    }

    // MARK: Safety filter

    private static let blocked = ["kill", "suicide", "die ", "drug", "weed", "vape", "sex", "nude", "porn", "drunk",
                                  "alcohol", "hate", "racist", "slur", "stupid", "ugly", "fat ", "dumb", "hook up", "hookup"]

    private static func ok(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (3...140).contains(t.count) && !blocked.contains { t.contains($0) }
    }

    private static func clean(_ list: [String]?) -> [String]? {
        guard let list else { return nil }
        let out = list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter(ok).prefix(30)
        return out.isEmpty ? nil : Array(out)
    }

    static func sanitized(_ d: DailyDrop) -> DailyDrop {
        var d = d
        d.theme = String(d.theme.prefix(40))
        d.emoji = d.emoji.map { String($0.prefix(2)) }
        d.wouldYouRather = d.wouldYouRather?.filter { $0.count == 2 && $0.allSatisfy(ok) }.prefix(30).map { $0 }
        d.mostLikely = clean(d.mostLikely)
        d.neverHave = clean(d.neverHave)
        d.hotSeat = clean(d.hotSeat)
        d.actWords = clean(d.actWords)
        return d
    }
}
