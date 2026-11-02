# Claude Buddy

A tiny desktop companion for **Claude Code** on macOS. It sits in the corner of your screen and
reacts to your Claude Code sessions. It thinks while Claude works, celebrates when a task is done,
and waves at you when Claude needs your permission. It also has its own little world: a room, XP,
unlockables, mini-games, secrets and quite a temper.

![Buddy's moods](docs/moods.png)

> Unofficial fan project. Not affiliated with or endorsed by Anthropic. "Claude" is a trademark of Anthropic.
> On Windows? → [claude-buddy-windows](https://github.com/ilyaanpoint-bot/claude-buddy-windows)

## What's new in 2.0

- **Coins 🪙 and a shop.** Earn coins from finished sessions, games, quests and level-ups. Spend them on
  furniture, wallpaper, floors, outfits and two new rooms. There's a 30%-off deal every day.
- **Daily quests and streaks.** Three new quests each day, plus a bonus for coming back day after day.
- **Room editor (🛠️).** Drag furniture where you want it, put things away, and pick wallpaper and floors.
- **Arcade with 5 games:** Bug Catch, Copycat, and the new Whack-a-Bug, Buddy Hop and Type Rush.
- **More looks:** 11 new skins (Panda, Galaxy, Lava, Robot…), 8 new hats, and a new accessory slot
  (sunglasses, glasses, bow tie, scarf, mustache, monocle…).
- **New rooms:** Snowy Cabin, Synthwave, Coral Reef. New furniture: disco ball, fairy lights, lava lamp,
  beanbag, wall clock, cactus, trophy case.
- **Focus timer 🍅** (right-click buddy → Focus timer). Buddy keeps watch and pays out when you finish.
- **"All done" shows how long the session took.**
- **Settings window:** name your buddy, size, volume, quiet mode, the second buddy's skin, launch at login.
- **Hide for 1 hour** (buddy pops back if Claude needs you).
- **Fixes:** a memory leak (~50 MB/hour), much lower CPU use when idle, wardrobe items and trophies that
  were cut off, keys sticking between games, games that kept running after the room closed.

Your XP, unlocks and scores carry over, plus a coin gift for upgrading.

## Features

- **Knows what Claude Code is doing** (through Claude Code hooks):
  - Thinking animation while a session runs.
  - Hops, sparkles and a chime when it finishes.
  - A "needs your permission" alert.
  - Click the speech bubble to jump back to your terminal.
- **Two sessions at once?** A blue friend appears, and each buddy follows its own session.
- **Its own room** (double-click buddy):
  - Buddy walks around and works at its desk while Claude runs.
  - It sleeps in bed when you're away, and the window shows the real time of day.
- **XP and levels** from finished sessions, petting, cookies and games. Leveling up unlocks:
  - **skins:** Mint, Grape, Midnight, Golden and more
  - **hats:** party hat, wizard hat, crown and more
  - **rooms:** Greenhouse, Space Station and more
  - **furniture:** plant, fish tank, arcade, a cat and more
- **Mini-games:** Bug Catch and Copycat.
- **Personality:**
  - Eyes that follow your cursor.
  - Idle routines: juggling, whistling, sneezing, coffee.
  - Random thoughts, and sounds generated live.
- **A temper.** Poke him too much, fling him across the screen, squish him or honk at him, and
  he gets angry. At the end he turns into a little devil and throws bombs across your screen. Click
  them to defuse them. 😈
- **Cookies:** too many make him sick, so keep some medicine handy.
- **Secrets.** Try typing `sudo buddy` in his room's console. There are more to find.

![Buddy's room](docs/room.png)

## Install

You need macOS 14 or later with Swift (`xcode-select --install` if you don't have it) and
[Claude Code](https://claude.com/claude-code).

```sh
git clone https://github.com/ilyaanpoint-bot/claude-buddy.git
cd claude-buddy
./install.sh            # or: ./install.sh --login   to start buddy whenever you log in
```

The installer:

1. builds **Claude Buddy.app** into `~/Applications`, so it's in Launchpad and Spotlight
2. installs `hook.sh` into `~/.claude/claude-buddy/`
3. adds five hooks to `~/.claude/settings.json`: `UserPromptSubmit`, `PostToolUse`, `Stop`,
   `Notification`, `SessionEnd`

It backs up your settings first and never removes your existing hooks. Claude Code sessions you
start after installing will talk to buddy.

**Lost buddy, or quit him?** Open **Claude Buddy** from Launchpad or Spotlight and he comes straight
back to the corner and waves. If he ends up off-screen (say, you unplug a display), he comes back
by himself.

To update to the latest version: `./update.sh` from the same folder. It pulls the newest code
from GitHub and reinstalls; your XP and unlocks are kept.

To remove it: `./uninstall.sh` (your XP and unlocks are kept).

## How it works

```
Claude Code ──hooks──▶ hook.sh ──appends a JSON line──▶ ~/.claude/claude-buddy/events.jsonl
                                                                  │
                                       ClaudeBuddy.app tails it ◀─┘
```

`hook.sh` only writes the event name, session ID, working-folder path and notification message
to a local file. Nothing leaves your Mac.

## Controls

| Do this | And buddy… |
|---|---|
| Click | giggles (and earns XP) |
| Double-click | opens the room |
| Click 5 times fast | gets dizzy |
| Drag | moves; flick hard to fling him |
| Click and hold | squishes |
| Wiggle the cursor on him | is tickled |
| Right-click | opens the menu: feed, honk, tease, medicine, games, wardrobe, sounds |

## Develop

```sh
./build.sh && open "build/Claude Buddy.app"
```

Everything is plain AppKit drawn by hand, with no assets or dependencies. The source files:

- `Character.swift`: looks and animation
- `Personality.swift`: temper and behaviours
- `Rage.swift`: the bomb tantrum
- `Room.swift`: the room
- `Copycat.swift`: the Copycat game
- `Sound.swift`, `SoundFX.swift`: the synth
- `Progress.swift`: XP and unlocks

PRs with new hats, rooms, games and secrets are very welcome.

## License

MIT
