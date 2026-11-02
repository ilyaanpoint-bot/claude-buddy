// The arcade: five mini-games that sit over buddy's room. Each game is a MiniGame subview with
// its own frame timer, a shared header, a game-over card and payouts through BuddyProgress.

import AppKit

let gameW: CGFloat = 460
let gameH: CGFloat = 296

struct GameInfo { let id: String; let name: String; let icon: String; let blurb: String }

let arcadeGames: [GameInfo] = [
    GameInfo(id: "bugcatch", name: "Bug Catch", icon: "🐞", blurb: "Catch bugs, dodge errors"),
    GameInfo(id: "copycat", name: "Copycat", icon: "🎵", blurb: "Copy buddy's tune"),
    GameInfo(id: "whack", name: "Whack-a-Bug", icon: "🔨", blurb: "Bonk bugs, not features"),
    GameInfo(id: "hop", name: "Buddy Hop", icon: "🪽", blurb: "Dodge merge conflicts"),
    GameInfo(id: "type", name: "Type Rush", icon: "⌨️", blurb: "Type before it lands"),
]

func makeGame(_ id: String, anim: Animator) -> MiniGame? {
    switch id {
    case "bugcatch": return BugCatchGame(anim: anim)
    case "copycat": return CopycatGame(anim: anim)
    case "whack": return WhackGame(anim: anim)
    case "hop": return HopGame(anim: anim)
    case "type": return TypeRushGame(anim: anim)
    default: return nil
    }
}

class MiniGame: NSView {
    let anim: Animator
    let gameID: String
    let title: String
    var onFinish: ((String, Int) -> GameReward)?
    var onClose: (() -> Void)?

    var score = 0
    private(set) var over = false
    private var reward: GameReward?
    private var timer: Timer?
    private var last = now()
    var started = now()

    var translucent: Bool { false }
    var centerText: String { "Score \(score)" }
    var rightText: String { "" }
    var overTitle: String { "Game over!" }
    var overLine: String { "Score \(score)" }
    var best: Int { BuddyProgress.shared.data.best[gameID] ?? 0 }
    var skin: String { BuddyProgress.shared.data.skin }
    var hat: String { BuddyProgress.shared.data.hat }
    var accessory: String { BuddyProgress.shared.data.accessory }

    private let againRect = NSRect(x: 136, y: 76, width: 88, height: 28)
    private let doneRect = NSRect(x: 236, y: 76, width: 88, height: 28)

    init(id: String, title: String, anim: Animator) {
        self.anim = anim
        gameID = id
        self.title = title
        super.init(frame: NSRect(x: 0, y: 44, width: gameW, height: gameH))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        window?.makeFirstResponder(self)
        restart()
    }

    func restart() {
        score = 0
        over = false
        reward = nil
        started = now()
        last = now()
        anim.asleep = false
        reset()
        window?.makeFirstResponder(self)
    }

    // Overridden by each game
    func reset() {}
    func update(_ dt: CGFloat, _ t: Double) {}
    func drawGame(_ t: Double) {}
    func click(_ p: NSPoint) {}
    func key(_ e: NSEvent) -> Bool { false }
    func keyReleased(_ e: NSEvent) {}

    func end() {
        guard !over else { return }
        over = true
        Synth.shared.gameOver()
        reward = onFinish?(gameID, score)
        if reward?.newBest == true && score > 0 {
            anim.celebrate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Synth.shared.levelUp() }
        }
    }

    func close() {
        timer?.invalidate()
        timer = nil
        let cb = onClose
        removeFromSuperview()
        cb?()
    }

    private func tick() {
        guard let w = window, w.isVisible, !w.isMiniaturized else { return }
        let t = now()
        let dt = CGFloat(min(0.05, t - last))
        last = t
        if !over { update(dt, t) }
        needsDisplay = true
    }

    // MARK: Drawing helpers

    func fill(_ c: NSColor, _ r: NSRect, radius: CGFloat = 0) {
        c.setFill()
        (radius > 0 ? NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) : NSBezierPath(rect: r)).fill()
    }

    func text(_ s: String, _ p: NSPoint, _ size: CGFloat, _ c: NSColor, _ w: NSFont.Weight = .bold, mono: Bool = false) {
        let f = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: w) : NSFont.systemFont(ofSize: size, weight: w)
        (s as NSString).draw(at: p, withAttributes: [.font: f, .foregroundColor: c])
    }

    func width(_ s: String, _ size: CGFloat, _ w: NSFont.Weight = .bold, mono: Bool = false) -> CGFloat {
        let f = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: w) : NSFont.systemFont(ofSize: size, weight: w)
        return (s as NSString).size(withAttributes: [.font: f]).width
    }

    func centered(_ s: String, y: CGFloat, _ size: CGFloat, _ c: NSColor, _ w: NSFont.Weight = .bold) {
        text(s, NSPoint(x: gameW / 2 - width(s, size, w) / 2, y: y), size, c, w)
    }

    func drawBuddy(_ pose: Pose, at c: NSPoint, scale: CGFloat, shadow: Bool = false) {
        Renderer.draw(skin: skin, hat: hat, accessory: accessory, pose: pose, at: c, scale: scale, shadow: shadow)
    }

    override func draw(_ dirtyRect: NSRect) {
        let t = now()
        fill(translucent ? rgb(0x0F1117, 0.55) : rgb(0x1E1B2E, 0.98), bounds)
        drawGame(t)
        fill(rgb(0x000000, 0.25), NSRect(x: 0, y: gameH - 36, width: gameW, height: 36))
        text(title, NSPoint(x: 14, y: gameH - 26), 13, .white, .heavy)
        centered(centerText, y: gameH - 26, 13, sparkYellow, .heavy)
        let r = rightText
        text(r, NSPoint(x: gameW - 14 - width(r, 13, .heavy), y: gameH - 26), 13, .white, .heavy)
        if !over { text("esc to quit", NSPoint(x: gameW - 70, y: 6), 9.5, NSColor(white: 1, alpha: 0.35), .medium) }
        if over { drawOverCard() }
    }

    private func drawOverCard() {
        let card = NSRect(x: 110, y: 62, width: 240, height: 150)
        fill(rgb(0x2B2D42, 0.98), card, radius: 14)
        centered(overTitle, y: card.maxY - 32, 16, .white, .heavy)
        centered("\(overLine)  ·  Best \(max(best, score))", y: card.maxY - 54, 11.5, NSColor(white: 0.85, alpha: 1), .semibold)
        if let r = reward {
            centered("+\(r.xp) XP   +\(r.coins) 🪙" + (r.newBest && score > 0 ? "   🎉 New best!" : ""), y: card.maxY - 76, 12, sparkYellow, .bold)
        }
        fill(claudeOrange, againRect, radius: 8)
        text("Play again", NSPoint(x: againRect.minX + 13, y: againRect.minY + 7), 11.5, .white)
        fill(NSColor(white: 1, alpha: 0.15), doneRect, radius: 8)
        text("Done", NSPoint(x: doneRect.minX + 28, y: doneRect.minY + 7), 11.5, .white)
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if over {
            if againRect.contains(p) { restart() } else if doneRect.contains(p) { close() }
            return
        }
        click(p)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { close(); return }
        if over {
            if event.keyCode == 49 || event.keyCode == 36 { restart() }
            return
        }
        if !key(event) { super.keyDown(with: event) }
    }

    override func keyUp(with event: NSEvent) { keyReleased(event) }
}

// MARK: - Bug Catch

final class BugCatchGame: MiniGame {
    private struct Bug { var x: CGFloat; var y: CGFloat; var vy: CGFloat; var kind: Int }   // 0 bug, 1 golden, 2 error
    private var bugs: [Bug] = []
    private var nextSpawn = 0.0
    private var x: CGFloat = 230
    private var keys = Set<UInt16>()
    private var popups: [(text: String, x: CGFloat, y: CGFloat, at: Double)] = []
    private let groundY: CGFloat = 51

    init(anim: Animator) { super.init(id: "bugcatch", title: "🐞 BUG CATCH", anim: anim) }
    required init?(coder: NSCoder) { fatalError() }

    override var translucent: Bool { true }
    override var rightText: String { over ? "0s" : String(format: "%.0fs", max(0, 30 - (now() - started))) }
    override var overTitle: String { "Time's up!" }

    override func reset() {
        bugs.removeAll(); popups.removeAll(); keys.removeAll()
        nextSpawn = now() + 0.6
        x = 230
    }

    override func update(_ dt: CGFloat, _ t: Double) {
        let elapsed = t - started
        if elapsed >= 30 { keys.removeAll(); end(); return }
        if keys.contains(123) { x -= 260 * dt } else if keys.contains(124) { x += 260 * dt } else if let w = window {
            let m = convert(w.mouseLocationOutsideOfEventStream, from: nil)
            if bounds.contains(m) { x += (m.x - x) * min(1, 12 * dt) }
        }
        x = max(24, min(gameW - 24, x))
        if t > nextSpawn {
            nextSpawn = t + max(0.28, 0.7 - elapsed * 0.014)
            let r = Double.random(in: 0...1)
            bugs.append(Bug(x: .random(in: 20...(gameW - 20)), y: gameH - 36, vy: CGFloat(90 + .random(in: 0...60) + elapsed * 3), kind: r < 0.08 ? 1 : r < 0.25 ? 2 : 0))
        }
        for i in bugs.indices { bugs[i].y -= bugs[i].vy * dt }
        bugs.removeAll { b in
            if abs(b.x - x) < 26 && b.y < 68 && b.y > 36 {
                let pts = [1, 5, -3][b.kind]
                score = max(0, score + pts)
                popups.append((pts > 0 ? "+\(pts)" : "\(pts)", b.x, b.y, t))
                if b.kind == 2 { Synth.shared.ouch(); anim.grumpy() } else { Synth.shared.catchBug(golden: b.kind == 1); if b.kind == 1 { anim.celebrate() } }
                return true
            }
            return b.y < 0
        }
        popups.removeAll { t - $0.at > 0.8 }
    }

    override func drawGame(_ t: Double) {
        for b in bugs { drawBug(b, t: t) }
        var pose = anim.pose(look: CGVector(dx: 0, dy: 1))
        pose.lift += keys.isEmpty ? 0 : CGFloat(abs(sin(t * 12))) * 3
        drawBuddy(pose, at: NSPoint(x: x, y: groundY), scale: 0.7, shadow: true)
        for pop in popups {
            let ph = CGFloat(t - pop.at) / 0.8
            text(pop.text, NSPoint(x: pop.x - 8, y: pop.y + ph * 24), 14, (pop.text.hasPrefix("-") ? rgb(0xFF6B6B) : sparkYellow).withAlphaComponent(1 - ph), .heavy)
        }
        if !over && t - started < 3 {
            centered("Catch bugs 🐞 (+1) and golden bugs (+5). Dodge errors (−3)!", y: 206, 11.5, .white, .medium)
            centered("Move with the mouse or ← →", y: 188, 11, NSColor(white: 0.8, alpha: 1), .regular)
        }
    }

    private func drawBug(_ b: Bug, t: Double) {
        if b.kind == 2 {
            fill(rgb(0xE5484D), NSRect(x: b.x - 10, y: b.y - 10, width: 20, height: 20), radius: 10)
            text("✕", NSPoint(x: b.x - 6, y: b.y - 8), 13, .white, .heavy)
            return
        }
        drawBugSprite(at: NSPoint(x: b.x, y: b.y), golden: b.kind == 1, t: t)
    }

    override func key(_ e: NSEvent) -> Bool {
        guard e.keyCode == 123 || e.keyCode == 124 else { return false }
        keys.insert(e.keyCode)
        return true
    }
    override func keyReleased(_ e: NSEvent) { keys.remove(e.keyCode) }
}

/// A little beetle (shared by Bug Catch and Whack-a-Bug).
func drawBugSprite(at p: NSPoint, golden: Bool, t: Double, scale s: CGFloat = 1) {
    let body = golden ? rgb(0xF2C94C) : rgb(0x3E9B4F)
    rgb(0x1E1E1E).setStroke()
    let legs = NSBezierPath(); legs.lineWidth = 1.2 * s
    let wig = CGFloat(sin(t * 20)) * 2 * s
    for k in -1...1 {
        let y = p.y + CGFloat(k) * 4 * s
        legs.move(to: NSPoint(x: p.x - 6 * s, y: y)); legs.line(to: NSPoint(x: p.x - 11 * s, y: y + wig))
        legs.move(to: NSPoint(x: p.x + 6 * s, y: y)); legs.line(to: NSPoint(x: p.x + 11 * s, y: y - wig))
    }
    legs.stroke()
    body.setFill()
    NSBezierPath(roundedRect: NSRect(x: p.x - 7 * s, y: p.y - 8 * s, width: 14 * s, height: 17 * s), xRadius: 7 * s, yRadius: 7 * s).fill()
    rgb(0x1E1E1E).setFill()
    NSBezierPath(roundedRect: NSRect(x: p.x - 4.5 * s, y: p.y - 11 * s, width: 9 * s, height: 6 * s), xRadius: 3 * s, yRadius: 3 * s).fill()
    let line = NSBezierPath(); line.lineWidth = s
    line.move(to: NSPoint(x: p.x, y: p.y - 6 * s)); line.line(to: NSPoint(x: p.x, y: p.y + 9 * s)); line.stroke()
    if golden { NSColor.white.setFill(); Renderer.sparkle(at: NSPoint(x: p.x + 9 * s, y: p.y + 9 * s), size: (3 + CGFloat(abs(sin(t * 8))) * 2) * s) }
}

// MARK: - Copycat

final class CopycatGame: MiniGame {
    private enum Phase { case showing, input }
    private var seq: [Int] = []
    private var phase = Phase.showing
    private var showIndex = 0
    private var inputIndex = 0
    private var nextStepAt = 0.0
    private var flashPad: Int?
    private var flashUntil = 0.0

    private let colors: [UInt32] = [0xE5395B, 0x3F7FE0, 0xF2C94C, 0x5DBB63]
    private let arrows = ["↑", "→", "↓", "←"]
    private let center = NSPoint(x: gameW / 2, y: 128)
    private func padCenter(_ i: Int) -> NSPoint {
        [NSPoint(x: center.x, y: center.y + 80), NSPoint(x: center.x + 104, y: center.y),
         NSPoint(x: center.x, y: center.y - 80), NSPoint(x: center.x - 104, y: center.y)][i]
    }

    init(anim: Animator) { super.init(id: "copycat", title: "🎵 COPYCAT", anim: anim) }
    required init?(coder: NSCoder) { fatalError() }

    override var centerText: String { "Round \(seq.count)" }
    override var rightText: String { "Best \(best + 1)" }
    override var overTitle: String { "Oops! 😵‍💫" }
    override var overLine: String { "You reached round \(score + 1)" }

    override func reset() {
        seq = [Int.random(in: 0..<4)]
        phase = .showing
        showIndex = 0
        nextStepAt = now() + 1
    }

    private func flash(_ i: Int) {
        flashPad = i
        flashUntil = now() + 0.32
        Synth.shared.pad(i)
    }

    override func update(_ dt: CGFloat, _ t: Double) {
        guard phase == .showing, t >= nextStepAt else { return }
        if showIndex < seq.count {
            flash(seq[showIndex])
            showIndex += 1
            nextStepAt = t + max(0.34, 0.62 - Double(seq.count) * 0.025)
        } else {
            phase = .input
            inputIndex = 0
        }
    }

    private func press(_ i: Int) {
        guard phase == .input, !over else { return }
        flash(i)
        if seq[inputIndex] == i {
            inputIndex += 1
            if inputIndex == seq.count {
                score = seq.count
                anim.celebrate()
                seq.append(Int.random(in: 0..<4))
                phase = .showing
                showIndex = 0
                nextStepAt = now() + 1.1
            }
        } else {
            Synth.shared.buzz()
            anim.dizzy()
            end()
        }
    }

    override func drawGame(_ t: Double) {
        let hint = over ? "" : phase == .showing ? "Watch buddy…" : "Your turn! Click the pads or use the arrow keys"
        text(hint, NSPoint(x: 14, y: 8), 11.5, NSColor(white: 0.75, alpha: 1), .medium)
        for i in 0..<4 {
            let c = padCenter(i)
            let lit = flashPad == i && t < flashUntil
            let r: CGFloat = lit ? 36 : 32
            rgb(colors[i], lit ? 1 : 0.38).setFill()
            NSGraphicsContext.saveGraphicsState()
            if lit { let glow = NSShadow(); glow.shadowColor = rgb(colors[i]); glow.shadowBlurRadius = 18; glow.set() }
            NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
            NSGraphicsContext.restoreGraphicsState()
            text(arrows[i], NSPoint(x: c.x - 7, y: c.y - 11), 18, NSColor(white: 1, alpha: lit ? 1 : 0.6), .heavy)
        }
        var look = CGVector.zero
        if let f = flashPad, t < flashUntil {
            let pc = padCenter(f)
            look = CGVector(dx: (pc.x - center.x) / 104, dy: (pc.y - center.y) / 80)
        }
        var pose = anim.pose(look: look)
        pose.lift = min(pose.lift, 12)
        drawBuddy(pose, at: center, scale: 1.0)
    }

    override func click(_ p: NSPoint) {
        for i in 0..<4 where hypot(p.x - padCenter(i).x, p.y - padCenter(i).y) < 36 { press(i); return }
    }

    override func key(_ e: NSEvent) -> Bool {
        switch e.keyCode {
        case 126: press(0)
        case 124: press(1)
        case 125: press(2)
        case 123: press(3)
        default: return false
        }
        return true
    }
}

// MARK: - Whack-a-Bug

final class WhackGame: MiniGame {
    private struct Mole { var hole: Int; var kind: Int; var upAt: Double; var downAt: Double; var hitAt: Double? }  // 0 bug, 1 golden, 2 feature
    private var moles: [Mole] = []
    private var nextSpawn = 0.0
    private var swingAt = -100.0
    private var popups: [(text: String, p: NSPoint, at: Double)] = []

    init(anim: Animator) { super.init(id: "whack", title: "🔨 WHACK-A-BUG", anim: anim) }
    required init?(coder: NSCoder) { fatalError() }

    override var rightText: String { over ? "0s" : String(format: "%.0fs", max(0, 30 - (now() - started))) }
    override var overTitle: String { "Time's up!" }

    private func screen(_ i: Int) -> NSRect {
        NSRect(x: 150 + CGFloat(i % 3) * 100, y: 178 - CGFloat(i / 3) * 76, width: 80, height: 58)
    }

    override func reset() {
        moles.removeAll(); popups.removeAll()
        nextSpawn = now() + 0.8
    }

    override func update(_ dt: CGFloat, _ t: Double) {
        let e = t - started
        if e >= 30 { end(); return }
        moles.removeAll { t > $0.downAt + 0.25 }
        if t > nextSpawn {
            nextSpawn = t + max(0.32, 0.75 - e * 0.015)
            let busy = Set(moles.map(\.hole))
            if let hole = (0..<9).filter({ !busy.contains($0) }).randomElement() {
                let r = Double.random(in: 0...1)
                let stay = max(0.6, 1.25 - e * 0.02)
                moles.append(Mole(hole: hole, kind: r < 0.1 ? 1 : r < 0.3 ? 2 : 0, upAt: t, downAt: t + stay, hitAt: nil))
            }
        }
        popups.removeAll { t - $0.at > 0.8 }
    }

    /// 0…1: how far out of its screen the critter is.
    private func height(_ m: Mole, _ t: Double) -> CGFloat {
        if let h = m.hitAt { return CGFloat(max(0, 1 - (t - h) / 0.2)) }
        let up = min(1, (t - m.upAt) / 0.15), down = min(1, max(0, (m.downAt - t) / 0.15))
        return CGFloat(min(up, down))
    }

    override func drawGame(_ t: Double) {
        for i in 0..<9 {
            let r = screen(i)
            fill(rgb(0x3A3F55), r.insetBy(dx: -4, dy: -4), radius: 8)
            fill(rgb(0x0F1117), r, radius: 5)
            fill(rgb(0x3A3F55), NSRect(x: r.midX - 8, y: r.minY - 12, width: 16, height: 8))
            text("~ $", NSPoint(x: r.minX + 5, y: r.maxY - 14), 8.5, rgb(0x7CF29A, 0.6), .regular, mono: true)
        }
        for m in moles {
            let r = screen(m.hole)
            let h = height(m, t)
            guard h > 0.01 else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).addClip()
            let c = NSPoint(x: r.midX, y: r.minY - 16 + h * 42)
            if m.kind == 2 {
                sparkYellow.setFill()
                Renderer.sparkle(at: c, size: 14)
                text("feature", NSPoint(x: c.x - 18, y: c.y - 22), 9, .white, .bold)
            } else {
                drawBugSprite(at: c, golden: m.kind == 1, t: t, scale: 1.4)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        for pop in popups {
            let ph = CGFloat(t - pop.at) / 0.8
            text(pop.text, NSPoint(x: pop.p.x - 10, y: pop.p.y + ph * 24), 16, (pop.text.hasPrefix("-") ? rgb(0xFF6B6B) : sparkYellow).withAlphaComponent(1 - ph), .heavy)
        }
        drawBuddy(anim.pose(look: CGVector(dx: 1, dy: 0.3)), at: NSPoint(x: 66, y: 100), scale: 0.9)
        if !over && t - started < 3 {
            text("Bonk bugs (+1),", NSPoint(x: 18, y: 40), 11, .white, .medium)
            text("golden (+3).", NSPoint(x: 18, y: 26), 11, .white, .medium)
            text("Spare features (−2)!", NSPoint(x: 18, y: 12), 11, rgb(0xFFB3B3), .medium)
        }
        // Mallet cursor
        if let w = window, !over {
            let m = convert(w.mouseLocationOutsideOfEventStream, from: nil)
            guard bounds.contains(m) else { return }
            let swing = CGFloat(max(0, 1 - (t - swingAt) / 0.15))
            NSGraphicsContext.saveGraphicsState()
            let xf = NSAffineTransform(); xf.translateX(by: m.x, yBy: m.y); xf.rotate(byRadians: 0.5 - swing * 0.9); xf.concat()
            fill(rgb(0x8A5A36), NSRect(x: -2, y: 0, width: 4, height: 26), radius: 2)
            fill(rgb(0xC0504D), NSRect(x: -11, y: 22, width: 22, height: 12), radius: 3)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func click(_ p: NSPoint) {
        let t = now()
        swingAt = t
        guard let i = moles.indices.first(where: { screen(moles[$0].hole).contains(p) && moles[$0].hitAt == nil && height(moles[$0], t) > 0.35 }) else { return }
        moles[i].hitAt = t
        moles[i].downAt = t
        let pts = [1, 3, -2][moles[i].kind]
        score = max(0, score + pts)
        popups.append((pts > 0 ? "+\(pts)" : "\(pts)", p, t))
        if moles[i].kind == 2 { Synth.shared.ouch(); anim.grumpy() } else { Synth.shared.whack(); if moles[i].kind == 1 { anim.celebrate() } else { anim.pet() } }
    }
}

// MARK: - Buddy Hop

final class HopGame: MiniGame {
    private struct Wall { var x: CGFloat; var gapY: CGFloat; var passed = false }
    private var y: CGFloat = 150
    private var vy: CGFloat = 0
    private var walls: [Wall] = []
    private var waiting = true
    private let bx: CGFloat = 110
    private let gap: CGFloat = 104
    private let wallW: CGFloat = 50
    private let floorY: CGFloat = 22
    private var ceilY: CGFloat { gameH - 40 }

    init(anim: Animator) { super.init(id: "hop", title: "🪽 BUDDY HOP", anim: anim) }
    required init?(coder: NSCoder) { fatalError() }

    override var rightText: String { "Best \(best)" }
    override var overTitle: String { "Merge conflict! 💥" }

    override func reset() {
        y = 150; vy = 0; walls.removeAll(); waiting = true
    }

    private func flap() {
        guard !over else { return }
        waiting = false
        vy = 330
        Synth.shared.flap()
    }

    override func update(_ dt: CGFloat, _ t: Double) {
        if waiting { y = 150 + CGFloat(sin(t * 3)) * 6; return }
        vy -= 1100 * dt
        y += vy * dt
        let speed = 150 + CGFloat(score) * 4
        for i in walls.indices { walls[i].x -= speed * dt }
        walls.removeAll { $0.x < -wallW }
        if walls.last.map({ $0.x < gameW - 200 }) ?? true {
            walls.append(Wall(x: gameW + 10, gapY: .random(in: (floorY + 70)...(ceilY - 70))))
        }
        for i in walls.indices where !walls[i].passed && walls[i].x + wallW < bx - 12 {
            walls[i].passed = true
            score += 1
            Synth.shared.coin()
        }
        let r: CGFloat = 13
        var hit = y - r < floorY || y + r > ceilY
        for w in walls where bx + r > w.x && bx - r < w.x + wallW {
            if y - r < w.gapY - gap / 2 || y + r > w.gapY + gap / 2 { hit = true }
        }
        if hit { anim.dizzy(); Synth.shared.thud(); end() }
    }

    override func drawGame(_ t: Double) {
        // Background: scrolling code lines
        for k in 0..<14 {
            let ly = floorY + 10 + CGFloat(k) * 17
            let off = CGFloat(fmod(t * 30 + Double(k * 53), 520))
            fill(NSColor(white: 1, alpha: 0.04), NSRect(x: gameW - off, y: ly, width: CGFloat(40 + (k * 31) % 90), height: 5), radius: 2.5)
        }
        fill(rgb(0x3A3F55), NSRect(x: 0, y: 0, width: gameW, height: floorY))
        for w in walls {
            let top = NSRect(x: w.x, y: w.gapY + gap / 2, width: wallW, height: ceilY - (w.gapY + gap / 2))
            let bottom = NSRect(x: w.x, y: floorY, width: wallW, height: w.gapY - gap / 2 - floorY)
            for (r, c, label) in [(top, rgb(0xC0504D), "<<<<<<<"), (bottom, rgb(0x4E9F55), ">>>>>>>")] {
                fill(c, r, radius: 4)
                for ly in stride(from: r.minY + 8, to: r.maxY - 6, by: 10) {
                    fill(NSColor(white: 1, alpha: 0.18), NSRect(x: r.minX + 6, y: ly, width: CGFloat(14 + Int(ly) % 22), height: 3), radius: 1.5)
                }
                let ly = label.hasPrefix("<") ? r.minY + 3 : r.maxY - 13
                text(label, NSPoint(x: r.minX + 3, y: ly), 9, .white, .heavy, mono: true)
            }
        }
        var pose = anim.pose(look: CGVector(dx: 1, dy: max(-1, min(1, vy / 300))))
        pose.lift = 0
        pose.rot += waiting ? 0 : max(-0.6, min(0.5, vy / 600))
        if !waiting && vy > 150 { pose.expression = .whee }
        drawBuddy(pose, at: NSPoint(x: bx, y: y), scale: 0.55)
        if waiting { centered("Click or press Space to flap", y: 90, 13, .white, .bold) }
    }

    override func click(_ p: NSPoint) { flap() }

    override func key(_ e: NSEvent) -> Bool {
        guard e.keyCode == 49 || e.keyCode == 126 else { return false }
        if !e.isARepeat { flap() }
        return true
    }
}

// MARK: - Type Rush

final class TypeRushGame: MiniGame {
    private struct Word { var text: String; var x: CGFloat; var y: CGFloat }
    private let pool = ["let", "var", "func", "async", "await", "return", "struct", "enum", "import", "class", "guard", "defer",
                        "git push", "git pull", "commit", "rebase", "merge", "deploy", "npm i", "mkdir", "grep", "sudo", "claude",
                        "cookie", "debug", "refactor", "ship it", "null", "true", "false", "while", "json", "yaml", "docker",
                        "lint", "test", "build", "hotfix", "main", "branch", "lambda", "regex", "cache", "query", "token", "buddy"]
    private var words: [Word] = []
    private var typed = ""
    private var lives = 3
    private var nextSpawn = 0.0
    private var hurtAt = -100.0
    private var bursts: [(text: String, p: NSPoint, at: Double)] = []
    private let dangerY: CGFloat = 56

    init(anim: Animator) { super.init(id: "type", title: "⌨️ TYPE RUSH", anim: anim) }
    required init?(coder: NSCoder) { fatalError() }

    override var rightText: String { String(repeating: "❤️", count: max(0, lives)) + String(repeating: "🖤", count: max(0, 3 - lives)) }
    override var overTitle: String { "Segfault! 💀" }
    override var overLine: String { "\(score) words" }

    override func reset() {
        words.removeAll(); bursts.removeAll()
        typed = ""; lives = 3
        nextSpawn = now() + 0.5
    }

    private let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    override func update(_ dt: CGFloat, _ t: Double) {
        if t > nextSpawn {
            nextSpawn = t + max(0.85, 2.2 - Double(score) * 0.06)
            let w = pool.randomElement()!
            let tw = (w as NSString).size(withAttributes: [.font: font]).width
            words.append(Word(text: w, x: .random(in: 14...(gameW - tw - 14)), y: gameH - 50))
        }
        let speed = 20 + CGFloat(score) * 1.1
        for i in words.indices { words[i].y -= speed * dt }
        let landed = words.filter { $0.y < dangerY }
        if !landed.isEmpty {
            words.removeAll { $0.y < dangerY }
            lives -= landed.count
            hurtAt = t
            Synth.shared.ouch()
            anim.grumpy()
            if !words.contains(where: { $0.text.hasPrefix(typed) }) { typed = "" }
            if lives <= 0 { lives = 0; end() }
        }
        bursts.removeAll { t - $0.at > 0.7 }
    }

    override func drawGame(_ t: Double) {
        if t - hurtAt < 0.4 { fill(rgb(0xE5484D, 0.25 * CGFloat(1 - (t - hurtAt) / 0.4)), bounds) }
        fill(rgb(0xE5484D, 0.5), NSRect(x: 0, y: dangerY - 2, width: gameW, height: 2))
        for w in words {
            let match = !typed.isEmpty && w.text.hasPrefix(typed)
            let done = match ? typed : ""
            let rest = String(w.text.dropFirst(done.count))
            let dw = (done as NSString).size(withAttributes: [.font: font]).width
            let full = (w.text as NSString).size(withAttributes: [.font: font]).width
            fill(match ? rgb(0x3F7FE0, 0.35) : NSColor(white: 1, alpha: 0.08), NSRect(x: w.x - 5, y: w.y - 3, width: full + 10, height: 22), radius: 6)
            (done as NSString).draw(at: NSPoint(x: w.x, y: w.y), withAttributes: [.font: font, .foregroundColor: sparkYellow])
            (rest as NSString).draw(at: NSPoint(x: w.x + dw, y: w.y), withAttributes: [.font: font, .foregroundColor: NSColor.white])
        }
        for b in bursts {
            let ph = CGFloat(t - b.at) / 0.7
            text(b.text, NSPoint(x: b.p.x, y: b.p.y + ph * 20), 13, rgb(0x7CF29A, 1 - ph), .heavy, mono: true)
        }
        // Prompt line with buddy typing
        let box = NSRect(x: 110, y: 12, width: 240, height: 28)
        fill(rgb(0x0F1117), box, radius: 8)
        let caret = fmod(t, 1) < 0.5 ? "▌" : " "
        text("> " + typed + caret, NSPoint(x: box.minX + 10, y: box.minY + 6), 14, rgb(0x7CF29A), .bold, mono: true)
        var pose = anim.pose(look: CGVector(dx: 0.6, dy: -0.4))
        pose.lift = min(pose.lift, 6)
        drawBuddy(pose, at: NSPoint(x: 64, y: 28), scale: 0.6)
        if !over && t - started < 3 { centered("Type the words before they hit the red line!", y: 150, 12.5, .white, .semibold) }
    }

    override func key(_ e: NSEvent) -> Bool {
        if e.keyCode == 51 { if !typed.isEmpty { typed.removeLast() }; return true }
        if e.keyCode == 36 { typed = ""; return true }
        guard let ch = e.characters?.lowercased(), ch.count == 1, let c = ch.first,
              c.isLetter || c.isNumber || c == " " || c == "-" || c == "." else { return false }
        let next = typed + String(c)
        if words.contains(where: { $0.text.hasPrefix(next) }) {
            typed = next
            Synth.shared.type()
            if let i = words.firstIndex(where: { $0.text == typed }) {
                let w = words.remove(at: i)
                score += 1
                bursts.append(("✓ " + w.text, NSPoint(x: w.x, y: w.y), now()))
                Synth.shared.catchBug(golden: w.text.count >= 7)
                if score % 5 == 0 { anim.celebrate() }
                typed = ""
            }
        } else {
            Synth.shared.grumble()
            typed = ""
        }
        return true
    }
}
