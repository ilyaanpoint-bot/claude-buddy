// The always-on-top corner widget: orange buddy, plus a blue friend for a second session.

import AppKit

final class Slot {
    let anim: Animator
    let inset: CGFloat           // distance of its centre from the window's right edge
    var present: Bool
    var presentChangedAt = -100.0
    var bubbleTitle = ""
    var bubbleSub = ""
    var bubbleAt = -100.0
    var bubbleDuration = 0.0
    var lastActivity = now()

    init(inset: CGFloat, present: Bool, phase: Double) {
        self.inset = inset; self.present = present; anim = Animator(phase: phase)
    }
}

final class CornerView: NSView {
    let slots = [Slot(inset: 46, present: true, phase: 0), Slot(inset: 130, present: false, phase: 1.3)]

    var onPoke: ((Int) -> Void)?
    var onFiveClicks: ((Int) -> Void)?
    var onShake: (() -> Void)?
    var onBubbleClick: ((Int) -> Void)?
    var onOpenRoom: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onFlick: ((CGVector) -> Void)?
    var onSquishRelease: ((Int, CGFloat) -> Void)?
    private(set) var holdIndex: Int?
    private(set) var holdStart = 0.0
    private var dragSamples: [(Double, NSPoint)] = []
    var menuProvider: (() -> NSMenu?)?

    private var pressed: (index: Int, bubble: Bool)?
    private var dragOffset: NSPoint?
    private var dragged = false
    private var lastDragX: CGFloat = 0
    private var lastDragSign: CGFloat = 0
    private var reversals: [Double] = []
    private var shookThisDrag = false
    private var pendingRoom: DispatchWorkItem?

    private let titleAttrs: [NSAttributedString.Key: Any] = {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
        return [.font: NSFont.systemFont(ofSize: 12.5, weight: .semibold), .foregroundColor: NSColor(white: 0.12, alpha: 1), .paragraphStyle: p]
    }()
    private let subAttrs: [NSAttributedString.Key: Any] = {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
        return [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(white: 0.38, alpha: 1), .paragraphStyle: p]
    }()

    private func home(_ i: Int) -> NSPoint { NSPoint(x: bounds.maxX - slots[i].inset, y: 44) }
    private func bubbleVisible(_ i: Int) -> Bool { slots[i].present && now() - slots[i].bubbleAt < slots[i].bubbleDuration }

    func skin(_ i: Int) -> String { i == 0 ? BuddyProgress.shared.data.skin : "sky" }
    func hat(_ i: Int) -> String { i == 0 ? BuddyProgress.shared.data.hat : "none" }

    func setPresent(_ i: Int, _ present: Bool) {
        let s = slots[i]
        guard s.present != present else { return }
        s.present = present
        s.presentChangedAt = now()
        if !present { s.bubbleDuration = 0 } else { s.lastActivity = now() }
    }

    func say(_ i: Int, title: String, sub: String = "", duration: Double = 8, voice: Bool = true) {
        let s = slots[i]
        s.bubbleTitle = title; s.bubbleSub = sub
        s.bubbleAt = now(); s.bubbleDuration = duration
        if voice {
            Synth.shared.babble(title, pitch: i == 0 ? 1 : 1.25)
            s.anim.talk(Double(max(2, min(9, title.count / 3))) * 0.072)
        }
    }

    func dismissBubble(_ i: Int) {
        let s = slots[i]
        if bubbleVisible(i) { s.bubbleDuration = min(s.bubbleDuration, now() - s.bubbleAt + 0.4) }
    }

    private func bubbleRect(_ i: Int) -> NSRect {
        let s = slots[i]
        let maxText: CGFloat = 200
        let tw = min(maxText, (s.bubbleTitle as NSString).size(withAttributes: titleAttrs).width)
        let sw = s.bubbleSub.isEmpty ? 0 : min(maxText, (s.bubbleSub as NSString).size(withAttributes: subAttrs).width)
        let w = max(tw, sw) + 34
        let h: CGFloat = s.bubbleSub.isEmpty ? 28 : 42
        // When both are talking, the newer bubble sits on top of the older one.
        let other = 1 - i
        let stacked = bubbleVisible(other) && slots[other].bubbleAt < s.bubbleAt
        let right = min(bounds.maxX - 4, home(i).x + 22)
        return NSRect(x: max(4, right - w), y: 100 + (stacked ? 48 : 0), width: w, height: h)
    }

    /// Which character (or its bubble) is under the point; everything else clicks through.
    func hit(at p: NSPoint) -> (index: Int, bubble: Bool)? {
        for i in slots.indices.reversed() where bubbleVisible(i) && bubbleRect(i).insetBy(dx: -4, dy: -4).contains(p) {
            return (i, true)
        }
        for i in slots.indices where slots[i].present {
            let h = home(i)
            if hypot(p.x - h.x, p.y - h.y) < 38 { return (i, false) }
        }
        return nil
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let mouse = window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? .zero
        for i in slots.indices {
            let s = slots[i]
            let appear = appearance(s)
            guard appear > 0.01 else { continue }
            let h = home(i)
            let v = CGVector(dx: mouse.x - h.x, dy: mouse.y - h.y)
            let len = max(80, hypot(v.dx, v.dy))
            var pose = s.anim.pose(look: CGVector(dx: v.dx / len, dy: v.dy / len))
            pose.sx *= appear; pose.sy *= appear
            Renderer.draw(skin: skin(i), hat: hat(i), pose: pose, at: h, scale: 1)
            if s.anim.mood == .working && !s.anim.isCelebrating && !s.anim.asleep { thinkingDots(i) }
            if s.anim.mood == .attention && !s.anim.asleep { attentionMark(i) }
        }
        for i in slots.indices where bubbleVisible(i) { drawBubble(i) }
    }

    /// 0…1 (with a little overshoot) as a character pops in or out.
    private func appearance(_ s: Slot) -> CGFloat {
        let e = now() - s.presentChangedAt
        if s.present {
            let x = min(1, e / 0.45)
            return CGFloat(1 + 2.7 * pow(x - 1, 3) + 1.7 * pow(x - 1, 2))
        }
        return CGFloat(max(0, 1 - e / 0.3))
    }

    private func thinkingDots(_ i: Int) {
        let t = now(), h = home(i)
        for d in 0..<3 {
            let hop = CGFloat(max(0, sin(t * 5 - Double(d) * 0.8))) * 4
            Renderer.rayColor(skin(i), d, t).withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: h.x - 44 + CGFloat(d) * 8, y: h.y + 28 + hop, width: 5, height: 5)).fill()
        }
    }

    private func attentionMark(_ i: Int) {
        let h = home(i)
        let bob = CGFloat(sin(now() * 6)) * 2
        let mark = NSAttributedString(string: "!", attributes: [.font: NSFont.systemFont(ofSize: 22, weight: .heavy),
                                                                .foregroundColor: Renderer.rayColor(skin(i), 0, now())])
        mark.draw(at: NSPoint(x: h.x + 24, y: h.y + 20 + bob))
    }

    private func drawBubble(_ i: Int) {
        let s = slots[i]
        let e = now() - s.bubbleAt
        let alpha = CGFloat(min(1, e / 0.25) * min(1, (s.bubbleDuration - e) / 0.4))
        var r = bubbleRect(i)
        r.origin.y -= CGFloat(1 - min(1, e / 0.25)) * 6
        let tipX = home(i).x + 6

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)
        NSGraphicsContext.current?.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        let path = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
        path.move(to: NSPoint(x: tipX - 12, y: r.minY + 2))
        path.line(to: NSPoint(x: tipX, y: r.minY - 10))
        path.line(to: NSPoint(x: tipX + 2, y: r.minY + 2))
        path.close()
        NSColor(white: 0.99, alpha: 1).setFill()
        path.fill()
        NSShadow().set()

        Renderer.rayColor(skin(i), 0, now()).setFill()
        NSBezierPath(ovalIn: NSRect(x: r.minX + 10, y: r.maxY - 18, width: 7, height: 7)).fill()

        let inner = NSRect(x: r.minX + 22, y: r.minY, width: r.width - 32, height: r.height)
        if s.bubbleSub.isEmpty {
            (s.bubbleTitle as NSString).draw(in: NSRect(x: inner.minX, y: r.minY + 6, width: inner.width, height: 17), withAttributes: titleAttrs)
        } else {
            (s.bubbleTitle as NSString).draw(in: NSRect(x: inner.minX, y: r.minY + 21, width: inner.width, height: 17), withAttributes: titleAttrs)
            (s.bubbleSub as NSString).draw(in: NSRect(x: inner.minX, y: r.minY + 6, width: inner.width, height: 15), withAttributes: subAttrs)
        }
        NSGraphicsContext.current?.cgContext.endTransparencyLayer()
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Mouse

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pressed = hit(at: convert(event.locationInWindow, from: nil))
        if let p = pressed, !p.bubble { holdIndex = p.index; holdStart = now() }
        dragSamples = [(now(), NSEvent.mouseLocation)]
        dragOffset = event.locationInWindow
        dragged = false
        shookThisDrag = false
        reversals.removeAll()
        lastDragX = NSEvent.mouseLocation.x
        lastDragSign = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let off = dragOffset, let w = window else { return }
        let m = NSEvent.mouseLocation
        let origin = NSPoint(x: m.x - off.x, y: m.y - off.y)
        if !dragged && hypot(origin.x - w.frame.minX, origin.y - w.frame.minY) < 3 { return }
        if !dragged { slots.forEach { $0.anim.dragging = true } }
        dragged = true
        holdIndex = nil
        w.setFrameOrigin(origin)
        dragSamples.append((now(), m))
        dragSamples.removeAll { now() - $0.0 > 0.08 }

        // Shake detection: lots of quick left/right reversals.
        let dx = m.x - lastDragX
        if abs(dx) > 4 {
            let sign: CGFloat = dx > 0 ? 1 : -1
            if lastDragSign != 0 && sign != lastDragSign { reversals.append(now()) }
            lastDragSign = sign
            lastDragX = m.x
        }
        reversals.removeAll { now() - $0 > 1.5 }
        if reversals.count >= 6 && !shookThisDrag { shookThisDrag = true; onShake?() }
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragOffset = nil; pressed = nil }
        let heldIndex = holdIndex
        holdIndex = nil
        if let h = heldIndex, slots[h].anim.squish > 0.05 {
            let amt = slots[h].anim.squish
            onSquishRelease?(h, amt)
            if amt > 0.3 { return }
        }
        if dragged {
            slots.forEach { $0.anim.dragging = false }
            if let w = window { onMoved?(w.frame.origin) }
            if let first = dragSamples.first, let last = dragSamples.last, last.0 - first.0 > 0.01 {
                let dt = CGFloat(last.0 - first.0)
                let v = CGVector(dx: (last.1.x - first.1.x) / dt, dy: (last.1.y - first.1.y) / dt)
                if hypot(v.dx, v.dy) > 1100 { onFlick?(v) }
            }
            return
        }
        guard let p = pressed else { return }
        if p.bubble { onBubbleClick?(p.index); return }
        onPoke?(p.index)
        pendingRoom?.cancel()
        if event.clickCount == 5 { onFiveClicks?(p.index) }
        if event.clickCount == 2 {
            let work = DispatchWorkItem { [weak self] in self?.onOpenRoom?() }
            pendingRoom = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}
