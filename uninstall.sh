#!/bin/sh
# Removes Claude Buddy's hooks and login item and quits it. Your save file (XP, unlocks)
# in ~/.claude/claude-buddy is left alone so you can reinstall later.
SETTINGS="$HOME/.claude/settings.json"
PLIST="$HOME/Library/LaunchAgents/com.claude-buddy.plist"

pkill -x ClaudeBuddy 2>/dev/null
[ -d "$HOME/Applications/Claude Buddy.app" ] && rm -rf "$HOME/Applications/Claude Buddy.app"
if [ -f "$PLIST" ]; then
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null
  mv "$PLIST" "$HOME/.claude/claude-buddy/com.claude-buddy.plist.disabled"
fi

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.backup-before-uninstall"
  /usr/bin/python3 - "$SETTINGS" <<'EOF'
import json, sys
path = sys.argv[1]
s = json.load(open(path))
hooks = s.get("hooks", {})
for event in list(hooks):
    kept = []
    for e in hooks[event]:
        e["hooks"] = [h for h in e.get("hooks", []) if "claude-buddy/hook.sh" not in h.get("command", "")]
        if e["hooks"]:
            kept.append(e)
    if kept: hooks[event] = kept
    else: del hooks[event]
json.dump(s, open(path, "w"), indent=2)
open(path, "a").write("\n")
EOF
fi
echo "✓ Claude Buddy removed. (Your progress is still in ~/.claude/claude-buddy/save.json)"
