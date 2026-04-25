# cc-game-console

A game console platform for [ComputerCraft: Tweaked](https://tweaked.cc/) (Minecraft). Uses redstone signals over a wired modem network to provide physical arcade-style controls for 2-player games rendered on an in-game computer terminal.

## How It Works

The system consists of transmitter computers wired to physical redstone inputs (buttons, levers, pressure plates) and a central gaming computer that runs the console. Transmitters detect redstone changes on 4 sides and broadcast them over the modem network. The gaming computer maps these signals to logical player actions (up, down, left, right, action, alt) and feeds them to whichever game is running.

Games are standalone Lua files that implement a simple interface (init, update, draw, cleanup) and get auto-discovered at startup.

## Project Structure

```
startup.lua          Auto-start: screensaver -> vgame loop
vgame.lua            Game console - menu, game selection, game loop
screensaver.lua      Screensaver engine - discovers and cycles screen modules
reset.lua            Utility - clears the monitor
config.lua           Hardware mappings, network channel, system settings
transmitter.lua      Signal transmitter program (runs on input computers)
lib/
  console.lua        Core console: menu, game loop, network/redstone listeners
  input.lua          Input state machine (held/pressed/released per action)
  sound.lua          Queue-based audio system (notes, sounds, DFPWM streaming)
  block_letters.lua  5x5 bitmap font renderer for title screens
  cards.lua          Card deck/hand management and rendering
  screen.lua         Shared utilities for screensaver modules
sounds/              DFPWM audio files for game music and effects
screens/
  screen_ball.lua    Bouncing ball with color-changing trail
  screen_cat.lua     Wandering ASCII cat with blinking eyes
  screen_fireworks.lua Firework rockets and particle explosions
  screen_matrix.lua  Cascading green character rain
games/
  game_blackjack.lua Blackjack - single player card game
  game_blocks.lua    Falling Blocks - single player puzzle
  game_invaders.lua  Space Invaders - single player shooter
  game_jurassic.lua  Jurassic Trail - survival narrative
  game_paku.lua      Paku Paku - single player maze chase
  game_pong.lua      Pong - 2 player paddle game
  game_road_racer.lua Road Racer - single player top-down racer
  game_trek.lua      Star Trek - tactical space combat
  game_test_inputs.lua Input test visualizer (--test flag)
  game_test_audio.lua  Audio test tool (--test-audio flag)
```

## Quick Start

1. **Transmitter computers** - Place computers with wired modems, connect to network. Upload `transmitter.lua` and run it on each.
2. **Gaming computer** - Place a computer with an advanced monitor and wired modem on the same network. Upload all project files preserving the directory structure.
3. **Configure** - Edit `config.lua` to map your transmitter computer IDs and redstone sides to player actions.
4. **Run** - Execute `vgame` on the gaming computer.

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

## Controls

Menu navigation uses Player 1's up/down/action buttons. During gameplay, hold alt+action (Player 1) for ~1 second to return to the menu. A redstone signal on the "left" side of the gaming computer acts as a reset button; "right" side returns to the screensaver.

## Test Mode

Run `vgame --test` to launch an input test visualizer that shows the real-time state of all 12 inputs (6 per player) without loading a game.

## Writing Games

See [INTERFACE.md](docs/INTERFACE.md) for the full game API specification. The short version: create `games/game_yourname.lua`, return a table with `title()`, `init(console)`, `update(dt, input)`, `draw()`, and `cleanup()` methods. The file is auto-discovered on next boot.

## Documentation

Additional documentation is in the [docs/](docs/) directory:

- [Architecture](docs/architecture.md) - System design and data flow
- [Hardware Setup](docs/hardware.md) - Physical build guide and wiring
- [Sound System](docs/sound.md) - Audio API, DFPWM files, and ffmpeg conversion

## Disclaimer

The games included in this repository are **independent, original sample implementations** created for educational and personal use. They are simple demonstrations of the vgame platform's capabilities and are not affiliated with, endorsed by, or derived from any commercial video game products.

Any resemblance to existing commercial games is due to the generic nature of the game mechanics involved (e.g., bouncing a ball between paddles, shooting descending enemies). These mechanics are common game design patterns that predate any specific commercial implementation and are not protected by copyright. No proprietary code, assets, names, or trademarks from any commercial game have been used.

See [LICENSE](LICENSE) for full terms.

## License

MIT License - See [LICENSE](LICENSE) for details.
