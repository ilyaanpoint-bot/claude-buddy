#!/bin/sh
# Installs Claude Buddy: builds the app, installs the hook script into ~/.claude/claude-buddy,
# and adds the Claude Code hooks to ~/.claude/settings.json (a backup is made first).
#
#   ./install.sh            install "Claude Buddy" into ~/Applications and start it
#   ./install.sh --login    also start buddy automatically when you log in
#
# Lost buddy, or quit him? Open "Claude Buddy" from Launchpad or Spotlight and he comes back.
set -e
cd "$(dirname "$0")"

DEST="$HOME/.claude/claude-buddy"
SETTINGS="$HOME/.claude/settings.json"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift isn't installed. Run:  xcode-select --install   then try again."
  exit 1
fi

APPS="$HOME/Applications"
APP="$APPS/Claude Buddy.app"

echo "→ Building Claude Buddy…"
./build.sh >/dev/null
pkill -x ClaudeBuddy 2>/dev/null || true
mkdir -p "$DEST" "$APPS"
rm -rf "$APP"
cp -R "build/Claude Buddy.app" "$APP"
cp hook.sh "$DEST/hook.sh"
chmod +x "$DEST/hook.sh"

echo "→ Adding Claude Code hooks to $SETTINGS…"
mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.backup-before-claude-buddy"
/usr/bin/python3 - "$SETTINGS" <<'EOF'
import json, os, sys
path = sys.argv[1]
s = json.load(open(path)) if os.path.exists(path) and os.path.getsize(path) else {}
hooks = s.setdefault("hooks", {})
for event, arg in [("UserPromptSubmit", "prompt"), ("PostToolUse", "tool"), ("Stop", "stop"),
                   ("Notification", "notify"), ("SessionEnd", "end")]:
    cmd = f"~/.claude/claude-buddy/hook.sh {arg}"
    entries = hooks.setdefault(event, [])
    if not any(h.get("command") == cmd for e in entries for h in e.get("hooks", [])):
        entries.append({"hooks": [{"type": "command", "command": cmd, "timeout": 5}]})
json.dump(s, open(path, "w"), indent=2)
open(path, "a").write("\n")
EOF

if [ "$1" = "--login" ]; then
  echo "→ Starting buddy at login…"
  PLIST="$HOME/Library/LaunchAgents/com.claude-buddy.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claude-buddy</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/ClaudeBuddy</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
else
  open "$APP"
fi

echo "✓ Claude Buddy is in the bottom-right corner of your screen."
echo "  Lost him or quit him? Open \"Claude Buddy\" from Launchpad or Spotlight and he comes right back."
echo "  New Claude Code sessions will talk to it. Double-click buddy to visit its room."
