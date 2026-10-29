// Buddy's room: a little world where buddy walks around, works at its desk while Claude
// Code runs, sleeps in bed, and where you change outfits, type console commands and play
// Bug Catch.

import AppKit

private let W: CGFloat = 460
private let H: CGFloat = 340
private let hudH: CGFloat = 44
private let floorTop: CGFloat = 124
private let groundY: CGFloat = 95
private let roomScale: CGFloat = 0.7

private struct Theme {
    let wall: NSColor, wallLine: NSColor, floor: NSColor, floorLine: NSColor, base: NSColor
}

private func theme(_ id: String) -> Theme {
    switch id {
    case "greenhouse": return Theme(wall: rgb(0xCFE8D2), wallLine: rgb(0xA9D3B0), floor: rgb(0xD9D2C3), floorLine: rgb(0xC2B9A6), base: rgb(0x6E9C74))
    case "space": return Theme(wall: rgb(0x3B4256), wallLine: rgb(0x4C556E), floor: rgb(0x2A2F3D), floorLine: rgb(0x3D455A), base: rgb(0x596178))
    case "beach": return Theme(wall: rgb(0xF6E7CB), wallLine: rgb(0xE8D3AE), floor: rgb(0xF0D9A6), floorLine: rgb(0xE0C48A), base: rgb(0xC9A877))
    default: return Theme(wall: rgb(0xF3E3C8), wallLine: rgb(0xEAD6B4), floor: rgb(0xB98556), floorLine: rgb(0xA27045), base: rgb(0x8A5A36))
    }
}

final class RoomView: NSView, NSTextFieldDelegate {
    enum Overlay { case none, wardrobe, console, game }
    private enum Place { case floor, desk, bed }

    let anim: Animator
    var onPoke: (() -> Void)?
    var onFeed: (() -> Bool)?
    var onCommand: ((String) -> [String])?
    var onGameOver: ((Int) -> Void)?
    var onMedicine: (() -> Void)?

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
    private var wardrobeTab = 0
    private var consoleLines = ["Buddy OS 1.0 — type 'help'"]
    private let input = NSTextField()

    private struct Bug { var x: CGFloat; var y: CGFloat; var vy: CGFloat; var kind: Int }   // 0 bug, 1 golden, 2 error
    private var bugs: [Bug] = []
    private var gameStart = 0.0
    private var gameScore = 0
    private var gameEnded = false
    private var nextSpawn = 0.0
    private var gameX: CGFloat = 230
    private var keys = Set<UInt16>()
    private var popups: [(text: String, x: CGFloat, y: CGFloat, at: Double)] = []

    private var p: BuddyProgress { BuddyProgress.shared }
    private var deskX: CGFloat { 365 }
    private var bedX: CGFloat { 72 }

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

    func open(_ o: Overlay) {
        closeCopycat()
        overlay = overlay == o ? .none : o
        input.isHidden = overlay != .console
        if overlay == .console { window?.makeFirstResponder(input) } else { window?.makeFirstResponder(self) }
        if overlay == .game { startGame() }
    }

    // MARK: Buddy behaviour

    private func updateBuddy(dt: CGFloat) {
        let t = now()
        if anim.asleep || anim.sick { targetX = bedX }
        else if anim.mood != .idle { targetX = deskX }
        else if place != .floor { targetX = 240; place = .floor }
        else if t > nextWander {
            nextWander = t + Double.random(in: 5...10)
            var spots: [(CGFloat, String?)] = [(CGFloat.random(in: 150...320), nil), (235, nil), (CGFloat.random(in: 150...320), nil)]
            if p.has("plant") { spots.append((178, "*waters plant* 🌱")) }
            if p.has("fishtank") { spots.append((211, "blub blub 🐟")) }
            if p.has("arcade") { spots.append((300, "one more game?")) }
            let pick = spots.randomElement()!
            targetX = pick.0
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

    private func buddyCenter(_ pose: Pose) -> NSPoint {
        switch place {
        case .desk: return NSPoint(x: bx, y: 140)
        case .bed: return NSPoint(x: 44, y: 100)
        case .floor: return NSPoint(x: bx, y: groundY)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let t = now()
        let dt = CGFloat(min(0.05, t - lastFrame))
        lastFrame = t
        let th = theme(p.data.room)

        if overlay == .game { updateGame(dt: dt) } else { updateBuddy(dt: dt) }

        drawWall(th)
        drawWindow(NSRect(x: 180, y: 180, width: 110, height: 110))
        drawWallDecor()
        drawFloor(th)
        drawBed()
        drawFurniture()

        if overlay != .game {
            var pose = anim.pose(look: lookVector())
            if walking && !anim.asleep {
                pose.lift += CGFloat(abs(sin(t * 12))) * 4
                pose.look = CGVector(dx: targetX > bx ? 1 : -1, dy: 0)
            }
            if place == .bed { pose.lying = true }
            let c = buddyCenter(pose)
            if place == .desk { Renderer.draw(skin: p.data.skin, hat: p.data.hat, pose: pose, at: c, scale: roomScale, shadow: false) }
            drawDesk()
            if place != .desk { Renderer.draw(skin: p.data.skin, hat: p.data.hat, pose: pose, at: c, scale: roomScale, shadow: place == .floor) }
            if place == .bed { drawBlanket() }
            if place == .desk && anim.mood == .working { typingParticles(at: c) }
            drawCat()
            drawCookie(target: c)
            if t < speechUntil { drawSpeech(above: NSPoint(x: c.x, y: c.y + 30 + pose.lift * roomScale)) }
        } else {
            drawDesk()
            drawCat()
        }

        if !lampOn || isNight || p.data.room == "space" {
            NSColor(srgbRed: 0.05, green: 0.06, blue: 0.2, alpha: lampOn ? 0.18 : 0.38).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: hudH, width: W, height: H - hudH)).fill()
        }

        switch overlay {
        case .wardrobe: drawWardrobe()
        case .console: drawConsole()
        case .game: drawGame()
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

    private func drawWall(_ th: Theme) {
        fill(th.wall, NSRect(x: 0, y: floorTop, width: W, height: H - floorTop))
        th.wallLine.setFill()
        switch p.data.room {
        case "greenhouse":
            for x in stride(from: CGFloat(0), to: W, by: 46) { NSBezierPath(rect: NSRect(x: x, y: floorTop, width: 3, height: H)).fill() }
            NSBezierPath(rect: NSRect(x: 0, y: 300, width: W, height: 3)).fill()
        case "space":
            for x in stride(from: CGFloat(0), to: W, by: 92) { NSBezierPath(rect: NSRect(x: x, y: floorTop, width: 2, height: H)).fill() }
            rgb(0x6A7390).setFill()
            for x in stride(from: CGFloat(8), to: W, by: 92) {
                for y in [floorTop + 10, H - 12] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 3)).fill() }
            }
        case "beach":
            for y in stride(from: floorTop + 18, to: H, by: 22) { NSBezierPath(rect: NSRect(x: 0, y: y, width: W, height: 2)).fill() }
        default:
            for x in stride(from: CGFloat(10), to: W, by: 28) { NSBezierPath(rect: NSRect(x: x, y: floorTop, width: 9, height: H)).fill() }
        }
    }

    private func drawFloor(_ th: Theme) {
        fill(th.floor, NSRect(x: 0, y: hudH, width: W, height: floorTop - hudH))
        th.floorLine.setFill()
        switch p.data.room {
        case "beach":
            for i in 0..<40 {
                let x = CGFloat((i * 97) % 460), y = hudH + CGFloat((i * 53) % 78)
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 2)).fill()
            }
            rgb(0xF4A6B8).setFill()
            NSBezierPath(ovalIn: NSRect(x: 160, y: 52, width: 9, height: 6)).fill()
        case "space", "greenhouse":
            for x in stride(from: CGFloat(0), to: W, by: 40) { NSBezierPath(rect: NSRect(x: x, y: hudH, width: 1.5, height: floorTop - hudH)).fill() }
            for y in stride(from: hudH, to: floorTop, by: 26) { NSBezierPath(rect: NSRect(x: 0, y: y, width: W, height: 1.5)).fill() }
        default:
            for y in stride(from: hudH + 16, to: floorTop, by: 16) { NSBezierPath(rect: NSRect(x: 0, y: y, width: W, height: 1.5)).fill() }
        }
        fill(th.base, NSRect(x: 0, y: floorTop - 4, width: W, height: 6))
        if p.has("rug") { fill(rgb(0xC0504D, 0.85), NSRect(x: 150, y: 54, width: 170, height: 30), radius: 15)
            rgb(0xF2C94C, 0.8).setStroke()
            let b = NSBezierPath(roundedRect: NSRect(x: 156, y: 58, width: 158, height: 22), xRadius: 11, yRadius: 11)
            b.lineWidth = 2; b.stroke()
        }
    }

    private func drawWindow(_ r: NSRect) {
        let t = now()
        let hour = Calendar.current.component(.hour, from: Date())
        if p.data.room == "space" {
            let c = NSRect(x: r.midX - 52, y: r.midY - 52, width: 104, height: 104)
            fill(rgb(0x0B0D1F), c, radius: 52)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: c).addClip()
            for i in 0..<30 {
                let x = c.minX + CGFloat((i * 37) % 104), y = c.minY + CGFloat((i * 61) % 104)
                NSColor(white: 1, alpha: 0.4 + 0.5 * CGFloat(abs(sin(t + Double(i))))).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill()
            }
            fill(rgb(0x3F7FE0), NSRect(x: c.minX + 30 + CGFloat(sin(t * 0.1)) * 6, y: c.minY - 30, width: 90, height: 90), radius: 45)
            fill(rgb(0x5DBB63), NSRect(x: c.minX + 50, y: c.minY + 20, width: 30, height: 18), radius: 9)
            NSGraphicsContext.restoreGraphicsState()
            rgb(0x8A93AE).setStroke()
            let ring = NSBezierPath(ovalIn: c); ring.lineWidth = 7; ring.stroke()
            return
        }
        let night = hour >= 20 || hour < 6
        let dusk = hour >= 17 && hour < 20
        let top = night ? rgb(0x0E1640) : dusk ? rgb(0xF08A5D) : rgb(0x7EC8F2)
        let bottom = night ? rgb(0x26306B) : dusk ? rgb(0xF7C873) : rgb(0xCDEBFA)
        NSGradient(starting: bottom, ending: top)?.draw(in: r, angle: 90)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: r).addClip()
        if night {
            for i in 0..<14 {
                NSColor(white: 1, alpha: 0.5 + 0.5 * CGFloat(abs(sin(t * 1.3 + Double(i))))).setFill()
                NSBezierPath(ovalIn: NSRect(x: r.minX + CGFloat((i * 41) % 104), y: r.minY + 30 + CGFloat((i * 29) % 76), width: 2, height: 2)).fill()
            }
            fill(rgb(0xF7F3D7), NSRect(x: r.maxX - 34, y: r.maxY - 32, width: 18, height: 18), radius: 9)
        } else {
            fill(rgb(0xFFE07A), NSRect(x: r.maxX - 36, y: r.maxY - 34, width: 20, height: 20), radius: 10)
            let cx = r.minX + CGFloat(fmod(t * 6, 160)) - 30
            NSColor(white: 1, alpha: 0.9).setFill()
            for (dx, dy, s) in [(0.0, 0.0, 16.0), (10.0, 4.0, 18.0), (22.0, 0.0, 14.0)] as [(CGFloat, CGFloat, CGFloat)] {
                NSBezierPath(ovalIn: NSRect(x: cx + dx, y: r.maxY - 50 + dy, width: s, height: s * 0.8)).fill()
            }
        }
        if p.data.room == "beach" {
            fill(night ? rgb(0x1B3A6B) : rgb(0x2E9CCA), NSRect(x: r.minX, y: r.minY, width: r.width, height: 34))
            NSColor(white: 1, alpha: 0.5).setFill()
            for i in 0..<4 {
                let x = r.minX + CGFloat(fmod(t * 10 + Double(i) * 30, 120)) - 10
                NSBezierPath(rect: NSRect(x: x, y: r.minY + 8 + CGFloat(i % 2) * 12, width: 14, height: 1.5)).fill()
            }
        } else {
            fill(night ? rgb(0x1E3B2C) : rgb(0x6DBE6A), NSRect(x: r.minX - 10, y: r.minY - 30, width: 80, height: 54), radius: 27)
            fill(night ? rgb(0x234A33) : rgb(0x84CF7A), NSRect(x: r.minX + 50, y: r.minY - 34, width: 90, height: 52), radius: 26)
        }
        NSGraphicsContext.restoreGraphicsState()
        let frameColor = p.data.room == "greenhouse" ? rgb(0x6E9C74) : rgb(0xFFFFFF)
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
        if p.has("poster") {
            fill(rgb(0x2B2D42), NSRect(x: 34, y: 186, width: 66, height: 88), radius: 3)
            Renderer.draw(skin: "classic", hat: "none", pose: Pose(), at: NSPoint(x: 67, y: 240), scale: 0.5, shadow: false)
            text("SHIP IT", NSPoint(x: 43, y: 192), size: 12, color: sparkYellow, weight: .heavy)
        }
        if p.has("neon") {
            let glow = 0.75 + 0.25 * CGFloat(sin(t * 3))
            let shadow = NSShadow(); shadow.shadowColor = rgb(0xFF4FA3, glow); shadow.shadowBlurRadius = 10
            NSGraphicsContext.saveGraphicsState(); shadow.set()
            text("</>", NSPoint(x: 112, y: 270), size: 26, color: rgb(0xFF7FC1, glow), weight: .bold, mono: true)
            NSGraphicsContext.restoreGraphicsState()
        }
        if p.has("shelf") {
            fill(rgb(0x8A5A36), NSRect(x: 330, y: 222, width: 118, height: 6), radius: 2)
            let books: [(CGFloat, UInt32, CGFloat)] = [(334, 0xC0504D, 26), (344, 0x3F7FE0, 30), (355, 0x5DBB63, 24), (364, 0xF2C94C, 28), (375, 0x9466DB, 22)]
            for (x, c, h) in books { fill(rgb(c), NSRect(x: x, y: 228, width: 9, height: h), radius: 1) }
            if p.has("records") {
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
                xf.rotate(byRadians: CGFloat(a) - .pi / 2 + .pi / 2); leaf.transform(using: xf as AffineTransform); leaf.fill()
            }
        }
    }

    private func drawBed() {
        fill(rgb(0x7A4E2D), NSRect(x: 14, y: 60, width: 8, height: 60), radius: 2)
        fill(rgb(0x7A4E2D), NSRect(x: 14, y: 60, width: 126, height: 10), radius: 2)
        fill(rgb(0x7A4E2D), NSRect(x: 134, y: 60, width: 6, height: 34), radius: 2)
        fill(rgb(0xFFFFFF), NSRect(x: 20, y: 70, width: 116, height: 22), radius: 6)
        fill(rgb(0xF5F0E6), NSRect(x: 22, y: 90, width: 36, height: 14), radius: 7)
        if place != .bed || overlay == .game { drawBlanket() }
    }

    private func drawBlanket() {
        fill(rgb(0x5B7FD6), NSRect(x: 62, y: 70, width: 76, height: 28), radius: 8)
        rgb(0x7E9DE6).setFill()
        for x in stride(from: CGFloat(70), to: 134, by: 16) { NSBezierPath(rect: NSRect(x: x, y: 72, width: 6, height: 24)).fill() }
    }

    private func drawFurniture() {
        let t = now()
        if p.has("plant") {
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
        if p.has("fishtank") {
            fill(rgb(0x6B4A33), NSRect(x: 188, y: 56, width: 48, height: 40), radius: 3)
            fill(rgb(0x7FD3F0, 0.75), NSRect(x: 186, y: 96, width: 52, height: 34), radius: 3)
            fill(rgb(0xE8D3AE), NSRect(x: 186, y: 96, width: 52, height: 6), radius: 2)
            for k in 0..<2 {
                let fx = 196 + CGFloat(fmod(t * (12 + Double(k) * 7), 34))
                fill(k == 0 ? rgb(0xF29A38) : rgb(0xE5395B), NSRect(x: fx, y: 108 + CGFloat(k) * 9, width: 9, height: 5), radius: 2.5)
            }
            NSColor(white: 1, alpha: 0.6).setFill()
            let by = 100 + CGFloat(fmod(t * 14, 30))
            NSBezierPath(ovalIn: NSRect(x: 228, y: by, width: 3, height: 3)).fill()
        }
        if p.has("arcade") {
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
        // Laptop, seen from behind, with a glowing sticker
        fill(rgb(0xBFC4CC), NSRect(x: 392, y: 114, width: 40, height: 28), radius: 3)
        let glow = anim.mood == .working ? 0.7 + 0.3 * CGFloat(abs(sin(t * 3))) : 0.85
        Renderer.rayColor(p.data.skin, 0, t).withAlphaComponent(glow).setFill()
        Renderer.sparkle(at: NSPoint(x: 412, y: 128), size: 6)
        if p.has("lamp") {
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
        guard p.has("cat") else { return }
        let t = now()
        let x: CGFloat = 112, y: CGFloat = 98
        rgb(0x3A3A3A).setStroke()
        let tail = NSBezierPath(); tail.lineWidth = 3; tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: x + 10, y: y + 2))
        tail.curve(to: NSPoint(x: x + 20, y: y + 14 + CGFloat(sin(t * 2)) * 4), controlPoint1: NSPoint(x: x + 20, y: y), controlPoint2: NSPoint(x: x + 22, y: y + 8))
        tail.stroke()
        fill(rgb(0x3A3A3A), NSRect(x: x - 10, y: y, width: 22, height: 16), radius: 8)
        fill(rgb(0x3A3A3A), NSRect(x: x - 14, y: y + 10, width: 16, height: 14), radius: 7)
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
        (toast as NSString).draw(at: NSPoint(x: r.minX + 14, y: r.minY + 6), withAttributes: attrs)
    }

    // MARK: HUD

    private let hudButtons = ["🍪 Feed", "🎮 Play", "🎩 Style", "⌨︎ Cmd"]
    private func hudButton(_ i: Int) -> NSRect { NSRect(x: 246 + CGFloat(i) * 53, y: 7, width: 50, height: 30) }

    private func drawHUD() {
        fill(rgb(0x1E1B2E), NSRect(x: 0, y: 0, width: W, height: hudH))
        fill(claudeOrange, NSRect(x: 10, y: 11, width: 44, height: 22), radius: 11)
        let lv = "Lv \(p.level)"
        text(lv, NSPoint(x: 32 - textWidth(lv, size: 12, weight: .heavy) / 2, y: 14), size: 12, color: .white, weight: .heavy)
        let next = BuddyProgress.xpNeeded(p.level + 1)
        text("\(p.data.xp) / \(next) XP", NSPoint(x: 64, y: 23), size: 10, color: NSColor(white: 0.75, alpha: 1), weight: .medium)
        fill(NSColor(white: 1, alpha: 0.15), NSRect(x: 64, y: 11, width: 166, height: 8), radius: 4)
        fill(sparkYellow, NSRect(x: 64, y: 11, width: max(8, 166 * CGFloat(p.levelFraction)), height: 8), radius: 4)
        let active: Int? = [.wardrobe: 2, .console: 3, .game: 1][overlay]
        for (i, label) in hudButtons.enumerated() {
            let label = i == 0 && anim.sick ? "💊 Meds" : label
            let r = hudButton(i)
            fill(active == i ? claudeOrange : NSColor(white: 1, alpha: 0.1), r, radius: 8)
            let w = textWidth(label, size: 10.5, weight: .semibold)
            text(label, NSPoint(x: r.midX - w / 2, y: r.minY + 8), size: 10.5, color: .white, weight: .semibold)
        }
    }

    // MARK: Wardrobe

    private let tabs = ["Skins", "Hats", "Rooms", "Trophies"]
    private let panel = NSRect(x: 10, y: 52, width: 440, height: 280)
    private func tabRect(_ i: Int) -> NSRect { NSRect(x: panel.minX + 10 + CGFloat(i) * 84, y: panel.maxY - 32, width: 80, height: 24) }
    private func cellRect(_ i: Int) -> NSRect {
        NSRect(x: panel.minX + 10 + CGFloat(i % 5) * 85, y: panel.maxY - 130 - CGFloat(i / 5) * 98, width: 80, height: 92)
    }
    private var tabItems: [Item] { catalog.filter { $0.kind == [ItemKind.skin, .hat, .room][min(wardrobeTab, 2)] } }

    private func drawWardrobe() {
        fill(rgb(0x1E1B2E, 0.94), panel, radius: 14)
        for (i, name) in tabs.enumerated() {
            let r = tabRect(i)
            fill(i == wardrobeTab ? claudeOrange : NSColor(white: 1, alpha: 0.1), r, radius: 12)
            text(name, NSPoint(x: r.midX - textWidth(name, size: 11.5, weight: .semibold) / 2, y: r.minY + 5), size: 11.5, color: .white, weight: .semibold)
        }
        text("✕", NSPoint(x: panel.maxX - 24, y: panel.maxY - 28), size: 14, color: NSColor(white: 0.8, alpha: 1), weight: .bold)

        if wardrobeTab == 3 { drawTrophies(); return }
        let mouse = window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? .zero
        var hoverHint: String?
        for (i, it) in tabItems.enumerated() {
            let r = cellRect(i)
            let unlocked = p.isUnlocked(it)
            let equipped = [p.data.skin, p.data.hat, p.data.room].contains(it.id)
            fill(NSColor(white: 1, alpha: r.contains(mouse) ? 0.14 : 0.07), r, radius: 10)
            if equipped {
                claudeOrange.setStroke()
                let b = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10); b.lineWidth = 2; b.stroke()
            }
            let c = NSPoint(x: r.midX, y: r.minY + 54)
            if unlocked || it.level != nil {
                NSGraphicsContext.saveGraphicsState()
                if !unlocked { NSGraphicsContext.current?.cgContext.setAlpha(0.25) }
                switch it.kind {
                case .skin: Renderer.draw(skin: it.id, hat: "none", pose: Pose(), at: c, scale: 0.55, shadow: false)
                case .hat: Renderer.draw(skin: p.data.skin, hat: it.id, pose: Pose(), at: NSPoint(x: c.x, y: c.y - 6), scale: 0.55, shadow: false)
                case .room:
                    let th = theme(it.id)
                    fill(th.wall, NSRect(x: c.x - 26, y: c.y - 6, width: 52, height: 30), radius: 4)
                    fill(th.floor, NSRect(x: c.x - 26, y: c.y - 20, width: 52, height: 14), radius: 4)
                case .decor: break
                }
                NSGraphicsContext.restoreGraphicsState()
            } else {
                text("?", NSPoint(x: c.x - 7, y: c.y - 14), size: 26, color: NSColor(white: 1, alpha: 0.35), weight: .heavy)
            }
            let name = unlocked || it.level != nil ? it.name : "Secret"
            text(name, NSPoint(x: r.midX - textWidth(name, size: 10.5, weight: .medium) / 2, y: r.minY + 18), size: 10.5, color: .white, weight: .medium)
            let tag = unlocked ? (equipped ? "Wearing" : "") : it.level.map { "🔒 Lv \($0)" } ?? "🔒 secret"
            if !tag.isEmpty {
                text(tag, NSPoint(x: r.midX - textWidth(tag, size: 9.5) / 2, y: r.minY + 5), size: 9.5, color: NSColor(white: 0.7, alpha: 1))
            }
            if r.contains(mouse) && !unlocked { hoverHint = it.level.map { "Reach level \($0) to unlock \(it.name)." } ?? "Hint: \(it.hint)" }
        }
        let footer = hoverHint ?? "Click something you've unlocked to wear it."
        text(footer, NSPoint(x: panel.minX + 14, y: panel.minY + 10), size: 11, color: sparkYellow, weight: .medium)
    }

    private func drawTrophies() {
        for (i, a) in achievements.enumerated() {
            let got = p.hasAchievement(a.id)
            let x = panel.minX + 16 + CGFloat(i % 2) * 214
            let y = panel.maxY - 66 - CGFloat(i / 2) * 42
            fill(NSColor(white: 1, alpha: got ? 0.12 : 0.05), NSRect(x: x - 6, y: y - 6, width: 206, height: 36), radius: 8)
            text(got ? "🏆" : "🔒", NSPoint(x: x, y: y + 4), size: 15, color: .white)
            text(got ? a.name : "???", NSPoint(x: x + 26, y: y + 12), size: 11.5, color: .white, weight: .bold)
            text(a.hint, NSPoint(x: x + 26, y: y - 1), size: 9.5, color: NSColor(white: 0.65, alpha: 1))
        }
        let s = p.data
        text("Sessions: \(s.sessions)   Cookies: \(s.cookies)   Pets: \(s.pets)   Best Bug Catch: \(s.bestScore)",
             NSPoint(x: panel.minX + 14, y: panel.minY + 10), size: 11, color: sparkYellow, weight: .medium)
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
        if cmd == "clear" { consoleLines.removeAll(); return }
        if cmd == "exit" { open(.console); return }
        consoleLines.append(contentsOf: onCommand?(cmd) ?? [])
    }

    // MARK: Bug Catch

    private func startGame() {
        anim.asleep = false
        bugs.removeAll(); popups.removeAll()
        gameStart = now(); gameScore = 0; gameEnded = false; nextSpawn = now() + 0.6; gameX = 230
        window?.makeFirstResponder(self)
    }

    private func updateGame(dt: CGFloat) {
        let t = now()
        guard !gameEnded else { return }
        let elapsed = t - gameStart
        if elapsed >= 30 {
            gameEnded = true
            Synth.shared.gameOver()
            onGameOver?(gameScore)
            return
        }
        // Keys move buddy; otherwise it follows the mouse.
        if keys.contains(123) { gameX -= 260 * dt } else if keys.contains(124) { gameX += 260 * dt } else if let w = window {
            let m = convert(w.mouseLocationOutsideOfEventStream, from: nil)
            if bounds.contains(m) { gameX += (m.x - gameX) * min(1, 12 * dt) }
        }
        gameX = max(24, min(W - 24, gameX))

        if t > nextSpawn {
            nextSpawn = t + max(0.28, 0.7 - elapsed * 0.014)
            let r = Double.random(in: 0...1)
            bugs.append(Bug(x: CGFloat.random(in: 20...(W - 20)), y: H, vy: CGFloat(90 + Double.random(in: 0...60) + elapsed * 3), kind: r < 0.08 ? 1 : r < 0.25 ? 2 : 0))
        }
        for i in bugs.indices { bugs[i].y -= bugs[i].vy * dt }
        bugs.removeAll { b in
            if abs(b.x - gameX) < 26 && b.y < 112 && b.y > 80 {
                let pts = [1, 5, -3][b.kind]
                gameScore = max(0, gameScore + pts)
                popups.append((pts > 0 ? "+\(pts)" : "\(pts)", b.x, b.y, t))
                if b.kind == 2 { Synth.shared.ouch(); anim.grumpy() } else { Synth.shared.catchBug(golden: b.kind == 1); if b.kind == 1 { anim.celebrate() } }
                return true
            }
            return b.y < hudH
        }
        popups.removeAll { t - $0.at > 0.8 }
    }

    private func drawGame() {
        let t = now()
        fill(rgb(0x0F1117, 0.55), NSRect(x: 0, y: hudH, width: W, height: H - hudH))
        for b in bugs { drawBug(b, t: t) }
        var pose = anim.pose(look: CGVector(dx: 0, dy: 1))
        pose.lift += keys.isEmpty ? 0 : CGFloat(abs(sin(t * 12))) * 3
        Renderer.draw(skin: p.data.skin, hat: p.data.hat, pose: pose, at: NSPoint(x: gameX, y: groundY), scale: roomScale)
        for pop in popups {
            let ph = CGFloat(t - pop.at) / 0.8
            text(pop.text, NSPoint(x: pop.x - 8, y: pop.y + ph * 24), size: 14, color: (pop.text.hasPrefix("-") ? rgb(0xFF6B6B) : sparkYellow).withAlphaComponent(1 - ph), weight: .heavy)
        }
        let left = max(0, 30 - (t - gameStart))
        text("🐞 BUG CATCH", NSPoint(x: 14, y: H - 28), size: 13, color: .white, weight: .heavy)
        text("Score \(gameScore)", NSPoint(x: 190, y: H - 28), size: 13, color: sparkYellow, weight: .heavy)
        text(String(format: "%.0fs", gameEnded ? 0 : left), NSPoint(x: W - 46, y: H - 28), size: 13, color: .white, weight: .heavy)
        if !gameEnded && t - gameStart < 3 {
            text("Catch bugs 🐞 (+1) and golden bugs (+5). Dodge errors (−3)!", NSPoint(x: 40, y: 250), size: 11.5, color: .white, weight: .medium)
            text("Move with the mouse or ← →", NSPoint(x: 150, y: 232), size: 11, color: NSColor(white: 0.8, alpha: 1))
        }
        if gameEnded {
            let card = NSRect(x: 120, y: 140, width: 220, height: 130)
            fill(rgb(0x1E1B2E, 0.97), card, radius: 14)
            text("Time's up!", NSPoint(x: card.minX + 66, y: card.maxY - 32), size: 16, color: .white, weight: .heavy)
            text("Score \(gameScore)  ·  Best \(p.data.bestScore)  ·  +\(min(60, gameScore)) XP", NSPoint(x: card.minX + 22, y: card.maxY - 56), size: 11.5, color: sparkYellow, weight: .semibold)
            fill(claudeOrange, againRect, radius: 8)
            text("Play again", NSPoint(x: againRect.minX + 12, y: againRect.minY + 7), size: 11.5, color: .white, weight: .bold)
            fill(NSColor(white: 1, alpha: 0.15), doneRect, radius: 8)
            text("Done", NSPoint(x: doneRect.minX + 26, y: doneRect.minY + 7), size: 11.5, color: .white, weight: .bold)
        }
    }

    private let againRect = NSRect(x: 136, y: 156, width: 88, height: 28)
    private let doneRect = NSRect(x: 236, y: 156, width: 88, height: 28)

    private func drawBug(_ b: Bug, t: Double) {
        if b.kind == 2 {
            fill(rgb(0xE5484D), NSRect(x: b.x - 10, y: b.y - 10, width: 20, height: 20), radius: 10)
            text("✕", NSPoint(x: b.x - 6, y: b.y - 8), size: 13, color: .white, weight: .heavy)
            return
        }
        let body = b.kind == 1 ? rgb(0xF2C94C) : rgb(0x3E9B4F)
        rgb(0x1E1E1E).setStroke()
        let legs = NSBezierPath(); legs.lineWidth = 1.2
        let wig = CGFloat(sin(t * 20)) * 2
        for k in -1...1 {
            let y = b.y + CGFloat(k) * 4
            legs.move(to: NSPoint(x: b.x - 6, y: y)); legs.line(to: NSPoint(x: b.x - 11, y: y + wig))
            legs.move(to: NSPoint(x: b.x + 6, y: y)); legs.line(to: NSPoint(x: b.x + 11, y: y - wig))
        }
        legs.move(to: NSPoint(x: b.x - 2, y: b.y - 8)); legs.line(to: NSPoint(x: b.x - 5, y: b.y - 13))
        legs.move(to: NSPoint(x: b.x + 2, y: b.y - 8)); legs.line(to: NSPoint(x: b.x + 5, y: b.y - 13))
        legs.stroke()
        fill(body, NSRect(x: b.x - 7, y: b.y - 8, width: 14, height: 17), radius: 7)
        fill(rgb(0x1E1E1E), NSRect(x: b.x - 4.5, y: b.y - 11, width: 9, height: 6), radius: 3)
        rgb(0x1E1E1E).setStroke()
        let line = NSBezierPath(); line.lineWidth = 1
        line.move(to: NSPoint(x: b.x, y: b.y - 6)); line.line(to: NSPoint(x: b.x, y: b.y + 9)); line.stroke()
        if b.kind == 1 { NSColor.white.setFill(); Renderer.sparkle(at: NSPoint(x: b.x + 9, y: b.y + 9), size: 3 + CGFloat(abs(sin(t * 8))) * 2) }
    }

    // MARK: Input

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { if overlay != .none { open(overlay) }; return }
        if overlay == .game {
            keys.insert(event.keyCode)
            if gameEnded && event.keyCode == 49 { startGame() }
        } else { super.keyDown(with: event) }
    }

    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { open(.console); return true }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let t = now()

        for i in hudButtons.indices where hudButton(i).contains(pt) {
            switch i {
            case 0: feed()
            case 1: showGameMenu()
            case 2: open(.wardrobe)
            default: open(.console)
            }
            return
        }

        switch overlay {
        case .wardrobe:
            if NSRect(x: panel.maxX - 30, y: panel.maxY - 32, width: 26, height: 26).contains(pt) { open(.wardrobe); return }
            for i in tabs.indices where tabRect(i).contains(pt) { wardrobeTab = i; Synth.shared.pop(); return }
            if wardrobeTab < 3 {
                for (i, it) in tabItems.enumerated() where cellRect(i).contains(pt) {
                    if p.isUnlocked(it) { p.equip(it); Synth.shared.unlock(); anim.celebrate() } else { Synth.shared.grumble() }
                    return
                }
            }
            return
        case .game:
            if gameEnded {
                if againRect.contains(pt) { startGame() } else if doneRect.contains(pt) { open(.game) }
            }
            return
        case .console:
            if !consoleRect.contains(pt) { open(.console) }
            return
        case .none:
            break
        }

        let pose = anim.pose(look: .zero)
        let c = buddyCenter(pose)
        if hypot(pt.x - c.x, pt.y - (c.y + pose.lift * roomScale)) < 26 { onPoke?(); return }

        func walk(to x: CGFloat, saying line: String) {
            guard !anim.asleep, anim.mood == .idle else { say(line); return }
            targetX = x; arriveLine = line; nextWander = t + 12
        }
        if p.has("cat") && NSRect(x: 96, y: 96, width: 30, height: 32).contains(pt) { Synth.shared.meow(); catHeartAt = t; return }
        if p.has("arcade") && NSRect(x: 290, y: 56, width: 30, height: 112).contains(pt) { open(.game); return }
        if p.has("lamp") && NSRect(x: 420, y: 112, width: 32, height: 44).contains(pt) { lampOn.toggle(); Synth.shared.pop(); return }
        if p.has("records") && NSRect(x: 392, y: 226, width: 52, height: 16).contains(pt) {
            musicOn.toggle()
            if musicOn { Synth.shared.done(pitch: 0.75); anim.dance() }
            return
        }
        if p.has("plant") && NSRect(x: 145, y: 56, width: 36, height: 74).contains(pt) { plantWiggleAt = t; walk(to: 182, saying: "*waters plant* 🌱"); return }
        if p.has("fishtank") && NSRect(x: 186, y: 56, width: 52, height: 76).contains(pt) { walk(to: 211, saying: "blub blub 🐟"); return }
        if p.has("poster") && NSRect(x: 34, y: 186, width: 66, height: 88).contains(pt) { say("SHIP IT! 🚀"); anim.celebrate(); return }
        if NSRect(x: 176, y: 172, width: 118, height: 124).contains(pt) {
            walk(to: 235, saying: p.data.room == "space" ? "Hi Earth! 🌍" : isNight ? "Look at the stars ✨" : "What a nice day ☀️"); return
        }
        if NSRect(x: 386, y: 112, width: 50, height: 32).contains(pt) { say(anim.mood == .idle ? "Nothing running. Break time!" : "Working on it… ⌨️"); return }
        if NSRect(x: 14, y: 60, width: 126, height: 46).contains(pt) { walk(to: 120, saying: "So comfy… 😴"); return }
    }

    func feed() {
        if anim.sick { onMedicine?(); return }
        guard cookieY == nil else { return }
        if overlay != .none && overlay != .console { open(overlay) }
        cookieY = H - 20
        Synth.shared.pop()
    }
}

final class RoomWindow: NSWindow {
    init(view: RoomView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable, .miniaturizable],
                   backing: .buffered, defer: false)
        title = "Buddy's Room"
        contentView = view
        isReleasedWhenClosed = false
        center()
    }
}
