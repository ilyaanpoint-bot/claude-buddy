// How a buddy looks (skins, hats, faces) and how it moves (the Animator turns
// mood + recent interactions into a Pose that the Renderer draws).

import AppKit

enum Expression { case normal, happy, surprised, asleep, dizzy, blush, chomp, grumpy, focused, love, whee,
                  angry, furious, devil, sick, scared, scrunch, yawn, whistle }

enum Prop { case juggle, notes, book, coffee, sneeze, wave, barf }
enum IdleAnim: CaseIterable { case yawn, lookAround, juggle, whistle, sneeze, spin, hop, read, coffee, wave }

struct Pose {
    var skinOverride: String?
    var hatOverride: String?
    var steam: CGFloat = 0
    var sick: CGFloat = 0
    var prop: Prop?
    var propT: Double = 0
    var dx: CGFloat = 0
    var lift: CGFloat = 0
    var rot: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var rayExtend: CGFloat = 1
    var rayWiggle = false
    var expression: Expression = .normal
    var look = CGVector.zero
    var blink = false
    var mouth: CGFloat = 0
    var zzz = false
    var sparks: Double?
    var lying = false
}

final class Animator {
    var mood: Mood = .idle
    var asleep = false
    var dragging = false
    private(set) var celebrateAt = -100.0
    private var petAt = -100.0
    private var dizzyUntil = -100.0
    private var chompUntil = -100.0
    private var grumpyUntil = -100.0
    private var surprisedAt = -100.0
    private var talkUntil = -100.0
    private var loveUntil = -100.0
    private var danceUntil = -100.0
    private var blinkAt = -100.0
    private var nextBlink = Double.random(in: 1.5...4)
    let phase: Double

    // Personality state
    var anger: Double = 0          // 0…100; 100 = devil mode
    var devil = false
    var sick = false
    var squish: CGFloat = 0        // 0…1 while being held down
    var flying = false
    private var scaredAt = -100.0
    private var idleAnim: IdleAnim?
    private var idleAt = -100.0
    private var barfAt = -100.0

    init(phase: Double) { self.phase = phase }

    func scare() { scaredAt = now() }
    func barf() { barfAt = now() }
    func startIdle(_ a: IdleAnim) { idleAnim = a; idleAt = now() }
    var idleBusy: Bool { idleAnim != nil && now() - idleAt < idleLength(idleAnim!) }

    private func idleLength(_ a: IdleAnim) -> Double {
        switch a {
        case .yawn: return 2.2
        case .lookAround: return 3
        case .juggle: return 4
        case .whistle: return 3.2
        case .sneeze: return 1.8
        case .spin: return 1.2
        case .hop: return 1.1
        case .read: return 5
        case .coffee: return 4
        case .wave: return 1.8
        }
    }

    var isCelebrating: Bool { now() - celebrateAt < 2.6 || now() < danceUntil }
    var isDizzy: Bool { now() < dizzyUntil }

    func celebrate() { celebrateAt = now() }
    func pet() { petAt = now() }
    func dizzy() { dizzyUntil = now() + 3 }
    func chomp() { chompUntil = now() + 1.4 }
    func grumpy() { grumpyUntil = now() + 2 }
    func surprise() { surprisedAt = now() }
    func talk(_ seconds: Double) { talkUntil = now() + seconds }
    func love() { loveUntil = now() + 3 }
    func dance() { danceUntil = now() + 6 }

    func pose(look: CGVector) -> Pose {
        let t = now()
        if t > nextBlink { blinkAt = t; nextBlink = t + 2.2 + Double.random(in: 0...3.5) }
        var p = Pose()
        p.look = look
        p.blink = t - blinkAt < 0.13

        if asleep {
            let b = CGFloat(sin(t * 1.2 + phase))
            p.sy = 1 + 0.05 * b
            p.sx = 1 - 0.02 * b
            p.rot = 0.04 * b
            p.expression = .asleep
            p.zzz = true
        } else {
            switch mood {
            case .idle:
                let b = CGFloat(sin(t * 1.6 + phase))
                p.sx = 1 + 0.035 * b; p.sy = p.sx
                p.rot = 0.08 * CGFloat(sin(t * 0.5 + phase))
            case .working:
                p.rot = CGFloat(t * 1.4 + phase)
                p.sx = 1 + 0.04 * CGFloat(sin(t * 5 + phase)); p.sy = p.sx
                p.rayWiggle = true
                p.expression = .focused
                p.look = CGVector(dx: sin(t * 1.8), dy: -0.3)
            case .attention:
                let w = fmod(t + phase, 1.4)
                if w < 0.5 { p.dx = CGFloat(sin(w * 42) * 3.2 * (1 - w / 0.5)) }
                p.lift = 3 * CGFloat(abs(sin(t * 3)))
                p.sx = 1.05; p.sy = 1.05
                p.expression = .surprised
            }
        }

        let ce = t - celebrateAt
        if ce < 2.6 {
            let decay = CGFloat(exp(-ce * 1.1))
            let hop = CGFloat(abs(sin(ce * 6.5)))
            p.lift += hop * 22 * decay
            p.rayExtend += 0.35 * decay * hop
            p.sx *= 1 + 0.08 * decay; p.sy *= 1 + 0.08 * decay
            p.rot += CGFloat(2 * Double.pi * (1 - pow(1 - min(1, ce / 1.1), 3)))
            p.expression = .happy
            p.sparks = ce
        }
        if t < danceUntil {
            p.lift += CGFloat(abs(sin(t * 7))) * 8
            p.dx += CGFloat(sin(t * 3.5)) * 6
            p.rot += CGFloat(sin(t * 7)) * 0.35
            p.expression = .happy
        }
        if t < loveUntil { p.expression = .love }

        let pe = t - petAt
        if pe < 0.6 {
            let d = CGFloat(1 - pe / 0.6) * CGFloat(abs(cos(pe * 14)))
            p.sy *= 1 - 0.16 * d
            p.sx *= 1 + 0.12 * d
            p.expression = .blush
        }
        if t < chompUntil { p.expression = .chomp; p.mouth = CGFloat(abs(sin(t * 16))) }
        if t < grumpyUntil {
            p.expression = .grumpy
            if grumpyUntil - t > 1.7 { p.dx += CGFloat(sin(t * 60)) * 1.5 }
        }
        let se = t - surprisedAt
        if se < 1.2 {
            p.expression = .surprised
            p.lift += CGFloat(max(0, sin(se * 5))) * 26 * CGFloat(exp(-se * 2))
            p.rayExtend += 0.4 * CGFloat(exp(-se * 3))
        }
        if t < dizzyUntil {
            p.expression = .dizzy
            p.rot += CGFloat(sin(t * 3)) * 0.6
            p.dx += CGFloat(sin(t * 4)) * 4
        }
        if dragging {
            p.expression = .whee
            p.rayExtend = 1.15
            p.rot += CGFloat(sin(t * 8)) * 0.3
        }
        applyPersonality(&p, t: t)
        if t < talkUntil && [.normal, .focused, .angry, .devil, .sick].contains(p.expression) {
            p.mouth = CGFloat(abs(sin(t * 22))) * 0.8
        }
        return p
    }

    private func applyPersonality(_ p: inout Pose, t: Double) {
        // Little idle routines (only when nothing else is going on)
        if let a = idleAnim, !asleep, mood == .idle, p.expression == .normal, !devil, !sick {
            let e = t - idleAt
            let len = idleLength(a)
            if e < len {
                let k = e / len
                switch a {
                case .yawn:
                    p.expression = .yawn
                    p.sy *= 1 + 0.14 * CGFloat(sin(k * .pi)); p.sx *= 1 - 0.05 * CGFloat(sin(k * .pi))
                case .lookAround:
                    p.look = CGVector(dx: sin(e * 2.2), dy: 0.2 * cos(e * 1.3))
                case .juggle:
                    p.prop = .juggle; p.propT = e; p.look = CGVector(dx: 0, dy: 1)
                case .whistle:
                    p.prop = .notes; p.propT = e; p.expression = .whistle
                case .sneeze:
                    if e < 1.1 { p.expression = .scrunch; p.sy *= 1 + 0.12 * CGFloat(e / 1.1) } else {
                        p.prop = .sneeze; p.propT = e - 1.1; p.expression = .scrunch
                        p.dx += CGFloat(exp(-(e - 1.1) * 8)) * 7
                    }
                case .spin:
                    p.rot += CGFloat(2 * Double.pi * (1 - pow(1 - k, 3)))
                    p.expression = .happy
                case .hop:
                    p.lift += CGFloat(abs(sin(k * 2 * .pi))) * 9
                    p.expression = .happy
                case .read:
                    p.prop = .book; p.propT = e; p.look = CGVector(dx: 0, dy: -1)
                case .coffee:
                    p.prop = .coffee; p.propT = e; p.expression = e.truncatingRemainder(dividingBy: 1.6) < 0.8 ? .blush : .normal
                case .wave:
                    p.prop = .wave; p.propT = e; p.expression = .happy
                    p.rot += CGFloat(sin(e * 12)) * 0.12
                }
            }
        }

        if sick && !devil {
            p.sick = 1
            if [.normal, .focused, .blush, .happy].contains(p.expression) { p.expression = .sick }
            p.dx += CGFloat(sin(t * 2.1)) * 1.5
            p.rot += CGFloat(sin(t * 1.7)) * 0.08
        }
        if t - barfAt < 2.5 { p.prop = .barf; p.propT = t - barfAt }

        if !devil && anger > 35 && [.normal, .focused, .blush, .whistle, .yawn].contains(p.expression) {
            p.expression = anger > 70 ? .furious : .angry
        }
        if !devil && anger > 35 {
            p.steam = CGFloat(min(1, (anger - 35) / 65))
            if anger > 70 { p.dx += CGFloat(sin(t * 55)) * 1.3 }
        }

        let se = t - scaredAt
        if se < 1.1 {
            p.expression = .scared
            p.lift += CGFloat(max(0, sin(se * 6))) * 20 * CGFloat(exp(-se * 2.5))
            p.rayExtend += 0.45 * CGFloat(exp(-se * 2))
        }
        if squish > 0.01 {
            p.sy *= 1 - 0.42 * squish
            p.sx *= 1 + 0.32 * squish
            p.expression = .scrunch
        }
        if flying {
            p.expression = fmod(t, 0.6) < 0.3 ? .scared : .whee
            p.rot += CGFloat(t * 12)
        }
        if devil {
            p.skinOverride = "devil"
            p.hatOverride = "horns"
            p.expression = .devil
            p.steam = 0
            p.lift += 4 + 3 * CGFloat(sin(t * 3))
            p.rayWiggle = true
        }
    }
}

// MARK: - Drawing

enum Renderer {
    static func rayColor(_ skin: String, _ i: Int, _ t: Double) -> NSColor {
        switch skin {
        case "sky": return friendBlue
        case "mint": return rgb(0x3FBF94)
        case "grape": return rgb(0x9466DB)
        case "midnight": return rgb(0x6E8EF0)
        case "gold": return sin(t * 3 - Double(i) * 0.6) > 0.6 ? rgb(0xFBE28A) : rgb(0xE3A92B)
        case "rainbow":
            return NSColor(hue: CGFloat(fmod(Double(i) / 12 + t * 0.15, 1)), saturation: 0.62, brightness: 0.95, alpha: 1)
        case "ghost": return NSColor(white: 1, alpha: 0.55)
        case "devil": return sin(t * 9 + Double(i) * 1.7) > 0.2 ? rgb(0xF2862E) : rgb(0xE0402A)
        case "slime": return rgb(0x7BD35B)
        default: return claudeOrange
        }
    }

    /// Mixes in sickly green and angry red on top of the skin colour.
    static func tint(_ c: NSColor, _ p: Pose) -> NSColor {
        var out = c
        if p.sick > 0 { out = out.blended(withFraction: 0.55 * p.sick, of: rgb(0x8BC34A)) ?? out }
        if p.steam > 0 { out = out.blended(withFraction: 0.35 * p.steam, of: rgb(0xE53935)) ?? out }
        return out
    }

    static func bodyColor(_ skin: String, _ t: Double) -> NSColor {
        switch skin {
        case "midnight": return rgb(0x273463)
        case "rainbow": return NSColor(hue: CGFloat(fmod(t * 0.15, 1)), saturation: 0.55, brightness: 0.95, alpha: 1)
        case "ghost": return NSColor(white: 0.97, alpha: 0.9)
        case "devil": return rgb(0xC8302B)
        case "slime": return rgb(0x6CC24A, 0.95)
        default: return rayColor(skin, 0, t)
        }
    }

    static func faceInk(_ skin: String) -> NSColor { skin == "midnight" ? rgb(0xE8EEFF) : faceColor }

    /// Draws a buddy whose resting body centre is `c`, at `s` times its natural size.
    static func draw(skin: String, hat: String, pose p: Pose, at c: NSPoint, scale s: CGFloat, shadow: Bool = true) {
        let t = now()
        let skin = p.skinOverride ?? skin
        let hat = p.hatOverride ?? hat
        var lift = p.lift
        if skin == "ghost" && !p.lying { lift += 4 + 3 * CGFloat(sin(t * 2)) }

        if shadow && !p.lying {
            let sw = 46 * s * max(0.3, 1 - lift / 45)
            NSColor(white: 0, alpha: 0.2 * max(0.2, 1 - lift / 60)).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x + p.dx * s - sw / 2, y: c.y - 36 * s, width: sw, height: 7 * s)).fill()
        }

        NSGraphicsContext.saveGraphicsState()
        let base = NSAffineTransform()
        base.translateX(by: c.x + p.dx * s, yBy: c.y + lift * s)
        base.scale(by: s)
        if p.lying { base.rotate(byDegrees: 90) }
        base.concat()

        if let ce = p.sparks, ce < 1.3 {
            let a = CGFloat(1 - ce / 1.3)
            for k in 0..<8 {
                let ang = Double(k) * .pi / 4 + 0.3
                let d = CGFloat(26 + ce * 46)
                (k % 2 == 0 ? sparkYellow : rayColor(skin, k, t)).withAlphaComponent(a).setFill()
                sparkle(at: NSPoint(x: CGFloat(cos(ang)) * d, y: CGFloat(sin(ang)) * d), size: 4.5 * a + 1.5)
            }
        }

        if skin == "midnight" {
            rgb(0x6E8EF0, 0.18 + 0.08 * CGFloat(sin(t * 2))).setFill()
            NSBezierPath(ovalIn: NSRect(x: -36, y: -36, width: 72, height: 72)).fill()
        }
        if skin == "devil" {
            rgb(0xFF5A1F, 0.22 + 0.1 * CGFloat(sin(t * 7))).setFill()
            NSBezierPath(ovalIn: NSRect(x: -38, y: -38, width: 76, height: 76)).fill()
            // Pointy tail swishing behind
            let sway = CGFloat(sin(t * 4)) * 6
            let tail = NSBezierPath()
            tail.lineWidth = 3; tail.lineCapStyle = .round
            tail.move(to: NSPoint(x: 8, y: -12))
            tail.curve(to: NSPoint(x: 34, y: -18 + sway), controlPoint1: NSPoint(x: 20, y: -30), controlPoint2: NSPoint(x: 30, y: -30 + sway))
            rgb(0x9E1F1B).setStroke(); tail.stroke()
            let tip = NSBezierPath()
            tip.move(to: NSPoint(x: 34, y: -12 + sway)); tip.line(to: NSPoint(x: 40, y: -20 + sway)); tip.line(to: NSPoint(x: 30, y: -22 + sway)); tip.close()
            rgb(0x9E1F1B).setFill(); tip.fill()
        }

        // Rays and body
        NSGraphicsContext.saveGraphicsState()
        let spin = NSAffineTransform()
        spin.rotate(byRadians: p.rot)
        spin.scaleX(by: p.sx, yBy: p.sy)
        spin.concat()
        let lens: [CGFloat] = [1.0, 0.74, 0.9, 0.8, 0.97, 0.7, 0.93, 0.78, 1.0, 0.72, 0.88, 0.82]
        let rayScale: CGFloat = skin == "ghost" ? 0.8 : 1
        for i in 0..<12 {
            let ang = CGFloat(i) * .pi / 6
            var len = 30 * lens[i] * p.rayExtend * rayScale
            if p.rayWiggle { len *= 1 + 0.13 * CGFloat(sin(t * 6 - Double(i) * 0.52)) }
            if skin == "devil" { len *= 1 + 0.16 * CGFloat(sin(t * 14 + Double(i) * 1.3)) }
            tint(rayColor(skin, i, t), p).setStroke()
            let ray = NSBezierPath()
            ray.lineWidth = 6.5
            ray.lineCapStyle = .round
            ray.move(to: NSPoint(x: cos(ang) * 10, y: sin(ang) * 10))
            ray.line(to: NSPoint(x: cos(ang) * len, y: sin(ang) * len))
            ray.stroke()
        }
        tint(bodyColor(skin, t), p).setFill()
        NSBezierPath(ovalIn: NSRect(x: -15.5, y: -15.5, width: 31, height: 31)).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Face and hat stay upright (just squash with the body)
        let squash = NSAffineTransform()
        squash.scaleX(by: p.sx, yBy: p.sy)
        NSGraphicsContext.saveGraphicsState()
        squash.concat()
        face(p, ink: faceInk(skin))
        drawHat(hat, t: t)
        NSGraphicsContext.restoreGraphicsState()

        if let prop = p.prop { drawProp(prop, e: p.propT, t: t) }
        if p.steam > 0.02 { drawSteam(p.steam, t: t) }

        NSGraphicsContext.restoreGraphicsState()

        if p.zzz { zzz(at: NSPoint(x: c.x + (p.lying ? -6 : 14) * s, y: c.y + (p.lying ? 12 : 18) * s), scale: s, t: t) }
    }

    // MARK: Face

    private static func face(_ p: Pose, ink: NSColor) {
        ink.setFill(); ink.setStroke()
        let lx = p.look.dx * 2.2, ly = p.look.dy * 1.6
        func eyes(w: CGFloat, h: CGFloat) {
            for sx in [-1.0, 1.0] as [CGFloat] {
                NSBezierPath(ovalIn: NSRect(x: sx * 5.5 + lx - w / 2, y: 2.5 + ly - h / 2, width: w, height: h)).fill()
            }
        }
        func happyEyes() {
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath()
                e.lineWidth = 2.2; e.lineCapStyle = .round; e.lineJoinStyle = .round
                e.move(to: NSPoint(x: sx * 5.5 - 3, y: 1))
                e.line(to: NSPoint(x: sx * 5.5, y: 4.5))
                e.line(to: NSPoint(x: sx * 5.5 + 3, y: 1))
                e.stroke()
            }
        }
        func grin(open: CGFloat = 0) {
            let m = NSBezierPath()
            m.appendArc(withCenter: NSPoint(x: 0, y: -3), radius: 5 + open, startAngle: 190, endAngle: 350)
            m.close(); m.fill()
        }
        func cheeks() {
            rgb(0xFF7FA0, 0.6).setFill()
            for sx in [-1.0, 1.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: sx * 9.5 - 3, y: -4.5, width: 6, height: 3.5)).fill() }
            ink.setFill()
        }
        func smile(talk: CGFloat) {
            if talk > 0.1 {
                NSBezierPath(ovalIn: NSRect(x: -2.5 + lx * 0.5, y: -6.5, width: 5, height: 1.5 + talk * 4)).fill()
            } else {
                let m = NSBezierPath()
                m.lineWidth = 1.8; m.lineCapStyle = .round
                m.appendArc(withCenter: NSPoint(x: lx * 0.5, y: -2.5), radius: 3.5, startAngle: 205, endAngle: 335)
                m.stroke()
            }
        }

        switch p.expression {
        case .normal:
            eyes(w: 2.8, h: p.blink ? 0.6 : 4)
            smile(talk: p.mouth)
        case .focused:
            eyes(w: 2.8, h: p.blink ? 0.6 : 2.6)
            if p.mouth > 0.1 { smile(talk: p.mouth) } else {
                let m = NSBezierPath(); m.lineWidth = 1.6; m.lineCapStyle = .round
                m.move(to: NSPoint(x: -2, y: -5)); m.line(to: NSPoint(x: 2, y: -5)); m.stroke()
            }
        case .happy:
            happyEyes(); grin()
        case .blush:
            happyEyes(); cheeks(); smile(talk: 0)
        case .whee:
            happyEyes(); cheeks()
            NSBezierPath(ovalIn: NSRect(x: -3.5, y: -9, width: 7, height: 7)).fill()
        case .love:
            rgb(0xE5395B).setFill()
            for sx in [-1.0, 1.0] as [CGFloat] { heart(at: NSPoint(x: sx * 5.8, y: 2.5), size: 4.2) }
            ink.setFill(); cheeks(); grin()
        case .surprised:
            eyes(w: 3.4, h: p.blink ? 0.8 : 5)
            NSBezierPath(ovalIn: NSRect(x: -2.2, y: -8, width: 4.4, height: 4.4)).fill()
        case .asleep:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath(); e.lineWidth = 1.8; e.lineCapStyle = .round
                e.appendArc(withCenter: NSPoint(x: sx * 5.5, y: 3.5), radius: 2.6, startAngle: 200, endAngle: 340)
                e.stroke()
            }
            let b = CGFloat(1 + sin(now() * 1.2)) * 0.6
            NSBezierPath(ovalIn: NSRect(x: -1.6, y: -6.5, width: 3.2, height: 2 + b)).fill()
        case .grumpy:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath(); e.lineWidth = 2; e.lineCapStyle = .round
                e.move(to: NSPoint(x: sx * 5.5 - 2.6, y: 2 + sx * 0.8)); e.line(to: NSPoint(x: sx * 5.5 + 2.6, y: 2 - sx * 0.8))
                e.stroke()
            }
            let m = NSBezierPath(); m.lineWidth = 1.8; m.lineCapStyle = .round
            m.appendArc(withCenter: NSPoint(x: 0, y: -9), radius: 3.5, startAngle: 30, endAngle: 150)
            m.stroke()
        case .dizzy:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let sp = NSBezierPath(); sp.lineWidth = 1.3
                let spin = now() * 6 * Double(sx)
                for k in 0...24 {
                    let a = Double(k) / 24 * 4 * .pi + spin
                    let r = CGFloat(k) / 24 * 3.4
                    let pt = NSPoint(x: sx * 5.5 + r * CGFloat(cos(a)), y: 2.5 + r * CGFloat(sin(a)))
                    k == 0 ? sp.move(to: pt) : sp.line(to: pt)
                }
                sp.stroke()
            }
            let m = NSBezierPath(); m.lineWidth = 1.6; m.lineCapStyle = .round
            m.move(to: NSPoint(x: -4, y: -5))
            m.curve(to: NSPoint(x: 0, y: -5), controlPoint1: NSPoint(x: -3, y: -3), controlPoint2: NSPoint(x: -1, y: -7))
            m.curve(to: NSPoint(x: 4, y: -5), controlPoint1: NSPoint(x: 1, y: -3), controlPoint2: NSPoint(x: 3, y: -7))
            m.stroke()
        case .chomp:
            happyEyes()
            NSBezierPath(ovalIn: NSRect(x: -3.5, y: -8, width: 7, height: 1.5 + p.mouth * 6)).fill()
            cheeks()
        case .angry, .furious:
            let furious = p.expression == .furious
            eyes(w: 2.8, h: furious ? 2.2 : 3.4)
            for sx in [-1.0, 1.0] as [CGFloat] {
                let brow = NSBezierPath(); brow.lineWidth = 2; brow.lineCapStyle = .round
                brow.move(to: NSPoint(x: sx * 9, y: furious ? 8.5 : 7.5)); brow.line(to: NSPoint(x: sx * 2.5, y: furious ? 4.8 : 5.8))
                brow.stroke()
            }
            if furious {
                NSColor.white.setFill()
                let teeth = NSRect(x: -4.5, y: -8, width: 9, height: 4)
                NSBezierPath(roundedRect: teeth, xRadius: 1, yRadius: 1).fill()
                ink.setStroke()
                let g = NSBezierPath(roundedRect: teeth, xRadius: 1, yRadius: 1); g.lineWidth = 1; g.stroke()
                for x in [-1.5, 1.5] as [CGFloat] { let l = NSBezierPath(); l.lineWidth = 0.8; l.move(to: NSPoint(x: x, y: -8)); l.line(to: NSPoint(x: x, y: -4)); l.stroke() }
                ink.setFill()
            } else {
                let m = NSBezierPath(); m.lineWidth = 1.8; m.lineCapStyle = .round
                m.appendArc(withCenter: NSPoint(x: 0, y: -8.5), radius: 3.2, startAngle: 35, endAngle: 145)
                m.stroke()
            }
        case .devil:
            rgb(0xFFE45C).setFill()
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath()
                e.move(to: NSPoint(x: sx * 2.5, y: 1)); e.line(to: NSPoint(x: sx * 8.5, y: 5)); e.line(to: NSPoint(x: sx * 7.5, y: 0.5)); e.close()
                e.fill()
            }
            ink.setFill()
            let grin = NSBezierPath()
            grin.move(to: NSPoint(x: -7, y: -3))
            grin.curve(to: NSPoint(x: 7, y: -3), controlPoint1: NSPoint(x: -4, y: -11), controlPoint2: NSPoint(x: 4, y: -11))
            grin.close(); grin.fill()
            NSColor.white.setFill()
            for sx in [-1.0, 1.0] as [CGFloat] {
                let fang = NSBezierPath()
                fang.move(to: NSPoint(x: sx * 4.5, y: -4)); fang.line(to: NSPoint(x: sx * 2.5, y: -4)); fang.line(to: NSPoint(x: sx * 3.5, y: -7)); fang.close()
                fang.fill()
            }
            ink.setFill()
        case .sick:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let lid = NSBezierPath(); lid.lineWidth = 1.6; lid.lineCapStyle = .round
                lid.move(to: NSPoint(x: sx * 5.5 - 3, y: 3.5)); lid.line(to: NSPoint(x: sx * 5.5 + 3, y: 3.5)); lid.stroke()
                NSBezierPath(ovalIn: NSRect(x: sx * 5.5 - 1.4, y: 0.6, width: 2.8, height: 2.6)).fill()
            }
            let m = NSBezierPath(); m.lineWidth = 1.6; m.lineCapStyle = .round
            m.move(to: NSPoint(x: -5, y: -6))
            for k in 1...4 { m.line(to: NSPoint(x: -5 + CGFloat(k) * 2.5, y: k % 2 == 0 ? -6 : -4.6)) }
            m.stroke()
            rgb(0x7FB3FF).setFill()
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: 11, y: 12)); drop.curve(to: NSPoint(x: 11, y: 5), controlPoint1: NSPoint(x: 7, y: 7), controlPoint2: NSPoint(x: 8, y: 5))
            drop.curve(to: NSPoint(x: 11, y: 12), controlPoint1: NSPoint(x: 14, y: 5), controlPoint2: NSPoint(x: 15, y: 7))
            drop.fill()
            ink.setFill()
        case .scared:
            NSColor.white.setFill()
            for sx in [-1.0, 1.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: sx * 5.8 - 3.2, y: -0.8, width: 6.4, height: 7.4)).fill() }
            ink.setFill()
            for sx in [-1.0, 1.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: sx * 5.8 - 1, y: 1.8, width: 2, height: 2)).fill() }
            NSBezierPath(ovalIn: NSRect(x: -2.6, y: -10, width: 5.2, height: 6.5)).fill()
        case .scrunch:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath(); e.lineWidth = 2; e.lineCapStyle = .round; e.lineJoinStyle = .round
                e.move(to: NSPoint(x: sx * 7.8, y: 4.5)); e.line(to: NSPoint(x: sx * 3.6, y: 2.5)); e.line(to: NSPoint(x: sx * 7.8, y: 0.5))
                e.stroke()
            }
            let m = NSBezierPath(); m.lineWidth = 1.8; m.lineCapStyle = .round
            m.move(to: NSPoint(x: -2.5, y: -5.5)); m.line(to: NSPoint(x: 2.5, y: -5.5)); m.stroke()
        case .yawn:
            for sx in [-1.0, 1.0] as [CGFloat] {
                let e = NSBezierPath(); e.lineWidth = 1.8; e.lineCapStyle = .round
                e.move(to: NSPoint(x: sx * 5.5 - 2.6, y: 3)); e.line(to: NSPoint(x: sx * 5.5 + 2.6, y: 3)); e.stroke()
            }
            NSBezierPath(ovalIn: NSRect(x: -3.5, y: -10, width: 7, height: 8)).fill()
        case .whistle:
            eyes(w: 2.8, h: p.blink ? 0.6 : 4)
            let m = NSBezierPath(ovalIn: NSRect(x: 0.5, y: -6.5, width: 3.6, height: 3.6)); m.lineWidth = 1.6; m.stroke()
            cheeks()
        }
    }

    // MARK: Props and steam (drawn in body coordinates)

    private static func emoji(_ s: String, at p: NSPoint, size: CGFloat, alpha: CGFloat = 1) {
        let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size)])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)
        a.draw(at: NSPoint(x: p.x - size * 0.6, y: p.y - size * 0.6))
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawProp(_ prop: Prop, e: Double, t: Double) {
        switch prop {
        case .juggle:
            let colors: [UInt32] = [0xE5395B, 0x3F7FE0, 0xF2C94C]
            for k in 0..<3 {
                let ph = e * 4.2 + Double(k) * 2.1
                let x = CGFloat(cos(ph)) * 16
                let y = 34 + CGFloat(abs(sin(ph))) * 18
                rgb(colors[k]).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)).fill()
            }
        case .notes:
            for k in 0..<3 {
                let ph = CGFloat(fmod(e * 0.9 + Double(k) / 3, 1))
                emoji(k % 2 == 0 ? "♪" : "♫", at: NSPoint(x: 14 + ph * 16, y: 6 + ph * 28 + CGFloat(sin(e * 5 + Double(k))) * 3), size: 12, alpha: 1 - ph)
            }
        case .book:
            rgb(0x3F7FE0).setFill()
            NSBezierPath(roundedRect: NSRect(x: -13, y: -22, width: 12, height: 15), xRadius: 1.5, yRadius: 1.5).fill()
            rgb(0xE5395B).setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: -22, width: 12, height: 15), xRadius: 1.5, yRadius: 1.5).fill()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: -1.2, y: -22, width: 2.4, height: 15)).fill()
        case .coffee:
            emoji("☕️", at: NSPoint(x: 20, y: -6 + CGFloat(sin(e * 1.6)) * 4), size: 14)
        case .sneeze:
            emoji("💨", at: NSPoint(x: -26 - CGFloat(e) * 30, y: 0), size: 14, alpha: CGFloat(max(0, 1 - e / 0.7)))
        case .wave:
            emoji("👋", at: NSPoint(x: 26, y: 12 + CGFloat(sin(e * 12)) * 3), size: 14)
        case .barf:
            let a = CGFloat(max(0, 1 - e / 2.5))
            rgb(0x8BC34A, 0.85 * a).setFill()
            let w = CGFloat(min(1, e / 0.3)) * 22
            NSBezierPath(ovalIn: NSRect(x: 6, y: -36, width: w, height: 6)).fill()
            if e < 0.4 {
                for k in 0..<4 {
                    NSBezierPath(ovalIn: NSRect(x: 2 + CGFloat(k) * 4, y: -8 - CGFloat(e) * 60 + CGFloat(k), width: 3.5, height: 3.5)).fill()
                }
            }
        }
    }

    private static func drawSteam(_ s: CGFloat, t: Double) {
        for side in [-1.0, 1.0] as [CGFloat] {
            for k in 0..<2 {
                let ph = CGFloat(fmod(t * 1.6 + Double(k) * 0.5 + (side > 0 ? 0.25 : 0), 1))
                NSColor(white: 1, alpha: 0.85 * s * (1 - ph)).setFill()
                let r = 3 + ph * 5 * s
                NSBezierPath(ovalIn: NSRect(x: side * (20 + ph * 8) - r, y: 14 + ph * 18 - r, width: 2 * r, height: 2 * r)).fill()
            }
        }
    }

    static func heart(at p: NSPoint, size s: CGFloat) {
        let h = NSBezierPath()
        h.move(to: NSPoint(x: p.x, y: p.y - s * 0.9))
        h.curve(to: NSPoint(x: p.x, y: p.y + s * 0.35), controlPoint1: NSPoint(x: p.x - s * 1.3, y: p.y - s * 0.1), controlPoint2: NSPoint(x: p.x - s * 0.6, y: p.y + s * 1.1))
        h.curve(to: NSPoint(x: p.x, y: p.y - s * 0.9), controlPoint1: NSPoint(x: p.x + s * 0.6, y: p.y + s * 1.1), controlPoint2: NSPoint(x: p.x + s * 1.3, y: p.y - s * 0.1))
        h.fill()
    }

    static func sparkle(at p: NSPoint, size s: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: p.x, y: p.y + s))
        path.curve(to: NSPoint(x: p.x + s, y: p.y), controlPoint1: p, controlPoint2: p)
        path.curve(to: NSPoint(x: p.x, y: p.y - s), controlPoint1: p, controlPoint2: p)
        path.curve(to: NSPoint(x: p.x - s, y: p.y), controlPoint1: p, controlPoint2: p)
        path.curve(to: NSPoint(x: p.x, y: p.y + s), controlPoint1: p, controlPoint2: p)
        path.fill()
    }

    private static func zzz(at p: NSPoint, scale s: CGFloat, t: Double) {
        for k in 0..<3 {
            let ph = CGFloat(fmod(t * 0.5 + Double(k) / 3, 1))
            let z = NSAttributedString(string: "z", attributes: [
                .font: NSFont.systemFont(ofSize: (8 + ph * 7) * s, weight: .heavy),
                .foregroundColor: NSColor(srgbRed: 0.55, green: 0.65, blue: 0.95, alpha: 1 - ph),
            ])
            z.draw(at: NSPoint(x: p.x + ph * 14 * s, y: p.y + ph * 26 * s))
        }
    }

    // MARK: Hats

    static func drawHat(_ hat: String, t: Double) {
        switch hat {
        case "party":
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: -10, y: 10)); cone.line(to: NSPoint(x: 10, y: 10)); cone.line(to: NSPoint(x: 2, y: 36)); cone.close()
            rgb(0xF06292).setFill(); cone.fill()
            NSGraphicsContext.saveGraphicsState()
            cone.addClip()
            sparkYellow.setFill()
            NSBezierPath(rect: NSRect(x: -12, y: 16, width: 24, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: -12, y: 24, width: 24, height: 3)).fill()
            NSGraphicsContext.restoreGraphicsState()
            sparkYellow.setFill()
            NSBezierPath(ovalIn: NSRect(x: -1.5, y: 33.5, width: 7, height: 7)).fill()
        case "beanie":
            let dome = NSBezierPath()
            dome.appendArc(withCenter: NSPoint(x: 0, y: 10), radius: 15.5, startAngle: 0, endAngle: 180)
            dome.close()
            rgb(0x2E8C9C).setFill(); dome.fill()
            rgb(0x1F6672).setFill()
            NSBezierPath(roundedRect: NSRect(x: -16.5, y: 7, width: 33, height: 7), xRadius: 3, yRadius: 3).fill()
            rgb(0xF2F2F2).setFill()
            NSBezierPath(ovalIn: NSRect(x: -4.5, y: 22.5, width: 9, height: 9)).fill()
        case "headphones":
            let band = NSBezierPath(); band.lineWidth = 3.5
            band.appendArc(withCenter: NSPoint(x: 0, y: 3), radius: 19, startAngle: 15, endAngle: 165)
            rgb(0x3A3A3A).setStroke(); band.stroke()
            for sx in [-1.0, 1.0] as [CGFloat] {
                rgb(0x444444).setFill()
                NSBezierPath(roundedRect: NSRect(x: sx * 19 - 4.5, y: -5, width: 9, height: 15), xRadius: 4, yRadius: 4).fill()
                rgb(0xE53935).setFill()
                NSBezierPath(roundedRect: NSRect(x: sx * 19 - 2, y: -2, width: 4, height: 9), xRadius: 2, yRadius: 2).fill()
            }
        case "wizard":
            rgb(0x5B3FA8).setFill()
            NSBezierPath(ovalIn: NSRect(x: -21, y: 7, width: 42, height: 9)).fill()
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: -12, y: 11))
            cone.curve(to: NSPoint(x: 9, y: 46), controlPoint1: NSPoint(x: -8, y: 30), controlPoint2: NSPoint(x: 0, y: 40))
            cone.curve(to: NSPoint(x: 12, y: 11), controlPoint1: NSPoint(x: 6, y: 36), controlPoint2: NSPoint(x: 10, y: 24))
            cone.close(); cone.fill()
            sparkYellow.setFill()
            sparkle(at: NSPoint(x: -3, y: 21), size: 3)
            sparkle(at: NSPoint(x: 4, y: 31), size: 2.4)
        case "crown":
            let c = NSBezierPath()
            c.move(to: NSPoint(x: -13, y: 10)); c.line(to: NSPoint(x: 13, y: 10)); c.line(to: NSPoint(x: 14, y: 25))
            c.line(to: NSPoint(x: 7, y: 18)); c.line(to: NSPoint(x: 0, y: 28)); c.line(to: NSPoint(x: -7, y: 18))
            c.line(to: NSPoint(x: -14, y: 25)); c.close()
            rgb(0xF2C94C).setFill(); c.fill()
            rgb(0xC99A22).setStroke(); c.lineWidth = 1; c.stroke()
            rgb(0xE53935).setFill(); NSBezierPath(ovalIn: NSRect(x: -2, y: 12, width: 4, height: 4)).fill()
            rgb(0x3F7FE0).setFill()
            for x in [-8.0, 8.0] as [CGFloat] { NSBezierPath(ovalIn: NSRect(x: x - 1.6, y: 12.4, width: 3.2, height: 3.2)).fill() }
        case "propeller":
            let dome = NSBezierPath()
            dome.appendArc(withCenter: NSPoint(x: 0, y: 10), radius: 14, startAngle: 0, endAngle: 180)
            dome.close()
            rgb(0xE53935).setFill(); dome.fill()
            rgb(0x3F7FE0).setFill(); NSBezierPath(rect: NSRect(x: -14, y: 9, width: 28, height: 3)).fill()
            rgb(0x555555).setFill(); NSBezierPath(rect: NSRect(x: -1, y: 23, width: 2, height: 5)).fill()
            let w = CGFloat(abs(cos(t * 18))) * 15 + 2
            sparkYellow.setFill(); NSBezierPath(ovalIn: NSRect(x: -w, y: 26.5, width: w, height: 4)).fill()
            rgb(0x3F7FE0).setFill(); NSBezierPath(ovalIn: NSRect(x: 0, y: 26.5, width: w, height: 4)).fill()
        case "chef":
            NSColor.white.setFill(); rgb(0xD8D8D8).setStroke()
            let puffs = NSBezierPath()
            puffs.appendOval(in: NSRect(x: -15, y: 17, width: 14, height: 14))
            puffs.appendOval(in: NSRect(x: -8, y: 21, width: 16, height: 16))
            puffs.appendOval(in: NSRect(x: 1, y: 17, width: 14, height: 14))
            puffs.lineWidth = 1; puffs.stroke(); puffs.fill()
            let band = NSBezierPath(roundedRect: NSRect(x: -11, y: 9, width: 22, height: 12), xRadius: 2, yRadius: 2)
            band.fill(); band.lineWidth = 1; band.stroke()
        case "nightcap":
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: -14, y: 11))
            cap.curve(to: NSPoint(x: 10, y: 32), controlPoint1: NSPoint(x: -13, y: 28), controlPoint2: NSPoint(x: 0, y: 34))
            cap.curve(to: NSPoint(x: 23, y: 17), controlPoint1: NSPoint(x: 18, y: 31), controlPoint2: NSPoint(x: 22, y: 25))
            cap.curve(to: NSPoint(x: 14, y: 11), controlPoint1: NSPoint(x: 18, y: 22), controlPoint2: NSPoint(x: 15, y: 18))
            cap.close()
            rgb(0x3F51B5).setFill(); cap.fill()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: -15.5, y: 7.5, width: 31, height: 6), xRadius: 3, yRadius: 3).fill()
            NSBezierPath(ovalIn: NSRect(x: 19.5, y: 11, width: 8, height: 8)).fill()
        case "horns":
            rgb(0x7A1512).setFill()
            for sx in [-1.0, 1.0] as [CGFloat] {
                let h = NSBezierPath()
                h.move(to: NSPoint(x: sx * 6, y: 11))
                h.curve(to: NSPoint(x: sx * 15, y: 26), controlPoint1: NSPoint(x: sx * 7, y: 20), controlPoint2: NSPoint(x: sx * 11, y: 24))
                h.curve(to: NSPoint(x: sx * 12, y: 9), controlPoint1: NSPoint(x: sx * 13, y: 18), controlPoint2: NSPoint(x: sx * 14, y: 12))
                h.close(); h.fill()
            }
        case "headband":
            rgb(0xE5395B).setFill()
            NSBezierPath(roundedRect: NSRect(x: -16, y: 6, width: 32, height: 6), xRadius: 3, yRadius: 3).fill()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: -16, y: 8, width: 32, height: 1.5)).fill()
            rgb(0xE5395B).setFill()
            let knot = NSBezierPath()
            knot.move(to: NSPoint(x: 15, y: 9)); knot.line(to: NSPoint(x: 24, y: 4 + CGFloat(sin(t * 5)) * 2)); knot.line(to: NSPoint(x: 22, y: 12)); knot.close()
            knot.fill()
        default:
            break
        }
    }
}
