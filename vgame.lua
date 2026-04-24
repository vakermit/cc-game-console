local console = require("lib.console")
local config = require("config")

local args = { ... }

console.init()

local function mainLoop()
    if args[1] == "--test" then
        console.runTestMode()
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
    console.redstoneListener
)

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Console shut down.")
os.sleep(8)
local monitor = peripheral.find("monitor")
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end
os.shutdown()
