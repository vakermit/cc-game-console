# cc-game-console

A game console platform for [ComputerCraft: Tweaked](https://tweaked.cc/) (Minecraft). 

Uses redstone signals over a wired modem network to provide physical arcade-style controls for 2-player games rendered on an in-game computer terminal.


<p align="center">
  <img src="docs/images/cc-game-console-block-breaker.png" width="600"/>
</p>

## How It Works

The system consists of transmitter computers wired to physical redstone inputs (buttons, levers, pressure plates) and a central gaming computer that runs the console. Transmitters detect redstone changes on 4 sides and broadcast them over the modem network. The gaming computer maps these signals to logical player actions (up, down, left, right, action, alt) and feeds them to whichever game is running.

Games are standalone Lua files that implement a simple interface (init, update, draw, cleanup) and get auto-discovered at startup.

## Project Structure

```
startup.lua          Auto-start: screensaver -> game-console loop
game-console.lua     Game console - menu, game selection, game loop
screensaver.lua      Screensaver engine - discovers and cycles screen modules
reset.lua            Utility - clears the monitor
config.lua           Hardware mappings, network channel, system settings
transmitter.lua      Signal transmitter program (runs on input computers)
simulate.lua         Local CC:Tweaked emulator - play games on macOS/Linux
simulate.sh          Emulator launcher - checks Lua, validates game, resizes iTerm2
lib/
  console.lua        Core console: menu, game loop, network/redstone listeners
  menu.lua           Reusable menu widget (select, toggle, scroll, hitTest)
  menugroup.lua      Focus manager composing multiple menus with edge transfer
  input.lua          Input state machine (held/pressed/released per action)
  sound.lua          Queue-based audio system (notes, sounds, DFPWM streaming)
  block_letters.lua  5x5 bitmap font renderer for title screens
  cards.lua          Card deck/hand management and rendering
  sprite.lua         Sprite loading and drawing system
  screen.lua         Shared utilities for screensaver modules
sounds/              DFPWM audio files for game music and effects
sprites/             Sprite definition files for game graphics
screens/
  screen_ball.lua    Bouncing ball with color-changing trail
  screen_cat.lua     Wandering ASCII cat with blinking eyes
  screen_fireworks.lua Firework rockets and particle explosions
  screen_matrix.lua  Cascading green character rain
games/
  game_adventure.lua Adventure - text-based exploration
  game_blackjack.lua Blackjack - single player card game
  game_blocks.lua    Falling Blocks - single player puzzle
  game_breakout.lua  Breakout - single player brick breaker
  game_flappy.lua    Flappy Bird - single player obstacle dodger
  game_invaders.lua  Space Invaders - single player shooter
  game_jurassic.lua  Jurassic Trail - survival narrative
  game_paku.lua      Paku Paku - single player maze chase
  game_pitfall.lua   Pitfall - side-scrolling platformer
  game_pong.lua      Pong - 2 player paddle game
  game_road_racer.lua Road Racer - single player top-down racer
  game_snake.lua     Snake - 1-2 player classic
  game_tictactoe.lua Tic Tac Toe - 2 player strategy
  game_trek.lua      Star Trek - tactical space combat
  game_wumpus.lua    Hunt the Wumpus - text adventure
  game_test_inputs.lua Input test visualizer (--test flag)
  game_test_audio.lua  Audio test tool (--test-audio flag)
```

## Quick Start

1. **Transmitter computers** - Place computers with wired modems, connect to network. Upload `transmitter.lua` and run it on each.
2. **Gaming computer** - Place a computer with an advanced monitor and wired modem on the same network. Upload all project files preserving the directory structure.
3. **Configure** - Edit `config.lua` to map your transmitter computer IDs and redstone sides to player actions.
4. **Run** - Execute `game-console` on the gaming computer.

## Auto-Start

ComputerCraft runs `startup.lua` automatically when a computer boots. The included `startup.lua` loops between the screensaver and the game console:

1. Boot → screensaver runs on the monitor
2. Any input (button press, redstone, network signal) → wakes into the game menu
3. Selecting "Shutdown" from the menu → returns to the screensaver

For transmitter computers, create a `startup.lua` with:

```lua
shell.run("transmitter")
```

With startup files in place, the entire arcade boots itself when the Minecraft chunk loads. To bypass auto-start and get a shell prompt, hold **Ctrl+T** during boot.

## Local Simulator

Play games on your Mac or Linux machine without Minecraft using the included CC:Tweaked emulator.

**Requirements:** Lua 5.3+ (`brew install lua` on macOS)

```bash
# Run a specific game
./simulate.sh pong
./simulate.sh snake

# Run the full game console with menu
./simulate.sh --console

# List available games
./simulate.sh --list

# Headless test (verifies game loads and runs 5 frames)
lua simulate.lua --test pong
```

**Simulator Controls:**

| Player 1 | Player 2 | System |
|-----------|----------|--------|
| W/A/S/D - move | Arrow keys - move | ESC - quit |
| Space - action | Enter - action | |
| Z - alt | | |

The simulator emulates all CC:Tweaked APIs (term, window, colors, fs, os, peripheral, parallel, textutils, redstone, keys) using ANSI terminal rendering. Sound is silently stubbed. Screen size defaults to 61x26 and can be changed in the `SIM_CONFIG` table at the top of `simulate.lua`.

**iTerm2 (macOS):** The launcher auto-resizes the terminal window to fit the game screen. For a larger font during gameplay, create an iTerm2 profile named "GameConsole" with your preferred font size — the simulator will switch to it automatically and restore your original profile on exit.

## Controls

Menu navigation uses Player 1's up/down/action buttons. During gameplay, hold alt+action (Player 1) for ~1 second to return to the menu. A redstone signal on the "left" side of the gaming computer acts as a reset button; "right" side returns to the screensaver.

## Test Mode

Run `game-console --test` to launch an input test visualizer that shows the real-time state of all 12 inputs (6 per player) without loading a game.

## Writing Games

See [INTERFACE.md](docs/INTERFACE.md) for the full game API specification. The short version: create `games/game_yourname.lua`, return a table with `title()`, `init(console)`, `update(dt, input)`, `draw()`, and `cleanup()` methods. The file is auto-discovered on next boot.

## Documentation

Additional documentation is in the [docs/](docs/) directory:

- [Architecture](docs/architecture.md) - System design and data flow
- [Hardware Setup](docs/hardware.md) - Physical build guide and wiring
- [Sound System](docs/sound.md) - Audio API, DFPWM files, and ffmpeg conversion

## Disclaimer

The games included in this repository are **independent, original sample implementations** created for educational and personal use. They are simple demonstrations of the game-console platform's capabilities and are not affiliated with, endorsed by, or derived from any commercial video game products.

Any resemblance to existing commercial games is due to the generic nature of the game mechanics involved (e.g., bouncing a ball between paddles, shooting descending enemies). These mechanics are common game design patterns that predate any specific commercial implementation and are not protected by copyright. No proprietary code, assets, names, or trademarks from any commercial game have been used.

See [LICENSE](LICENSE) for full terms.

## License

MIT License - See [LICENSE](LICENSE) for details.
