# Hardware Setup

## Requirements

- ComputerCraft: Tweaked mod
- 3-4 computers (transmitters) + 1 computer (gaming console)
- Wired modems and networking cable
- Redstone signal sources (buttons, levers, pressure plates, etc.)
- [Create mod](https://create.fandom.com/) (optional, for wireless controllers)
  - [Redstone Links](https://create.fandom.com/wiki/Redstone_Link) (2 per input)
  - [Linked Controllers](https://create.fandom.com/wiki/Linked_Controller) (1 per player)

## Network

All computers must be connected to the same wired modem network. Each transmitter and the gaming computer need a wired modem attached. The default communication channel is 123 (configurable in `config.lua`). Note: this needs to be manually changed in `rs_xmit.lua`

## Transmitter Computers

Each transmitter runs `rs_xmit.lua` and monitors 4 redstone sides: **top, left, right, back** (front and bottom are not used).

> **Note:** ComputerCraft sides are from the **computer's own perspective**, not yours. The computer faces toward you when placed (screen side = front), so its "left" and "right" are **mirrored** from your view when looking at the screen — like facing another person. If inputs seem swapped, this is likely why. Use `vgame --test` to verify mappings.

### Default Layout (3 transmitters)

The default `config.lua` maps 3 transmitters:

| Computer ID | Sides Used | Actions |
|-------------|-----------|---------|
| 15 | top, left, right, back | P1: up, left, right, down |
| 16 | top, left, right, back | P2: up, left, right, down |
| 17 | top, back, left, right | P1: action, alt / P2: action, alt |

Computer 17 is shared between both players for their action and alt buttons.

### Wiring

Connect a redstone signal source to the appropriate side of each transmitter. The transmitter detects analog signal strength (0-15), where 0 = released and any positive value = pressed.

Any redstone-producing block works (button, lever, pressure plate), but the recommended approach uses **Create mod Redstone Links** for wireless input. A Redstone Link acts as a wireless redstone transmitter/receiver pair — place one in transmit mode at the input location and one in receive mode adjacent to the transmitter computer.

Each Redstone Link is tuned to a frequency defined by **two items placed in its slots**. This is where the color coding scheme comes in: use a **Glazed Terracotta** block to identify the player and a **Wool** block to identify the action (see Color Coding below). For example, a link tuned with Blue Glazed Terracotta + Yellow Wool carries the Player 1 Up signal.

For the actual handheld controllers, use **Create Linked Controllers**. A Linked Controller is a handheld item that, when linked to a set of Redstone Links, sends redstone signals when the player presses its buttons (WASD + jump + sneak). Each player holds one Linked Controller that drives their 6 inputs wirelessly. Link each controller to the Redstone Links for that player's actions, and the signals arrive at the transmitter computers without any physical wiring from the player's position.

### Color Coding

Each Redstone Link uses two item slots to define its frequency. This build uses one slot for player identity and one for the action, making every link visually self-documenting:

**Slot 1 — Player (Glazed Terracotta):**
- Player 1: Blue Glazed Terracotta
- Player 2: Orange Glazed Terracotta

**Slot 2 — Action (Wool):**
- Up: Yellow Wool
- Down: Green Wool
- Left: Blue Wool
- Right: Red Wool
- Action: White Wool
- Alt: Black Wool

This gives each input a unique two-color frequency. For example:

| Link Frequency | Signal |
|----------------|--------|
| Blue Terracotta + Yellow Wool | Player 1 Up |
| Blue Terracotta + White Wool | Player 1 Action |
| Orange Terracotta + Red Wool | Player 2 Right |
| Orange Terracotta + Black Wool | Player 2 Alt |

The color scheme also makes the physical build readable at a glance — you can tell which player and action a link carries just by looking at it.

## Gaming Computer

The main computer runs `vgame.lua` and needs:

- A wired modem connected to the same network as the transmitters
- Optionally, an advanced monitor for a larger display (the console adapts to terminal size)

### Special Redstone Inputs

The gaming computer itself uses 2 redstone sides for system control:

| Side | Function | Behavior |
|------|----------|----------|
| **left** | Reset | Interrupts current game, returns to title screen |
| **right** | Power | Shuts down the computer completely (os.shutdown) |

Both have a 0.3-second debounce to prevent double-triggering.

## File Deployment

Upload the following to the gaming computer, preserving directory structure:

```
/vgame.lua
/config.lua
/lib/console.lua
/lib/input.lua
/lib/block_letters.lua
/games/game_pong.lua
/games/game_invaders.lua
/games/game_test_inputs.lua
```

Upload to each transmitter:

```
/rs_xmit.lua
```

## Testing

After wiring everything up:

1. Start `rs_xmit.lua` on each transmitter (they print debug messages on signal changes)
2. Run `vgame --test` on the gaming computer to launch the input test visualizer
3. Press each physical button and verify the correct indicator lights up on screen
4. If a button maps to the wrong action, adjust `config.keyMappings` in `config.lua`
