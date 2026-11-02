// `ClaudeBuddy --snapshot <dir>` renders every screen to PNG files without opening any windows
// (used to check the UI). Point BUDDY_SAVE at a copy of save.json so the real one isn't touched.

import AppKit

private func png(_ v: NSView, _ url: URL) {
    guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
    v.cacheDisplay(in: v.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

func runSnapshot(_ dir: String) {
    let out = URL(fileURLWithPath: dir)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    _ = NSApplication.shared
    BuddyProgress.shared.rollDay()
    let anim = Animator(phase: 0)
    let room = RoomView(anim: anim)
    func shot(_ name: String) { room.needsDisplay = true; png(room, out.appendingPathComponent(name + ".png")) }

    shot("room")
    for t in 0..<8 { room.debugShow(.style, tab: t); shot("style-\(t)") }
    room.debugShow(.style, tab: 1, page: 1); shot("style-1-p2")
    room.debugShow(.style, tab: 7, page: 2); shot("style-7-p3")
    for t in 0..<5 { room.debugShow(.shop, tab: t); shot("shop-\(t)") }
    room.debugShow(.shop, tab: 0, pending: "disco"); shot("shop-buy")
    room.debugShow(.quests); shot("quests")
    room.debugShow(.arcade); shot("arcade")
    room.debugShow(.edit); shot("edit")
    room.debugShow(.console); shot("console")
    room.debugShow(.none)

    for g in arcadeGames {
        guard let game = makeGame(g.id, anim: anim) else { continue }
        room.addSubview(game)
        game.restart()
        game.started = now() - 4
        for k in 0..<240 {
            if g.id == "hop" && k % 25 == 0 { game.click(NSPoint(x: 10, y: 10)) }
            game.update(1.0 / 60, now() + Double(k) / 60)
        }
        if g.id == "copycat" { game.update(0.016, now() + 3) }
        shot("game-\(g.id)")
        game.end()
        shot("game-\(g.id)-over")
        game.close()
    }

    // Corner widget, with the focus ring and a bubble
    let corner = CornerView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
    corner.focusProvider = { ("18:42", 0.3) }
    corner.say(0, title: "All done! ✨", sub: "claude-buddy · 3m 12s · +25 XP +5 🪙", voice: false)
    png(corner, out.appendingPathComponent("corner.png"))

    // Every skin, hat and accessory on one sheet
    let sheet = SheetView(frame: NSRect(x: 0, y: 0, width: 720, height: 300))
    png(sheet, out.appendingPathComponent("wardrobe-sheet.png"))
    print("Wrote snapshots to \(dir)")
}

private final class SheetView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.93, alpha: 1).setFill(); bounds.fill()
        let skins = catalog.filter { $0.kind == .skin }, hats = catalog.filter { $0.kind == .hat }, accs = catalog.filter { $0.kind == .accessory }
        for (i, s) in skins.enumerated() { Renderer.draw(skin: s.id, hat: "none", pose: Pose(), at: NSPoint(x: 36 + CGFloat(i) * 36, y: 250), scale: 0.5, shadow: false) }
        for (i, h) in hats.enumerated() { Renderer.draw(skin: "classic", hat: h.id, pose: Pose(), at: NSPoint(x: 36 + CGFloat(i) * 36, y: 150), scale: 0.5, shadow: false) }
        for (i, a) in accs.enumerated() { Renderer.draw(skin: "classic", hat: "none", accessory: a.id, pose: Pose(), at: NSPoint(x: 50 + CGFloat(i) * 80, y: 50), scale: 1.2, shadow: false) }
    }
}
