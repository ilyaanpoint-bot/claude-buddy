// Buddy's room: a little world where buddy walks around, works at its desk while Claude Code
// runs and sleeps in bed. From the bar at the bottom you feed buddy, play arcade games, change
// outfits, shop, check daily quests, rearrange the furniture and type console commands.

import AppKit

let roomW: CGFloat = 460
let roomH: CGFloat = 340
private let W = roomW
private let H = roomH
private let hudH: CGFloat = 44
private let floorTop: CGFloat = 124
private let groundY: CGFloat = 95
private let roomScale: CGFloat = 0.7

// MARK: - Themes

struct Theme {
    var wall: NSColor, wallLine: NSColor, wallPattern: String
    var floor: NSColor, floorLine: NSColor, floorPattern: String
    var base: NSColor
}

func roomTheme(_ id: String) -> Theme {
    switch id {
    case "greenhouse": return Theme(wall: rgb(0xCFE8D2), wallLine: rgb(0xA9D3B0), wallPattern: "mullions", floor: rgb(0xD9D2C3), floorLine: rgb(0xC2B9A6), floorPattern: "tiles", base: rgb(0x6E9C74))
    case "space": return Theme(wall: rgb(0x3B4256), wallLine: rgb(0x4C556E), wallPattern: "rivets", floor: rgb(0x2A2F3D), floorLine: rgb(0x3D455A), floorPattern: "tiles", base: rgb(0x596178))
    case "beach": return Theme(wall: rgb(0xF6E7CB), wallLine: rgb(0xE8D3AE), wallPattern: "boards", floor: rgb(0xF0D9A6), floorLine: rgb(0xE0C48A), floorPattern: "sand", base: rgb(0xC9A877))
    case "cabin": return Theme(wall: rgb(0xC89B6D), wallLine: rgb(0xAF825A), wallPattern: "logs", floor: rgb(0x7A5236), floorLine: rgb(0x684530), floorPattern: "planks", base: rgb(0x5A3A24))
    case "synthwave": return Theme(wall: rgb(0x2A1B3D), wallLine: rgb(0x4A2A6E), wallPattern: "grid", floor: rgb(0x1A1028), floorLine: rgb(0xFF4FA3), floorPattern: "neon", base: rgb(0x3B2358))
    case "reef": return Theme(wall: rgb(0x2C6E91), wallLine: rgb(0x3E86AB), wallPattern: "waves", floor: rgb(0xE6D3A3), floorLine: rgb(0xD4BE88), floorPattern: "sand", base: rgb(0x1F5673))
    default: return Theme(wall: rgb(0xF3E3C8), wallLine: rgb(0xEAD6B4), wallPattern: "panels", floor: rgb(0xB98556), floorLine: rgb(0xA27045), floorPattern: "planks", base: rgb(0x8A5A36))
    }
}

func wallpaperStyle(_ id: String) -> (NSColor, NSColor, String)? {
    switch id {
    case "wp-cream": return (rgb(0xF5EBDD), rgb(0xEADBC6), "stripes")
    case "wp-sage": return (rgb(0xD5E3D0), rgb(0xB9CEB2), "dots")
    case "wp-blush": return (rgb(0xF6D9DA), rgb(0xEEC3C6), "stripes")
    case "wp-sun": return (rgb(0xFFF3C4), rgb(0xF2D675), "dots")
    case "wp-bricks": return (rgb(0xC9715A), rgb(0xB25E48), "bricks")
    case "wp-navy": return (rgb(0x2F3B5C), rgb(0x56669A), "stars")
    case "wp-cosmos": return (rgb(0x1E1B3A), rgb(0x4A4590), "stars")
    default: return nil
    }
}

func floorStyle(_ id: String) -> (NSColor, NSColor, String)? {
    switch id {
    case "fl-oak": return (rgb(0xC8955F), rgb(0xB07E4C), "planks")
    case "fl-tiles": return (rgb(0xE8E4DC), rgb(0xD2CCC0), "tiles")
    case "fl-carpet": return (rgb(0x6E5A8C), rgb(0x7D6A9C), "carpet")
    case "fl-checker": return (rgb(0xF2F2F2), rgb(0x2B2D42), "checker")
    case "fl-marble": return (rgb(0xEDEAE6), rgb(0xCFC9C2), "marble")
    default: return nil
    }
}

func currentTheme() -> Theme {
    let d = BuddyProgress.shared.data
    var th = roomTheme(d.room)
    if let w = wallpaperStyle(d.wallpaper) { th.wall = w.0; th.wallLine = w.1; th.wallPattern = w.2 }
    if let f = floorStyle(d.floor) { th.floor = f.0; th.floorLine = f.1; th.floorPattern = f.2 }
    return th
}

// MARK: - Furniture layout

struct DecorSpec { let id: String; let rect: NSRect; let wall: Bool; let movable: Bool }

let decorSpecs: [DecorSpec] = [
    DecorSpec(id: "lights", rect: NSRect(x: 0, y: 306, width: 460, height: 30), wall: true, movable: false),
    DecorSpec(id: "poster", rect: NSRect(x: 34, y: 186, width: 66, height: 88), wall: true, movable: true),
    DecorSpec(id: "neon", rect: NSRect(x: 108, y: 264, width: 64, height: 36), wall: true, movable: true),
    DecorSpec(id: "trophycase", rect: NSRect(x: 26, y: 134, width: 74, height: 36), wall: true, movable: true),
    DecorSpec(id: "clock", rect: NSRect(x: 298, y: 258, width: 28, height: 28), wall: true, movable: true),
    DecorSpec(id: "shelf", rect: NSRect(x: 330, y: 222, width: 118, height: 42), wall: true, movable: true),
    DecorSpec(id: "disco", rect: NSRect(x: 128, y: 300, width: 26, height: 40), wall: true, movable: true),
    DecorSpec(id: "rug", rect: NSRect(x: 150, y: 54, width: 170, height: 30), wall: false, movable: true),
    DecorSpec(id: "cactus", rect: NSRect(x: 18, y: 50, width: 20, height: 36), wall: false, movable: true),
    DecorSpec(id: "lavalamp", rect: NSRect(x: 118, y: 52, width: 18, height: 50), wall: false, movable: true),
    DecorSpec(id: "plant", rect: NSRect(x: 145, y: 56, width: 36, height: 74), wall: false, movable: true),
    DecorSpec(id: "fishtank", rect: NSRect(x: 186, y: 56, width: 52, height: 76), wall: false, movable: true),
    DecorSpec(id: "beanbag", rect: NSRect(x: 240, y: 50, width: 48, height: 32), wall: false, movable: true),
    DecorSpec(id: "arcade", rect: NSRect(x: 290, y: 56, width: 30, height: 112), wall: false, movable: true),
]

private let decorIcons: [String: String] = [
    "plant": "🪴", "poster": "🖼️", "lamp": "💡", "shelf": "📚", "rug": "🧶", "fishtank": "🐠", "records": "💿",
    "arcade": "🕹️", "neon": "🌈", "cat": "🐈‍⬛", "cactus": "🌵", "clock": "🕰️", "beanbag": "🛋️", "lavalamp": "🫧",
    "lights": "✨", "disco": "🪩", "trophycase": "🏆",
]

final class RoomView: NSView, NSTextFieldDelegate {
    enum Overlay { case none, style, shop, quests, arcade, console, edit }
    private enum Place { case floor, desk, bed }

    let anim: Animator
    var onPoke: (() -> Void)?
    var onFeed: (() -> Bool)?
    var onCommand: ((String) -> [String])?
    var onMedicine: (() -> Void)?
    var onGameFinish: ((String, Int) -> GameReward)?
    var menuProvider: (() -> NSMenu?)?

    private(set) var overlay: Overlay = .none
    private var bx: CGFloat = 240
    private var targetX: CGFloat = 240
    private var place: Place = .floor
    private var nextWander = now() + 4
    private var arriveLine: String?
    private var speech = ""
    private var speechUntil = -100.0
    private var lastFrame = now()
    private var cookieY: CGFloat?
    private var toast = ""
    private var toastUntil = -100.0
    private var plantWiggleAt = -100.0
    private var catHeartAt = -100.0
    private var lampOn = true
    private var musicOn = false
    private var consoleLines = ["Buddy OS 2.0 — type 'help'"]
    private let input = NSTextField()

    // Panels
    private var tab = 0
    private var page = 0
    private var pendingBuy: Item?
    private var buyNote = ""
    // Edit mode
    private var dragID: String?
    private var dragStartX: CGFloat = 0
    private var dragStartDX: CGFloat = 0
    private var movedSomething = false

    private var p: BuddyProgress { BuddyProgress.shared }
    private var deskX: CGFloat { 365 }
    private var bedX: CGFloat { 72 }
    private var gameOpen: Bool { subviews.contains { $0 is MiniGame } }

    init(anim: Animator) {
        self.anim = anim
        super.init(frame: NSRect(x: 0, y: 0, width: W, height: H))
        input.isBordered = false
        input.drawsBackground = false
        input.focusRingType = .none
        input.textColor = rgb(0x7CF29A)
        input.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        input.frame = NSRect(x: 128, y: 60, width: 310, height: 18)
        input.delegate = self
        input.target = self
        input.action = #selector(submitCommand)
        input.isHidden = true
        addSubview(input)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    func say(_ text: String, seconds: Double = 3.5) {
        speech = text
        speechUntil = now() + seconds
        Synth.shared.babble(text)
        anim.talk(Double(max(2, min(9, text.count / 3))) * 0.072)
    }

    func showToast(_ text: String) { toast = text; toastUntil = now() + 4.5 }

    /// Opens a panel (or closes it if it's already open).
    func open(_ o: Overlay) {
        closeGames()
        if o == .edit && overlay == .edit { finishEditing() }
        overlay = overlay == o ? .none : o
        tab = 0; page = 0; pendingBuy = nil; buyNote = ""
        input.isHidden = overlay != .console
        if overlay == .console { window?.makeFirstResponder(input) } else { window?.makeFirstResponder(self) }
    }

    func openShop(tab t: Int = 0) { if overlay != .shop { open(.shop) }; tab = t }

    // MARK: Games

    func startGame(_ id: String) {
        closeGames()
        if overlay != .none { open(overlay) }
        guard let g = makeGame(id, anim: anim) else { return }
        g.onFinish = { [weak self] id, score in self?.onGameFinish?(id, score) ?? GameReward(xp: 0, coins: 0, newBest: false) }
        g.onClose = { [weak self] in if let self { self.window?.makeFirstResponder(self) } }
        addSubview(g)
    }

    func closeGames() {
        subviews.compactMap { $0 as? MiniGame }.forEach { $0.close() }
    }

    // MARK: Buddy behaviour

    private func decorRect(_ id: String) -> NSRect {
        guard let s = decorSpecs.first(where: { $0.id == id }) else { return .zero }
        return s.rect.offsetBy(dx: offset(id), dy: 0)
    }

    private func offset(_ id: String) -> CGFloat {
        guard let s = decorSpecs.first(where: { $0.id == id }), s.movable else { return 0 }
        let dx = CGFloat(p.data.decorX[id] ?? 0)
        return max(4 - s.rect.minX, min(W - 4 - s.rect.maxX, dx))
    }

    private func updateBuddy(dt: CGFloat) {
        let t = now()
        if anim.asleep || anim.sick { targetX = bedX }
        else if anim.mood != .idle { targetX = deskX }
        else if place != .floor { targetX = 240; place = .floor }
        else if t > nextWander {
            nextWander = t + Double.random(in: 5...10)
            var spots: [(CGFloat, String?)] = [(CGFloat.random(in: 150...320), nil), (235, nil), (CGFloat.random(in: 150...320), nil)]
            if p.placed("plant") { spots.append((decorRect("plant").midX + 16, "*waters plant* 🌱")) }
            if p.placed("fishtank") { spots.append((decorRect("fishtank").midX, "blub blub 🐟")) }
            if p.placed("arcade") { spots.append((decorRect("arcade").midX, "one more game?")) }
            if p.placed("beanbag") { spots.append((decorRect("beanbag").midX, "so squishy 😌")) }
            if p.placed("lavalamp") { spots.append((decorRect("lavalamp").midX + 14, "ooh, blobby ✨")) }
            let pick = spots.randomElement()!
            targetX = max(30, min(W - 30, pick.0))
            arriveLine = pick.1.flatMap { _ in Bool.random() ? pick.1 : nil }
        }

        let d = targetX - bx
        let step = 70 * dt
        if abs(d) > step { bx += d > 0 ? step : -step } else {
            bx = targetX
            if anim.asleep || anim.sick { place = .bed } else if anim.mood != .idle { place = .desk }
            if let line = arriveLine { arriveLine = nil; say(line); if line.contains("plant") { plantWiggleAt = t } }
        }
        if abs(d) > step && place != .floor { place = .floor }
    }

    private var walking: Bool { abs(targetX - bx) > 1 }

    private func buddyCenter() -> NSPoint {
        switch place {
        case .desk: return NSPoint(x: bx, y: 140)
        case .bed: return NSPoint(x: 44, y: 100)
        case .floor: return NSPoint(x: bx, y: groundY)
        }
    }

    private func drawBuddy(_ pose: Pose, at c: NSPoint, shadow: Bool) {
        Renderer.draw(skin: p.data.skin, hat: p.data.hat, accessory: p.data.accessory, pose: pose, at: c, scale: roomScale, shadow: shadow)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let t = now()
        let dt = CGFloat(min(0.05, t - lastFrame))
        lastFrame = t
        let th = currentTheme()

        if !gameOpen { updateBuddy(dt: dt) }

        drawWall(th)
        drawWindow(NSRect(x: 180, y: 180, width: 110, height: 110))
        drawWallDecor()
        drawFloor(th)
        drawBed()
        drawFurniture()

        if !gameOpen {
            var pose = anim.pose(look: lookVector())
            if walking && !anim.asleep {
                pose.lift += CGFloat(abs(sin(t * 12))) * 4
                pose.look = CGVector(dx: targetX > bx ? 1 : -1, dy: 0)
            }
            if place == .bed { pose.lying = true }
            let c = buddyCenter()
            if place == .desk { drawBuddy(pose, at: c, shadow: false) }
            drawDesk()
            if place != .desk { drawBuddy(pose, at: c, shadow: place == .floor) }
            if place == .bed { drawBlanket() }
            if place == .desk && anim.mood == .working { typingParticles(at: c) }
            drawCat()
            drawCookie(target: c)
            if t < speechUntil { drawSpeech(above: NSPoint(x: c.x, y: c.y + 30 + pose.lift * roomScale)) }
        } else {
            drawDesk()
            drawCat()
        }
        drawAmbient(t)

        let dim = ["space", "synthwave"].contains(p.data.room)
        if !lampOn || isNight || dim {
            NSColor(srgbRed: 0.05, green: 0.06, blue: 0.2, alpha: lampOn ? 0.18 : 0.38).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: hudH, width: W, height: H - hudH)).fill()
        }

        switch overlay {
        case .style: drawStyle()
        case .shop: drawShop()
        case .quests: drawQuests()
        case .arcade: drawArcade()
        case .console: drawConsole()
        case .edit: drawEdit()
        case .none: break
        }
        drawHUD()
        if t < toastUntil { drawToast() }
    }

    private var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 20 || h < 6
    }

    private func lookVector() -> CGVector {
        guard let w = window else { return .zero }
        let m = convert(w.mouseLocationOutsideOfEventStream, from: nil)
        let v = CGVector(dx: m.x - bx, dy: m.y - groundY)
        let len = max(80, hypot(v.dx, v.dy))
        return bounds.contains(m) ? CGVector(dx: v.dx / len, dy: v.dy / len) : .zero
    }

    private var mouse: NSPoint { window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? NSPoint(x: -1, y: -1) }

    private func fill(_ c: NSColor, _ r: NSRect, radius: CGFloat = 0) {
        c.setFill()
        (radius > 0 ? NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) : NSBezierPath(rect: r)).fill()
    }

    private func text(_ s: String, _ pt: NSPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular, mono: Bool = false) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        (s as NSString).draw(at: pt, withAttributes: [.font: font, .foregroundColor: color])
    }

    private func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
    }

    private func centerText(_ s: String, in r: NSRect, y: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        text(s, NSPoint(x: r.midX - textWidth(s, size: size, weight: weight) / 2, y: y), size: size, color: color, weight: weight)
    }

    private func withOffset(_ id: String, _ body: () -> Void) {
        guard p.placed(id) else { return }
        NSGraphicsContext.saveGraphicsState()
        let xf = NSAffineTransform(); xf.translateX(by: offset(id), yBy: 0); xf.concat()
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Walls and floors

    func paintWall(_ th: Theme, in r: NSRect, t: Double) {
        fill(th.wall, r)
        th.wallLine.setFill()
        switch th.wallPattern {
        case "mullions":
            for x in stride(from: r.minX, to: r.maxX, by: 46) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 3, height: r.height)).fill() }
            NSBezierPath(rect: NSRect(x: r.minX, y: r.maxY - 40, width: r.width, height: 3)).fill()
        case "rivets":
            for x in stride(from: r.minX, to: r.maxX, by: 92) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 2, height: r.height)).fill() }
            rgb(0x6A7390).setFill()
            for x in stride(from: r.minX + 8, to: r.maxX, by: 92) {
                for y in [r.minY + 10, r.maxY - 12] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 3)).fill() }
            }
        case "boards":
            for y in stride(from: r.minY + 18, to: r.maxY, by: 22) { NSBezierPath(rect: NSRect(x: r.minX, y: y, width: r.width, height: 2)).fill() }
        case "logs":
            for y in stride(from: r.minY + 4, to: r.maxY, by: 24) {
                NSBezierPath(roundedRect: NSRect(x: r.minX - 6, y: y, width: r.width + 12, height: 20), xRadius: 10, yRadius: 10).fill()
                th.wall.setFill()
                NSBezierPath(roundedRect: NSRect(x: r.minX - 6, y: y + 3, width: r.width + 12, height: 14), xRadius: 7, yRadius: 7).fill()
                th.wallLine.setFill()
            }
        case "grid":
            for x in stride(from: r.minX, to: r.maxX, by: 30) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 1, height: r.height)).fill() }
            for y in stride(from: r.minY, to: r.maxY, by: 30) { NSBezierPath(rect: NSRect(x: r.minX, y: y, width: r.width, height: 1)).fill() }
        case "waves":
            th.wallLine.setStroke()
            for (k, y) in stride(from: r.minY + 20, to: r.maxY, by: 34).enumerated() {
                let w = NSBezierPath(); w.lineWidth = 2
                w.move(to: NSPoint(x: r.minX, y: y))
                for x in stride(from: r.minX, through: r.maxX, by: 8) {
                    w.line(to: NSPoint(x: x, y: y + 4 * CGFloat(sin(Double(x) / 18 + t * 0.8 + Double(k)))))
                }
                w.stroke()
            }
        case "stripes":
            for x in stride(from: r.minX + 6, to: r.maxX, by: 24) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 10, height: r.height)).fill() }
        case "dots":
            for (row, y) in stride(from: r.minY + 10, to: r.maxY, by: 20).enumerated() {
                for x in stride(from: r.minX + (row % 2 == 0 ? 8 : 18), to: r.maxX, by: 20) { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 5, height: 5)).fill() }
            }
        case "bricks":
            for (row, y) in stride(from: r.minY, to: r.maxY, by: 14).enumerated() {
                NSBezierPath(rect: NSRect(x: r.minX, y: y, width: r.width, height: 2)).fill()
                for x in stride(from: r.minX + (row % 2 == 0 ? 0 : 16), to: r.maxX, by: 32) { NSBezierPath(rect: NSRect(x: x, y: y, width: 2, height: 14)).fill() }
            }
        case "stars":
            for i in 0..<36 {
                let x = r.minX + CGFloat((i * 89) % Int(max(1, r.width))), y = r.minY + CGFloat((i * 47) % Int(max(1, r.height)))
                th.wallLine.withAlphaComponent(0.5 + 0.5 * CGFloat(abs(sin(t + Double(i))))).setFill()
                Renderer.sparkle(at: NSPoint(x: x, y: y), size: i % 3 == 0 ? 3 : 1.8)
            }
        default:
            for x in stride(from: r.minX + 10, to: r.maxX, by: 28) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 9, height: r.height)).fill() }
        }
    }

    func paintFloor(_ th: Theme, in r: NSRect) {
        fill(th.floor, r)
        th.floorLine.setFill()
        switch th.floorPattern {
        case "sand":
            for i in 0..<40 {
                NSBezierPath(ovalIn: NSRect(x: r.minX + CGFloat((i * 97) % Int(r.width)), y: r.minY + CGFloat((i * 53) % Int(max(1, r.height))), width: 3, height: 2)).fill()
            }
        case "tiles":
            for x in stride(from: r.minX, to: r.maxX, by: 40) { NSBezierPath(rect: NSRect(x: x, y: r.minY, width: 1.5, height: r.height)).fill() }
            for y in stride(from: r.minY, to: r.maxY, by: 26) { NSBezierPath(rect: NSRect(x: r.minX, y: y, width: r.width, height: 1.5)).fill() }
        case "carpet":
            for i in 0..<60 {
                NSBezierPath(ovalIn: NSRect(x: r.minX + CGFloat((i * 71) % Int(r.width)), y: r.minY + CGFloat((i * 37) % Int(max(1, r.height))), width: 2, height: 2)).fill()
            }
        case "checker":
            for (row, y) in stride(from: r.minY, to: r.maxY, by: 20).enumerated() {
                for (col, x) in stride(from: r.minX, to: r.maxX, by: 20).enumerated() where (row + col) % 2 == 0 {
                    NSBezierPath(rect: NSRect(x: x, y: y, width: 20, height: min(20, r.maxY - y))).fill()
                }
            }
        case "marble":
            th.floorLine.setStroke()
            for k in 0..<6 {
                let v = NSBezierPath(); v.lineWidth = 1
                let x0 = r.minX + CGFloat(k) * r.width / 6
                v.move(to: NSPoint(x: x0, y: r.minY))
                v.curve(to: NSPoint(x: x0 + 50, y: r.maxY), controlPoint1: NSPoint(x: x0 + 30, y: r.midY - 10), controlPoint2: NSPoint(x: x0 + 10, y: r.midY + 20))
                v.stroke()
            }
        case "neon":
            let horizon = NSPoint(x: r.midX, y: r.maxY + 60)
            th.floorLine.withAlphaComponent(0.7).setStroke()
            let g = NSBezierPath(); g.lineWidth = 1
            for k in -8...8 {
                let bx = r.midX + CGFloat(k) * 60
                let k2 = (r.maxY - r.minY) / (horizon.y - r.minY)
                g.move(to: NSPoint(x: bx, y: r.minY)); g.line(to: NSPoint(x: bx + (horizon.x - bx) * k2, y: r.maxY))
            }
            for y in stride(from: r.minY + 8, to: r.maxY, by: 18) { g.move(to: NSPoint(x: r.minX, y: y)); g.line(to: NSPoint(x: r.maxX, y: y)) }
            g.stroke()
        default:
            for y in stride(from: r.minY + 16, to: r.maxY, by: 16) { NSBezierPath(rect: NSRect(x: r.minX, y: y, width: r.width, height: 1.5)).fill() }
        }
    }

    private func drawWall(_ th: Theme) {
        paintWall(th, in: NSRect(x: 0, y: floorTop, width: W, height: H - floorTop), t: now())
    }

    private func drawFloor(_ th: Theme) {
        paintFloor(th, in: NSRect(x: 0, y: hudH, width: W, height: floorTop - hudH))
        if p.data.room == "beach" { fill(rgb(0xF4A6B8), NSRect(x: 160, y: 52, width: 9, height: 6), radius: 3) }
        fill(th.base, NSRect(x: 0, y: floorTop - 4, width: W, height: 6))
        withOffset("rug") {
            fill(rgb(0xC0504D, 0.85), NSRect(x: 150, y: 54, width: 170, height: 30), radius: 15)
            rgb(0xF2C94C, 0.8).setStroke()
            let b = NSBezierPath(roundedRect: NSRect(x: 156, y: 58, width: 158, height: 22), xRadius: 11, yRadius: 11)
            b.lineWidth = 2; b.stroke()
        }
    }

    private func drawWindow(_ r: NSRect) {
        let t = now()
        let hour = Calendar.current.component(.hour, from: Date())
        let room = p.data.room
        if room == "space" || room == "reef" {
            let c = NSRect(x: r.midX - 52, y: r.midY - 52, width: 104, height: 104)
            fill(room == "space" ? rgb(0x0B0D1F) : rgb(0x0E3B5C), c, radius: 52)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: c).addClip()
            if room == "space" {
                for i in 0..<30 {
                    let x = c.minX + CGFloat((i * 37) % 104), y = c.minY + CGFloat((i * 61) % 104)
                    NSColor(white: 1, alpha: 0.4 + 0.5 * CGFloat(abs(sin(t + Double(i))))).setFill()
                    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill()
                }
                fill(rgb(0x3F7FE0), NSRect(x: c.minX + 30 + CGFloat(sin(t * 0.1)) * 6, y: c.minY - 30, width: 90, height: 90), radius: 45)
                fill(rgb(0x5DBB63), NSRect(x: c.minX + 50, y: c.minY + 20, width: 30, height: 18), radius: 9)
            } else {
                NSGradient(starting: rgb(0x0B2A44), ending: rgb(0x1F6E9A))?.draw(in: c, angle: 90)
                for k in 0..<3 {
                    let fx = c.minX + CGFloat(fmod(t * (14 + Double(k) * 9) + Double(k) * 40, 150)) - 20
                    let fy = c.minY + 26 + CGFloat(k) * 22 + CGFloat(sin(t * 2 + Double(k))) * 4
                    fill([rgb(0xF29A38), rgb(0xFFD54F), rgb(0xE5395B)][k], NSRect(x: fx, y: fy, width: 14, height: 8), radius: 4)
                    let tail = NSBezierPath()
                    tail.move(to: NSPoint(x: fx, y: fy + 4)); tail.line(to: NSPoint(x: fx - 6, y: fy + 8)); tail.line(to: NSPoint(x: fx - 6, y: fy)); tail.close(); tail.fill()
                }
                fill(rgb(0xE07A9A), NSRect(x: c.minX + 10, y: c.minY - 6, width: 22, height: 30), radius: 8)
                fill(rgb(0x5DBB63), NSRect(x: c.maxX - 30, y: c.minY - 4, width: 10, height: 34), radius: 5)
            }
            NSGraphicsContext.restoreGraphicsState()
            rgb(room == "space" ? 0x8A93AE : 0xC9A877).setStroke()
            let ring = NSBezierPath(ovalIn: c); ring.lineWidth = 7; ring.stroke()
            return
        }
        let night = hour >= 20 || hour < 6
        let dusk = hour >= 17 && hour < 20
        var top = night ? rgb(0x0E1640) : dusk ? rgb(0xF08A5D) : rgb(0x7EC8F2)
        var bottom = night ? rgb(0x26306B) : dusk ? rgb(0xF7C873) : rgb(0xCDEBFA)
        if room == "synthwave" { top = rgb(0x1A0B33); bottom = rgb(0xFF4FA3) }
        if room == "cabin" && !night { top = rgb(0xA9C7E0); bottom = rgb(0xE8F1F8) }
        NSGradient(starting: bottom, ending: top)?.draw(in: r, angle: 90)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: r).addClip()
        if room == "synthwave" {
            let sun = NSRect(x: r.midX - 30, y: r.minY + 22, width: 60, height: 60)
            NSGradient(starting: rgb(0xFF4FA3), ending: rgb(0xFFD54F))?.draw(in: NSBezierPath(ovalIn: sun), angle: 90)
            rgb(0x1A0B33).setFill()
            for k in 0..<4 { NSBezierPath(rect: NSRect(x: sun.minX, y: sun.minY + 6 + CGFloat(k) * 8, width: sun.width, height: 2 + CGFloat(k) * 0.6)).fill() }
            rgb(0x2A1B3D).setFill()
            let m = NSBezierPath()
            m.move(to: NSPoint(x: r.minX, y: r.minY)); m.line(to: NSPoint(x: r.minX + 24, y: r.minY + 30)); m.line(to: NSPoint(x: r.minX + 46, y: r.minY + 12))
            m.line(to: NSPoint(x: r.minX + 76, y: r.minY + 38)); m.line(to: NSPoint(x: r.maxX, y: r.minY + 8)); m.line(to: NSPoint(x: r.maxX, y: r.minY)); m.close(); m.fill()
            rgb(0xFF4FA3).setStroke()
            m.lineWidth = 1; m.stroke()
        } else if night {
            for i in 0..<14 {
                NSColor(white: 1, alpha: 0.5 + 0.5 * CGFloat(abs(sin(t * 1.3 + Double(i))))).setFill()
                NSBezierPath(ovalIn: NSRect(x: r.minX + CGFloat((i * 41) % 104), y: r.minY + 30 + CGFloat((i * 29) % 76), width: 2, height: 2)).fill()
            }
            fill(rgb(0xF7F3D7), NSRect(x: r.maxX - 34, y: r.maxY - 32, width: 18, height: 18), radius: 9)
        } else if room != "cabin" {
            fill(rgb(0xFFE07A), NSRect(x: r.maxX - 36, y: r.maxY - 34, width: 20, height: 20), radius: 10)
            let cx = r.minX + CGFloat(fmod(t * 6, 160)) - 30
            NSColor(white: 1, alpha: 0.9).setFill()
            for (dx, dy, s) in [(0.0, 0.0, 16.0), (10.0, 4.0, 18.0), (22.0, 0.0, 14.0)] as [(CGFloat, CGFloat, CGFloat)] {
                NSBezierPath(ovalIn: NSRect(x: cx + dx, y: r.maxY - 50 + dy, width: s, height: s * 0.8)).fill()
            }
        }
        if room == "beach" {
            fill(night ? rgb(0x1B3A6B) : rgb(0x2E9CCA), NSRect(x: r.minX, y: r.minY, width: r.width, height: 34))
            NSColor(white: 1, alpha: 0.5).setFill()
            for i in 0..<4 {
                let x = r.minX + CGFloat(fmod(t * 10 + Double(i) * 30, 120)) - 10
                NSBezierPath(rect: NSRect(x: x, y: r.minY + 8 + CGFloat(i % 2) * 12, width: 14, height: 1.5)).fill()
            }
        } else if room == "cabin" {
            fill(NSColor(white: 0.97, alpha: 1), NSRect(x: r.minX, y: r.minY, width: r.width, height: 20))
            for (x, h) in [(14.0, 46.0), (44.0, 60.0), (80.0, 40.0)] as [(CGFloat, CGFloat)] {
                let tree = NSBezierPath()
                tree.move(to: NSPoint(x: r.minX + x - 14, y: r.minY + 14)); tree.line(to: NSPoint(x: r.minX + x, y: r.minY + 14 + h)); tree.line(to: NSPoint(x: r.minX + x + 14, y: r.minY + 14)); tree.close()
                rgb(night ? 0x1E3B2C : 0x2F6B4A).setFill(); tree.fill()
            }
            NSColor.white.setFill()
            for i in 0..<22 {
                let x = r.minX + CGFloat(fmod(Double(i * 23) + sin(t + Double(i)) * 6, 110))
                let y = r.maxY - CGFloat(fmod(t * (14 + Double(i % 4) * 3) + Double(i * 17), 110))
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2.5, height: 2.5)).fill()
            }
        } else if room != "synthwave" {
            fill(night ? rgb(0x1E3B2C) : rgb(0x6DBE6A), NSRect(x: r.minX - 10, y: r.minY - 30, width: 80, height: 54), radius: 27)
            fill(night ? rgb(0x234A33) : rgb(0x84CF7A), NSRect(x: r.minX + 50, y: r.minY - 34, width: 90, height: 52), radius: 26)
        }
        NSGraphicsContext.restoreGraphicsState()
        let frameColor = room == "greenhouse" ? rgb(0x6E9C74) : room == "synthwave" ? rgb(0xFF4FA3) : room == "cabin" ? rgb(0x6A4630) : rgb(0xFFFFFF)
        frameColor.setStroke()
        let fr = NSBezierPath(rect: r); fr.lineWidth = 6; fr.stroke()
        let cross = NSBezierPath(); cross.lineWidth = 4
        cross.move(to: NSPoint(x: r.midX, y: r.minY)); cross.line(to: NSPoint(x: r.midX, y: r.maxY))
        cross.move(to: NSPoint(x: r.minX, y: r.midY)); cross.line(to: NSPoint(x: r.maxX, y: r.midY))
        cross.stroke()
        fill(frameColor, NSRect(x: r.minX - 8, y: r.minY - 8, width: r.width + 16, height: 6), radius: 2)
    }

    private func drawWallDecor() {
        let t = now()
        withOffset("poster") {
            fill(rgb(0x2B2D42), NSRect(x: 34, y: 186, width: 66, height: 88), radius: 3)
            Renderer.draw(skin: "classic", hat: "none", pose: Pose(), at: NSPoint(x: 67, y: 240), scale: 0.5, shadow: false)
            text("SHIP IT", NSPoint(x: 43, y: 192), size: 12, color: sparkYellow, weight: .heavy)
        }
        withOffset("neon") {
            let glow = 0.75 + 0.25 * CGFloat(sin(t * 3))
            let shadow = NSShadow(); shadow.shadowColor = rgb(0xFF4FA3, glow); shadow.shadowBlurRadius = 10
            NSGraphicsContext.saveGraphicsState(); shadow.set()
            text("</>", NSPoint(x: 116, y: 268), size: 26, color: rgb(0xFF7FC1, glow), weight: .bold, mono: true)
            NSGraphicsContext.restoreGraphicsState()
        }
        withOffset("clock") {
            let c = NSPoint(x: 312, y: 272)
            fill(rgb(0x5A3A24), NSRect(x: c.x - 14, y: c.y - 14, width: 28, height: 28), radius: 14)
            fill(rgb(0xFFF8E7), NSRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22), radius: 11)
            let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
            let m = Double(comps.minute ?? 0), h = Double((comps.hour ?? 0) % 12) + m / 60, s = Double(comps.second ?? 0)
            for (ang, len, w, col) in [(h / 12, 6.0, 2.0, faceColor), (m / 60, 9.0, 1.4, faceColor), (s / 60, 9.5, 0.8, rgb(0xE5395B))] as [(Double, CGFloat, CGFloat, NSColor)] {
                col.setStroke()
                let hand = NSBezierPath(); hand.lineWidth = w; hand.lineCapStyle = .round
                hand.move(to: c); hand.line(to: NSPoint(x: c.x + CGFloat(sin(ang * 2 * .pi)) * len, y: c.y + CGFloat(cos(ang * 2 * .pi)) * len)); hand.stroke()
            }
        }
        withOffset("trophycase") {
            fill(rgb(0x6B4A33), NSRect(x: 26, y: 134, width: 74, height: 5), radius: 2)
            let n = min(5, max(1, p.data.achievements.count / 5))
            for k in 0..<n {
                let x: CGFloat = 32 + CGFloat(k) * 13
                fill(rgb(0xF2C94C), NSRect(x: x, y: 147, width: 9, height: 9), radius: 3)
                fill(rgb(0xC99A22), NSRect(x: x + 3, y: 141, width: 3, height: 7))
                fill(rgb(0xC99A22), NSRect(x: x, y: 139, width: 9, height: 3), radius: 1)
            }
        }
        withOffset("shelf") {
            fill(rgb(0x8A5A36), NSRect(x: 330, y: 222, width: 118, height: 6), radius: 2)
            let books: [(CGFloat, UInt32, CGFloat)] = [(334, 0xC0504D, 26), (344, 0x3F7FE0, 30), (355, 0x5DBB63, 24), (364, 0xF2C94C, 28), (375, 0x9466DB, 22)]
            for (x, c, h) in books { fill(rgb(c), NSRect(x: x, y: 228, width: 9, height: h), radius: 1) }
            if p.placed("records") {
                fill(rgb(0x4A3B33), NSRect(x: 394, y: 228, width: 48, height: 10), radius: 2)
                let spin = musicOn ? t * 4 : 0
                fill(rgb(0x111111), NSRect(x: 400, y: 232, width: 30, height: 9), radius: 4.5)
                fill(rgb(0xC0504D), NSRect(x: 412 + CGFloat(cos(spin)) * 2, y: 235, width: 6, height: 3), radius: 1.5)
                if musicOn {
                    for k in 0..<3 {
                        let ph = CGFloat(fmod(t * 0.6 + Double(k) / 3, 1))
                        text(k % 2 == 0 ? "♪" : "♫", NSPoint(x: 410 + ph * 20 + CGFloat(sin(t * 3 + Double(k))) * 6, y: 244 + ph * 40),
                             size: 13, color: rgb(0x9466DB, 1 - ph), weight: .bold)
                    }
                }
            }
        }
        if p.data.room == "greenhouse" {
            for (x, len) in [(30.0, 40.0), (130.0, 28.0), (320.0, 34.0)] as [(CGFloat, CGFloat)] {
                rgb(0x6E9C74).setStroke()
                let rope = NSBezierPath(); rope.lineWidth = 1.5
                rope.move(to: NSPoint(x: x + 10, y: H)); rope.line(to: NSPoint(x: x + 10, y: H - len)); rope.stroke()
                fill(rgb(0xC8734E), NSRect(x: x, y: H - len - 14, width: 20, height: 14), radius: 3)
                rgb(0x4E9F55).setFill()
                for k in 0..<4 {
                    let sway = CGFloat(sin(t * 1.2 + Double(k))) * 2
                    NSBezierPath(ovalIn: NSRect(x: x - 6 + CGFloat(k) * 8 + sway, y: H - len - 30 + CGFloat(k % 2) * 4, width: 8, height: 18)).fill()
                }
            }
        }
        if p.data.room == "beach" {
            rgb(0x8A5A36).setFill()
            NSBezierPath(rect: NSRect(x: 18, y: 124, width: 6, height: 70)).fill()
            rgb(0x4E9F55).setFill()
            for k in 0..<5 {
                let a = Double(k) / 4 * .pi
                let leaf = NSBezierPath(ovalIn: NSRect(x: -20, y: -5, width: 40, height: 10))
                let xf = NSAffineTransform(); xf.translateX(by: 21 + CGFloat(cos(a)) * 18, yBy: 196 + CGFloat(sin(a)) * 8)
                xf.rotate(byRadians: CGFloat(a)); leaf.transform(using: xf as AffineTransform); leaf.fill()
            }
        }
        if p.data.room == "cabin" {
            // A little fireplace glow under the window
            fill(rgb(0x6A4630), NSRect(x: 196, y: 124, width: 78, height: 40), radius: 4)
            fill(rgb(0x2B1D16), NSRect(x: 206, y: 124, width: 58, height: 30), radius: 3)
            for k in 0..<3 {
                let h = 12 + 8 * CGFloat(abs(sin(t * 6 + Double(k) * 1.7)))
                fill(rgb(k == 1 ? 0xFFD54F : 0xFF7A1F), NSRect(x: 218 + CGFloat(k) * 12, y: 126, width: 10, height: h), radius: 5)
            }
        }
        withOffset("disco") {
            NSColor(white: 0.6, alpha: 1).setStroke()
            let s = NSBezierPath(); s.lineWidth = 1; s.move(to: NSPoint(x: 141, y: H)); s.line(to: NSPoint(x: 141, y: 326)); s.stroke()
            fill(rgb(0xB0BEC5), NSRect(x: 128, y: 300, width: 26, height: 26), radius: 13)
            for k in 0..<12 {
                let x = 131 + CGFloat(k % 4) * 5.5, y = 303 + CGFloat(k / 4) * 6.5
                NSColor(white: 1, alpha: 0.3 + 0.6 * CGFloat(abs(sin(t * 4 + Double(k))))).setFill()
                NSBezierPath(rect: NSRect(x: x, y: y, width: 4, height: 4.5)).fill()
            }
        }
        if p.placed("lights") {
            rgb(0x3A3A3A).setStroke()
            let wire = NSBezierPath(); wire.lineWidth = 1
            wire.move(to: NSPoint(x: 0, y: 332))
            for k in 0...6 { wire.curve(to: NSPoint(x: CGFloat(k + 1) * 66, y: 332), controlPoint1: NSPoint(x: CGFloat(k) * 66 + 22, y: 314), controlPoint2: NSPoint(x: CGFloat(k) * 66 + 44, y: 314)) }
            wire.stroke()
            let colors: [UInt32] = [0xFF6B9A, 0xFFD54F, 0x7CF29A, 0x6EC6FF, 0xC59BFF]
            for k in 0..<21 {
                let x = CGFloat(k) * 22 + 8
                let ph = fmod(Double(x), 66) / 66
                let y = 332 - CGFloat(sin(ph * .pi)) * 13
                let on = sin(t * 2.5 + Double(k)) > -0.3
                let c = rgb(colors[k % colors.count], on ? 1 : 0.35)
                if on {
                    NSGraphicsContext.saveGraphicsState()
                    let glow = NSShadow(); glow.shadowColor = c; glow.shadowBlurRadius = 6; glow.set()
                    fill(c, NSRect(x: x - 2.5, y: y - 7, width: 5, height: 7), radius: 2.5)
                    NSGraphicsContext.restoreGraphicsState()
                } else {
                    fill(c, NSRect(x: x - 2.5, y: y - 7, width: 5, height: 7), radius: 2.5)
                }
            }
        }
    }

    private func drawBed() {
        fill(rgb(0x7A4E2D), NSRect(x: 14, y: 60, width: 8, height: 60), radius: 2)
        fill(rgb(0x7A4E2D), NSRect(x: 14, y: 60, width: 126, height: 10), radius: 2)
        fill(rgb(0x7A4E2D), NSRect(x: 134, y: 60, width: 6, height: 34), radius: 2)
        fill(rgb(0xFFFFFF), NSRect(x: 20, y: 70, width: 116, height: 22), radius: 6)
        fill(rgb(0xF5F0E6), NSRect(x: 22, y: 90, width: 36, height: 14), radius: 7)
        if place != .bed || gameOpen { drawBlanket() }
    }

    private func drawBlanket() {
        fill(rgb(0x5B7FD6), NSRect(x: 62, y: 70, width: 76, height: 28), radius: 8)
        rgb(0x7E9DE6).setFill()
        for x in stride(from: CGFloat(70), to: 134, by: 16) { NSBezierPath(rect: NSRect(x: x, y: 72, width: 6, height: 24)).fill() }
    }

    private func drawFurniture() {
        let t = now()
        withOffset("cactus") {
            fill(rgb(0xC8734E), NSRect(x: 20, y: 50, width: 16, height: 12), radius: 3)
            fill(rgb(0x4E9F55), NSRect(x: 23, y: 60, width: 10, height: 24), radius: 5)
            fill(rgb(0x4E9F55), NSRect(x: 16, y: 68, width: 8, height: 5), radius: 2.5)
            fill(rgb(0x4E9F55), NSRect(x: 16, y: 68, width: 4, height: 11), radius: 2)
            fill(rgb(0x4E9F55), NSRect(x: 32, y: 72, width: 6, height: 4), radius: 2)
            fill(rgb(0x4E9F55), NSRect(x: 35, y: 72, width: 4, height: 9), radius: 2)
            fill(rgb(0xFF8FC7), NSRect(x: 25, y: 82, width: 6, height: 5), radius: 2.5)
        }
        withOffset("lavalamp") {
            fill(rgb(0x5A5A6E), NSRect(x: 120, y: 52, width: 14, height: 10), radius: 2)
            fill(rgb(0x7E57C2, 0.85), NSRect(x: 121, y: 61, width: 12, height: 32), radius: 6)
            for k in 0..<3 {
                let y = 64 + CGFloat(fmod(t * (5 + Double(k) * 2) + Double(k) * 9, 24))
                fill(rgb(0xFF7A1F), NSRect(x: 123 + CGFloat(k % 2) * 3, y: y, width: 6 + CGFloat(k), height: 6 + CGFloat(k)), radius: 3.5)
            }
            fill(rgb(0x5A5A6E), NSRect(x: 122, y: 92, width: 10, height: 6), radius: 2)
        }
        withOffset("plant") {
            let wig = CGFloat(sin((t - plantWiggleAt) * 20)) * 3 * CGFloat(max(0, 1 - (t - plantWiggleAt)))
            rgb(0x4E9F55).setFill()
            for (dx, h, a) in [(-8.0, 34.0, -0.35), (0.0, 44.0, 0.0), (8.0, 36.0, 0.35), (-3.0, 26.0, -0.7), (4.0, 28.0, 0.7)] as [(CGFloat, CGFloat, CGFloat)] {
                let leaf = NSBezierPath(ovalIn: NSRect(x: -5, y: 0, width: 10, height: h))
                let xf = NSAffineTransform()
                xf.translateX(by: 162 + dx + wig, yBy: 80)
                xf.rotate(byRadians: a + wig * 0.03)
                leaf.transform(using: xf as AffineTransform); leaf.fill()
            }
            fill(rgb(0xC8734E), NSRect(x: 150, y: 56, width: 26, height: 26), radius: 4)
            fill(rgb(0xB0613F), NSRect(x: 147, y: 76, width: 32, height: 7), radius: 2)
        }
        withOffset("fishtank") {
            fill(rgb(0x6B4A33), NSRect(x: 188, y: 56, width: 48, height: 40), radius: 3)
            fill(rgb(0x7FD3F0, 0.75), NSRect(x: 186, y: 96, width: 52, height: 34), radius: 3)
            fill(rgb(0xE8D3AE), NSRect(x: 186, y: 96, width: 52, height: 6), radius: 2)
            for k in 0..<2 {
                let fx = 196 + CGFloat(fmod(t * (12 + Double(k) * 7), 34))
                fill(k == 0 ? rgb(0xF29A38) : rgb(0xE5395B), NSRect(x: fx, y: 108 + CGFloat(k) * 9, width: 9, height: 5), radius: 2.5)
            }
            NSColor(white: 1, alpha: 0.6).setFill()
            NSBezierPath(ovalIn: NSRect(x: 228, y: 100 + CGFloat(fmod(t * 14, 30)), width: 3, height: 3)).fill()
        }
        withOffset("beanbag") {
            fill(rgb(0x3F7FE0), NSRect(x: 240, y: 50, width: 48, height: 28), radius: 14)
            fill(rgb(0x5B95EA), NSRect(x: 246, y: 64, width: 34, height: 16), radius: 8)
        }
        withOffset("arcade") {
            fill(rgb(0x3B2A6B), NSRect(x: 290, y: 56, width: 30, height: 112), radius: 4)
            fill(rgb(0x111122), NSRect(x: 294, y: 126, width: 22, height: 26), radius: 2)
            fill(rgb(0x7CF29A, 0.4 + 0.3 * CGFloat(abs(sin(t * 4)))), NSRect(x: 297, y: 130, width: 16, height: 18), radius: 1)
            fill(rgb(0xE5395B), NSRect(x: 300, y: 110, width: 5, height: 5), radius: 2.5)
            fill(rgb(0xF2C94C), NSRect(x: 308, y: 110, width: 5, height: 5), radius: 2.5)
        }
    }

    private func drawDesk() {
        let t = now()
        fill(rgb(0x5A3A24), NSRect(x: 326, y: 106, width: 128, height: 8), radius: 2)
        fill(rgb(0x6B4A33), NSRect(x: 330, y: 56, width: 10, height: 52))
        fill(rgb(0x6B4A33), NSRect(x: 440, y: 56, width: 10, height: 52))
        fill(rgb(0x6B4A33), NSRect(x: 340, y: 84, width: 100, height: 22))
        fill(rgb(0x8A6448), NSRect(x: 380, y: 92, width: 20, height: 4), radius: 2)
        fill(rgb(0xBFC4CC), NSRect(x: 392, y: 114, width: 40, height: 28), radius: 3)
        let glow = anim.mood == .working ? 0.7 + 0.3 * CGFloat(abs(sin(t * 3))) : 0.85
        Renderer.rayColor(p.data.skin, 0, t).withAlphaComponent(glow).setFill()
        Renderer.sparkle(at: NSPoint(x: 412, y: 128), size: 6)
        if p.placed("lamp") {
            fill(rgb(0x444444), NSRect(x: 436, y: 114, width: 12, height: 3), radius: 1)
            rgb(0x444444).setStroke()
            let arm = NSBezierPath(); arm.lineWidth = 2.5
            arm.move(to: NSPoint(x: 442, y: 116)); arm.line(to: NSPoint(x: 446, y: 140)); arm.line(to: NSPoint(x: 434, y: 150)); arm.stroke()
            fill(rgb(0xF2C94C), NSRect(x: 424, y: 144, width: 18, height: 9), radius: 4)
            if lampOn {
                let cone = NSBezierPath()
                cone.move(to: NSPoint(x: 426, y: 145)); cone.line(to: NSPoint(x: 400, y: 112)); cone.line(to: NSPoint(x: 446, y: 112)); cone.line(to: NSPoint(x: 440, y: 145)); cone.close()
                rgb(0xFFE9A0, 0.25).setFill(); cone.fill()
            }
        }
    }

    private func drawCat() {
        guard p.placed("cat") else { return }
        let t = now()
        let x: CGFloat = 112, y: CGFloat = 98
        rgb(0x3A3A3A).setStroke()
        let tail = NSBezierPath(); tail.lineWidth = 3; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: x + 10, y: y + 2))
        tail.curve(to: NSPoint(x: x + 20, y: y + 14 + CGFloat(sin(t * 2)) * 4), controlPoint1: NSPoint(x: x + 20, y: y), controlPoint2: NSPoint(x: x + 22, y: y + 8))
        tail.stroke()
        fill(rgb(0x3A3A3A), NSRect(x: x - 10, y: y, width: 22, height: 16), radius: 8)
        fill(rgb(0x3A3A3A), NSRect(x: x - 14, y: y + 10, width: 16, height: 14), radius: 7)
        rgb(0x3A3A3A).setFill()
        for ex in [-12.0, -2.0] as [CGFloat] {
            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: x + ex, y: y + 21)); ear.line(to: NSPoint(x: x + ex + 2, y: y + 28)); ear.line(to: NSPoint(x: x + ex + 5, y: y + 21)); ear.close()
            ear.fill()
        }
        let blink = fmod(t, 4) < 0.15
        fill(rgb(0xB7F06A), NSRect(x: x - 11, y: y + 15, width: 3, height: blink ? 0.6 : 3), radius: 1)
        fill(rgb(0xB7F06A), NSRect(x: x - 4, y: y + 15, width: 3, height: blink ? 0.6 : 3), radius: 1)
        if t - catHeartAt < 1.5 {
            let ph = CGFloat(t - catHeartAt) / 1.5
            rgb(0xE5395B, 1 - ph).setFill()
            Renderer.heart(at: NSPoint(x: x - 6, y: y + 32 + ph * 18), size: 5)
        }
    }

    /// Bubbles under the sea and disco sparkles while the music plays.
    private func drawAmbient(_ t: Double) {
        if p.data.room == "reef" {
            for i in 0..<10 {
                let x = CGFloat((i * 47) % 440) + 10 + CGFloat(sin(t + Double(i))) * 5
                let y = hudH + CGFloat(fmod(t * (16 + Double(i % 3) * 6) + Double(i * 37), Double(H - hudH)))
                NSColor(white: 1, alpha: 0.35).setStroke()
                let b = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 5 + CGFloat(i % 3), height: 5 + CGFloat(i % 3))); b.lineWidth = 1; b.stroke()
            }
        }
        if p.placed("disco") && musicOn {
            let colors: [UInt32] = [0xFF6B9A, 0xFFD54F, 0x7CF29A, 0x6EC6FF, 0xC59BFF]
            for i in 0..<14 {
                let a = t * 0.8 + Double(i) * 0.45
                let x = W / 2 + CGFloat(cos(a)) * CGFloat(80 + (i * 23) % 150)
                let y = 190 + CGFloat(sin(a * 1.3)) * CGFloat(40 + (i * 11) % 90)
                fill(rgb(colors[i % colors.count], 0.35), NSRect(x: x, y: y, width: 7, height: 7), radius: 3.5)
            }
        }
    }

    private func typingParticles(at c: NSPoint) {
        let t = now()
        for k in 0..<4 {
            let ph = CGFloat(fmod(t * 0.8 + Double(k) / 4, 1))
            let glyph = ["{", "}", ";", "</>"][k]
            text(glyph, NSPoint(x: c.x + 22 + ph * 14 + CGFloat(k) * 4, y: c.y + 4 + ph * 34), size: 10, color: rgb(0x3F7FE0, 1 - ph), weight: .bold, mono: true)
        }
    }

    private func drawCookie(target c: NSPoint) {
        guard var y = cookieY else { return }
        y -= 4
        if y <= c.y + 14 {
            cookieY = nil
            anim.chomp()
            Synth.shared.chomp()
            if onFeed?() == false { say("I'm stuffed! 🥴") } else { say(["nom nom nom", "yummy! 🍪", "more please!", "crunchy!"].randomElement()!) }
            return
        }
        cookieY = y
        fill(rgb(0xD9A066), NSRect(x: c.x - 7, y: y, width: 14, height: 14), radius: 7)
        rgb(0x5A3A24).setFill()
        for (dx, dy) in [(3.0, 4.0), (8.0, 9.0), (5.0, 10.0), (9.0, 3.0)] as [(CGFloat, CGFloat)] {
            NSBezierPath(ovalIn: NSRect(x: c.x - 7 + dx, y: y + dy - 1, width: 2.5, height: 2.5)).fill()
        }
    }

    private func drawSpeech(above pt: NSPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor(white: 0.12, alpha: 1)]
        let size = (speech as NSString).size(withAttributes: attrs)
        let w = min(220, size.width + 16)
        var r = NSRect(x: pt.x - w / 2, y: pt.y + 4, width: w, height: 22)
        r.origin.x = max(6, min(W - w - 6, r.origin.x))
        r.origin.y = min(H - 30, r.origin.y)
        NSColor(white: 0.99, alpha: 0.97).setFill()
        let path = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
        path.move(to: NSPoint(x: pt.x - 5, y: r.minY + 1)); path.line(to: NSPoint(x: pt.x, y: r.minY - 6)); path.line(to: NSPoint(x: pt.x + 5, y: r.minY + 1))
        path.fill()
        (speech as NSString).draw(in: r.insetBy(dx: 8, dy: 4), withAttributes: attrs)
    }

    private func drawToast() {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12.5, weight: .bold), .foregroundColor: NSColor.white]
        let w = min(W - 20, (toast as NSString).size(withAttributes: attrs).width + 28)
        let e = now() - (toastUntil - 4.5)
        let drop = CGFloat(max(0, 1 - e / 0.3)) * 30
        let r = NSRect(x: (W - w) / 2, y: H - 40 + drop, width: w, height: 28)
        fill(rgb(0x2B2D42, 0.95), r, radius: 14)
        (toast as NSString).draw(in: NSRect(x: r.minX + 14, y: r.minY + 6, width: r.width - 20, height: 18), withAttributes: attrs)
    }

    // MARK: HUD

    private let hudIcons = ["🍪", "🕹️", "👕", "🛍️", "📋", "🛠️", "⌨️"]
    private let hudLabels = ["Feed", "Arcade", "Style", "Shop", "Daily quests", "Edit room", "Console"]
    private let hudOverlays: [Overlay?] = [nil, .arcade, .style, .shop, .quests, .edit, .console]
    private func hudButton(_ i: Int) -> NSRect { NSRect(x: 232 + CGFloat(i) * 32, y: 8, width: 29, height: 28) }
    private let coinRect = NSRect(x: 168, y: 10, width: 58, height: 24)

    private func drawHUD() {
        fill(rgb(0x1E1B2E), NSRect(x: 0, y: 0, width: W, height: hudH))
        fill(claudeOrange, NSRect(x: 8, y: 11, width: 42, height: 22), radius: 11)
        let lv = "Lv \(p.level)"
        text(lv, NSPoint(x: 29 - textWidth(lv, size: 12, weight: .heavy) / 2, y: 14), size: 12, color: .white, weight: .heavy)
        text(p.data.name, NSPoint(x: 56, y: 23), size: 10.5, color: .white, weight: .bold)
        fill(NSColor(white: 1, alpha: 0.15), NSRect(x: 56, y: 12, width: 104, height: 7), radius: 3.5)
        fill(sparkYellow, NSRect(x: 56, y: 12, width: max(7, 104 * CGFloat(p.levelFraction)), height: 7), radius: 3.5)
        fill(NSColor(white: 1, alpha: 0.1), coinRect, radius: 12)
        let coins = "🪙 \(p.data.coins)"
        text(coins, NSPoint(x: coinRect.midX - textWidth(coins, size: 11, weight: .bold) / 2, y: coinRect.minY + 5), size: 11, color: sparkYellow, weight: .bold)

        let m = mouse
        var tip: (String, NSRect)?
        for (i, icon) in hudIcons.enumerated() {
            let r = hudButton(i)
            let active = hudOverlays[i] != nil && hudOverlays[i] == overlay || (i == 1 && gameOpen)
            fill(active ? claudeOrange : NSColor(white: 1, alpha: r.contains(m) ? 0.2 : 0.1), r, radius: 8)
            let ic = i == 0 && anim.sick ? "💊" : icon
            text(ic, NSPoint(x: r.midX - 8.5, y: r.minY + 5), size: 14, color: .white)
            if r.contains(m) { tip = (i == 0 && anim.sick ? "Give medicine" : hudLabels[i], r) }
        }
        if NSRect(x: 8, y: 6, width: 156, height: 32).contains(m) {
            tip = ("Level \(p.level) · \(p.data.xp) / \(BuddyProgress.xpNeeded(p.level + 1)) XP", NSRect(x: 8, y: 8, width: 156, height: 28))
        }
        if coinRect.contains(m) { tip = ("Coins: earn them from sessions, games and quests", coinRect) }
        if let (label, r) = tip {
            let w = textWidth(label, size: 10.5, weight: .semibold) + 16
            let x = max(4, min(W - w - 4, r.midX - w / 2))
            fill(rgb(0x2B2D42, 0.96), NSRect(x: x, y: hudH + 4, width: w, height: 20), radius: 6)
            text(label, NSPoint(x: x + 8, y: hudH + 7), size: 10.5, color: .white, weight: .semibold)
        }
    }

    // MARK: Shared panel pieces

    private let panel = NSRect(x: 10, y: 52, width: 440, height: 280)
    private var closeRect: NSRect { NSRect(x: panel.maxX - 28, y: panel.maxY - 30, width: 22, height: 22) }

    private func drawPanel(title: String, tabs: [String]) {
        fill(rgb(0x1E1B2E, 0.95), panel, radius: 14)
        if tabs.isEmpty {
            text(title, NSPoint(x: panel.minX + 16, y: panel.maxY - 30), size: 14, color: .white, weight: .heavy)
        } else {
            let tw = (panel.width - 50) / CGFloat(tabs.count)
            for (i, name) in tabs.enumerated() {
                let r = tabRect(i, count: tabs.count, width: tw)
                fill(i == tab ? claudeOrange : NSColor(white: 1, alpha: r.contains(mouse) ? 0.18 : 0.1), r, radius: 11)
                centerText(name, in: r, y: r.minY + 5, size: 10.5, color: .white, weight: .semibold)
            }
        }
        text("✕", NSPoint(x: closeRect.minX + 5, y: closeRect.minY + 3), size: 14, color: NSColor(white: closeRect.contains(mouse) ? 1 : 0.7, alpha: 1), weight: .bold)
    }

    private func tabRect(_ i: Int, count: Int, width tw: CGFloat) -> NSRect {
        NSRect(x: panel.minX + 10 + CGFloat(i) * tw, y: panel.maxY - 32, width: tw - 4, height: 24)
    }

    private func tabHit(_ pt: NSPoint, count: Int) -> Int? {
        let tw = (panel.width - 50) / CGFloat(count)
        return (0..<count).first { tabRect($0, count: count, width: tw).contains(pt) }
    }

    private func cellRect(_ i: Int) -> NSRect {
        NSRect(x: panel.minX + 10 + CGFloat(i % 5) * 85, y: panel.maxY - 130 - CGFloat(i / 5) * 98, width: 80, height: 92)
    }

    private let perPage = 10
    private var prevRect: NSRect { NSRect(x: panel.maxX - 76, y: panel.minY + 6, width: 24, height: 22) }
    private var nextRect: NSRect { NSRect(x: panel.maxX - 30, y: panel.minY + 6, width: 24, height: 22) }
    private var buyRect: NSRect { NSRect(x: panel.maxX - 152, y: panel.minY + 6, width: 60, height: 22) }
    private var cancelRect: NSRect { NSRect(x: panel.maxX - 86, y: panel.minY + 6, width: 60, height: 22) }

    private func drawPager(count: Int) {
        let pages = max(1, (count + perPage - 1) / perPage)
        page = min(page, pages - 1)
        guard pages > 1, pendingBuy == nil else { return }
        let label = "\(page + 1)/\(pages)"
        text(label, NSPoint(x: prevRect.maxX + 11 - textWidth(label, size: 10.5) / 2, y: prevRect.minY + 4), size: 10.5, color: NSColor(white: 0.8, alpha: 1))
        for (r, s, on) in [(prevRect, "‹", page > 0), (nextRect, "›", page < pages - 1)] {
            fill(NSColor(white: 1, alpha: on ? (r.contains(mouse) ? 0.25 : 0.14) : 0.05), r, radius: 6)
            text(s, NSPoint(x: r.midX - 4, y: r.minY + 1), size: 15, color: NSColor(white: 1, alpha: on ? 1 : 0.3), weight: .bold)
        }
    }

    private func pagerHit(_ pt: NSPoint, count: Int) -> Bool {
        let pages = max(1, (count + perPage - 1) / perPage)
        guard pages > 1, pendingBuy == nil else { return false }
        if prevRect.contains(pt) { if page > 0 { page -= 1; Synth.shared.pop() }; return true }
        if nextRect.contains(pt) { if page < pages - 1 { page += 1; Synth.shared.pop() }; return true }
        return false
    }

    /// Draws one item's preview inside a cell.
    private func drawPreview(_ it: Item, at c: NSPoint, locked: Bool) {
        NSGraphicsContext.saveGraphicsState()
        if locked { NSGraphicsContext.current?.cgContext.setAlpha(0.3) }
        let d = p.data
        switch it.kind {
        case .skin: Renderer.draw(skin: it.id, hat: "none", pose: Pose(), at: c, scale: 0.55, shadow: false)
        case .hat: Renderer.draw(skin: d.skin, hat: it.id, pose: Pose(), at: NSPoint(x: c.x, y: c.y - 6), scale: 0.55, shadow: false)
        case .accessory: Renderer.draw(skin: d.skin, hat: "none", accessory: it.id, pose: Pose(), at: c, scale: 0.62, shadow: false)
        case .room:
            let th = roomTheme(it.id)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 46), xRadius: 5, yRadius: 5).addClip()
            paintWall(th, in: NSRect(x: c.x - 28, y: c.y - 4, width: 56, height: 28), t: 0)
            paintFloor(th, in: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 18))
            NSGraphicsContext.restoreGraphicsState()
        case .wallpaper:
            var th = roomTheme(d.room)
            if let w = wallpaperStyle(it.id) { th.wall = w.0; th.wallLine = w.1; th.wallPattern = w.2 }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 46), xRadius: 5, yRadius: 5).addClip()
            paintWall(th, in: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 46), t: 0)
            NSGraphicsContext.restoreGraphicsState()
        case .floor:
            var th = roomTheme(d.room)
            if let f = floorStyle(it.id) { th.floor = f.0; th.floorLine = f.1; th.floorPattern = f.2 }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 46), xRadius: 5, yRadius: 5).addClip()
            paintFloor(th, in: NSRect(x: c.x - 28, y: c.y - 22, width: 56, height: 46))
            NSGraphicsContext.restoreGraphicsState()
        case .decor:
            text(decorIcons[it.id] ?? "📦", NSPoint(x: c.x - 15, y: c.y - 16), size: 26, color: .white)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The item grid used by both Style and Shop.
    private func drawGrid(_ items: [Item], shop: Bool) -> String? {
        let m = mouse
        var hover: String?
        let slice = Array(items.dropFirst(page * perPage).prefix(perPage))
        let deal = p.dailyDeal?.id
        for (i, it) in slice.enumerated() {
            let r = cellRect(i)
            let unlocked = p.isUnlocked(it)
            let equipped = unlocked && p.isEquipped(it)
            fill(NSColor(white: 1, alpha: r.contains(m) ? 0.15 : 0.07), r, radius: 10)
            if equipped || pendingBuy?.id == it.id {
                (pendingBuy?.id == it.id ? sparkYellow : claudeOrange).setStroke()
                let b = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10); b.lineWidth = 2; b.stroke()
            }
            let c = NSPoint(x: r.midX, y: r.minY + 54)
            let secret = !unlocked && it.level == nil && it.price == nil
            if secret {
                text("?", NSPoint(x: c.x - 7, y: c.y - 14), size: 26, color: NSColor(white: 1, alpha: 0.35), weight: .heavy)
            } else {
                drawPreview(it, at: c, locked: !unlocked)
            }
            let name = secret ? "Secret" : it.name
            centerText(name, in: r, y: r.minY + 18, size: 10.5, color: .white, weight: .medium)
            var tag = ""
            var tagColor = NSColor(white: 0.7, alpha: 1)
            if unlocked {
                tag = equipped ? (it.kind == .decor ? "In room" : "Wearing") : (shop ? "Owned" : "")
                if it.kind == .decor && !equipped { tag = "Put away" }
                if [.room, .wallpaper, .floor].contains(it.kind) && equipped { tag = "Using" }
            } else if let price = p.price(it) {
                tag = "🪙 \(price)"
                tagColor = p.data.coins >= price ? sparkYellow : rgb(0xFF8A80)
            } else if let l = it.level { tag = "🔒 Lv \(l)" } else { tag = "🔒 secret" }
            if !tag.isEmpty { centerText(tag, in: r, y: r.minY + 5, size: 9.5, color: tagColor, weight: .semibold) }
            if !unlocked && deal == it.id {
                fill(rgb(0xE5395B), NSRect(x: r.maxX - 32, y: r.maxY - 16, width: 30, height: 14), radius: 7)
                text("-30%", NSPoint(x: r.maxX - 29, y: r.maxY - 15), size: 9, color: .white, weight: .heavy)
            }
            if r.contains(m) {
                if unlocked {
                    hover = it.kind == .decor ? (equipped ? "Click to put \(it.name) away." : "Click to put \(it.name) in the room.") : "Click to use \(it.name)."
                } else if let price = p.price(it) {
                    hover = "\(it.name) costs 🪙\(price). Click to buy."
                } else if let l = it.level {
                    hover = "Reach level \(l) to unlock \(it.name)."
                } else {
                    hover = "Hint: \(it.hint)"
                }
            }
        }
        drawPager(count: items.count)
        return hover
    }

    private func drawFooter(_ s: String) {
        if let it = pendingBuy, let price = p.price(it) {
            let afford = p.data.coins >= price
            text(afford ? "Buy \(it.name) for 🪙\(price)?" : "You need 🪙\(price - p.data.coins) more for \(it.name).",
                 NSPoint(x: panel.minX + 14, y: panel.minY + 10), size: 11.5, color: afford ? sparkYellow : rgb(0xFF8A80), weight: .semibold)
            if afford {
                fill(claudeOrange, buyRect, radius: 7)
                centerText("Buy", in: buyRect, y: buyRect.minY + 4, size: 11, color: .white, weight: .bold)
            }
            fill(NSColor(white: 1, alpha: 0.15), cancelRect, radius: 7)
            centerText(afford ? "Cancel" : "OK", in: cancelRect, y: cancelRect.minY + 4, size: 11, color: .white, weight: .bold)
            return
        }
        text(buyNote.isEmpty ? s : buyNote, NSPoint(x: panel.minX + 14, y: panel.minY + 10), size: 11, color: sparkYellow, weight: .medium)
    }

    /// Handles a click on a grid cell; returns true if it hit one.
    private func gridClick(_ pt: NSPoint, items: [Item]) -> Bool {
        let slice = Array(items.dropFirst(page * perPage).prefix(perPage))
        for (i, it) in slice.enumerated() where cellRect(i).contains(pt) {
            buyNote = ""
            if p.isUnlocked(it) {
                pendingBuy = nil
                p.equip(it)
                Synth.shared.unlock()
                if it.kind != .decor { anim.celebrate() }
            } else if p.price(it) != nil {
                pendingBuy = it
                Synth.shared.pop()
            } else {
                pendingBuy = nil
                Synth.shared.grumble()
            }
            return true
        }
        return false
    }

    private func buyClick(_ pt: NSPoint) -> Bool {
        guard let it = pendingBuy else { return false }
        if buyRect.contains(pt), p.buy(it) {
            pendingBuy = nil
            p.equip(it)
            Synth.shared.coin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Synth.shared.unlock() }
            anim.celebrate()
            buyNote = "Yours! \(it.name) is " + (it.kind == .decor ? "in the room. Use 🛠️ to move it." : "on. ✨")
            say(["ooh, fancy! ✨", "I love it!!", "for ME?! 🥹", "shopping spree! 🛍️"].randomElement()!)
            return true
        }
        if cancelRect.contains(pt) { pendingBuy = nil; return true }
        return false
    }

    // MARK: Style

    private let styleTabs = ["Skins", "Hats", "Extras", "Rooms", "Walls", "Floors", "Decor", "Trophies"]
    private let styleKinds: [ItemKind] = [.skin, .hat, .accessory, .room, .wallpaper, .floor, .decor]
    private var styleItems: [Item] { tab < styleKinds.count ? catalog.filter { $0.kind == styleKinds[tab] } : [] }

    private func drawStyle() {
        drawPanel(title: "", tabs: styleTabs)
        if tab == 7 { drawTrophies(); return }
        let hover = drawGrid(styleItems, shop: false)
        drawFooter(hover ?? "Click something you've unlocked to use it.")
    }

    private func drawTrophies() {
        let list = Array(achievements.dropFirst(page * perPage).prefix(perPage))
        for (i, a) in list.enumerated() {
            let got = p.hasAchievement(a.id)
            let x = panel.minX + 16 + CGFloat(i % 2) * 214
            let y = panel.maxY - 66 - CGFloat(i / 2) * 41
            fill(NSColor(white: 1, alpha: got ? 0.12 : 0.05), NSRect(x: x - 6, y: y - 6, width: 206, height: 36), radius: 8)
            text(got ? "🏆" : "🔒", NSPoint(x: x, y: y + 4), size: 15, color: .white)
            text(got ? a.name : "???", NSPoint(x: x + 26, y: y + 12), size: 11.5, color: .white, weight: .bold)
            text(a.hint, NSPoint(x: x + 26, y: y - 1), size: 9.5, color: NSColor(white: 0.65, alpha: 1))
        }
        drawPager(count: achievements.count)
        text("\(p.data.achievements.count)/\(achievements.count) trophies", NSPoint(x: panel.minX + 14, y: panel.minY + 10), size: 11, color: sparkYellow, weight: .semibold)
    }

    // MARK: Shop

    private let shopTabs = ["Furniture", "Walls", "Floors", "Outfits", "Rooms"]
    private var shopItems: [Item] {
        let kinds: [[ItemKind]] = [[.decor], [.wallpaper], [.floor], [.skin, .hat, .accessory], [.room]]
        return catalog.filter { $0.price != nil && kinds[min(tab, 4)].contains($0.kind) }
    }

    private func drawShop() {
        drawPanel(title: "", tabs: shopTabs)
        let hover = drawGrid(shopItems, shop: true)
        var footer = "🪙 \(p.data.coins) to spend"
        if let d = p.dailyDeal, let price = p.price(d) { footer += "  ·  🔥 Deal of the day: \(d.name) for 🪙\(price)" }
        drawFooter(hover ?? footer)
    }

    // MARK: Quests

    private func drawQuests() {
        drawPanel(title: "📋 Daily quests", tabs: [])
        p.rollDay()
        let d = p.data
        let streak = "🔥 \(d.streak)-day streak"
        text(streak, NSPoint(x: panel.maxX - 40 - textWidth(streak, size: 12, weight: .bold), y: panel.maxY - 29), size: 12, color: rgb(0xFFB74D), weight: .bold)
        for (i, q) in d.quests.enumerated() {
            guard let def = questPool.first(where: { $0.id == q.id }) else { continue }
            let r = NSRect(x: panel.minX + 12, y: panel.maxY - 84 - CGFloat(i) * 48, width: panel.width - 24, height: 42)
            fill(NSColor(white: 1, alpha: q.done ? 0.14 : 0.07), r, radius: 9)
            text(q.done ? "✅" : "⬜️", NSPoint(x: r.minX + 10, y: r.minY + 12), size: 15, color: .white)
            text(def.text, NSPoint(x: r.minX + 38, y: r.minY + 22), size: 12, color: .white, weight: .semibold)
            let frac = CGFloat(min(1, Double(q.progress) / Double(def.goal)))
            fill(NSColor(white: 1, alpha: 0.12), NSRect(x: r.minX + 38, y: r.minY + 9, width: 240, height: 7), radius: 3.5)
            fill(q.done ? rgb(0x7CF29A) : sparkYellow, NSRect(x: r.minX + 38, y: r.minY + 9, width: max(7, 240 * frac), height: 7), radius: 3.5)
            text("\(q.progress)/\(def.goal)", NSPoint(x: r.minX + 286, y: r.minY + 6), size: 10, color: NSColor(white: 0.75, alpha: 1), weight: .medium)
            let reward = q.done ? "Done!" : "🪙 \(def.coins)"
            text(reward, NSPoint(x: r.maxX - 12 - textWidth(reward, size: 12, weight: .bold), y: r.minY + 14), size: 12, color: q.done ? rgb(0x7CF29A) : sparkYellow, weight: .bold)
        }
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: Date().addingTimeInterval(86400))
        let left = Int(midnight.timeIntervalSinceNow)
        let all = d.quests.allSatisfy(\.done)
        text(all ? "All done today! 🎉 New quests in \(left / 3600)h \(left % 3600 / 60)m" : "Finish all three for a 🪙25 bonus · new quests in \(left / 3600)h \(left % 3600 / 60)m",
             NSPoint(x: panel.minX + 14, y: panel.maxY - 204), size: 10.5, color: NSColor(white: 0.75, alpha: 1), weight: .medium)

        let statsY = panel.minY + 40
        fill(NSColor(white: 1, alpha: 0.06), NSRect(x: panel.minX + 12, y: panel.minY + 8, width: panel.width - 24, height: 56), radius: 9)
        text("Today", NSPoint(x: panel.minX + 24, y: statsY + 4), size: 11, color: claudeOrange, weight: .heavy)
        text("\(d.sessionsToday) sessions · \(d.focusToday) min focus · \(d.cookiesToday) cookies", NSPoint(x: panel.minX + 70, y: statsY + 4), size: 11, color: .white, weight: .medium)
        text("All time", NSPoint(x: panel.minX + 24, y: statsY - 18), size: 11, color: claudeOrange, weight: .heavy)
        text("\(d.sessions) sessions · \(d.gamesPlayed) games · \(d.questsDone) quests · \(d.focusMinutes) min focus", NSPoint(x: panel.minX + 80, y: statsY - 18), size: 11, color: .white, weight: .medium)
    }

    // MARK: Arcade

    private func arcadeCard(_ i: Int) -> NSRect {
        let w: CGFloat = 132, h: CGFloat = 100
        if i < 3 { return NSRect(x: panel.minX + 12 + CGFloat(i) * (w + 8), y: panel.maxY - 148, width: w, height: h) }
        return NSRect(x: panel.minX + 82 + CGFloat(i - 3) * (w + 8), y: panel.maxY - 256, width: w, height: h)
    }

    private func drawArcade() {
        drawPanel(title: "🕹️ Arcade", tabs: [])
        let m = mouse
        for (i, g) in arcadeGames.enumerated() {
            let r = arcadeCard(i)
            fill(NSColor(white: 1, alpha: r.contains(m) ? 0.18 : 0.08), r, radius: 12)
            if r.contains(m) {
                claudeOrange.setStroke()
                let b = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12); b.lineWidth = 2; b.stroke()
            }
            centerText(g.icon, in: r, y: r.maxY - 40, size: 26, color: .white)
            centerText(g.name, in: r, y: r.minY + 40, size: 12.5, color: .white, weight: .bold)
            centerText(g.blurb, in: r, y: r.minY + 24, size: 9.5, color: NSColor(white: 0.72, alpha: 1), weight: .medium)
            let best = p.data.best[g.id] ?? 0
            centerText(best > 0 ? "Best \(g.id == "copycat" ? best + 1 : best)" : "New!", in: r, y: r.minY + 7, size: 10, color: sparkYellow, weight: .bold)
        }
        text("Every game pays XP and 🪙 coins.", NSPoint(x: panel.minX + 14, y: panel.minY + 8), size: 10.5, color: NSColor(white: 0.7, alpha: 1), weight: .medium)
    }

    // MARK: Edit room

    private var doneEditRect: NSRect { NSRect(x: W - 74, y: H - 32, width: 64, height: 24) }
    private func xButton(_ id: String) -> NSRect { let r = decorRect(id); return NSRect(x: r.maxX - 8, y: r.maxY - 8, width: 16, height: 16) }
    private var editable: [DecorSpec] { decorSpecs.filter { $0.movable && p.placed($0.id) } }
    private var putAway: [Item] { catalog.filter { $0.kind == .decor && p.has($0.id) && !p.placed($0.id) } }
    private func trayChip(_ i: Int, _ x: inout CGFloat, _ name: String) -> NSRect {
        let w = textWidth("+ " + name, size: 10.5, weight: .semibold) + 16
        defer { x += w + 6 }
        return NSRect(x: x, y: H - 64, width: w, height: 22)
    }

    private func drawEdit() {
        let m = mouse
        fill(rgb(0x1E1B2E, 0.9), NSRect(x: 0, y: H - 38, width: W, height: 38))
        text("🛠️ Drag furniture to move it. ✕ puts it away.", NSPoint(x: 12, y: H - 26), size: 11.5, color: .white, weight: .semibold)
        fill(claudeOrange, doneEditRect, radius: 8)
        centerText("Done", in: doneEditRect, y: doneEditRect.minY + 4, size: 11.5, color: .white, weight: .bold)
        for s in editable {
            let r = decorRect(s.id).insetBy(dx: -3, dy: -3)
            let hot = dragID == s.id || r.contains(m)
            (hot ? sparkYellow : NSColor(white: 1, alpha: 0.7)).setStroke()
            let path = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
            path.lineWidth = hot ? 2 : 1.2
            path.setLineDash([5, 3], count: 2, phase: CGFloat(now() * 12).truncatingRemainder(dividingBy: 8))
            path.stroke()
            if hot {
                let x = xButton(s.id)
                fill(rgb(0xE5484D), x, radius: 8)
                text("✕", NSPoint(x: x.minX + 3.5, y: x.minY + 1.5), size: 10, color: .white, weight: .heavy)
            }
        }
        // Tray of furniture that's put away
        let away = putAway
        fill(rgb(0x1E1B2E, 0.75), NSRect(x: 0, y: H - 68, width: W, height: 30))
        if away.isEmpty {
            text("Everything you own is in the room. Buy more in the 🛍️ shop!", NSPoint(x: 12, y: H - 60), size: 10.5, color: NSColor(white: 0.75, alpha: 1), weight: .medium)
        } else {
            var x: CGFloat = 10
            for (i, it) in away.enumerated() {
                let r = trayChip(i, &x, it.name)
                guard r.maxX < W - 6 else { break }
                fill(NSColor(white: 1, alpha: r.contains(m) ? 0.25 : 0.12), r, radius: 11)
                text("+ " + it.name, NSPoint(x: r.minX + 8, y: r.minY + 4), size: 10.5, color: .white, weight: .semibold)
            }
        }
    }

    private func editMouseDown(_ pt: NSPoint) {
        if doneEditRect.contains(pt) { open(.edit); return }
        var x: CGFloat = 10
        for (i, it) in putAway.enumerated() {
            let r = trayChip(i, &x, it.name)
            guard r.maxX < W - 6 else { break }
            if r.contains(pt) { p.equip(it); Synth.shared.pop(); return }
        }
        for s in editable.reversed() {
            if xButton(s.id).contains(pt) && decorRect(s.id).insetBy(dx: -10, dy: -10).contains(pt) {
                if let it = item(s.id) { p.equip(it); Synth.shared.pop() }
                return
            }
            if decorRect(s.id).insetBy(dx: -3, dy: -3).contains(pt) {
                dragID = s.id
                dragStartX = pt.x
                dragStartDX = offset(s.id)
                Synth.shared.pop()
                return
            }
        }
    }

    private func finishEditing() {
        dragID = nil
        p.save()
        if movedSomething { p.achieve("decorator") }
        movedSomething = false
    }

    // MARK: Console

    private let consoleRect = NSRect(x: 10, y: 52, width: 440, height: 150)

    private func drawConsole() {
        fill(rgb(0x0F1117, 0.95), consoleRect, radius: 10)
        for (k, color) in [rgb(0xFF5F57), rgb(0xFEBC2E), rgb(0x28C840)].enumerated() {
            fill(color, NSRect(x: consoleRect.minX + 10 + CGFloat(k) * 14, y: consoleRect.maxY - 16, width: 9, height: 9), radius: 4.5)
        }
        let lines = consoleLines.suffix(7)
        for (k, line) in lines.enumerated() {
            text(line, NSPoint(x: consoleRect.minX + 12, y: consoleRect.maxY - 36 - CGFloat(k) * 15), size: 11, color: rgb(0xCFE8D2), mono: true)
        }
        text("buddy@room ~ %", NSPoint(x: consoleRect.minX + 12, y: 61), size: 12, color: claudeOrange, weight: .bold, mono: true)
    }

    @objc private func submitCommand() {
        let cmd = input.stringValue.trimmingCharacters(in: .whitespaces)
        input.stringValue = ""
        guard !cmd.isEmpty else { return }
        consoleLines.append("% " + cmd)
        if consoleLines.count > 200 { consoleLines.removeFirst(consoleLines.count - 200) }
        if cmd == "clear" { consoleLines.removeAll(); return }
        if cmd == "exit" { open(.console); return }
        let out = onCommand?(cmd) ?? []
        if overlay == .console { consoleLines.append(contentsOf: out) }
    }

    // MARK: Input

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { if overlay != .none { open(overlay) }; return }
        if [.style, .shop].contains(overlay) {
            let count = overlay == .shop ? shopItems.count : tab == 7 ? achievements.count : styleItems.count
            let pages = max(1, (count + perPage - 1) / perPage)
            if event.keyCode == 123 { page = max(0, page - 1); return }
            if event.keyCode == 124 { page = min(pages - 1, page + 1); return }
        }
        super.keyDown(with: event)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { open(.console); return true }
        return false
    }

    private var scrollAccum: CGFloat = 0
    private var lastFlip = -100.0

    /// Scrolling (or swiping) flips pages in Style and Shop.
    override func scrollWheel(with event: NSEvent) {
        guard [.style, .shop].contains(overlay), event.momentumPhase == [] else { return }
        let count = overlay == .shop ? shopItems.count : tab == 7 ? achievements.count : styleItems.count
        let pages = max(1, (count + perPage - 1) / perPage)
        scrollAccum += abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) ? -event.scrollingDeltaY : -event.scrollingDeltaX
        guard abs(scrollAccum) > 30, now() - lastFlip > 0.35 else { return }
        let dir = scrollAccum > 0 ? 1 : -1
        scrollAccum = 0
        lastFlip = now()
        let np = max(0, min(pages - 1, page + dir))
        if np != page { page = np; Synth.shared.pop() }
    }

    /// Used by the --snapshot renderer.
    func debugShow(_ o: Overlay, tab t: Int = 0, page pg: Int = 0, pending: String? = nil) {
        if overlay != o { open(o) }
        tab = t; page = pg
        pendingBuy = pending.flatMap(item)
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard overlay == .edit, let id = dragID, let s = decorSpecs.first(where: { $0.id == id }) else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let dx = max(4 - s.rect.minX, min(W - 4 - s.rect.maxX, dragStartDX + pt.x - dragStartX))
        p.setDecorX(id, Double(dx))
        movedSomething = true
    }

    override func mouseUp(with event: NSEvent) {
        if dragID != nil { dragID = nil; p.save() }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let t = now()

        if pt.y < hudH {
            for i in hudIcons.indices where hudButton(i).contains(pt) {
                if i == 0 { feed() } else if let o = hudOverlays[i] {
                    if i == 1 && gameOpen { closeGames(); return }
                    open(o)
                    Synth.shared.pop()
                }
                return
            }
            if coinRect.contains(pt) { open(.shop) }
            return
        }

        switch overlay {
        case .style, .shop:
            if closeRect.contains(pt) { open(overlay); return }
            if buyClick(pt) { return }
            let tabs = overlay == .style ? styleTabs.count : shopTabs.count
            if let i = tabHit(pt, count: tabs) { tab = i; page = 0; pendingBuy = nil; buyNote = ""; Synth.shared.pop(); return }
            if overlay == .style && tab == 7 { _ = pagerHit(pt, count: achievements.count); return }
            let items = overlay == .style ? styleItems : shopItems
            if pagerHit(pt, count: items.count) { return }
            _ = gridClick(pt, items: items)
            return
        case .quests:
            if closeRect.contains(pt) || !panel.contains(pt) { open(.quests) }
            return
        case .arcade:
            if closeRect.contains(pt) || !panel.contains(pt) { open(.arcade); return }
            for (i, g) in arcadeGames.enumerated() where arcadeCard(i).contains(pt) { Synth.shared.pop(); startGame(g.id); return }
            return
        case .console:
            if !consoleRect.contains(pt) { open(.console) }
            return
        case .edit:
            editMouseDown(pt)
            return
        case .none:
            break
        }

        let pose = anim.pose(look: .zero)
        let c = buddyCenter()
        if hypot(pt.x - c.x, pt.y - (c.y + pose.lift * roomScale)) < 26 { onPoke?(); return }

        func walk(to x: CGFloat, saying line: String) {
            guard !anim.asleep, anim.mood == .idle else { say(line); return }
            targetX = max(30, min(W - 30, x)); arriveLine = line; nextWander = t + 12
        }
        if p.placed("cat") && NSRect(x: 96, y: 96, width: 30, height: 32).contains(pt) { Synth.shared.meow(); catHeartAt = t; return }
        if p.placed("arcade") && decorRect("arcade").contains(pt) { open(.arcade); return }
        if p.placed("lamp") && NSRect(x: 420, y: 112, width: 32, height: 44).contains(pt) { lampOn.toggle(); Synth.shared.pop(); return }
        if p.placed("records") && p.placed("shelf") && NSRect(x: 392, y: 226, width: 52, height: 16).offsetBy(dx: offset("shelf"), dy: 0).contains(pt) {
            musicOn.toggle()
            if musicOn { Synth.shared.done(pitch: 0.75); anim.dance() }
            return
        }
        if p.placed("disco") && decorRect("disco").contains(pt) {
            musicOn.toggle()
            if musicOn { Synth.shared.done(pitch: 0.75); anim.dance(); say("let's boogie! 🪩") }
            return
        }
        if p.placed("clock") && decorRect("clock").contains(pt) {
            let f = DateFormatter(); f.timeStyle = .short
            say("it's \(f.string(from: Date())) ⏰"); Synth.shared.tick(); return
        }
        if p.placed("trophycase") && decorRect("trophycase").insetBy(dx: 0, dy: -10).contains(pt) { open(.style); tab = 7; return }
        if p.placed("plant") && decorRect("plant").contains(pt) { plantWiggleAt = t; walk(to: decorRect("plant").midX + 16, saying: "*waters plant* 🌱"); return }
        if p.placed("fishtank") && decorRect("fishtank").contains(pt) { walk(to: decorRect("fishtank").midX, saying: "blub blub 🐟"); return }
        if p.placed("beanbag") && decorRect("beanbag").contains(pt) { walk(to: decorRect("beanbag").midX, saying: "*flops onto the beanbag* 😌"); return }
        if p.placed("lavalamp") && decorRect("lavalamp").contains(pt) { walk(to: decorRect("lavalamp").midX + 16, saying: "so mesmerising… 🫧"); return }
        if p.placed("cactus") && decorRect("cactus").contains(pt) { say("ouch! pointy 🌵"); anim.grumpy(); return }
        if p.placed("poster") && decorRect("poster").contains(pt) { say("SHIP IT! 🚀"); anim.celebrate(); return }
        if NSRect(x: 176, y: 172, width: 118, height: 124).contains(pt) {
            let line: String
            switch p.data.room {
            case "space": line = "Hi Earth! 🌍"
            case "reef": line = "hi fishies! 🐠"
            case "cabin": line = "it's so cold out there ❄️"
            case "synthwave": line = "outrun vibes 🌆"
            default: line = isNight ? "Look at the stars ✨" : "What a nice day ☀️"
            }
            walk(to: 235, saying: line); return
        }
        if NSRect(x: 386, y: 112, width: 50, height: 32).contains(pt) { say(anim.mood == .idle ? "Nothing running. Break time!" : "Working on it… ⌨️"); return }
        if NSRect(x: 14, y: 60, width: 126, height: 46).contains(pt) { walk(to: 120, saying: "So comfy… 😴"); return }
    }

    func feed() {
        if anim.sick { onMedicine?(); return }
        guard cookieY == nil, !gameOpen else { return }
        if overlay != .none && overlay != .console { open(overlay) }
        cookieY = H - 20
        Synth.shared.pop()
    }
}

final class RoomWindow: NSWindow {
    init(view: RoomView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: roomW, height: roomH), styleMask: [.titled, .closable, .miniaturizable],
                   backing: .buffered, defer: false)
        title = "Buddy's Room"
        contentView = view
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        center()
    }
}
