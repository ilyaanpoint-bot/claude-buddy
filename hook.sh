#!/bin/sh
# Claude Buddy hook: appends one small JSON line per Claude Code event for the corner animation.
# Usage (from ~/.claude/settings.json): hook.sh prompt|tool|stop|notify|end

payload=$(cat)
# Only the first part of the payload is needed (tool payloads can be huge).
head=$(printf '%.3000s' "$payload" | tr -d '\n\r')

field() {
  printf '%s' "$head" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | sed 's/\\$//'
}

printf '{"event":"%s","app":"%s","session_id":"%s","cwd":"%s","message":"%s","type":"%s"}\n' \
  "$1" "${__CFBundleIdentifier:-$TERM_PROGRAM}" "$(field session_id)" "$(field cwd)" \
  "$(field message)" "$(field notification_type)" \
  >> "$HOME/.claude/claude-buddy/events.jsonl" 2>/dev/null
exit 0
