// Shared constants, the unlock catalogue, the shop, daily quests, and XP / coins / save-file handling.

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

enum ItemKind: String { case skin, hat, accessory, room, decor, wallpaper, floor }

struct Item {
    let id: String
    let kind: ItemKind
    let name: String
    let level: Int?        // nil = secret (unlocked by doing something) or sold in the shop
    let hint: String
    var price: Int? = nil  // sold in the shop for this many coins
}

let catalog: [Item] = [
    // Skins
    Item(id: "classic", kind: .skin, name: "Classic", level: 1, hint: ""),
    Item(id: "sky", kind: .skin, name: "Sky", level: 1, hint: ""),
    Item(id: "bubblegum", kind: .skin, name: "Bubblegum", level: 2, hint: ""),
    Item(id: "mint", kind: .skin, name: "Mint", level: 3, hint: ""),
    Item(id: "grape", kind: .skin, name: "Grape", level: 5, hint: ""),
    Item(id: "ocean", kind: .skin, name: "Ocean", level: 6, hint: ""),
    Item(id: "midnight", kind: .skin, name: "Midnight", level: 8, hint: ""),
    Item(id: "strawberry", kind: .skin, name: "Strawberry", level: 10, hint: ""),
    Item(id: "gold", kind: .skin, name: "Golden", level: 12, hint: ""),
    Item(id: "panda", kind: .skin, name: "Panda", level: 16, hint: ""),
    Item(id: "lava", kind: .skin, name: "Lava", level: 20, hint: ""),
    Item(id: "robot", kind: .skin, name: "Robot", level: nil, hint: "", price: 180),
    Item(id: "galaxy", kind: .skin, name: "Galaxy", level: nil, hint: "", price: 260),
    Item(id: "rainbow", kind: .skin, name: "Rainbow", level: nil, hint: "Try being root."),
    Item(id: "ghost", kind: .skin, name: "Ghost", level: nil, hint: "Say something spooky in the console."),
    Item(id: "devil", kind: .skin, name: "Little Devil", level: nil, hint: "Make buddy REALLY angry."),
    Item(id: "slime", kind: .skin, name: "Slime", level: nil, hint: "Too much of a good thing…"),
    Item(id: "cookie", kind: .skin, name: "Cookie", level: nil, hint: "Feed buddy 100 cookies."),
    Item(id: "shadow", kind: .skin, name: "Shadow", level: nil, hint: "Visit the room at 3 in the morning."),

    // Hats
    Item(id: "none", kind: .hat, name: "No hat", level: 1, hint: ""),
    Item(id: "party", kind: .hat, name: "Party hat", level: 2, hint: ""),
    Item(id: "bow", kind: .hat, name: "Bow", level: 3, hint: ""),
    Item(id: "beanie", kind: .hat, name: "Beanie", level: 4, hint: ""),
    Item(id: "headphones", kind: .hat, name: "Headphones", level: 6, hint: ""),
    Item(id: "cowboy", kind: .hat, name: "Cowboy hat", level: 7, hint: ""),
    Item(id: "wizard", kind: .hat, name: "Wizard hat", level: 9, hint: ""),
    Item(id: "grad", kind: .hat, name: "Grad cap", level: 11, hint: ""),
    Item(id: "flower", kind: .hat, name: "Flower crown", level: 13, hint: ""),
    Item(id: "crown", kind: .hat, name: "Crown", level: 15, hint: ""),
    Item(id: "santa", kind: .hat, name: "Santa hat", level: nil, hint: "", price: 90),
    Item(id: "pirate", kind: .hat, name: "Pirate hat", level: nil, hint: "", price: 120),
    Item(id: "viking", kind: .hat, name: "Viking helmet", level: nil, hint: "", price: 150),
    Item(id: "halo", kind: .hat, name: "Halo", level: nil, hint: "", price: 200),
    Item(id: "propeller", kind: .hat, name: "Propeller cap", level: nil, hint: "Make buddy dizzy."),
    Item(id: "chef", kind: .hat, name: "Chef hat", level: nil, hint: "Feed buddy 10 cookies."),
    Item(id: "nightcap", kind: .hat, name: "Nightcap", level: nil, hint: "Keep poking a sleeping buddy."),
    Item(id: "horns", kind: .hat, name: "Devil horns", level: nil, hint: "Defuse 5 bombs in one tantrum."),
    Item(id: "headband", kind: .hat, name: "Headband", level: nil, hint: "Reach round 8 in Copycat."),

    // Accessories
    Item(id: "none-acc", kind: .accessory, name: "Nothing", level: 1, hint: ""),
    Item(id: "sunglasses", kind: .accessory, name: "Sunglasses", level: 2, hint: ""),
    Item(id: "glasses", kind: .accessory, name: "Nerd glasses", level: 4, hint: ""),
    Item(id: "bowtie", kind: .accessory, name: "Bow tie", level: 6, hint: ""),
    Item(id: "scarf", kind: .accessory, name: "Scarf", level: 9, hint: ""),
    Item(id: "mustache", kind: .accessory, name: "Mustache", level: nil, hint: "", price: 60),
    Item(id: "monocle", kind: .accessory, name: "Monocle", level: nil, hint: "", price: 140),
    Item(id: "medal", kind: .accessory, name: "Gold medal", level: nil, hint: "Complete 10 daily quests."),

    // Rooms
    Item(id: "studio", kind: .room, name: "Cozy Studio", level: 1, hint: ""),
    Item(id: "greenhouse", kind: .room, name: "Greenhouse", level: 7, hint: ""),
    Item(id: "cabin", kind: .room, name: "Snowy Cabin", level: 9, hint: ""),
    Item(id: "space", kind: .room, name: "Space Station", level: 11, hint: ""),
    Item(id: "synthwave", kind: .room, name: "Synthwave", level: nil, hint: "", price: 300),
    Item(id: "reef", kind: .room, name: "Coral Reef", level: nil, hint: "", price: 300),
    Item(id: "beach", kind: .room, name: "Beach Hut", level: nil, hint: "Score 20 in Bug Catch."),

    // Furniture
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
    Item(id: "cactus", kind: .decor, name: "Cactus", level: nil, hint: "", price: 40),
    Item(id: "clock", kind: .decor, name: "Wall clock", level: nil, hint: "", price: 50),
    Item(id: "beanbag", kind: .decor, name: "Beanbag", level: nil, hint: "", price: 70),
    Item(id: "lavalamp", kind: .decor, name: "Lava lamp", level: nil, hint: "", price: 80),
    Item(id: "lights", kind: .decor, name: "Fairy lights", level: nil, hint: "", price: 90),
    Item(id: "disco", kind: .decor, name: "Disco ball", level: nil, hint: "", price: 150),
    Item(id: "trophycase", kind: .decor, name: "Trophy case", level: nil, hint: "", price: 120),

    // Wallpaper and floors
    Item(id: "wp-room", kind: .wallpaper, name: "Room default", level: 1, hint: ""),
    Item(id: "wp-cream", kind: .wallpaper, name: "Cream stripes", level: 1, hint: ""),
    Item(id: "wp-sage", kind: .wallpaper, name: "Sage dots", level: nil, hint: "", price: 40),
    Item(id: "wp-blush", kind: .wallpaper, name: "Blush stripes", level: nil, hint: "", price: 40),
    Item(id: "wp-sun", kind: .wallpaper, name: "Sunny dots", level: nil, hint: "", price: 50),
    Item(id: "wp-bricks", kind: .wallpaper, name: "Red brick", level: nil, hint: "", price: 80),
    Item(id: "wp-navy", kind: .wallpaper, name: "Navy stars", level: nil, hint: "", price: 90),
    Item(id: "wp-cosmos", kind: .wallpaper, name: "Cosmos", level: nil, hint: "", price: 120),
    Item(id: "fl-room", kind: .floor, name: "Room default", level: 1, hint: ""),
    Item(id: "fl-oak", kind: .floor, name: "Light oak", level: 1, hint: ""),
    Item(id: "fl-tiles", kind: .floor, name: "White tiles", level: nil, hint: "", price: 40),
    Item(id: "fl-carpet", kind: .floor, name: "Plum carpet", level: nil, hint: "", price: 50),
    Item(id: "fl-checker", kind: .floor, name: "Checkerboard", level: nil, hint: "", price: 70),
    Item(id: "fl-marble", kind: .floor, name: "Marble", level: nil, hint: "", price: 90),
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
    Achievement(id: "whacker", name: "Whack Master", hint: "Score 25 in Whack-a-Bug.", xp: 50),
    Achievement(id: "flyer", name: "Frequent Flyer", hint: "Score 10 in Buddy Hop.", xp: 50),
    Achievement(id: "typist", name: "Speed Typist", hint: "Score 20 in Type Rush.", xp: 50),
    Achievement(id: "shopper", name: "Shopaholic", hint: "Buy 5 things in the shop.", xp: 50),
    Achievement(id: "decorator", name: "Interior Designer", hint: "Rearrange the furniture.", xp: 30),
    Achievement(id: "focus", name: "Deep Focus", hint: "Finish a focus timer.", xp: 40),
    Achievement(id: "streak", name: "On Fire", hint: "Visit buddy 7 days in a row.", xp: 80),
    Achievement(id: "quester", name: "Quest Champion", hint: "Complete 10 daily quests.", xp: 80),
    Achievement(id: "cookiejar", name: "Cookie Jar", hint: "Feed 100 cookies.", xp: 80),
    Achievement(id: "witching", name: "Witching Hour", hint: "Visit the room at 3am.", xp: 50),
    Achievement(id: "named", name: "Hello, My Name Is", hint: "Give buddy a name.", xp: 20),
]

// MARK: - Daily quests

struct QuestDef { let id: String; let text: String; let goal: Int; let coins: Int; let best: Bool }

/// `best` quests track the best single score today instead of adding up.
let questPool: [QuestDef] = [
    QuestDef(id: "pet", text: "Pet buddy 5 times", goal: 5, coins: 15, best: false),
    QuestDef(id: "feed", text: "Feed buddy 3 cookies", goal: 3, coins: 15, best: false),
    QuestDef(id: "session", text: "Finish 3 Claude sessions", goal: 3, coins: 30, best: false),
    QuestDef(id: "games", text: "Play 2 arcade games", goal: 2, coins: 20, best: false),
    QuestDef(id: "bugcatch", text: "Score 15 in Bug Catch", goal: 15, coins: 25, best: true),
    QuestDef(id: "copycat", text: "Reach round 6 in Copycat", goal: 5, coins: 25, best: true),
    QuestDef(id: "whack", text: "Score 20 in Whack-a-Bug", goal: 20, coins: 25, best: true),
    QuestDef(id: "hop", text: "Score 5 in Buddy Hop", goal: 5, coins: 25, best: true),
    QuestDef(id: "type", text: "Score 15 in Type Rush", goal: 15, coins: 25, best: true),
    QuestDef(id: "focus", text: "Finish a focus timer", goal: 1, coins: 30, best: false),
    QuestDef(id: "console", text: "Type 3 console commands", goal: 3, coins: 10, best: false),
    QuestDef(id: "outfit", text: "Try on a new outfit", goal: 1, coins: 10, best: false),
]

struct Quest: Codable { var id: String; var progress: Int; var done: Bool }

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
    // 2.0
    var coins = 0
    var accessory = "none-acc"
    var owned: [String] = []
    var hidden: [String] = []
    var decorX: [String: Double] = [:]
    var wallpaper = "wp-room"
    var floor = "fl-room"
    var best: [String: Int] = [:]
    var questDay = ""
    var quests: [Quest] = []
    var questsDone = 0
    var streak = 0
    var streakDay = ""
    var name = "Buddy"
    var friendSkin = "sky"
    var focusMinutes = 0
    var focusToday = 0
    var gamesPlayed = 0
    var bought = 0
    var v2 = false

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
        coins = get(.coins, 0); accessory = get(.accessory, "none-acc"); owned = get(.owned, []); hidden = get(.hidden, [])
        decorX = get(.decorX, [:]); wallpaper = get(.wallpaper, "wp-room"); floor = get(.floor, "fl-room")
        best = get(.best, [:]); questDay = get(.questDay, ""); quests = get(.quests, []); questsDone = get(.questsDone, 0)
        streak = get(.streak, 0); streakDay = get(.streakDay, ""); name = get(.name, "Buddy"); friendSkin = get(.friendSkin, "sky")
        focusMinutes = get(.focusMinutes, 0); focusToday = get(.focusToday, 0); gamesPlayed = get(.gamesPlayed, 0)
        bought = get(.bought, 0); v2 = get(.v2, false)
    }
}

struct GameReward { let xp: Int; let coins: Int; let newBest: Bool }

final class BuddyProgress {
    static let shared = BuddyProgress()

    private(set) var data: SaveData
    var onLevelUp: ((Int, [Item]) -> Void)?
    var onAchievement: ((Achievement, Item?) -> Void)?
    var onQuest: ((QuestDef, Bool) -> Void)?     // quest, and whether all of today's are now done
    var onStreak: ((Int, Int) -> Void)?          // streak days, coins
    /// Coins given to players coming from 1.x (shown once as a welcome toast).
    private(set) var welcomeGift = 0

    private init() {
        data = (try? JSONDecoder().decode(SaveData.self, from: Data(contentsOf: saveURL))) ?? SaveData()
    }

    /// One-time upgrade from 1.x save files (called by the buddy app, not by apps that only display buddy).
    func migrate() {
        guard !data.v2 else { return }
        data.v2 = true
        let gift = 100 + 10 * level
        data.coins += gift
        welcomeGift = gift
        if data.bestScore > 0 { data.best["bugcatch"] = data.bestScore }
        let cc = UserDefaults.standard.integer(forKey: "bestCopycat")
        if cc > 0 { data.best["copycat"] = cc }
        save()
    }

    /// Re-reads the save file (used by other apps that only display buddy).
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
        return data.unlocked.contains(it.id) || data.owned.contains(it.id)
    }

    func has(_ id: String) -> Bool { item(id).map(isUnlocked) ?? false }

    /// Furniture that is owned and not put away.
    func placed(_ id: String) -> Bool { has(id) && !data.hidden.contains(id) }

    func hasAchievement(_ id: String) -> Bool { data.achievements.contains(id) }

    func isEquipped(_ it: Item) -> Bool {
        switch it.kind {
        case .skin: return data.skin == it.id
        case .hat: return data.hat == it.id
        case .accessory: return data.accessory == it.id
        case .room: return data.room == it.id
        case .wallpaper: return data.wallpaper == it.id
        case .floor: return data.floor == it.id
        case .decor: return placed(it.id)
        }
    }

    func award(_ xp: Int) {
        guard xp > 0 else { return }
        let before = level
        data.xp += xp
        let after = level
        if after > before { data.coins += 20 * (after - before) }
        save()
        if after > before {
            let fresh = catalog.filter { ($0.level ?? 0) > before && ($0.level ?? 0) <= after }
            onLevelUp?(after, fresh)
        }
    }

    func earn(_ coins: Int) {
        guard coins > 0 else { return }
        data.coins += coins
        save()
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

    /// Wears / applies an item; for furniture, puts it out or away.
    func equip(_ it: Item) {
        guard isUnlocked(it) else { return }
        switch it.kind {
        case .skin: data.skin = it.id
        case .hat: data.hat = it.id
        case .accessory: data.accessory = it.id
        case .room: data.room = it.id
        case .wallpaper: data.wallpaper = it.id
        case .floor: data.floor = it.id
        case .decor:
            if let i = data.hidden.firstIndex(of: it.id) { data.hidden.remove(at: i) } else { data.hidden.append(it.id) }
        }
        if [.skin, .hat, .accessory].contains(it.kind) { track("outfit") }
        save()
    }

    func setDecorX(_ id: String, _ dx: Double) { data.decorX[id] = dx }

    func setName(_ name: String) {
        let n = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        guard !n.isEmpty, n != data.name else { return }
        data.name = n
        save()
        achieve("named")
    }

    func setFriendSkin(_ id: String) { data.friendSkin = id; save() }

    // MARK: Shop

    /// Today's deal: one shop item at 30% off, the same all day.
    var dailyDeal: Item? {
        let forSale = catalog.filter { $0.price != nil && !isUnlocked($0) }
        guard !forSale.isEmpty else { return nil }
        return forSale[Int(dayHash(today) % UInt64(forSale.count))]
    }

    func price(_ it: Item) -> Int? {
        guard let p = it.price else { return nil }
        return dailyDeal?.id == it.id ? p * 7 / 10 : p
    }

    func buy(_ it: Item) -> Bool {
        guard let p = price(it), !isUnlocked(it), data.coins >= p else { return false }
        data.coins -= p
        data.owned.append(it.id)
        data.bought += 1
        save()
        if data.bought >= 5 { achieve("shopper") }
        return true
    }

    // MARK: Days, streaks and quests

    var today: String { ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate]) }

    private var yesterday: String {
        ISO8601DateFormatter.string(from: Date().addingTimeInterval(-86400), timeZone: .current, formatOptions: [.withFullDate])
    }

    private func dayHash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }

    /// Resets the per-day counters when the date changes, and counts the visit toward the streak.
    func rollDay() {
        let d = today
        if d != data.day { data.day = d; data.toolXPToday = 0; data.cookiesToday = 0; data.sessionsToday = 0; data.focusToday = 0 }
        if data.streakDay != d {
            data.streak = data.streakDay == yesterday ? data.streak + 1 : 1
            data.streakDay = d
            let bonus = 5 * min(7, data.streak)
            data.coins += bonus
            save()
            onStreak?(data.streak, bonus)
            if data.streak >= 7 { achieve("streak") }
        }
        if data.questDay != d {
            data.questDay = d
            var rng = SeededRNG(seed: dayHash(d))
            data.quests = questPool.shuffled(using: &rng).prefix(3).map { Quest(id: $0.id, progress: 0, done: false) }
            save()
        }
    }

    /// Moves a daily quest along. For score quests pass the score as `amount`.
    func track(_ id: String, _ amount: Int = 1) {
        rollDay()
        guard let i = data.quests.firstIndex(where: { $0.id == id && !$0.done }),
              let def = questPool.first(where: { $0.id == id }) else { return }
        data.quests[i].progress = def.best ? max(data.quests[i].progress, amount) : data.quests[i].progress + amount
        guard data.quests[i].progress >= def.goal else { save(); return }
        data.quests[i].progress = def.goal
        data.quests[i].done = true
        data.questsDone += 1
        data.coins += def.coins
        let sweep = data.quests.allSatisfy(\.done)
        if sweep { data.coins += 25 }
        save()
        onQuest?(def, sweep)
        award(15)
        if data.questsDone >= 10 { achieve("quester", unlocking: "medal") }
    }

    // MARK: Things that happen

    func toolUsed() {
        rollDay()
        guard data.toolXPToday < 80 else { return }
        data.toolXPToday += 1
        award(1)
    }

    /// Returns the XP and coins earned for a finished session (with first-of-the-day bonus).
    @discardableResult
    func sessionFinished() -> (xp: Int, coins: Int) {
        rollDay()
        data.sessions += 1
        data.sessionsToday += 1
        let first = data.sessionsToday == 1
        let xp = first ? 45 : 25, coins = first ? 15 : 5
        data.coins += coins
        award(xp)
        track("session")
        if Calendar.current.component(.hour, from: Date()) < 5 { achieve("night") }
        if data.sessionsToday >= 10 { achieve("marathon") }
        return (xp, coins)
    }

    /// Returns false when buddy is too full for more cookies today.
    func fedCookie() -> Bool {
        rollDay()
        data.cookies += 1
        if data.cookies >= 10 { achieve("cookies", unlocking: "chef") }
        if data.cookies >= 100 { achieve("cookiejar", unlocking: "cookie") }
        track("feed")
        guard data.cookiesToday < 12 else { save(); return false }
        data.cookiesToday += 1
        award(2)
        return true
    }

    func petted() { data.pets += 1; award(1); track("pet") }

    func focusFinished(minutes: Int) -> (xp: Int, coins: Int) {
        rollDay()
        data.focusMinutes += minutes
        data.focusToday += minutes
        let xp = min(60, minutes), coins = max(5, minutes / 2)
        data.coins += coins
        award(xp)
        track("focus")
        achieve("focus")
        return (xp, coins)
    }

    /// Records a finished arcade game and pays out.
    func finishGame(_ id: String, score: Int) -> GameReward {
        rollDay()
        let s = max(0, score)
        let newBest = s > (data.best[id] ?? 0)
        if newBest { data.best[id] = s }
        if id == "bugcatch" { data.bestScore = max(data.bestScore, s) }
        data.gamesPlayed += 1
        let (xpMul, coinDiv): (Int, Int) = ["copycat": (3, 1), "hop": (5, 1), "whack": (2, 2), "type": (2, 2)][id] ?? (1, 2)
        let xp = min(60, s * xpMul)
        let coins = min(30, id == "copycat" || id == "hop" ? s * 2 : s / coinDiv)
        data.coins += coins
        save()
        award(xp)
        track("games")
        track(id, s)
        switch id {
        case "bugcatch": if s >= 20 { achieve("squasher", unlocking: "beach") }
        case "copycat": if s >= 7 { achieve("copycat", unlocking: "headband") }
        case "whack": if s >= 25 { achieve("whacker") }
        case "hop": if s >= 10 { achieve("flyer") }
        case "type": if s >= 20 { achieve("typist") }
        default: break
        }
        return GameReward(xp: xp, coins: coins, newBest: newBest)
    }

    func save() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: saveURL, options: .atomic) }
    }
}

/// Small deterministic generator so everyone's quests stay the same all day.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}
