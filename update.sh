#!/bin/sh
# Updates Claude Buddy to the latest version on GitHub and reinstalls it.
# Your XP, unlocks and settings are kept.
#
#   ./update.sh
set -e
cd "$(dirname "$0")"

if [ ! -d .git ]; then
  echo "This folder isn't a git clone. Download the latest with:"
  echo "  git clone https://github.com/ilyaanpoint-bot/claude-buddy.git"
  exit 1
fi

echo "→ Fetching the latest Claude Buddy…"
before=$(git rev-parse HEAD)
git pull --ff-only --quiet
after=$(git rev-parse HEAD)
if [ "$before" = "$after" ]; then
  echo "  Already up to date. Reinstalling anyway…"
else
  git --no-pager log --oneline "$before..$after" | sed 's/^/  • /'
fi

# Keep "start at login" if it was set up before.
if [ -f "$HOME/Library/LaunchAgents/com.claude-buddy.plist" ]; then
  exec ./install.sh --login
else
  exec ./install.sh
fi
