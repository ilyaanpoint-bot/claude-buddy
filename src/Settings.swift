// Preferences (stored in UserDefaults) and the native Settings window.

import AppKit
import ServiceManagement

enum Prefs {
    private static var d: UserDefaults { .standard }

    /// Corner buddy size: 0.75, 1, 1.25 or 1.5.
    static var scale: CGFloat {
        get { let v = d.double(forKey: "scale"); return v == 0 ? 1 : CGFloat(v) }
        set { d.set(Double(newValue), forKey: "scale") }
    }
    static var volume: Float {
        get { d.object(forKey: "volume") == nil ? 0.45 : d.float(forKey: "volume") }
        set { d.set(newValue, forKey: "volume") }
    }
    /// Quiet mode: no babble sounds and no random chatter (finished/attention bubbles still show).
    static var quiet: Bool {
        get { d.bool(forKey: "quiet") }
        set { d.set(newValue, forKey: "quiet") }
    }
    static var thoughts: Bool {
        get { !d.bool(forKey: "noThoughts") }
        set { d.set(!newValue, forKey: "noThoughts") }
    }
    static var showFocusInCorner: Bool { true }
}

final class SettingsController: NSObject, NSTextFieldDelegate {
    private var window: NSWindow?
    var onScale: ((CGFloat) -> Void)?
    var onResetPosition: (() -> Void)?

    private let nameField = NSTextField()
    private let sizePopup = NSPopUpButton()
    private let soundBox = NSButton(checkboxWithTitle: "Sound effects", target: nil, action: nil)
    private let volume = NSSlider(value: 0.45, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let quietBox = NSButton(checkboxWithTitle: "Quiet mode (no babbling or random chatter)", target: nil, action: nil)
    private let thoughtsBox = NSButton(checkboxWithTitle: "Random thoughts and jokes", target: nil, action: nil)
    private let friendPopup = NSPopUpButton()
    private let loginBox = NSButton(checkboxWithTitle: "Open Claude Buddy when I log in", target: nil, action: nil)
    private let loginNote = NSTextField(labelWithString: "")
    private let sizes: [(String, CGFloat)] = [("Small", 0.75), ("Normal", 1), ("Large", 1.25), ("Huge", 1.5)]

    func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 110).isActive = true
        return l
    }

    private func row(_ title: String, _ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: [label(title)] + views)
        s.orientation = .horizontal
        s.alignment = .firstBaseline
        s.spacing = 10
        return s
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Claude Buddy Settings"
        w.isReleasedWhenClosed = false

        nameField.placeholderString = "Buddy"
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(nameChanged)
        nameField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        sizePopup.addItems(withTitles: sizes.map(\.0))
        sizePopup.target = self; sizePopup.action = #selector(sizeChanged)

        soundBox.target = self; soundBox.action = #selector(soundChanged)
        volume.target = self; volume.action = #selector(volumeChanged)
        volume.widthAnchor.constraint(equalToConstant: 160).isActive = true
        quietBox.target = self; quietBox.action = #selector(quietChanged)
        thoughtsBox.target = self; thoughtsBox.action = #selector(thoughtsChanged)
        friendPopup.target = self; friendPopup.action = #selector(friendChanged)
        loginBox.target = self; loginBox.action = #selector(loginChanged)
        loginNote.font = .systemFont(ofSize: 11)
        loginNote.textColor = .secondaryLabelColor

        let reset = NSButton(title: "Move buddy back to the corner", target: self, action: #selector(resetPos))
        let folder = NSButton(title: "Show save folder", target: self, action: #selector(showFolder))

        let stack = NSStackView(views: [
            row("Name", [nameField]),
            row("Size", [sizePopup]),
            row("Sound", [soundBox, volume]),
            row("", [quietBox]),
            row("Chatter", [thoughtsBox]),
            row("Second buddy", [friendPopup]),
            row("Startup", [loginBox]),
            row("", [loginNote]),
            row("", [reset, folder]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        w.contentView = stack
        w.center()
        window = w
    }

    private func refresh() {
        let p = BuddyProgress.shared
        nameField.stringValue = p.data.name
        sizePopup.selectItem(at: sizes.firstIndex { $0.1 == Prefs.scale } ?? 1)
        soundBox.state = Synth.shared.muted ? .off : .on
        volume.floatValue = Prefs.volume
        volume.isEnabled = !Synth.shared.muted
        quietBox.state = Prefs.quiet ? .on : .off
        thoughtsBox.state = Prefs.thoughts ? .on : .off

        friendPopup.removeAllItems()
        let skins = catalog.filter { $0.kind == .skin && p.isUnlocked($0) }
        for s in skins {
            friendPopup.addItem(withTitle: s.name)
            friendPopup.lastItem?.representedObject = s.id
        }
        if let i = skins.firstIndex(where: { $0.id == p.data.friendSkin }) { friendPopup.selectItem(at: i) }

        let agent = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/LaunchAgents/com.claude-buddy.plist")
        if agent {
            loginBox.state = .on
            loginBox.isEnabled = false
            loginNote.stringValue = "Already set up by install.sh --login."
        } else {
            loginBox.isEnabled = true
            loginBox.state = SMAppService.mainApp.status == .enabled ? .on : .off
            loginNote.stringValue = SMAppService.mainApp.status == .requiresApproval ? "Approve it in System Settings › General › Login Items." : ""
        }
    }

    @objc private func nameChanged() { BuddyProgress.shared.setName(nameField.stringValue) }
    func controlTextDidEndEditing(_ obj: Notification) { nameChanged() }

    @objc private func sizeChanged() {
        let s = sizes[max(0, sizePopup.indexOfSelectedItem)].1
        Prefs.scale = s
        onScale?(s)
    }
    @objc private func soundChanged() {
        Synth.shared.muted = soundBox.state == .off
        volume.isEnabled = !Synth.shared.muted
        Synth.shared.pop()
    }
    @objc private func volumeChanged() {
        Prefs.volume = volume.floatValue
        Synth.shared.applyVolume()
        if NSApp.currentEvent?.type == .leftMouseUp { Synth.shared.pop() }
    }
    @objc private func quietChanged() { Prefs.quiet = quietBox.state == .on }
    @objc private func thoughtsChanged() { Prefs.thoughts = thoughtsBox.state == .on }
    @objc private func friendChanged() {
        if let id = friendPopup.selectedItem?.representedObject as? String { BuddyProgress.shared.setFriendSkin(id) }
    }
    @objc private func loginChanged() {
        do {
            if loginBox.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginNote.stringValue = "Couldn't change it: \(error.localizedDescription)"
        }
        refresh()
    }
    @objc private func resetPos() { onResetPosition?() }
    @objc private func showFolder() { NSWorkspace.shared.activateFileViewerSelecting([saveURL]) }
}
