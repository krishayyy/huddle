import SwiftUI

// MARK: - Shared room state (host-authoritative, synced to everyone)

struct Member: Codable, Identifiable, Equatable {
    var id: String            // "Name#ab12" – unique per device session
    var bails: Int = 0        // times they left the app during a lock

    var name: String { String(id.split(separator: "#").first ?? "?") }
}

struct LockInfo: Codable, Equatable {
    var startedAt: Date
    var endsAt: Date
    var isActive: Bool { Date() < endsAt }
}

struct RoomState: Codable, Equatable {
    var members: [Member] = []
    var lock: LockInfo?
    var game: Game?
    var feed: [String] = []   // little event log: "Sam peeked 👀"

    func name(of id: String) -> String { members.first { $0.id == id }?.name ?? "Someone" }
}

// MARK: - Games

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case wouldYouRather, hotSeat, twoTruths
    var id: String { rawValue }

    var title: String {
        switch self {
        case .wouldYouRather: "Would You Rather"
        case .hotSeat: "Hot Seat"
        case .twoTruths: "Two Truths & a Lie"
        }
    }
    var emoji: String {
        switch self { case .wouldYouRather: "⚖️"; case .hotSeat: "🔥"; case .twoTruths: "🕵️" }
    }
    var color: Color {
        switch self { case .wouldYouRather: Theme.cyan; case .hotSeat: Theme.orange; case .twoTruths: Theme.lime }
    }
    var blurb: String {
        switch self {
        case .wouldYouRather: "Everyone votes, then argue about it."
        case .hotSeat: "One person answers. Everyone else asks follow-ups."
        case .twoTruths: "Write 3 things about you. Can they spot the lie?"
        }
    }
}

enum Game: Codable, Equatable {
    case wyr(WYR)
    case hotSeat(HotSeat)
    case twoTruths(TwoTruths)

    var kind: GameKind {
        switch self {
        case .wyr: .wouldYouRather
        case .hotSeat: .hotSeat
        case .twoTruths: .twoTruths
        }
    }
}

struct WYR: Codable, Equatable {
    var a: String
    var b: String
    var votes: [String: Int] = [:]     // member id -> 0 or 1
    var revealed = false
}

struct HotSeat: Codable, Equatable {
    var question: String
    var seat: String                   // member id in the hot seat
}

struct TwoTruths: Codable, Equatable {
    enum Phase: String, Codable { case writing, guessing, revealed }
    var author: String
    var phase: Phase = .writing
    var statements: [String] = []
    var lie: Int = 0
    var guesses: [String: Int] = [:]
}

// MARK: - Wire protocol

enum Action: Codable {
    case startLock(minutes: Int)
    case endLock
    case bail
    case startGame(GameKind)
    case stopGame
    case vote(Int)
    case reveal
    case next
    case submitTruths(statements: [String], lie: Int)
    case guess(Int)
}

enum Wire: Codable {
    case state(RoomState)
    case action(Action)
}

// MARK: - Content

enum Prompts {
    static let wouldYouRather: [(String, String)] = [
        ("Have no phone for a month", "Have no friends text you for a month"),
        ("Always be 10 minutes late", "Always be 30 minutes early"),
        ("Only eat pizza forever", "Never eat pizza again"),
        ("Be able to fly", "Be able to read minds"),
        ("Live in a treehouse", "Live on a houseboat"),
        ("Know every language", "Play every instrument"),
        ("Have a pause button for life", "Have a rewind button for life"),
        ("Never have homework again", "Never have a test again"),
        ("Meet your future self", "Meet your past self"),
        ("Have unlimited snacks", "Have unlimited video games"),
        ("Be famous for something silly", "Be unknown but really good at something"),
        ("Talk like a pirate daily", "Whisper everything you say")
    ]

    static let hotSeat: [String] = [
        "What's a small thing that instantly makes your day better?",
        "What's the best thing that happened to you this week?",
        "If you could master any skill overnight, what would it be?",
        "What's a hill you will absolutely die on?",
        "Describe your perfect Saturday, hour by hour.",
        "What's the most underrated song you know?",
        "What's something you changed your mind about recently?",
        "Who's someone you admire and why?",
        "What's your most useless talent?",
        "What would you do with a free day and zero screens?",
        "What's a memory you'd happily relive?",
        "If you started a YouTube channel, what's it about?"
    ]
}
