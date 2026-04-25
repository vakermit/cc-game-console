# Sound System

## Overview

The sound system (`lib/sound.lua`) provides non-blocking audio playback for the game console. It runs as a background coroutine alongside the game loop, processing a queue of sound requests without interrupting gameplay.

A CC:T Speaker peripheral must be attached to the gaming computer. If no speaker is found, all sound functions are no-ops.

## Architecture

```
Game code                    Sound queue              Speaker peripheral
   │                            │                          │
   ├─ sound.playNote(...)  ──▶  │  { type="note", ... }   │
   ├─ sound.playSound(...) ──▶  │  { type="sound", ... }  │
   ├─ sound.playNotes(...) ──▶  │  { type="note" }...     │
   ├─ sound.playFile(...)  ──▶  │  { type="file", ... }   │
   │                            │                          │
   │                     sound.listener() ──────────────▶  │
   │                     (background coroutine)            │
   │                     processes queue items              │
   │                     yields between items               │
```

The listener coroutine is started in `vgame.lua` as the 4th `parallel.waitForAny` worker. Games never interact with the speaker directly.

## API Reference

### `sound.init()`

Finds the speaker peripheral and reads the `config.sound.enabled` default. Called once at startup in `vgame.lua`.

### `sound.playNote(instrument, volume, pitch)`

Queues a single note block sound.

- **instrument** (string): `"harp"`, `"basedrum"`, `"snare"`, `"hat"`, `"bass"`, `"flute"`, `"bell"`, `"guitar"`, `"chime"`, `"xylophone"`, `"iron_xylophone"`, `"cow_bell"`, `"didgeridoo"`, `"bit"`, `"banjo"`, `"pling"`
- **volume** (number, optional): `0.0–3.0`, default `1.0`
- **pitch** (number, optional): `0–24` semitones, default `12` (middle)

### `sound.playSound(name, volume, pitch)`

Queues a Minecraft sound effect.

- **name** (string): Minecraft resource location, e.g. `"entity.experience_orb.pickup"`, `"entity.lightning_bolt.thunder"`
- **volume** (number, optional): `0.0–3.0`, default `1.0`
- **pitch** (number, optional): `0.5–2.0` speed multiplier, default `1.0`

### `sound.playNotes(notes, tempo)`

Queues a melody — a sequence of notes with rests between them.

- **notes** (table): Array of `{ instrument, volume, pitch, rest }` tables. `instrument` defaults to `"harp"`, `rest` is pause duration in ticks (1 tick = 0.05s)
- **tempo** (number, optional): Default rest between notes if `rest` is not specified per note. Default `4` (0.2s)

Example:
```lua
sound.playNotes({
    { pitch = 12, rest = 2 },
    { pitch = 16, rest = 2 },
    { pitch = 19, rest = 4 },
    { instrument = "bell", pitch = 24, rest = 6 },
})
```

### `sound.playFile(filename, volume)`

Queues a DFPWM audio file for streaming playback.

- **filename** (string): File name relative to the `sounds/` directory, e.g. `"theme.dfpwm"`
- **volume** (number, optional): Default `1.0`

The file is streamed in 16KB chunks through the `cc.audio.dfpwm` decoder at 48kHz. Playback yields between chunks so it never blocks the game loop. If sound is disabled mid-playback, streaming stops immediately.

### `sound.stop()`

Clears the queue and stops the speaker immediately. Use when transitioning between game states or exiting a game.

### `sound.setEnabled(val)` / `sound.isEnabled()`

Toggle sound on/off. Disabling stops current playback immediately. The toggle is accessible from the game title screen (Play / Sound menu).

### `sound.hasSpeaker()`

Returns `true` if a speaker peripheral was found during init.

### Built-in Jingles

- `sound.menuBeep()` — Short hi-hat tick for menu navigation
- `sound.menuSelect()` — Two-note harp rising for menu selection
- `sound.gameOver()` — Descending harp + bass for game over
- `sound.victory()` — Ascending harp + bell for victory

## Creating DFPWM Audio Files

DFPWM (Dynamic Filter Pulse Width Modulation) is the audio format used by CC:T speakers. Files must be mono, 48kHz.

### Converting with ffmpeg

Convert any audio file to DFPWM:

```bash
ffmpeg -i input.mp3 -ac 1 -ar 48000 -c:a dfpwm output.dfpwm
```

Extract a specific section (start at 30s, duration 60s):

```bash
ffmpeg -ss 00:00:30 -t 00:01:00 -i input.mp3 -ac 1 -ar 48000 -c:a dfpwm output.dfpwm
```

Common options:

| Flag | Purpose |
|------|---------|
| `-i input.mp3` | Input file (any format ffmpeg supports) |
| `-ac 1` | Mono (required — speakers are mono) |
| `-ar 48000` | 48kHz sample rate (required — CC:T playback rate) |
| `-c:a dfpwm` | DFPWM codec output |
| `-ss HH:MM:SS` | Start time (place before `-i` for fast seek) |
| `-t HH:MM:SS` | Duration |
| `-af "volume=0.5"` | Adjust volume before encoding |

### File Placement

Place `.dfpwm` files in the `sounds/` directory on the gaming computer. Games reference them by filename:

```lua
sound.playFile("theme.dfpwm")
```

The Audio Test tool (`vgame --test-audio`) has a Files section that lists all `.dfpwm` files in `sounds/` for testing playback.

## Configuration

In `config.lua`:

```lua
config.sound = {
    enabled = true,  -- default sound state on startup
}
```

## Adding Sound to a Game

```lua
local sound = require("lib.sound")

-- In game events:
sound.playNote("bell", 1.0, 18)           -- single note
sound.playSound("entity.player.levelup")  -- minecraft sound
sound.playFile("victory.dfpwm")           -- audio file
sound.playNotes({...})                    -- melody sequence

-- On game over:
sound.gameOver()

-- In cleanup:
function game.cleanup()
    sound.stop()
end
```

Always call `sound.stop()` in your game's `cleanup()` to prevent audio bleeding into the menu.
