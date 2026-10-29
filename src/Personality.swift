// Buddy's personality: idle routines and random thoughts, a temper (with a devil-mode
// tantrum that bombs the screen), cookie overload, and lots of ways to annoy him.

import AppKit

/// Mutable personality state (extensions can't add stored properties to AppDelegate).
final class Fun {
    static let shared = Fun()
    var lastTick = now()
    var nextIdle = now() + 25
    var pokeTimes: [Double] = []
    var lastPoke = -100.0
    var cookieTimes: [Double] = []
    var sickUntil = 0.0
    var nextQueasy = 0.0
    var raging = false
    let rage = RageShow()
    var flyVel: CGVector?
    var flyPos = NSPoint.zero
    var squishing = false
    var lastMouse = NSPoint.zero
    var tickleAccum: CGFloat = 0
    var tickleTime = 0.0
    var tickleNext = 0.0
    var stillSince = now()
    var lastStare = -200.0
}

private let thoughts = [
    "is a hotdog a sandwich? 🌭", "I wonder if bugs have feelings 🐞", "semicolons are just winking periods ;)",
    "I could really go for a cookie 🍪", "do you think Claude dreams in markdown?", "I just counted my rays. still 12.",
    "you're doing great btw ✨", "have you had water today? 💧", "it works on my machine 🤷", "naming things is hard",
    "bored… pet me? 👉👈", "bet I could beat you at Bug Catch", "git push --force? brave.", "*hums the dial-up sound*",
    "what if the cloud is just someone else's computer ☁️", "I'm 100% pixels and 0% calories",
]

private let jokes = [
    ["Why do programmers prefer dark mode?", "Because light attracts bugs. 🐛"],
    ["How many programmers does it take to change a light bulb?", "None. That's a hardware problem."],
    ["I told my code a joke…", "it didn't get it. no sense of humour, just syntax."],
    ["Why did the developer go broke?", "He used up all his cache. 💸"],
    ["A SQL query walks into a bar, sees two tables and asks…", "\"Can I JOIN you?\""],
]

extension AppDelegate {
    var buddy: Animator { corner.slots[0].anim }

    func setupPersonality() {
        Fun.shared.rage.onDefuse = { [weak self] in self?.progress.award(2) }
        Fun.shared.rage.onFinished = { [weak self] n in self?.endRage(defused: n) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.wake(0)
            self.buddy.startIdle(.wave)
            self.corner.say(0, title: ["you're back!! 👋", "welcome back!", "oh hi! I missed you 🥹"].randomElement()!, duration: 4)
        }
    }

    /// Puts buddy back in the corner and says hi (used when the app is reopened or he's lost).
    func comeBack() {
        Fun.shared.flyVel = nil
        buddy.flying = false
        resetPosition()
        wake(0)
        buddy.startIdle(.wave)
        Synth.shared.chirp()
        corner.say(0, title: ["here I am! 👋", "you called? 😊", "I'm right here!"].randomElement()!, duration: 4)
    }

    // MARK: Temper

    func annoy(_ amount: Double, quiet: Bool = false) {
        let f = Fun.shared
        guard !f.raging, !buddy.devil else { return }
        let before = buddy.anger
        buddy.anger = min(100, buddy.anger + amount)
        let a = buddy.anger
        if a >= 100 { rage(); return }
        guard !quiet else { return }
        if before < 70 && a >= 70 {
            Synth.shared.growl()
            corner.say(0, title: ["I'm warning you… 😡", "you're making me MAD", "grrrrr…", "one more time. I DARE you."].randomElement()!, duration: 3)
        } else if before < 35 && a >= 35 {
            corner.say(0, title: ["hey!! 😠", "cut it out!", "stoppp", "rude."].randomElement()!, duration: 2.5)
        }
    }

    func calm(_ amount: Double) { buddy.anger = max(0, buddy.anger - amount) }

    func rage() {
        let f = Fun.shared
        guard !f.raging else { return }
        f.raging = true
        wake(0)
        buddy.sick = false
        Synth.shared.growl()
        corner.say(0, title: "THAT'S IT!!! 😡", duration: 1.6, voice: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.buddy.devil = true
            Synth.shared.transform()
            self.corner.say(0, title: "MWAHAHAHA 😈", sub: "click the bombs to defuse them!", duration: 3, voice: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { Synth.shared.devilLaugh() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                let home = NSPoint(x: self.panel.frame.maxX - 46, y: self.panel.frame.minY + 44)
                f.rage.start(from: home)
            }
        }
    }

    private func endRage(defused: Int) {
        Fun.shared.raging = false
        buddy.devil = false
        buddy.anger = 0
        buddy.love()
        buddy.celebrate()
        Synth.shared.calmDown()
        corner.say(0, title: "phew… sorry about that 😇", sub: defused > 0 ? "you defused \(defused) bomb\(defused == 1 ? "" : "s")!" : "I feel much better now",
                   duration: 6, voice: false)
        progress.achieve("rage", unlocking: "devil")
        if defused >= 5 { progress.achieve("defuse", unlocking: "horns") }
    }

    // MARK: Pokes, cookies, sickness

    /// Returns true when the poke was fully handled here.
    func pokeMischief(_ i: Int) -> Bool {
        let f = Fun.shared
        if f.raging || buddy.devil { if i == 0 { Synth.shared.devilLaugh() }; return true }
        guard i == 0 else { return false }
        let t = now()
        if buddy.asleep { annoy(12, quiet: true); return false }
        f.pokeTimes = f.pokeTimes.filter { t - $0 < 2 } + [t]
        let gentle = t - f.lastPoke > 1.5
        f.lastPoke = t
        if f.pokeTimes.count >= 4 {
            annoy(9)
            buddy.grumpy()
            Synth.shared.grumble()
            return true
        }
        if gentle && buddy.anger > 0 { calm(6) }
        return false
    }

    /// Returns true if buddy refused the cookie.
    func refuseCookie() -> Bool {
        if Fun.shared.raging || buddy.devil { corner.say(0, title: "😈 NO.", duration: 2); return true }
        if buddy.sick {
            Synth.shared.burp()
            annoy(8, quiet: true)
            corner.say(0, title: ["no more cookies… 🤢", "please… no…", "I can't even look at it"].randomElement()!, duration: 3)
            return true
        }
        return false
    }

    func ateCookie() {
        let f = Fun.shared
        let t = now()
        f.cookieTimes = f.cookieTimes.filter { t - $0 < 600 } + [t]
        calm(10)
        switch f.cookieTimes.count {
        case 4: corner.say(0, title: "getting full… 😮‍💨", duration: 3)
        case 5: corner.say(0, title: "one more and I'll pop 🫃", duration: 3)
        case 6...: getSick()
        default: break
        }
    }

    func roomAteCookie() -> Bool {
        wake(0)
        let ok = progress.fedCookie()
        ateCookie()
        return ok
    }

    func getSick() {
        let f = Fun.shared
        buddy.sick = true
        f.sickUntil = now() + 180
        f.nextQueasy = now() + 6
        Synth.shared.burp()
        corner.say(0, title: "uh oh… I don't feel so good 🤢", sub: "right-click me → Give medicine", duration: 6)
        progress.achieve("sick", unlocking: "slime")
    }

    func giveMedicine() {
        guard buddy.sick else { corner.say(0, title: "I'm not sick! …but thanks 💊", duration: 3); return }
        buddy.sick = false
        Fun.shared.cookieTimes.removeAll()
        Synth.shared.heal()
        buddy.love()
        corner.say(0, title: "much better!! thank you 🥹", duration: 4)
    }

    func honk() {
        guard !Fun.shared.raging else { return }
        wake(0)
        Synth.shared.honk()
        buddy.scare()
        corner.say(0, title: ["AAH! 😱", "don't DO that!!", "my heart!! 💔"].randomElement()!, duration: 2.5)
        annoy(12, quiet: buddy.anger < 30)
    }

    func teaseCookie() {
        guard !Fun.shared.raging else { return }
        wake(0)
        buddy.love()
        corner.say(0, title: "a cookie?! for ME?? 🤩🍪", duration: 1.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
            guard let self else { return }
            Synth.shared.grumble()
            self.buddy.grumpy()
            self.corner.say(0, title: "…HEY! that's just mean 😤", duration: 3)
            self.annoy(22, quiet: true)
            self.progress.achieve("tease")
        }
    }

    // MARK: Flick physics, squish, tickle, staring, idle routines

    func flick(_ v: CGVector) {
        guard !Fun.shared.raging else { return }
        let f = Fun.shared
        f.flyVel = CGVector(dx: max(-3500, min(3500, v.dx)), dy: max(-3500, min(3500, v.dy)))
        f.flyPos = NSPoint(x: panel.frame.maxX - 46, y: panel.frame.minY + 44)
        buddy.flying = true
        wake(0)
        Synth.shared.whee()
    }

    func squishReleased(_ amount: CGFloat) {
        Synth.shared.boing()
        if amount > 0.6 {
            progress.achieve("squish")
            annoy(8, quiet: true)
            corner.say(0, title: "I'm not a stress ball!! 😤", duration: 2.5)
        }
    }

    private func flyStep(dt: CGFloat) {
        let f = Fun.shared
        guard var v = f.flyVel else { return }
        let vf = (panel.screen ?? NSScreen.main!).visibleFrame
        var p = f.flyPos
        v.dy -= 2600 * dt
        p.x += v.dx * dt
        p.y += v.dy * dt
        let minX = vf.minX + 34, maxX = vf.maxX - 34, minY = vf.minY + 40, maxY = vf.maxY - 36
        if p.x < minX { p.x = minX; v.dx = -v.dx * 0.6; Synth.shared.thud() }
        if p.x > maxX { p.x = maxX; v.dx = -v.dx * 0.6; Synth.shared.thud() }
        if p.y > maxY { p.y = maxY; v.dy = -v.dy * 0.6; Synth.shared.thud() }
        if p.y < minY {
            p.y = minY
            if abs(v.dy) > 260 { Synth.shared.thud() }
            v.dy = abs(v.dy) < 260 ? 0 : -v.dy * 0.5
            v.dx *= 0.82
        }
        f.flyPos = p
        panel.setFrameOrigin(NSPoint(x: p.x - (panel.frame.width - 46), y: p.y - 44))
        if p.y <= minY && v.dy == 0 && abs(v.dx) < 30 {
            f.flyVel = nil
            buddy.flying = false
            buddy.dizzy()
            UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: originKey)
            corner.say(0, title: ["WHEEE— oof. 😵‍💫", "did you just YEET me?!", "again! again!… no wait"].randomElement()!, duration: 3)
            progress.achieve("yeet")
            annoy(10, quiet: true)
        } else {
            f.flyVel = v
        }
    }

    func funTick() {
        let f = Fun.shared
        let t = now()
        let dt = CGFloat(min(0.05, t - f.lastTick))
        f.lastTick = t
        if !f.raging { buddy.anger = max(0, buddy.anger - Double(dt) * 2.2) }
        flyStep(dt: dt)

        // Squish while held down
        if let h = corner.holdIndex, h == 0 {
            buddy.squish = min(1, max(0, CGFloat(t - corner.holdStart - 0.25)))
        } else if buddy.squish > 0 {
            buddy.squish = max(0, buddy.squish - dt * 6)
        }

        // Tickle (wiggling the cursor over him) and staring (hovering very still)
        let m = NSEvent.mouseLocation
        let home = NSPoint(x: panel.frame.maxX - 46, y: panel.frame.minY + 44)
        let inside = hypot(m.x - home.x, m.y - home.y) < 34 && f.flyVel == nil
        let moved = hypot(m.x - f.lastMouse.x, m.y - f.lastMouse.y)
        f.lastMouse = m
        if inside { f.tickleAccum += moved }
        f.tickleAccum *= 0.97
        if moved > 1.5 || !inside { f.stillSince = t }
        if f.tickleAccum > 700 && !buddy.asleep && !f.raging {
            f.tickleTime += Double(dt)
            if t > f.tickleNext {
                f.tickleNext = t + 0.45
                buddy.pet()
                Synth.shared.giggle()
                if f.tickleTime > 3.5 {
                    annoy(6, quiet: true)
                    if Int.random(in: 0..<3) == 0 { corner.say(0, title: ["okay okay STOP 😂", "hahaha no— stop!!", "I can't breathe 🤣"].randomElement()!, duration: 1.5) }
                }
            }
            progress.achieve("tickle")
        } else if f.tickleAccum < 200 { f.tickleTime = 0 }
        if inside && t - f.stillSince > 2.8 && t - f.lastStare > 120 && !buddy.asleep {
            f.lastStare = t
            buddy.pet()
            corner.say(0, title: "um… why are you staring at me? 😳", duration: 3)
        }

        // Feeling sick
        if buddy.sick {
            if t > f.sickUntil {
                buddy.sick = false
                corner.say(0, title: "phew, feeling better 😌", duration: 3)
            } else if t > f.nextQueasy {
                f.nextQueasy = t + Double.random(in: 9...16)
                if Bool.random() {
                    Synth.shared.burp(); corner.say(0, title: "*burp* 🤢", duration: 2)
                } else {
                    buddy.barf(); Synth.shared.hurl(); corner.say(0, title: "hurk! 🤮", duration: 2)
                }
            }
        }

        // Idle routines and thoughts
        if t > f.nextIdle {
            f.nextIdle = t + Double.random(in: 18...48)
            guard buddy.mood == .idle, !buddy.asleep, !buddy.sick, !buddy.devil, buddy.anger < 35, corner.slots[0].present else { return }
            let hour = Calendar.current.component(.hour, from: Date())
            var options: [IdleAnim] = [.yawn, .lookAround, .juggle, .whistle, .sneeze, .spin, .hop, .read, .wave]
            if hour >= 6 && hour < 11 { options += [.coffee, .coffee] }
            let a = options.randomElement()!
            buddy.startIdle(a)
            switch a {
            case .whistle: Synth.shared.whistle()
            case .yawn: Synth.shared.yawn()
            case .sneeze: DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { Synth.shared.sneeze() }
            case .hop: Synth.shared.boing()
            default: break
            }
            if Int.random(in: 0..<3) == 0 {
                var pool = thoughts
                if hour >= 1 && hour < 5 { pool += ["it's late… go to bed? 🥱", "the bugs will still be there tomorrow"] }
                if Calendar.current.component(.weekday, from: Date()) == 6 { pool.append("it's FRIDAY!! 🎉") }
                corner.say(0, title: pool.randomElement()!, duration: 4.5)
            }
        }
    }

    // MARK: Console and menu

    func funCommand(_ cmd: String) -> [String]? {
        let insults = ["bad buddy", "stupid", "dumb", "ugly", "i hate you", "you suck", "idiot", "loser", "useless"]
        if insults.contains(where: { cmd.contains($0) }) {
            annoy(25)
            buddy.grumpy()
            Synth.shared.grumble()
            return [["RUDE. 😤", "excuse me?!", "I'm telling Claude.", "wow. okay. noted. 📝"].randomElement()!]
        }
        switch cmd {
        case "help", "?":
            return ["commands: help feed pet dance sleep wake stats wear <item>",
                    "  honk joke fortune sorry meds mood juggle whistle",
                    "  read sneeze yawn coffee wave flip copycat ls clear exit",
                    "(and a few secrets… 👀)"]
        case "sorry", "i'm sorry", "im sorry", "apologize":
            calm(45); buddy.love()
            return ["…okay. I forgive you 🥺"]
        case "honk": honk(); return ["📯 HONK"]
        case "meds", "medicine": giveMedicine(); return ["💊 here you go"]
        case "mood":
            let a = buddy.anger
            return [buddy.sick ? "feeling sick 🤢" : buddy.devil ? "😈😈😈" : a > 70 ? "FURIOUS 😡 (\(Int(a))/100)" : a > 35 ? "annoyed 😠 (\(Int(a))/100)" : "happy 😊 (\(Int(a))/100 grumpy)"]
        case "joke":
            let j = jokes.randomElement()!
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.buddy.celebrate(); Synth.shared.giggle() }
            return j
        case "fortune":
            return [["Your next build will pass on the first try. 🔮", "A wild bug appears… and you squash it.",
                     "You will mass-rename a variable and feel powerful.", "Today's lucky number: 404"].randomElement()!]
        case "rage", "tantrum", "devil": return ["nice try. you have to EARN it 😈"]
        case "flip", "tableflip":
            buddy.startIdle(.spin); Synth.shared.boing(); return ["(╯°□°)╯︵ ┻━┻"]
        case "juggle", "whistle", "read", "sneeze", "yawn", "coffee", "wave":
            let map: [String: IdleAnim] = ["juggle": .juggle, "whistle": .whistle, "read": .read, "sneeze": .sneeze, "yawn": .yawn, "coffee": .coffee, "wave": .wave]
            buddy.startIdle(map[cmd]!)
            if cmd == "whistle" { Synth.shared.whistle() }
            if cmd == "sneeze" { DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { Synth.shared.sneeze() } }
            return ["*\(cmd)s*"]
        case "copycat": roomView?.startCopycat(); return ["🎵 let's play!"]
        default: return nil
        }
    }

    func addFunItems(to menu: NSMenu) {
        menu.addItem(.separator())
        let a = buddy.anger
        let mood = buddy.sick ? "Mood: sick 🤢" : a > 70 ? "Mood: FURIOUS 😡" : a > 35 ? "Mood: annoyed 😠" : "Mood: happy 😊"
        menu.addItem(withTitle: mood, action: nil, keyEquivalent: "").isEnabled = false
        for (title, sel) in [("Honk at buddy 📯", #selector(honkMenu)), ("Tease with a cookie 😈", #selector(teaseMenu)),
                             ("Give medicine 💊", #selector(medicineMenu)), ("Play Copycat 🎵", #selector(copycatMenu))] {
            menu.addItem(withTitle: title, action: sel, keyEquivalent: "").target = self
        }
        let test = menu.addItem(withTitle: "Test: tantrum 😈", action: #selector(rageMenu), keyEquivalent: "")
        test.target = self
    }

    @objc func honkMenu() { honk() }
    @objc func teaseMenu() { teaseCookie() }
    @objc func medicineMenu() { giveMedicine() }
    @objc func rageMenu() { rage() }
    @objc func copycatMenu() {
        openRoom()
        roomView?.startCopycat()
    }
}
