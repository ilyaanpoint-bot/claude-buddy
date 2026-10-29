// Shared constants, the unlock catalogue, and XP / save-file handling.

import AppKit

let buddyDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claude-buddy")
let eventsURL = buddyDir.appendingPathComponent("events.jsonl")
let saveURL = ProcessInfo.processInfo.environment["BUDDY_SAVE"].map { URL(fileURLWithPath: $0) } ?? buddyDir.appendingPathComponent("save.json")

private let appStart = CACurrentMediaTime()
func now() -> Double { CACurrentMediaTime() - appStart }

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let claudeOrange = rgb(0xD97757)
let friendBlue = rgb(0x548FEB)
let sparkYellow = rgb(0xFAC75C)
let faceColor = rgb(0x2E1A14)

enum Mood { case idle, working, attention }

// MARK: - Catalogue

enum ItemKind: String { case skin, hat, room, decor }

struct Item {
    let id: String
    let kind: ItemKind
    let name: String
    let level: Int?        // nil = secret, unlocked by doing something
    let hint: String
}

let catalog: [Item] = [
    Item(id: "classic", kind: .skin, name: "Classic", level: 1, hint: ""),
    Item(id: "sky", kind: .skin, name: "Sky", level: 1, hint: ""),
    Item(id: "mint", kind: .skin, name: "Mint", level: 3, hint: ""),
    Item(id: "grape", kind: .skin, name: "Grape", level: 5, hint: ""),
    Item(id: "midnight", kind: .skin, name: "Midnight", level: 8, hint: ""),
    Item(id: "gold", kind: .skin, name: "Golden", level: 12, hint: ""),
    Item(id: "rainbow", kind: .skin, name: "Rainbow", level: nil, hint: "Try being root."),
    Item(id: "ghost", kind: .skin, name: "Ghost", level: nil, hint: "Say something spooky in the console."),
    Item(id: "devil", kind: .skin, name: "Little Devil", level: nil, hint: "Make buddy REALLY angry."),
    Item(id: "slime", kind: .skin, name: "Slime", level: nil, hint: "Too much of a good thing…"),

    Item(id: "none", kind: .hat, name: "No hat", level: 1, hint: ""),
    Item(id: "party", kind: .hat, name: "Party hat", level: 2, hint: ""),
    Item(id: "beanie", kind: .hat, name: "Beanie", level: 4, hint: ""),
    Item(id: "headphones", kind: .hat, name: "Headphones", level: 6, hint: ""),
    Item(id: "wizard", kind: .hat, name: "Wizard hat", level: 9, hint: ""),
    Item(id: "crown", kind: .hat, name: "Crown", level: 15, hint: ""),
    Item(id: "propeller", kind: .hat, name: "Propeller cap", level: nil, hint: "Make buddy dizzy."),
    Item(id: "chef", kind: .hat, name: "Chef hat", level: nil, hint: "Feed buddy 10 cookies."),
    Item(id: "nightcap", kind: .hat, name: "Nightcap", level: nil, hint: "Keep poking a sleeping buddy."),
    Item(id: "horns", kind: .hat, name: "Devil horns", level: nil, hint: "Defuse 5 bombs in one tantrum."),
    Item(id: "headband", kind: .hat, name: "Headband", level: nil, hint: "Reach round 8 in Copycat."),

    Item(id: "studio", kind: .room, name: "Cozy Studio", level: 1, hint: ""),
    Item(id: "greenhouse", kind: .room, name: "Greenhouse", level: 7, hint: ""),
    Item(id: "space", kind: .room, name: "Space Station", level: 11, hint: ""),
    Item(id: "beach", kind: .room, name: "Beach Hut", level: nil, hint: "Score 20 in Bug Catch."),

    Item(id: "plant", kind: .decor, name: "Plant", level: 2, hint: ""),
    Item(id: "poster", kind: .decor, name: "Poster", level: 3, hint: ""),
    Item(id: "lamp", kind: .decor, name: "Desk lamp", level: 4, hint: ""),
    Item(id: "shelf", kind: .decor, name: "Bookshelf", level: 5, hint: ""),
    Item(id: "rug", kind: .decor, name: "Rug", level: 6, hint: ""),
    Item(id: "fishtank", kind: .decor, name: "Fish tank", level: 8, hint: ""),
    Item(id: "records", kind: .decor, name: "Record player", level: 10, hint: ""),
    Item(id: "arcade", kind: .decor, name: "Arcade cabinet", level: 13, hint: ""),
    Item(id: "neon", kind: .decor, name: "Neon sign", level: 14, hint: ""),
    Item(id: "cat", kind: .decor, name: "Byte the cat", level: 18, hint: ""),
]

func item(_ id: String) -> Item? { catalog.first { $0.id == id } }

struct Achievement { let id: String; let name: String; let hint: String; let xp: Int }

let achievements: [Achievement] = [
    Achievement(id: "dizzy", name: "Dizzy!", hint: "Click buddy's head five times, fast.", xp: 30),
    Achievement(id: "whee", name: "Wheee!", hint: "Shake buddy around.", xp: 30),
    Achievement(id: "cookies", name: "Cookie Monster", hint: "Feed 10 cookies.", xp: 40),
    Achievement(id: "root", name: "Root Access", hint: "Type a very powerful command.", xp: 50),
    Achievement(id: "boo", name: "Spooky", hint: "Scare buddy.", xp: 30),
    Achievement(id: "grumpy", name: "Five More Minutes", hint: "Bother buddy while it sleeps.", xp: 30),
    Achievement(id: "night", name: "Night Shift", hint: "Finish a session between midnight and 5am.", xp: 50),
    Achievement(id: "marathon", name: "Marathon", hint: "Finish 10 sessions in one day.", xp: 100),
    Achievement(id: "squasher", name: "Bug Squasher", hint: "Score 20 in Bug Catch.", xp: 50),
    Achievement(id: "xyzzy", name: "Adventurer", hint: "An old magic word.", xp: 20),
    Achievement(id: "rage", name: "Unleashed", hint: "Push buddy over the edge.", xp: 60),
    Achievement(id: "defuse", name: "Bomb Squad", hint: "Defuse 5 bombs in one tantrum.", xp: 60),
    Achievement(id: "sick", name: "Tummy Ache", hint: "Too many cookies.", xp: 30),
    Achievement(id: "yeet", name: "Yeet!", hint: "Fling buddy across the screen.", xp: 30),
    Achievement(id: "squish", name: "Stress Ball", hint: "Squish buddy.", xp: 20),
    Achievement(id: "tickle", name: "Tickle Monster", hint: "Wiggle the cursor on buddy.", xp: 20),
    Achievement(id: "tease", name: "Rude!", hint: "Take back a cookie.", xp: 20),
    Achievement(id: "copycat", name: "Copycat Champ", hint: "Reach round 8 in Copycat.", xp: 60),
]

// MARK: - Save data

struct SaveData: Codable {
    var xp = 0
    var unlocked: [String] = []
    var achievements: [String] = []
    var skin = "classic"
    var hat = "none"
    var room = "studio"
    var cookies = 0
    var sessions = 0
    var pets = 0
    var bestScore = 0
    var day = ""
    var toolXPToday = 0
    var cookiesToday = 0
    var sessionsToday = 0

    init() {}

    // Tolerates missing keys so older save files keep loading as fields are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decode(T.self, forKey: k)) ?? d }
        xp = get(.xp, 0); unlocked = get(.unlocked, []); achievements = get(.achievements, [])
        skin = get(.skin, "classic"); hat = get(.hat, "none"); room = get(.room, "studio")
        cookies = get(.cookies, 0); sessions = get(.sessions, 0); pets = get(.pets, 0)
        bestScore = get(.bestScore, 0); day = get(.day, "")
        toolXPToday = get(.toolXPToday, 0); cookiesToday = get(.cookiesToday, 0); sessionsToday = get(.sessionsToday, 0)
    }
}

final class BuddyProgress {
    static let shared = BuddyProgress()

    private(set) var data: SaveData
    var onLevelUp: ((Int, [Item]) -> Void)?
    var onAchievement: ((Achievement, Item?) -> Void)?

    private init() {
        data = (try? JSONDecoder().decode(SaveData.self, from: Data(contentsOf: saveURL))) ?? SaveData()
    }

    /// Re-reads the save file (used by other apps, like Isle, that only display buddy).
    func reload() {
        if let d = try? JSONDecoder().decode(SaveData.self, from: Data(contentsOf: saveURL)) { data = d }
    }

    static func xpNeeded(_ level: Int) -> Int { 25 * (level - 1) * level }   // L2 50, L5 500, L10 2250

    var level: Int {
        var l = 1
        while data.xp >= BuddyProgress.xpNeeded(l + 1) { l += 1 }
        return l
    }

    var levelFraction: Double {
        let lo = BuddyProgress.xpNeeded(level), hi = BuddyProgress.xpNeeded(level + 1)
        return Double(data.xp - lo) / Double(hi - lo)
    }

    func isUnlocked(_ it: Item) -> Bool {
        if let l = it.level { return level >= l }
        return data.unlocked.contains(it.id)
    }

    func has(_ id: String) -> Bool { item(id).map(isUnlocked) ?? false }

    func hasAchievement(_ id: String) -> Bool { data.achievements.contains(id) }

    func award(_ xp: Int) {
        guard xp > 0 else { return }
        let before = level
        data.xp += xp
        save()
        let after = level
        if after > before {
            let fresh = catalog.filter { ($0.level ?? 0) > before && ($0.level ?? 0) <= after }
            onLevelUp?(after, fresh)
        }
    }

    /// Grants an achievement (once) and the secret item tied to it, if any.
    func achieve(_ id: String, unlocking itemID: String? = nil) {
        guard let a = achievements.first(where: { $0.id == id }), !data.achievements.contains(id) else { return }
        data.achievements.append(id)
        var it: Item?
        if let itemID, !data.unlocked.contains(itemID) { data.unlocked.append(itemID); it = item(itemID) }
        save()
        onAchievement?(a, it)
        award(a.xp)
    }

    func equip(_ it: Item) {
        guard isUnlocked(it) else { return }
        switch it.kind {
        case .skin: data.skin = it.id
        case .hat: data.hat = it.id
        case .room: data.room = it.id
        case .decor: return
        }
        save()
    }

    /// Resets the per-day counters when the date changes.
    private func rollDay() {
        let d = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        if d != data.day { data.day = d; data.toolXPToday = 0; data.cookiesToday = 0; data.sessionsToday = 0 }
    }

    func toolUsed() {
        rollDay()
        guard data.toolXPToday < 80 else { return }
        data.toolXPToday += 1
        award(1)
    }

    /// Returns the XP earned for a finished session (with first-of-the-day bonus).
    @discardableResult
    func sessionFinished() -> Int {
        rollDay()
        data.sessions += 1
        data.sessionsToday += 1
        let xp = data.sessionsToday == 1 ? 45 : 25
        award(xp)
        if Calendar.current.component(.hour, from: Date()) < 5 { achieve("night") }
        if data.sessionsToday >= 10 { achieve("marathon") }
        return xp
    }

    /// Returns false when buddy is too full for more cookies today.
    func fedCookie() -> Bool {
        rollDay()
        data.cookies += 1
        if data.cookies >= 10 { achieve("cookies", unlocking: "chef") }
        guard data.cookiesToday < 12 else { save(); return false }
        data.cookiesToday += 1
        award(2)
        return true
    }

    func petted() { data.pets += 1; award(1) }

    func gameOver(score: Int) {
        if score > data.bestScore { data.bestScore = score }
        if score >= 20 { achieve("squasher", unlocking: "beach") }
        award(min(60, max(0, score)))
        save()
    }

    func save() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: saveURL, options: .atomic) }
    }
}
