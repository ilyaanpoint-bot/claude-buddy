// Claude Buddy — app entry: reads Claude Code hook events, runs the corner widget and the
// room window, and turns everything that happens into XP, coins, quests, unlocks and secrets.

import AppKit

struct Session {
    var mood: Mood
    var project: String
    var app: String
    var updated: Date
    var slot: Int
    var started: Date?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var corner: CornerView!
    var roomView: RoomView?
    var roomWindow: RoomWindow?
    let settings = SettingsController()
    var sessions: [String: Session] = [:]
    var lastApp = ""
    var offset: UInt64 = 0
    var partial = Data()
    var testFriendUntil = -100.0
    var sleepPokes = 0
    var lastPetXP = -100.0
    var frameCount = 0
    var hiddenUntil: Date?
    var focusStart = 0.0
    var focusEnd: Double?
    var focusMinutes = 0
    let size = NSSize(width: 320, height: 200)
    let originKey = "origin2"
    var progress: BuddyProgress { BuddyProgress.shared }
    var scale: CGFloat { Prefs.scale }

    /// Opening the app again (Launchpad, Spotlight, Dock, Finder) brings buddy back to the corner.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        comeBack()
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: buddyDir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }
        // Events written while buddy wasn't running are stale; start from a clean file if it got big.
        if fileSize() > 256_000 { try? Data().write(to: eventsURL) }
        offset = fileSize()   // only react to events from now on
        progress.migrate()

        let scaled = NSSize(width: size.width * scale, height: size.height * scale)
        var origin = defaultOrigin(scaled)
        if let saved = UserDefaults.standard.string(forKey: originKey) {
            let p = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.frame.contains(NSPoint(x: p.x + scaled.width / 2, y: p.y + scaled.height / 2)) }) { origin = p }
        }

        panel = NSPanel(contentRect: NSRect(origin: origin, size: scaled), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        corner = CornerView(frame: NSRect(origin: .zero, size: scaled))
        corner.setBoundsSize(size)
        corner.onPoke = { [weak self] in self?.poke($0) }
        corner.onFiveClicks = { [weak self] in self?.dizzy($0) }
        corner.onShake = { [weak self] in self?.shaken() }
        corner.onBubbleClick = { [weak self] in self?.bubbleClicked($0) }
        corner.onOpenRoom = { [weak self] in self?.openRoom() }
        corner.onMoved = { [originKey] in UserDefaults.standard.set(NSStringFromPoint($0), forKey: originKey) }
        corner.menuProvider = { [weak self] in self?.makeMenu() }
        corner.focusProvider = { [weak self] in self?.focusStatus() }
        panel.contentView = corner
        panel.orderFrontRegardless()

        settings.onScale = { [weak self] in self?.applyScale($0) }
        settings.onResetPosition = { [weak self] in self?.comeBack() }

        progress.onLevelUp = { [weak self] level, items in
            guard let self else { return }
            let names = items.map(\.name).joined(separator: ", ")
            self.corner.say(0, title: "Level up! Lv \(level) 🎉", sub: names.isEmpty ? "+20 🪙 · keep it up!" : "Unlocked: \(names)", duration: 10, voice: false)
            self.corner.slots[0].anim.love()
            self.corner.slots[0].anim.celebrate()
            Synth.shared.levelUp()
            self.roomView?.showToast("Level \(level)! +20 🪙" + (names.isEmpty ? "" : " · Unlocked: \(names)"))
        }
        progress.onAchievement = { [weak self] a, it in
            guard let self else { return }
            let sub = it.map { "Secret unlocked: \($0.name)" } ?? "+\(a.xp) XP"
            self.corner.say(0, title: "🏆 \(a.name)", sub: sub, duration: 9, voice: false)
            Synth.shared.unlock()
            self.roomView?.showToast("🏆 \(a.name) · \(sub)")
        }
        progress.onQuest = { [weak self] q, sweep in
            guard let self else { return }
            Synth.shared.coin()
            let msg = sweep ? "All quests done! +\(q.coins + 25) 🪙" : "Quest done: \(q.text) · +\(q.coins) 🪙"
            self.roomView?.showToast("📋 " + msg)
            if self.roomWindow?.isVisible != true { self.corner.say(0, title: "📋 Quest complete!", sub: msg, duration: 6, voice: false) }
        }
        progress.onStreak = { [weak self] days, coins in
            guard let self, days > 1 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                self.corner.say(0, title: "🔥 \(days)-day streak!", sub: "+\(coins) 🪙 for coming back", duration: 6, voice: false)
            }
        }

        let frameTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in autoreleasepool { self?.frameTick() } }
        RunLoop.main.add(frameTimer, forMode: .common)
        let pollTimer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in autoreleasepool { self?.readEvents() } }
        RunLoop.main.add(pollTimer, forMode: .common)

        corner.onFlick = { [weak self] in self?.flick($0) }
        corner.onSquishRelease = { [weak self] i, amt in if i == 0 { self?.squishReleased(amt) } }
        setupPersonality()
        progress.rollDay()
        if progress.welcomeGift > 0 {
            corner.say(0, title: "Buddy 2.0 is here! 🎉", sub: "Here's 🪙\(progress.welcomeGift) for the new shop. Double-click me!", duration: 12)
        } else {
            corner.say(0, title: "Hi! Lv \(progress.level) \(progress.data.name) reporting 👋", sub: "Double-click me to visit my room", duration: 6)
        }
    }

    func defaultOrigin(_ s: NSSize? = nil) -> NSPoint {
        let s = s ?? panel.frame.size
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: vf.maxX - s.width - 6, y: vf.minY + 6)
    }

    /// Where buddy's body is on screen.
    func buddyHome() -> NSPoint { NSPoint(x: panel.frame.maxX - 46 * scale, y: panel.frame.minY + 44 * scale) }

    func applyScale(_ s: CGFloat) {
        let new = NSSize(width: size.width * s, height: size.height * s)
        let old = panel.frame
        // Keep buddy's spot (bottom-right) where it was.
        panel.setFrame(NSRect(x: old.maxX - new.width, y: old.minY, width: new.width, height: new.height), display: true)
        corner.frame = NSRect(origin: .zero, size: new)
        corner.setBoundsSize(size)
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: originKey)
    }

    // MARK: Frame loop

    func frameTick() {
        frameCount += 1
        let date = Date()
        for (id, s) in sessions {
            let quiet = date.timeIntervalSince(s.updated)
            if quiet > 60 * 60 { sessions[id] = nil } else if quiet > 25 * 60 && s.mood != .idle { sessions[id]?.mood = .idle }
        }
        updateMoods()
        funTick()
        focusTick()
        if let h = hiddenUntil, date >= h { unhide() }

        // If buddy ended up somewhere you can't see (e.g. a display was unplugged), bring him back.
        let home = buddyHome()
        let spot = NSRect(x: home.x - 40 * scale, y: home.y - 34 * scale, width: 80 * scale, height: 80 * scale)
        if hiddenUntil == nil && Fun.shared.flyVel == nil && !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(spot) }) { comeBack() }

        // Buddies doze off when nothing has happened for a while (sooner late at night).
        let lateNight = Calendar.current.component(.hour, from: date) < 6
        for s in corner.slots where s.present && !s.anim.asleep {
            if s.anim.mood == .idle && !s.anim.isCelebrating && !s.anim.devil && !s.anim.flying && focusEnd == nil && now() - s.lastActivity > (lateNight ? 180 : 600) {
                s.anim.asleep = true
                sleepPokes = 0
                Synth.shared.yawn()
            }
        }

        let m = NSEvent.mouseLocation
        let local = NSPoint(x: (m.x - panel.frame.minX) / scale, y: (m.y - panel.frame.minY) / scale)
        let mouseNear = panel.frame.insetBy(dx: -20, dy: -20).contains(m)
        let passThrough = corner.hit(at: local) == nil
        if panel.ignoresMouseEvents != passThrough { panel.ignoresMouseEvents = passThrough }

        // Redraw the corner at 60 fps only while something lively is happening; 20 fps otherwise, 15 asleep.
        let lively = mouseNear || Fun.shared.flyVel != nil || Fun.shared.raging || corner.slots.contains { $0.anim.dragging || $0.anim.isCelebrating || $0.anim.isDizzy }
        let allAsleep = corner.slots.allSatisfy { !$0.present || $0.anim.asleep }
        let every = lively ? 1 : allAsleep ? 4 : 3
        if hiddenUntil == nil && frameCount % every == 0 {
            if lively { corner.needsDisplay = true } else { corner.setNeedsDisplay(corner.activeRect(focus: focusEnd != nil)) }
        }
        if let w = roomWindow, w.isVisible, !w.isMiniaturized { roomView?.needsDisplay = true }
    }

    func updateMoods() {
        for (i, s) in corner.slots.enumerated() {
            let moods = sessions.values.filter { $0.slot == i }.map(\.mood)
            s.anim.mood = moods.contains(.attention) ? .attention : moods.contains(.working) ? .working : .idle
        }
        corner.setPresent(1, sessions.values.contains { $0.slot == 1 } || now() < testFriendUntil)
    }

    func wake(_ i: Int) {
        let s = corner.slots[i]
        s.lastActivity = now()
        if s.anim.asleep { s.anim.asleep = false; s.anim.surprise() }
    }

    /// Orange takes the first session; the friend takes the second; any more share orange.
    func freeSlot() -> Int {
        let used = Set(sessions.values.map(\.slot))
        if !used.contains(0) { return 0 }
        return used.contains(1) ? 0 : 1
    }

    // MARK: Claude Code events

    func fileSize() -> UInt64 {
        var st = stat()
        return stat(eventsURL.path, &st) == 0 ? UInt64(st.st_size) : 0
    }

    func readEvents() {
        let size = fileSize()
        if size < offset { offset = 0; partial.removeAll() }
        guard size > offset, let h = try? FileHandle(forReadingFrom: eventsURL) else { return }
        defer { try? h.close() }
        try? h.seek(toOffset: offset)
        let data = h.readDataToEndOfFile()
        offset += UInt64(data.count)
        partial.append(data)
        while let nl = partial.firstIndex(of: 0x0A) {
            let line = Data(partial[partial.startIndex..<nl])
            partial.removeSubrange(partial.startIndex...nl)
            handle(line)
        }
        if offset > 1_000_000 && partial.isEmpty {
            try? Data().write(to: eventsURL)
            offset = 0
        }
    }

    static func duration(_ secs: TimeInterval) -> String {
        let s = Int(secs)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \(s % 3600 / 60)m"
    }

    func handle(_ line: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let event = obj["event"] as? String else { return }
        let id = (obj["session_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "default"
        let cwd = obj["cwd"] as? String ?? ""
        let project = cwd.isEmpty ? "Claude Code" : (cwd as NSString).lastPathComponent
        let app = obj["app"] as? String ?? ""

        if event == "end" { sessions[id] = nil; updateMoods(); return }

        var s = sessions[id] ?? Session(mood: .idle, project: project, app: app, updated: Date(), slot: freeSlot())
        s.project = project
        s.updated = Date()
        if !app.isEmpty { s.app = app; lastApp = app }
        let i = s.slot

        switch event {
        case "prompt":
            if s.mood != .working || s.started == nil { s.started = Date() }
            s.mood = .working
            progress.award(3)
        case "tool":
            if s.started == nil { s.started = Date() }
            s.mood = .working
            progress.toolUsed()
        case "stop":
            let took = s.started.map { Date().timeIntervalSince($0) }
            s.mood = .idle
            s.started = nil
            sessions[id] = s
            wake(i)
            corner.slots[i].anim.celebrate()
            Synth.shared.done(pitch: i == 0 ? 1 : 1.25)
            let r = progress.sessionFinished()
            let time = took.map { " · " + AppDelegate.duration($0) } ?? ""
            corner.say(i, title: "All done! ✨", sub: "\(project)\(time) · +\(r.xp) XP +\(r.coins) 🪙", duration: 9, voice: false)
            updateMoods()
            return
        case "notify":
            let msg = obj["message"] as? String ?? ""
            let type = obj["type"] as? String ?? ""
            // The "waiting for your input" nudge comes after a stop we already celebrated.
            if type == "idle_prompt" || msg.localizedCaseInsensitiveContains("waiting for your input") { return }
            s.mood = .attention
            if hiddenUntil != nil { unhide() }
            let title = msg.localizedCaseInsensitiveContains("permission") ? "Needs your permission" : "Needs your attention"
            corner.say(i, title: title, sub: project, duration: 14, voice: false)
            Synth.shared.boop()
        default:
            return
        }
        sessions[id] = s
        wake(i)
        updateMoods()
    }

    // MARK: Interactions and secrets

    func poke(_ i: Int) {
        if pokeMischief(i) { return }
        let s = corner.slots[i]
        if s.anim.asleep {
            sleepPokes += 1
            s.anim.grumpy()
            Synth.shared.grumble()
            if sleepPokes >= 3 {
                wake(i)
                corner.say(i, title: "FINE. I'm up. 😤", duration: 4)
                progress.achieve("grumpy", unlocking: "nightcap")
            } else {
                corner.say(i, title: ["5 more minutes…", "zzz… go away…"][sleepPokes - 1], duration: 3)
            }
            return
        }
        corner.dismissBubble(i)
        s.lastActivity = now()
        s.anim.pet()
        Synth.shared.giggle(pitch: i == 0 ? 1 : 1.25)
        if now() - lastPetXP > 2 { lastPetXP = now(); progress.petted() }
        if !Prefs.quiet && Int.random(in: 0..<5) == 0 {
            corner.say(i, title: ["hehe", "that tickles!", "hi!! 👋", "boop!", "*happy noises*", "you're the best"].randomElement()!, duration: 2.5)
        }
    }

    func dizzy(_ i: Int) {
        let s = corner.slots[i]
        guard !s.anim.asleep else { return }
        s.anim.dizzy()
        annoy(15, quiet: true)
        Synth.shared.dizzy()
        corner.say(i, title: "whoa… the room is spinning 😵‍💫", duration: 3.5)
        progress.achieve("dizzy", unlocking: "propeller")
    }

    func shaken() {
        for (i, s) in corner.slots.enumerated() where s.present { wake(i); s.anim.dizzy() }
        Synth.shared.whee()
        annoy(18, quiet: true)
        corner.say(0, title: "WHEEEE! 🎢", duration: 3)
        progress.achieve("whee")
    }

    func bubbleClicked(_ i: Int) {
        corner.dismissBubble(i)
        let mine = sessions.values.filter { $0.slot == i }
        let target = (mine.filter { $0.mood == .attention }.max { $0.updated < $1.updated }
                      ?? mine.max { $0.updated < $1.updated })?.app ?? lastApp
        activate(app: target)
    }

    func activate(app: String) {
        let byTermProgram = [
            "Apple_Terminal": "com.apple.Terminal", "iTerm.app": "com.googlecode.iterm2",
            "vscode": "com.microsoft.VSCode", "WarpTerminal": "dev.warp.Warp-Stable",
            "ghostty": "com.mitchellh.ghostty", "WezTerm": "com.github.wez.wezterm",
        ]
        let bundleID = app.contains(".") ? app : byTermProgram[app]
        guard let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func feedFromCorner() {
        if refuseCookie() { return }
        defer { ateCookie() }
        let a = corner.slots[0].anim
        wake(0)
        a.chomp()
        Synth.shared.chomp()
        corner.say(0, title: progress.fedCookie() ? ["nom nom nom 🍪", "yummy!", "crunchy!"].randomElement()! : "I'm stuffed! 🥴", duration: 3)
    }

    // MARK: Hiding

    func hide(for seconds: TimeInterval) {
        hiddenUntil = Date().addingTimeInterval(seconds)
        panel.orderOut(nil)
    }

    func unhide() {
        hiddenUntil = nil
        panel.orderFrontRegardless()
        wake(0)
        buddy.startIdle(.wave)
    }

    // MARK: Focus timer

    func startFocus(_ minutes: Int) {
        focusMinutes = minutes
        focusStart = now()
        focusEnd = now() + Double(minutes * 60)
        wake(0)
        buddy.startIdle(.coffee)
        Synth.shared.tick()
        corner.say(0, title: "Focus time! 🍅 \(minutes) minutes", sub: "I'll keep watch. You've got this.", duration: 5)
    }

    func stopFocus() {
        guard focusEnd != nil else { return }
        focusEnd = nil
        corner.say(0, title: "Focus timer stopped", sub: "No worries, try again later!", duration: 4)
    }

    func focusTick() {
        guard let end = focusEnd, now() >= end else { return }
        focusEnd = nil
        let r = progress.focusFinished(minutes: focusMinutes)
        wake(0)
        if hiddenUntil != nil { unhide() }
        buddy.celebrate()
        buddy.love()
        Synth.shared.levelUp()
        corner.say(0, title: "Focus session done! 🍅🎉", sub: "Take a 5-minute break · +\(r.xp) XP +\(r.coins) 🪙", duration: 14, voice: false)
    }

    func focusStatus() -> (String, CGFloat)? {
        guard let end = focusEnd else { return nil }
        let left = max(0, end - now())
        let frac = CGFloat(1 - left / max(1, end - focusStart))
        return (String(format: "%d:%02d", Int(left) / 60, Int(left) % 60), frac)
    }

    // MARK: Room

    @objc func openRoom() {
        if roomView == nil {
            let v = RoomView(anim: corner.slots[0].anim)
            v.onPoke = { [weak self] in self?.poke(0) }
            v.onFeed = { [weak self] in self?.roomAteCookie() ?? false }
            v.onMedicine = { [weak self] in self?.giveMedicine() }
            v.onCommand = { [weak self] in self?.command($0) ?? [] }
            v.onGameFinish = { [weak self] id, score in
                self?.progress.finishGame(id, score: score) ?? GameReward(xp: 0, coins: 0, newBest: false)
            }
            v.menuProvider = { [weak self] in self?.makeMenu() }
            roomView = v
            roomWindow = RoomWindow(view: v)
        }
        if Calendar.current.component(.hour, from: Date()) == 3 { progress.achieve("witching", unlocking: "shadow") }
        progress.rollDay()
        NSApp.activate(ignoringOtherApps: true)
        roomWindow?.makeKeyAndOrderFront(nil)
    }

    func openRoom(_ o: RoomView.Overlay) {
        openRoom()
        if roomView?.overlay != o { roomView?.open(o) }
    }

    func command(_ raw: String) -> [String] {
        let cmd = raw.lowercased().trimmingCharacters(in: .whitespaces)
        let a = corner.slots[0].anim
        progress.track("console")
        if let r = funCommand(cmd) { return r }
        if cmd.hasPrefix("sudo") {
            guard cmd.contains("buddy") else { return ["Nice try. 😏"] }
            a.celebrate()
            Synth.shared.levelUp()
            progress.achieve("root", unlocking: "rainbow")
            return ["[sudo] password for buddy: ********",
                    "buddy is not in the sudoers file. This incident will be reported.",
                    "…just kidding. Root access granted 🌈 (try: wear rainbow)"]
        }
        if cmd.hasPrefix("wear ") {
            let name = String(cmd.dropFirst(5))
            guard let it = catalog.first(where: { ($0.id == name || $0.name.lowercased() == name) && [.skin, .hat, .accessory].contains($0.kind) }) else {
                return ["no item called '\(name)'"]
            }
            guard progress.isUnlocked(it) else { return ["🔒 \(it.name) is still locked"] }
            progress.equip(it)
            a.celebrate()
            Synth.shared.unlock()
            return ["now wearing \(it.name) ✨"]
        }
        if cmd.hasPrefix("name ") {
            progress.setName(String(raw.trimmingCharacters(in: .whitespaces).dropFirst(5)))
            a.love()
            return ["call me \(progress.data.name)! 🥹"]
        }
        if cmd.hasPrefix("play ") {
            let q = String(cmd.dropFirst(5))
            guard let g = arcadeGames.first(where: { $0.id == q || $0.name.lowercased().hasPrefix(q) }) else { return ["games: " + arcadeGames.map(\.id).joined(separator: ", ")] }
            DispatchQueue.main.async { self.roomView?.startGame(g.id) }
            return ["\(g.icon) starting \(g.name)…"]
        }
        if cmd.hasPrefix("focus") {
            let n = Int(cmd.dropFirst(5).trimmingCharacters(in: .whitespaces)) ?? 25
            if cmd == "focus stop" { stopFocus(); return ["⏹ focus timer stopped"] }
            startFocus(max(1, min(120, n)))
            return ["🍅 focusing for \(max(1, min(120, n))) minutes"]
        }
        switch cmd {
        case "help", "?":
            return ["help feed pet dance sleep wake stats coins quests",
                    "wear <item>  name <name>  play <game>  focus <min>",
                    "shop  style  edit  arcade  settings  honk joke fortune",
                    "sorry meds mood juggle whistle flip ls clear exit",
                    "(and a few secrets… 👀)"]
        case "boo":
            wake(0); a.surprise()
            Synth.shared.scream()
            progress.achieve("boo", unlocking: "ghost")
            return ["AAAAH! 👻", "…oh. it's you."]
        case "dance":
            wake(0); a.dance()
            Synth.shared.done(pitch: 0.8)
            return ["💃 *dances*"]
        case "feed", "cookie":
            roomView?.feed(); return ["🍪 incoming!"]
        case "pet":
            poke(0); return ["*happy noises*"]
        case "sleep":
            a.asleep = true; sleepPokes = 0; Synth.shared.yawn(); return ["goodnight 🌙"]
        case "wake", "wake up":
            wake(0); return ["☀️ good morning!"]
        case "stats":
            let d = progress.data
            return ["\(d.name) · level \(progress.level) · \(d.xp) XP · 🪙 \(d.coins)",
                    "sessions \(d.sessions) · cookies \(d.cookies) · pets \(d.pets) · games \(d.gamesPlayed)",
                    "trophies \(d.achievements.count)/\(achievements.count) · streak \(d.streak) 🔥 · focus \(d.focusMinutes) min"]
        case "coins", "money", "wallet": return ["🪙 \(progress.data.coins) coins"]
        case "quests":
            DispatchQueue.main.async { self.roomView?.open(.quests) }
            return ["📋 opening quests"]
        case "shop", "store":
            DispatchQueue.main.async { self.roomView?.open(.shop) }
            return []
        case "style", "wardrobe":
            DispatchQueue.main.async { self.roomView?.open(.style) }
            return []
        case "edit", "decorate":
            DispatchQueue.main.async { self.roomView?.open(.edit) }
            return []
        case "arcade", "games", "play":
            DispatchQueue.main.async { self.roomView?.open(.arcade) }
            return []
        case "settings", "prefs":
            settings.show(); return ["⚙️ opening settings"]
        case "xyzzy":
            progress.achieve("xyzzy"); return ["Nothing happens.", "…or does it? ✨"]
        case "ls": return ["desk.txt  bed.txt  cookie_jar/  arcade/"]
        case "ls -a", "ls -la": return [".  ..  .secrets/  desk.txt  bed.txt  cookie_jar/  arcade/"]
        case "ls arcade", "ls arcade/": return arcadeGames.map { "\($0.id).exe" }
        case "cd .secrets", "ls .secrets", "cat .secrets": return ["permission denied. (have you tried being root?)"]
        case "cat desk.txt": return ["TODO: help my human ship cool stuff"]
        case "cat bed.txt": return ["zzz"]
        case "ls cookie_jar", "ls cookie_jar/": return ["cookie.png  cookie.png  cookie (1).png"]
        case "rm -rf /", "rm -rf ~", "rm -rf *": return ["nope. 🙅"]
        case "hi", "hello", "hey": a.pet(); Synth.shared.giggle(); return ["hi!! 👋"]
        case "whoami": return ["my favourite human"]
        case "42": return ["the answer to everything ✨"]
        case "meow": return progress.placed("cat") ? ["Byte: meow 🐱"] : ["there's no cat here… yet."]
        case "claude": return ["that's me! well, a tiny version."]
        default: return ["buddy: command not found: \(raw)"]
        }
    }

    // MARK: Menu

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        @discardableResult
        func add(_ title: String, _ action: Selector, to m: NSMenu? = nil, tag: Int = 0) -> NSMenuItem {
            let it = (m ?? menu).addItem(withTitle: title, action: action, keyEquivalent: "")
            it.target = self
            it.tag = tag
            return it
        }
        let d = progress.data
        menu.addItem(withTitle: "\(d.name) · Lv \(progress.level) · 🪙 \(d.coins)", action: nil, keyEquivalent: "").isEnabled = false
        if d.streak > 1 { menu.addItem(withTitle: "🔥 \(d.streak)-day streak", action: nil, keyEquivalent: "").isEnabled = false }
        menu.addItem(.separator())
        add("Open Buddy's Room", #selector(openRoomMenu))
        let arcade = NSMenu()
        for (i, g) in arcadeGames.enumerated() { add("\(g.icon) \(g.name)", #selector(playMenu(_:)), to: arcade, tag: i) }
        menu.addItem(withTitle: "Arcade", action: nil, keyEquivalent: "").submenu = arcade
        add("Style…", #selector(styleMenu))
        add("Shop…", #selector(shopMenu))
        add("Daily quests…", #selector(questsMenu))
        add("Feed a cookie 🍪", #selector(feedMenu))

        let focus = NSMenu()
        if let (left, _) = focusStatus() {
            focus.addItem(withTitle: "\(left) left", action: nil, keyEquivalent: "").isEnabled = false
            add("Stop", #selector(stopFocusMenu), to: focus)
        } else {
            for m in [15, 25, 45, 60] { add("\(m) minutes", #selector(focusMenu(_:)), to: focus, tag: m) }
        }
        menu.addItem(withTitle: focusEnd == nil ? "Focus timer 🍅" : "Focus timer 🍅 (running)", action: nil, keyEquivalent: "").submenu = focus
        addFunItems(to: menu)

        menu.addItem(.separator())
        add("Settings…", #selector(settingsMenu))
        add("Sounds", #selector(toggleSound)).state = Synth.shared.muted ? .off : .on
        add("Hide for 1 hour", #selector(hideMenu))
        add("Move back to corner", #selector(resetPosition))
        let test = NSMenu()
        add("Celebration", #selector(testCelebrate), to: test)
        add("Second buddy", #selector(testFriend), to: test)
        add("Tantrum 😈", #selector(rageMenu), to: test)
        menu.addItem(withTitle: "Test", action: nil, keyEquivalent: "").submenu = test
        menu.addItem(.separator())
        add("Quit Claude Buddy", #selector(quit))
        return menu
    }

    @objc func openRoomMenu() { openRoom() }
    @objc func feedMenu() { feedFromCorner() }
    @objc func styleMenu() { openRoom(.style) }
    @objc func shopMenu() { openRoom(.shop) }
    @objc func questsMenu() { openRoom(.quests) }
    @objc func settingsMenu() { settings.show() }
    @objc func hideMenu() { hide(for: 3600) }
    @objc func playMenu(_ sender: NSMenuItem) { openRoom(); roomView?.startGame(arcadeGames[sender.tag].id) }
    @objc func focusMenu(_ sender: NSMenuItem) { startFocus(sender.tag) }
    @objc func stopFocusMenu() { stopFocus() }
    @objc func testCelebrate() {
        wake(0)
        corner.slots[0].anim.celebrate()
        Synth.shared.done()
        corner.say(0, title: "All done! ✨", sub: "test-project · 2m 14s", voice: false)
    }
    @objc func testFriend() {
        testFriendUntil = now() + 12
        updateMoods()
        corner.say(1, title: "Hi, I'm the second session!", sub: "other-project", duration: 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.corner.slots[1].anim.celebrate()
            Synth.shared.done(pitch: 1.25)
            self?.corner.say(1, title: "All done! ✨", sub: "other-project", voice: false)
        }
    }
    @objc func toggleSound() { Synth.shared.muted.toggle() }
    @objc func resetPosition() {
        panel.setFrameOrigin(defaultOrigin())
        UserDefaults.standard.removeObject(forKey: originKey)
    }
    @objc func quit() { NSApp.terminate(nil) }
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    runSnapshot(CommandLine.arguments[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
