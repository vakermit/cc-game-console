# Architecture

## Overview

game-console is a split-architecture game console. Physical input is captured by dedicated transmitter computers and relayed over a wired modem network to a central gaming computer that runs the game loop and renders output.

## Components

### Transmitter (`transmitter.lua`)

Lightweight event-driven program. Monitors 4 redstone sides (top, left, right, back) for analog signal changes and broadcasts a message on each change containing the side name, signal strength, and the transmitter's computer ID.

Each player needs 2 transmitter computers to cover all 6 actions (4 sides per computer, 6 actions per player). One computer is shared between players for the action/alt buttons.

### Gaming Computer (`game-console.lua`)

Entry point that boots the console and runs four coroutines in parallel:

1. **Main loop** - Menu display, game selection, game execution
2. **Network listener** - Receives modem messages and maps them to input actions via `config.keyMappings`
3. **Redstone listener** - Monitors local redstone for reset and power-off signals
4. **Sound listener** - Processes the audio queue (notes, sounds, DFPWM files) via the speaker peripheral

### Console (`lib/console.lua`)

Core runtime that manages:

- **Window system** - Status bar (1 row) + game area (remainder of screen)
- **Game discovery** - Scans `games/` for `game_*.lua` files, loads and validates them
- **Menu** - Navigable game selection driven by Player 1 controls
- **Game loop** - Title screen → init → tick loop (update + draw at 20Hz) → cleanup
- **Exit detection** - Hold alt+action for ~1 second to return to menu

### Input (`lib/input.lua`)

Stateful input manager with per-tick edge detection:

- `set(action, value)` - Called by network listener on signal change
- `tick()` - Computes pressed/released edges from current vs. previous state
- `isDown(action)` / `wasPressed(action)` / `wasReleased(action)` - Queried by games
- `getPlayer(n)` - Returns a scoped interface that auto-prefixes actions with `pN_`

### Sound (`lib/sound.lua`)

Queue-based audio system. Games call `playNote`, `playSound`, `playNotes`, or `playFile` to enqueue audio. The listener coroutine processes the queue in the background, yielding between items. Supports CC:T note block instruments, Minecraft sound resources, melodies, and DFPWM file streaming. See [Sound System](sound.md) for full API reference.

### Block Letters (`lib/block_letters.lua`)

5x5 bitmap font renderer used for game title screens. Each glyph is stored as 5 rows of 5-bit integers.

## Data Flow

```
Physical buttons/levers
        │
        ▼
 Redstone signal (analog 0-15)
        │
        ▼
 Transmitter computer (transmitter.lua)
   Detects change on side → broadcasts modem message
        │
        ▼
 Wired modem network (channel 123)
        │
        ▼
 Gaming computer (console.networkListener)
   Looks up (computerID, side) in config.keyMappings
   Maps to logical action (e.g., "p1_up")
        │
        ▼
 input.set("p1_up", true/false)
        │
        ▼
 Game tick (20Hz)
   input.tick() computes edges
   game.update(dt, input) reads state
   game.draw() renders to game window
```

## Configuration

`config.lua` defines:

- **Network** - Modem channel (default 123)
- **System** - Tick rate (50ms = 20Hz), game directory, file prefix
- **Redstone** - Which sides of the gaming computer are reset/power, debounce timing
- **Key mappings** - Table mapping `[computerID][side]` → logical action string
- **Menu actions** - Which logical actions drive menu navigation
