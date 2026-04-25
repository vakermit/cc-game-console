local console = require("lib.console")
local config = require("config")
local sound = require("lib.sound")

local args = { ... }

sound.init()
console.init()

local function mainLoop()
    if args[1] == "--test" then
        console.runTestMode("game_test_inputs")
    elseif args[1] == "--test-audio" then
        console.runTestMode("game_test_audio")
    else
        local games = console.discoverGames()

        if #games == 0 then
            print("No games found in " .. config.system.gameDir .. "/")
            print("Place game_*.lua files there to play.")
            return
        end

        while console.isRunning() do
            local game = console.showMenu(games)
            if game then
                console.runGame(game)
            else
                break
            end
        end
    end
    console.shutdown()
end

parallel.waitForAny(
    mainLoop,
    console.networkListener,
    console.redstoneListener,
    sound.listener
)

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
