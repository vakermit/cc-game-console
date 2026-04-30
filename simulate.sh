#!/usr/bin/env bash
#
# CC:Tweaked Game Simulator launcher
# Usage: ./simulate.sh <game_name>
#        ./simulate.sh --console
#        ./simulate.sh --list

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Find Lua ---
LUA_BIN=""
for candidate in lua lua5.4 lua5.3; do
    if command -v "$candidate" &>/dev/null; then
        LUA_BIN="$candidate"
        break
    fi
done

if [ -z "$LUA_BIN" ]; then
    echo "ERROR: Lua is not installed."
    echo ""
    echo "Install Lua 5.3+ using one of:"
    echo ""
    if [ "$(uname)" = "Darwin" ]; then
        echo "  macOS:   brew install lua"
    fi
    echo "  Ubuntu:  sudo apt install lua5.4"
    echo "  Fedora:  sudo dnf install lua"
    echo "  Generic: https://www.lua.org/download.html"
    exit 1
fi

# --- Check Lua version ---
LUA_VERSION=$($LUA_BIN -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
LUA_MAJOR=$(echo "$LUA_VERSION" | cut -d. -f1)
LUA_MINOR=$(echo "$LUA_VERSION" | cut -d. -f2)

if [ "$LUA_MAJOR" -lt 5 ] || { [ "$LUA_MAJOR" -eq 5 ] && [ "$LUA_MINOR" -lt 3 ]; }; then
    echo "ERROR: Lua $LUA_VERSION found, but 5.3+ is required."
    echo "Found: $($LUA_BIN -v 2>&1)"
    echo ""
    if [ "$(uname)" = "Darwin" ]; then
        echo "Upgrade with: brew upgrade lua"
    else
        echo "Please install Lua 5.3 or newer."
    fi
    exit 1
fi

# --- Usage ---
if [ $# -eq 0 ]; then
    echo "CC:Tweaked Game Simulator"
    echo ""
    echo "Usage: $0 <game_name>    Run a specific game"
    echo "       $0 --console      Run the full game console"
    echo "       $0 --list         List available games"
    echo ""
    echo "Examples:"
    echo "  $0 pong"
    echo "  $0 snake"
    echo "  $0 game_flappy"
    echo ""
    echo "Controls:"
    echo "  Player 1: W/A/S/D + Space (action) + Z (alt)"
    echo "  Player 2: Arrow keys + Enter (action)"
    echo "  ESC: Quit simulator"
    echo ""
    echo "Using: $($LUA_BIN -v 2>&1)"
    exit 0
fi

GAME_NAME="$1"
shift

# --- Helpers ---
list_games() {
    for f in "$SCRIPT_DIR"/games/game_*.lua; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .lua)
        name=${name#game_}
        case "$name" in
            test_*) continue ;;
        esac
        echo "  $name"
    done
}

# --- List mode ---
if [ "$GAME_NAME" = "--list" ]; then
    echo "Available games:"
    list_games
    exit 0
fi

# --- Validate game ---
if [ "$GAME_NAME" != "--console" ]; then
    CLEAN_NAME="${GAME_NAME%.lua}"
    CLEAN_NAME="${CLEAN_NAME#game_}"

    GAME_FILE="$SCRIPT_DIR/games/game_${CLEAN_NAME}.lua"
    if [ ! -f "$GAME_FILE" ]; then
        echo "ERROR: Game not found: game_${CLEAN_NAME}.lua"
        echo ""
        echo "Available games:"
        list_games
        exit 1
    fi
fi

# --- Launch ---
cd "$SCRIPT_DIR"
exec "$LUA_BIN" simulate.lua "$GAME_NAME" "$@"
