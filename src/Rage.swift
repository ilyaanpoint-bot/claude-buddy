// Buddy's tantrum: a click-through overlay on every screen where the little devil lobs
// bombs everywhere. Click a bomb before its fuse runs out to defuse it.

import AppKit

final class RageShow {
    struct Bomb {
        var target: NSPoint        // screen coordinates
        var spawnAt: Double
        var fuseEnd: Double
        var state = 0              // 0 live, 1 exploded, 2 defused
        var stateAt = 0.0
        var word = ""
    }

    private(set) var bombs: [Bomb] = []
    private(set) var origin = NSPoint.zero
    private(set) var startedAt = 0.0
    private(set) var shakeUntil = -100.0
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private(set) var defused = 0
    var onDefuse: (() -> Void)?
    var onFinished: ((Int) -> Void)?

    var running: Bool { timer != nil }

    func start(from point: NSPoint) {
        origin = point
        startedAt = now()
        defused = 0
        let words = ["BOOM!", "KABOOM!", "POW!", "BLAM!", "KAPOW!", "BANG!"]
        let screens = NSScreen.screens
        let count = 12 + screens.count * 5
        bombs = (0..<count).map { i in
            let s = screens[i % screens.count].visibleFrame.insetBy(dx: 70, dy: 70)
            let spawn = startedAt + 0.15 + Double(i) * 0.11
            return Bomb(target: NSPoint(x: CGFloat.random(in: s.minX...s.maxX), y: CGFloat.random(in: s.minY...s.maxY)),
                        spawnAt: spawn, fuseEnd: spawn + 2.4 + Double.random(in: 0...1.8), word: words.randomElement()!)
        }
        for screen in screens {
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.ignoresMouseEvents = true
            w.contentView = RageView(show: self, screenFrame: screen.frame)
            w.orderFrontRegardless()
            windows.append(w)
        }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Where a bomb is right now (it flies from buddy to its spot first).
    func position(_ b: Bomb, at t: Double) -> (NSPoint, landed: Bool) {
        let k = min(1, max(0, (t - b.spawnAt) / 0.55))
        let x = origin.x + (b.target.x - origin.x) * CGFloat(k)
        let arc = CGFloat(sin(k * .pi)) * 160
        let y = origin.y + (b.target.y - origin.y) * CGFloat(k) + arc
        return (NSPoint(x: x, y: y), k >= 1)
    }

    private func tick() {
        let t = now()
        for i in bombs.indices where bombs[i].state == 0 && t >= bombs[i].fuseEnd {
            bombs[i].state = 1
            bombs[i].stateAt = t
            shakeUntil = t + 0.18
            Synth.shared.boom(big: i == bombs.count - 1)
        }
        // Only grab the mouse while it's over a live bomb.
        let m = NSEvent.mouseLocation
        let overBomb = bombs.contains { b in
            b.state == 0 && t > b.spawnAt + 0.55 && hypot(b.target.x - m.x, b.target.y - m.y) < 26
        }
        for w in windows {
            let ignore = !(overBomb && w.frame.contains(m))
            if w.ignoresMouseEvents != ignore { w.ignoresMouseEvents = ignore }
            w.contentView?.needsDisplay = true
        }
        let lastEvent = bombs.map { $0.state == 0 ? Double.infinity : $0.stateAt }.max() ?? t
        if t - lastEvent > 1.6 { finish() }
    }

    func click(at p: NSPoint) {
        let t = now()
        guard let i = bombs.indices.filter({ bombs[$0].state == 0 && t > bombs[$0].spawnAt + 0.55 })
            .min(by: { hypot(bombs[$0].target.x - p.x, bombs[$0].target.y - p.y) < hypot(bombs[$1].target.x - p.x, bombs[$1].target.y - p.y) }),
              hypot(bombs[i].target.x - p.x, bombs[i].target.y - p.y) < 30 else { return }
        bombs[i].state = 2
        bombs[i].stateAt = t
        defused += 1
        Synth.shared.fizzle()
        onDefuse?()
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onFinished?(defused)
    }
}

final class RageView: NSView {
    private weak var show: RageShow?
    private let screenFrame: NSRect

    init(show: RageShow, screenFrame: NSRect) {
        self.show = show
        self.screenFrame = screenFrame
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        show?.click(at: NSPoint(x: p.x + screenFrame.minX, y: p.y + screenFrame.minY))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let show else { return }
        let t = now()
        // A red flash as the tantrum starts
        let flash = max(0, 1 - (t - show.startedAt) / 0.8)
        if flash > 0 {
            NSGradient(colors: [NSColor(red: 0.9, green: 0.1, blue: 0.05, alpha: 0), NSColor(red: 0.9, green: 0.1, blue: 0.05, alpha: 0.35 * flash)])?
                .draw(in: NSBezierPath(rect: bounds), relativeCenterPosition: .zero)
        }
        NSGraphicsContext.saveGraphicsState()
        if t < show.shakeUntil {
            let xf = NSAffineTransform()
            xf.translateX(by: CGFloat.random(in: -6...6), yBy: CGFloat.random(in: -6...6))
            xf.concat()
        }
        for b in show.bombs where t >= b.spawnAt {
            let (sp, landed) = show.position(b, at: t)
            let p = NSPoint(x: sp.x - screenFrame.minX, y: sp.y - screenFrame.minY)
            guard bounds.insetBy(dx: -200, dy: -200).contains(p) else { continue }
            switch b.state {
            case 0: drawBomb(at: p, left: b.fuseEnd - t, total: b.fuseEnd - b.spawnAt, landed: landed, t: t)
            case 1: drawExplosion(at: p, e: t - b.stateAt, word: b.word)
            default: drawDefused(at: p, e: t - b.stateAt)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBomb(at p: NSPoint, left: Double, total: Double, landed: Bool, t: Double) {
        let danger = left < 0.8 && fmod(t, 0.2) < 0.1
        let r: CGFloat = 15 * (landed ? 1 + 0.06 * CGFloat(sin(t * 12)) : 0.8)
        NSColor(white: 0, alpha: 0.18).setFill()
        if landed { NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r - 6, width: 2 * r, height: 7)).fill() }
        (danger ? rgb(0xB71C1C) : rgb(0x1E1E24)).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
        NSColor(white: 1, alpha: 0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - r * 0.55, y: p.y + r * 0.2, width: r * 0.5, height: r * 0.35)).fill()
        rgb(0x44444C).setFill()
        NSBezierPath(rect: NSRect(x: p.x - 4, y: p.y + r - 2, width: 8, height: 5)).fill()
        // Fuse shrinks as time runs out
        let frac = CGFloat(max(0, min(1, left / total)))
        let fuse = NSBezierPath(); fuse.lineWidth = 2; fuse.lineCapStyle = .round
        let start = NSPoint(x: p.x, y: p.y + r + 3)
        let end = NSPoint(x: p.x + 4 + 8 * frac, y: p.y + r + 4 + 10 * frac)
        fuse.move(to: start)
        fuse.curve(to: end, controlPoint1: NSPoint(x: p.x - 2, y: p.y + r + 10 * frac), controlPoint2: NSPoint(x: end.x - 4, y: end.y))
        rgb(0xA1887F).setStroke(); fuse.stroke()
        let s = 4 + CGFloat.random(in: 0...3)
        rgb(0xFFF59D).setFill()
        Renderer.sparkle(at: end, size: s + 2)
        rgb(0xFF9800).setFill()
        Renderer.sparkle(at: end, size: s * 0.6)
    }

    private func drawExplosion(at p: NSPoint, e: Double, word: String) {
        if e < 0.55 {
            let k = CGFloat(e / 0.55)
            for (c, scale) in [(rgb(0xFF5722), 1.0), (rgb(0xFF9800), 0.75), (rgb(0xFFEB3B), 0.45)] as [(NSColor, CGFloat)] {
                let r = (20 + 110 * k) * scale
                c.withAlphaComponent(1 - k).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
            }
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi + 0.3
                let d = 30 + 150 * k
                rgb(i % 2 == 0 ? 0xFFC107 : 0x5D4037, 1 - k).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x + CGFloat(cos(a)) * d - 3, y: p.y + CGFloat(sin(a)) * d - 3, width: 6, height: 6)).fill()
            }
        }
        if e < 3 {
            rgb(0x2B1D16, 0.45 * CGFloat(max(0, 1 - e / 3))).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 34, y: p.y - 16, width: 68, height: 32)).fill()
        }
        if e < 1 {
            let k = CGFloat(e)
            let size = 22 + 18 * min(1, k * 4)
            let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.6); shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 2, height: -2)
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .black),
                                                        .foregroundColor: rgb(0xFFEB3B, 1 - k * 0.8), .shadow: shadow]
            let s = NSAttributedString(string: word, attributes: attrs)
            s.draw(at: NSPoint(x: p.x - s.size().width / 2, y: p.y + 20 + k * 30))
        }
    }

    private func drawDefused(at p: NSPoint, e: Double) {
        guard e < 1.4 else { return }
        let k = CGFloat(e / 1.4)
        rgb(0x1E1E24, 1 - k).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)).fill()
        for i in 0..<3 {
            NSColor(white: 0.85, alpha: 0.7 * (1 - k)).setFill()
            let r = 6 + k * 10
            NSBezierPath(ovalIn: NSRect(x: p.x - r + CGFloat(i - 1) * 10, y: p.y + 14 + k * 40 + CGFloat(i) * 4, width: 2 * r, height: 2 * r)).fill()
        }
        let s = NSAttributedString(string: "fzzt ✓", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .heavy), .foregroundColor: rgb(0x66BB6A, 1 - k)])
        s.draw(at: NSPoint(x: p.x - 22, y: p.y - 36))
    }
}
