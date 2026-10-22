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
    var scores: [String: Int] = [:]   // game points per member id
    var feed: [String] = []           // little event log: "Sam peeked 👀"
    var dailyTheme: String?           // e.g. "🎃 Spooky season" (from DailyContent)
    var featured: GameKind?           // today's featured game

    func name(of id: String) -> String { members.first { $0.id == id }?.name ?? "Someone" }
}

// MARK: - Games
//
// Design rules every game follows (from what works for teens in person):
//  1. The phone is the referee, not the show: short text, so people look up and talk.
//  2. Everyone plays every round (no sitting out waiting for a turn).
//  3. There's a reveal moment that gets a reaction.
//  4. Rounds are about a minute, and the next round is one tap away.
//  5. Low-stakes: you can always pass, nobody is put on the spot with mean content.

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case imposter, mostLikely, neverHave, wouldYouRather, actItOut, twoTruths, hotSeat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .imposter: "Imposter"
        case .mostLikely: "Most Likely To"
        case .neverHave: "Never Have I Ever"
        case .wouldYouRather: "Would You Rather"
        case .actItOut: "Act It Out"
        case .twoTruths: "Two Truths & a Lie"
        case .hotSeat: "Hot Seat"
        }
    }
    var emoji: String {
        switch self {
        case .imposter: "🕵️"
        case .mostLikely: "👑"
        case .neverHave: "🙈"
        case .wouldYouRather: "⚖️"
        case .actItOut: "🎭"
        case .twoTruths: "🤥"
        case .hotSeat: "🔥"
        }
    }
    /// SF Symbol used in the interface (emoji stay in the prompts, not the chrome).
    var symbol: String {
        switch self {
        case .imposter: "eye.slash"
        case .mostLikely: "crown"
        case .neverHave: "hand.raised"
        case .wouldYouRather: "arrow.left.arrow.right"
        case .actItOut: "theatermasks"
        case .twoTruths: "questionmark.bubble"
        case .hotSeat: "flame"
        }
    }
    var color: Color {
        switch self {
        case .imposter: Theme.pink
        case .mostLikely: Theme.yellow
        case .neverHave: Theme.lime
        case .wouldYouRather: Theme.cyan
        case .actItOut: Theme.orange
        case .twoTruths: Theme.violet
        case .hotSeat: Theme.pink
        }
    }
    var blurb: String {
        switch self {
        case .imposter: "One of you doesn't know the word. Find them."
        case .mostLikely: "Vote for the friend who fits. Reveal. Chaos."
        case .neverHave: "Tap if you have. See who's lying."
        case .wouldYouRather: "Everyone picks, then you argue about it."
        case .actItOut: "No talking. 60 seconds. Get the group to guess."
        case .twoTruths: "Write 3 things about you. Spot the lie."
        case .hotSeat: "One person answers. Everyone asks follow-ups."
        }
    }
    var minPlayers: Int { self == .imposter ? 3 : 2 }
}

enum Game: Codable, Equatable {
    case wyr(WYR)
    case mostLikely(MostLikely)
    case neverHave(NeverHave)
    case hotSeat(HotSeat)
    case twoTruths(TwoTruths)
    case actItOut(ActItOut)
    case imposter(Imposter)

    var kind: GameKind {
        switch self {
        case .wyr: .wouldYouRather
        case .mostLikely: .mostLikely
        case .neverHave: .neverHave
        case .hotSeat: .hotSeat
        case .twoTruths: .twoTruths
        case .actItOut: .actItOut
        case .imposter: .imposter
        }
    }
}

struct WYR: Codable, Equatable {
    var a: String
    var b: String
    var talk: String                   // "say it out loud" prompt shown at reveal
    var votes: [String: Int] = [:]     // member id -> 0 or 1
    var revealed = false
}

struct MostLikely: Codable, Equatable {
    var prompt: String
    var talk: String
    var votes: [String: String] = [:]  // voter id -> chosen member id
    var revealed = false
}

struct NeverHave: Codable, Equatable {
    var prompt: String
    var talk: String
    var haves: [String: Bool] = [:]    // member id -> true if they have
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

struct ActItOut: Codable, Equatable {
    enum Phase: String, Codable { case ready, running, done }
    var actor: String
    var word: String
    var phase: Phase = .ready
    var endsAt: Date?
    var got = 0
    var passed = 0
    var seconds = 60
}

struct Imposter: Codable, Equatable {
    enum Phase: String, Codable { case clues, voting, revealed }
    var category: String
    var word: String
    var imposter: String
    var order: [String]                // speaking order for the clue round
    var phase: Phase = .clues
    var votes: [String: String] = [:]
    var caught = false
}

// MARK: - Wire protocol

enum Action: Codable {
    case startLock(minutes: Int)
    case endLock
    case bail
    case startGame(GameKind)
    case stopGame
    case vote(Int)
    case voteFor(String)
    case answerHave(Bool)
    case reveal
    case next
    case reroll
    case submitTruths(statements: [String], lie: Int)
    case guess(Int)
    case startRound
    case gotIt
    case skipWord
    case startVoting
}

enum Wire: Codable {
    case state(RoomState)
    case action(Action)
}

// MARK: - Content (all wholesome, nobody gets embarrassed for real)

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
        ("Talk like a pirate daily", "Whisper everything you say"),
        ("Have a personal chef", "Have a personal driver"),
        ("Be the funniest in the room", "Be the smartest in the room"),
        ("Go back 100 years", "Go forward 100 years"),
        ("Always have to sing instead of talk", "Always have to dance instead of walk"),
        ("Have a pet dragon", "Have a pet robot"),
        ("Never see snow again", "Never see the sun again")
    ]

    static let mostLikely: [String] = [
        "Most likely to become famous",
        "Most likely to survive a zombie apocalypse",
        "Most likely to text back instantly",
        "Most likely to cry at a movie",
        "Most likely to get lost with GPS on",
        "Most likely to start a business",
        "Most likely to adopt 10 pets",
        "Most likely to fall asleep first at a sleepover",
        "Most likely to win a game show",
        "Most likely to be late to their own birthday",
        "Most likely to talk to a stranger and make a friend",
        "Most likely to eat the last slice",
        "Most likely to laugh at the wrong moment",
        "Most likely to become president",
        "Most likely to go viral",
        "Most likely to hide in a closet during hide-and-seek and win"
    ]

    static let neverHave: [String] = [
        "Never have I ever fallen asleep in class",
        "Never have I ever sent a text to the wrong person",
        "Never have I ever pretended to like a song to fit in",
        "Never have I ever eaten food that fell on the floor",
        "Never have I ever laughed so hard I cried",
        "Never have I ever stayed up all night",
        "Never have I ever forgotten someone's name right after hearing it",
        "Never have I ever walked into a glass door",
        "Never have I ever practiced a conversation in the mirror",
        "Never have I ever waved at someone who wasn't waving at me",
        "Never have I ever binge-watched a whole season in a day",
        "Never have I ever gotten lost somewhere I should know",
        "Never have I ever sung in the shower",
        "Never have I ever lied about having seen a movie"
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
        "If you started a YouTube channel, what's it about?",
        "What's the best advice you've ever gotten?",
        "What's something you're weirdly proud of?",
        "What would your theme song be?"
    ]

    /// Shown after reveals so people look up and keep talking instead of staring at the phone.
    static let talkBacks: [String] = [
        "Out loud: who surprised you most, and why?",
        "Out loud: defend your answer in one sentence.",
        "Out loud: tell a quick story that explains your pick.",
        "Out loud: who do you think had the most unpopular answer?",
        "Out loud: what would change your mind?"
    ]

    static let actWords: [String] = [
        "Shark", "Selfie", "Skateboard", "Pizza chef", "Robot", "Dentist", "Karaoke", "Zombie",
        "Basketball", "Ice skating", "Cat", "Giving a TED talk", "Cooking", "Superhero", "Surfing",
        "Brushing teeth", "Taking a test", "Dinosaur", "Playing guitar", "Sleepwalking", "Magician",
        "Photographer", "Lost in a maze", "Eating spicy food", "Walking a dog"
    ]

    static let imposter: [(String, [String])] = [
        ("Food", ["Pizza", "Tacos", "Sushi", "Pancakes", "Ice cream", "Burger"]),
        ("Place", ["Beach", "School", "Airport", "Library", "Mall", "Zoo"]),
        ("Animal", ["Dolphin", "Panda", "Eagle", "Octopus", "Fox", "Penguin"]),
        ("Hobby", ["Gaming", "Drawing", "Skating", "Cooking", "Dancing", "Photography"]),
        ("Movie genre", ["Horror", "Comedy", "Romance", "Superhero", "Animation", "Mystery"]),
        ("Job", ["Pilot", "Chef", "Teacher", "Firefighter", "Vet", "Streamer"])
    ]
}
