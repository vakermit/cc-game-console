# game-console - Game Interface Specification

## Creating a New Game

1. Create `games/game_yourname.lua`
2. Return a table with the required methods below
3. The game appears in the menu automatically

## Required Methods

```lua
return {
    title = function()
        -- Returns: string (display name for menu)
        return "My Game"
    end,

    init = function(console)
        -- Called once when game is selected
        -- console.getWidth()  -> number (game area width in chars)
        -- console.getHeight() -> number (game area height in chars)
    end,

    update = function(dt, input)
        -- Called every tick (default 50ms)
        -- dt: number (seconds since last tick)
        -- input: table with methods:
        --   input.getPlayer(n) -> player table with:
        --     player.isDown("action")     -> bool (held this frame)
        --     player.wasPressed("action") -> bool (just pressed)
        --     player.wasReleased("action")-> bool (just released)
        --   Actions: "up", "down", "left", "right", "action", "alt"
    end,

    draw = function()
        -- Called every tick after update
        -- term is already redirected to the game window
        -- Use term.clear(), term.setCursorPos(), term.write() normally
    end,

    cleanup = function()
        -- Called when game exits (reset, menu return, crash)
    end,
}
```

## Optional Methods

```lua
    getControls = function()
        -- Returns table of {action, description} for help display
        return {
            { action = "left/right", description = "Move" },
            { action = "action",     description = "Fire" },
        }
    end,
```

## Network Message Format (transmitter.lua -> console)

Transmitters send on channel 123 (configurable in config.lua):
```lua
{
    side = "left"|"right"|"back"|"top",           -- which redstone side changed (4 sides)
    strength = 0-15,                               -- analog signal strength (0=released)
    computerID = number                            -- transmitter's os.getComputerID()
}
```

Key mappings in config.lua map (computerID, side) -> logical action (e.g., "p1_up").

## Test Mode

Run `game-console --test` to launch the input test visualizer. Shows real-time state of all 12 inputs (6 per player). Does not appear in the game selection menu. Hold alt+action to exit.

## Hardware Setup

- 4 transmitter computers: run transmitter.lua, wired to modem network (2 per player)
- Each transmitter uses 4 redstone sides: top, left, right, back
- 1 gaming computer: run game-console.lua, wired to same modem network
- Power button: redstone signal on "top" side of gaming computer
- Reset button: redstone signal on "back" side of gaming computer
- Computer IDs and side mappings configurable in config.lua
