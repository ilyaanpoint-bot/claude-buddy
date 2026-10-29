// Claude Buddy — app entry: reads Claude Code hook events, runs the corner widget and the
// room window, and turns everything that happens into XP, unlocks and secrets.

import AppKit

struct Session {
    var mood: Mood
    var project: String
    var app: String
    var updated: Date
    var slot: Int
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var corner: CornerView!
    var roomView: RoomView?
    var roomWindow: RoomWindow?
    var sessions: [String: Session] = [:]
    var lastApp = ""
    var offset: UInt64 = 0
    var partial = Data()
    var testFriendUntil = -100.0
    var sleepPokes = 0
    var lastPetXP = -100.0
    let size = NSSize(width: 320, height: 200)
    let originKey = "origin2"
    var progress: BuddyProgress { BuddyProgress.shared }

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
        offset = fileSize()   // only react to events from now on

        var origin = defaultOrigin()
        if let saved = UserDefaults.standard.string(forKey: originKey) {
            let p = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.frame.contains(NSPoint(x: p.x + size.width / 2, y: p.y + size.height / 2)) }) { origin = p }
        }

        panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        corner = CornerView(frame: NSRect(origin: .zero, size: size))
        corner.onPoke = { [weak self] in self?.poke($0) }
        corner.onFiveClicks = { [weak self] in self?.dizzy($0) }
        corner.onShake = { [weak self] in self?.shaken() }
        corner.onBubbleClick = { [weak self] in self?.bubbleClicked($0) }
        corner.onOpenRoom = { [weak self] in self?.openRoom() }
        corner.onMoved = { [originKey] in UserDefaults.standard.set(NSStringFromPoint($0), forKey: originKey) }
        corner.menuProvider = { [weak self] in self?.makeMenu() }
        panel.contentView = corner
        panel.orderFrontRegardless()

        progress.onLevelUp = { [weak self] level, items in
            guard let self else { return }
            let names = items.filter { $0.kind != .decor || true }.map(\.name).joined(separator: ", ")
            self.corner.say(0, title: "Level up! Lv \(level) 🎉", sub: names.isEmpty ? "Keep it up!" : "Unlocked: \(names)", duration: 10, voice: false)
            self.corner.slots[0].anim.love()
            self.corner.slots[0].anim.celebrate()
            Synth.shared.levelUp()
            self.roomView?.showToast("Level \(level)!" + (names.isEmpty ? "" : " Unlocked: \(names)"))
        }
        progress.onAchievement = { [weak self] a, it in
            guard let self else { return }
            let sub = it.map { "Secret unlocked: \($0.name)" } ?? "+\(a.xp) XP"
            self.corner.say(0, title: "🏆 \(a.name)", sub: sub, duration: 9, voice: false)
            Synth.shared.unlock()
            self.roomView?.showToast("🏆 \(a.name) · \(sub)")
        }

        let frameTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.frameTick() }
        RunLoop.main.add(frameTimer, forMode: .common)
        let pollTimer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in self?.readEvents() }
        RunLoop.main.add(pollTimer, forMode: .common)

        corner.onFlick = { [weak self] in self?.flick($0) }
        corner.onSquishRelease = { [weak self] i, amt in if i == 0 { self?.squishReleased(amt) } }
        setupPersonality()
        corner.say(0, title: "Hi! Lv \(progress.level) buddy reporting 👋", sub: "Double-click me to visit my room", duration: 6)
    }

    func defaultOrigin() -> NSPoint {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: vf.maxX - size.width - 6, y: vf.minY + 6)
    }

    // MARK: Frame loop

    func frameTick() {
        let date = Date()
        for (id, s) in sessions {
            let quiet = date.timeIntervalSince(s.updated)
            if quiet > 60 * 60 { sessions[id] = nil } else if quiet > 25 * 60 && s.mood != .idle { sessions[id]?.mood = .idle }
        }
        updateMoods()
        funTick()
        // If buddy ended up somewhere you can't see (e.g. a display was unplugged), bring him back.
        let spot = NSRect(x: panel.frame.maxX - 90, y: panel.frame.minY + 10, width: 80, height: 80)
        if Fun.shared.flyVel == nil && !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(spot) }) { comeBack() }

        // Buddies doze off when nothing has happened for a while (sooner late at night).
        let lateNight = Calendar.current.component(.hour, from: date) < 6
        for s in corner.slots where s.present && !s.anim.asleep {
            if s.anim.mood == .idle && !s.anim.isCelebrating && !s.anim.devil && !s.anim.flying && now() - s.lastActivity > (lateNight ? 180 : 600) {
                s.anim.asleep = true
                sleepPokes = 0
                Synth.shared.yawn()
            }
        }

        let m = NSEvent.mouseLocation
        let local = NSPoint(x: m.x - panel.frame.minX, y: m.y - panel.frame.minY)
        let passThrough = corner.hit(at: local) == nil
        if panel.ignoresMouseEvents != passThrough { panel.ignoresMouseEvents = passThrough }
        corner.needsDisplay = true
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

    /// Orange takes the first session; blue takes the second; any more share orange.
    func freeSlot() -> Int {
        let used = Set(sessions.values.map(\.slot))
        if !used.contains(0) { return 0 }
        return used.contains(1) ? 0 : 1
    }

    // MARK: Claude Code events

    func fileSize() -> UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: eventsURL.path))?[.size] as? NSNumber)?.uint64Value ?? 0
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
            s.mood = .working
            progress.award(3)
        case "tool":
            s.mood = .working
            progress.toolUsed()
        case "stop":
            s.mood = .idle
            sessions[id] = s
            wake(i)
            corner.slots[i].anim.celebrate()
            Synth.shared.done(pitch: i == 0 ? 1 : 1.25)
            let xp = progress.sessionFinished()
            corner.say(i, title: "All done! ✨", sub: "\(project) · +\(xp) XP", duration: 9, voice: false)
            updateMoods()
            return
        case "notify":
            let msg = obj["message"] as? String ?? ""
            let type = obj["type"] as? String ?? ""
            // The "waiting for your input" nudge comes after a stop we already celebrated.
            if type == "idle_prompt" || msg.localizedCaseInsensitiveContains("waiting for your input") { return }
            s.mood = .attention
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
        if Int.random(in: 0..<5) == 0 {
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

    // MARK: Room

    @objc func openRoom() {
        if roomView == nil {
            let v = RoomView(anim: corner.slots[0].anim)
            v.onPoke = { [weak self] in self?.poke(0) }
            v.onFeed = { [weak self] in self?.roomAteCookie() ?? false }
            v.onMedicine = { [weak self] in self?.giveMedicine() }
            v.onCommand = { [weak self] in self?.command($0) ?? [] }
            v.onGameOver = { [weak self] in self?.progress.gameOver(score: $0) }
            roomView = v
            roomWindow = RoomWindow(view: v)
        }
        NSApp.activate(ignoringOtherApps: true)
        roomWindow?.makeKeyAndOrderFront(nil)
    }

    func command(_ raw: String) -> [String] {
        let cmd = raw.lowercased().trimmingCharacters(in: .whitespaces)
        let a = corner.slots[0].anim
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
            guard let it = catalog.first(where: { ($0.id == name || $0.name.lowercased() == name) && $0.kind != .decor }) else {
                return ["no item called '\(name)'"]
            }
            guard progress.isUnlocked(it) else { return ["🔒 \(it.name) is still locked"] }
            progress.equip(it)
            a.celebrate()
            Synth.shared.unlock()
            return ["now using \(it.name) ✨"]
        }
        switch cmd {
        case "help", "?":
            return ["commands: help  feed  pet  dance  sleep  wake  stats", "          wear <item>  ls  whoami  clear  exit",
                    "(there may be others… 👀)"]
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
            return ["level \(progress.level) · \(d.xp) XP", "sessions \(d.sessions) · cookies \(d.cookies) · pets \(d.pets) · best catch \(d.bestScore)",
                    "trophies \(d.achievements.count)/\(achievements.count)"]
        case "xyzzy":
            progress.achieve("xyzzy"); return ["Nothing happens.", "…or does it? ✨"]
        case "ls": return ["desk.txt  bed.txt  cookie_jar/"]
        case "ls -a", "ls -la": return [".  ..  .secrets/  desk.txt  bed.txt  cookie_jar/"]
        case "cd .secrets", "ls .secrets", "cat .secrets": return ["permission denied. (have you tried being root?)"]
        case "cat desk.txt": return ["TODO: help my human ship cool stuff"]
        case "cat bed.txt": return ["zzz"]
        case "ls cookie_jar", "ls cookie_jar/": return ["cookie.png  cookie.png  cookie (1).png"]
        case "rm -rf /", "rm -rf ~", "rm -rf *": return ["nope. 🙅"]
        case "hi", "hello", "hey": a.pet(); Synth.shared.giggle(); return ["hi!! 👋"]
        case "whoami": return ["my favourite human"]
        case "42": return ["the answer to everything ✨"]
        case "meow": return progress.has("cat") ? ["Byte: meow 🐱"] : ["there's no cat here… yet."]
        case "claude": return ["that's me! well, a tiny version."]
        default: return ["buddy: command not found: \(raw)"]
        }
    }

    // MARK: Menu

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector) -> NSMenuItem {
            let it = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            it.target = self
            return it
        }
        let header = menu.addItem(withTitle: "Level \(progress.level) · \(progress.data.xp) XP", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(.separator())
        _ = add("Open Buddy's Room", #selector(openRoom))
        _ = add("Feed a cookie 🍪", #selector(feedMenu))
        _ = add("Wardrobe…", #selector(wardrobeMenu))
        addFunItems(to: menu)
        menu.addItem(.separator())
        _ = add("Test celebration", #selector(testCelebrate))
        _ = add("Test with friend", #selector(testFriend))
        add("Sounds", #selector(toggleSound)).state = Synth.shared.muted ? .off : .on
        _ = add("Move back to corner", #selector(resetPosition))
        menu.addItem(.separator())
        _ = add("Quit Claude Buddy", #selector(quit))
        return menu
    }

    @objc func feedMenu() { feedFromCorner() }
    @objc func wardrobeMenu() { openRoom(); if roomView?.overlay != .wardrobe { roomView?.open(.wardrobe) } }
    @objc func testCelebrate() {
        wake(0)
        corner.slots[0].anim.celebrate()
        Synth.shared.done()
        corner.say(0, title: "All done! ✨", sub: "test-project", voice: false)
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
