// Copycat: buddy lights up coloured pads in a pattern; you copy it. One more step each round.

import AppKit

private let roomW: CGFloat = 460
private let roomH: CGFloat = 296

final class CopycatView: NSView {
    private enum Phase { case showing, input, over }

    let anim: Animator
    var onEnd: ((Int) -> Void)?

    private var seq: [Int] = []
    private var phase = Phase.showing
    private var showIndex = 0
    private var inputIndex = 0
    private var nextStepAt = 0.0
    private var flashPad: Int?
    private var flashUntil = 0.0
    private var timer: Timer?
    private var score = 0

    private let colors: [UInt32] = [0xE5395B, 0x3F7FE0, 0xF2C94C, 0x5DBB63]
    private let arrows = ["↑", "→", "↓", "←"]
    private let center = NSPoint(x: roomW / 2, y: 140)
    private func padCenter(_ i: Int) -> NSPoint {
        [NSPoint(x: center.x, y: center.y + 84), NSPoint(x: center.x + 104, y: center.y),
         NSPoint(x: center.x, y: center.y - 84), NSPoint(x: center.x - 104, y: center.y)][i]
    }
    private let againRect = NSRect(x: 136, y: 40, width: 88, height: 28)
    private let doneRect = NSRect(x: 236, y: 40, width: 88, height: 28)

    init(anim: Animator) {
        self.anim = anim
        super.init(frame: NSRect(x: 0, y: 44, width: roomW, height: roomH))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        window?.makeFirstResponder(self)
        restart()
    }

    override func removeFromSuperview() {
        timer?.invalidate()
        super.removeFromSuperview()
    }

    private func restart() {
        seq = [Int.random(in: 0..<4)]
        phase = .showing
        showIndex = 0
        nextStepAt = now() + 1
        score = 0
    }

    private func flash(_ i: Int) {
        flashPad = i
        flashUntil = now() + 0.32
        Synth.shared.pad(i)
    }

    private func tick() {
        let t = now()
        if phase == .showing && t >= nextStepAt {
            if showIndex < seq.count {
                flash(seq[showIndex])
                showIndex += 1
                nextStepAt = t + max(0.34, 0.62 - Double(seq.count) * 0.025)
            } else {
                phase = .input
                inputIndex = 0
            }
        }
        needsDisplay = true
    }

    private func press(_ i: Int) {
        guard phase == .input else { return }
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
            phase = .over
            Synth.shared.buzz()
            anim.dizzy()
            onEnd?(score)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let t = now()
        rgb(0x1E1B2E, 0.97).setFill()
        NSBezierPath(rect: bounds).fill()
        func text(_ s: String, _ p: NSPoint, _ size: CGFloat, _ c: NSColor, _ w: NSFont.Weight = .bold) {
            (s as NSString).draw(at: p, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: w), .foregroundColor: c])
        }
        text("🎵 COPYCAT", NSPoint(x: 14, y: roomH - 28), 13, .white, .heavy)
        text("Round \(seq.count)", NSPoint(x: roomW / 2 - 28, y: roomH - 28), 13, sparkYellow, .heavy)
        text("Best \(UserDefaults.standard.integer(forKey: "bestCopycat"))", NSPoint(x: roomW - 70, y: roomH - 28), 12, NSColor(white: 0.7, alpha: 1))
        let hint = phase == .showing ? "Watch buddy…" : phase == .input ? "Your turn! Click the pads or use the arrow keys" : ""
        text(hint, NSPoint(x: 14, y: 12), 11.5, NSColor(white: 0.75, alpha: 1), .medium)

        for i in 0..<4 {
            let c = padCenter(i)
            let lit = flashPad == i && t < flashUntil
            let r: CGFloat = lit ? 36 : 32
            rgb(colors[i], lit ? 1 : 0.38).setFill()
            if lit {
                let glow = NSShadow(); glow.shadowColor = rgb(colors[i]); glow.shadowBlurRadius = 18
                NSGraphicsContext.saveGraphicsState(); glow.set()
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
                NSGraphicsContext.restoreGraphicsState()
            } else {
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
            }
            text(arrows[i], NSPoint(x: c.x - 7, y: c.y - 11), 18, NSColor(white: 1, alpha: lit ? 1 : 0.6), .heavy)
        }

        var look = CGVector.zero
        if let f = flashPad, t < flashUntil {
            let pc = padCenter(f)
            look = CGVector(dx: (pc.x - center.x) / 104, dy: (pc.y - center.y) / 84)
        }
        var pose = anim.pose(look: look)
        pose.lift = min(pose.lift, 12)
        let d = BuddyProgress.shared.data
        Renderer.draw(skin: d.skin, hat: d.hat, pose: pose, at: center, scale: 1.05, shadow: false)

        if phase == .over {
            let card = NSRect(x: 120, y: 30, width: 220, height: 120)
            rgb(0x2B2D42, 0.98).setFill()
            NSBezierPath(roundedRect: card, xRadius: 14, yRadius: 14).fill()
            text("Oops! 😵‍💫", NSPoint(x: card.minX + 70, y: card.maxY - 32), 16, .white, .heavy)
            text("You reached round \(score + 1)  ·  +\(min(60, score * 3)) XP", NSPoint(x: card.minX + 22, y: card.maxY - 56), 11.5, sparkYellow, .semibold)
            claudeOrange.setFill(); NSBezierPath(roundedRect: againRect, xRadius: 8, yRadius: 8).fill()
            text("Play again", NSPoint(x: againRect.minX + 12, y: againRect.minY + 7), 11.5, .white)
            NSColor(white: 1, alpha: 0.15).setFill(); NSBezierPath(roundedRect: doneRect, xRadius: 8, yRadius: 8).fill()
            text("Done", NSPoint(x: doneRect.minX + 26, y: doneRect.minY + 7), 11.5, .white)
        }
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if phase == .over {
            if againRect.contains(p) { restart() } else if doneRect.contains(p) { removeFromSuperview() }
            return
        }
        for i in 0..<4 where hypot(p.x - padCenter(i).x, p.y - padCenter(i).y) < 36 { press(i); return }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: press(0)
        case 124: press(1)
        case 125: press(2)
        case 123: press(3)
        case 53: removeFromSuperview()
        case 49: if phase == .over { restart() }
        default: super.keyDown(with: event)
        }
    }
}

extension RoomView {
    /// Play button: pick a game.
    func showGameMenu() {
        let menu = NSMenu()
        let bug = menu.addItem(withTitle: "🐞 Bug Catch", action: #selector(startBugCatch), keyEquivalent: "")
        bug.target = self
        let cc = menu.addItem(withTitle: "🎵 Copycat", action: #selector(startCopycat), keyEquivalent: "")
        cc.target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 299, y: 40), in: self)
    }

    @objc func startBugCatch() {
        closeCopycat()
        if overlay != .game { open(.game) }
    }

    @objc func startCopycat() {
        closeCopycat()
        if overlay != .none { open(overlay) }
        let v = CopycatView(anim: anim)
        v.onEnd = { score in
            let best = UserDefaults.standard.integer(forKey: "bestCopycat")
            if score > best { UserDefaults.standard.set(score, forKey: "bestCopycat") }
            BuddyProgress.shared.award(min(60, score * 3))
            if score + 1 >= 8 { BuddyProgress.shared.achieve("copycat", unlocking: "headband") }
        }
        addSubview(v)
    }

    func closeCopycat() {
        subviews.compactMap { $0 as? CopycatView }.forEach { $0.removeFromSuperview() }
    }
}
