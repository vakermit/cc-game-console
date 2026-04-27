local input = require("lib.input")
local config = require("config")
local block_letters = require("lib.block_letters")
local sound = require("lib.sound")
local Menu = require("lib.menu")
local MenuGroup = require("lib.menugroup")

local console = {}

local statusWin, gameWin
local originalTerm
local consoleWidth, consoleHeight
local running = true
local resetFlag = false
local powerFlag = false
local lastResetTime = 0
local lastPowerTime = 0

function console.init()
    input.init()

    originalTerm = term.current()
    local monitor = peripheral.find("monitor")
    if monitor then
        term.redirect(monitor)
    end

    local w, h = term.getSize()
    statusWin = window.create(term.current(), 1, 1, w, 1)
    gameWin = window.create(term.current(), 1, 2, w, h - 1)

    consoleWidth = w
    consoleHeight = h - 1

    return console
end

function console.getWidth()
    return consoleWidth
end

function console.getHeight()
    return consoleHeight
end

local function drawStatus(text)
    local old = term.redirect(statusWin)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    local w = consoleWidth
    local pad = w - #text
    if pad > 0 then
        term.write(text .. string.rep(" ", pad))
    else
        term.write(text:sub(1, w))
    end
    term.redirect(old)
end

local function clearGame()
    local old = term.redirect(gameWin)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.redirect(old)
end

function console.discoverGames()
    local gameDir = config.system.gameDir
    local prefix = config.system.gamePrefix
    local games = {}

    if not fs.exists(gameDir) or not fs.isDir(gameDir) then
        return games
    end

    local files = fs.list(gameDir)
    for _, file in ipairs(files) do
        if file:sub(1, #prefix) == prefix and file:sub(-4) == ".lua" then
            local name = file:sub(1, -5)
            if not name:find("_test_") then
                local modPath = gameDir .. "." .. name
                local ok, game = pcall(require, modPath)
                if ok and type(game) == "table" and type(game.title) == "function" then
                    table.insert(games, game)
                end
            end
        end
    end

    table.sort(games, function(a, b) return a.title():lower() < b.title():lower() end)

    return games
end

local menuColors = {
    colors.cyan, colors.yellow, colors.lime, colors.orange,
    colors.lightBlue, colors.magenta, colors.pink, colors.red,
}

function console.showMenu(games)
    drawStatus("game-console - Select a game")

    local gw, gh = gameWin.getSize()

    local gameItems = {}
    for i, g in ipairs(games) do
        local itemColor = menuColors[((i - 1) % #menuColors) + 1]
        table.insert(gameItems, {
            label = g.title(),
            color = itemColor,
            highlight_bg = itemColor,
            highlight_fg = colors.black,
            data = g,
        })
    end

    local gameMenuY = math.max(1, math.floor((gh - #games - 2) / 2))

    local gameMenu = Menu.new({
        x = 1,
        y = gameMenuY,
        width = gw,
        centered = true,
        max_rows = gh - 2,
        up_action = config.actions.menu_up,
        down_action = config.actions.menu_down,
        select_action = config.actions.menu_select,
        items = gameItems,
    })

    local shutdownMenu = Menu.new({
        x = 1,
        y = gh,
        width = gw,
        centered = true,
        max_rows = 1,
        focused = false,
        up_action = config.actions.menu_up,
        down_action = config.actions.menu_down,
        select_action = config.actions.menu_select,
        items = {
            { label = "Shutdown", color = colors.gray,
              highlight_bg = colors.red, highlight_fg = colors.white },
        },
    })

    local group = MenuGroup.new({
        menus = { gameMenu, shutdownMenu },
        up_action = config.actions.menu_up,
        down_action = config.actions.menu_down,
        select_action = config.actions.menu_select,
    })

    group:onEvent(function(ev)
        if ev.type == "navigate" or ev.type == "focus" then
            sound.menuBeep()
        end
    end)

    local old = term.redirect(gameWin)
    term.setBackgroundColor(colors.black)
    term.clear()

    local result = group:run(config.system.tickRate, input)
    term.redirect(old)

    if not result or not result.item.data then
        sound.menuSelect()
        return nil
    end

    sound.menuSelect()
    return result.item.data
end

local function drawTitleArt(gw, gh, words, controls)
    local lineHeight = 6
    local totalHeight = #words * lineHeight - 1
    local ty = math.max(1, math.floor((gh - totalHeight) / 2) - 4)

    for i, word in ipairs(words) do
        local wordW = block_letters.width(word)
        local wx = math.max(1, math.floor((gw - wordW) / 2) + 1)
        local wy = ty + (i - 1) * lineHeight
        block_letters.draw(wx, wy, word)
    end

    local menuY = ty + totalHeight + 2

    if controls then
        local cy = menuY + 3
        term.setTextColor(colors.lightGray)
        term.setBackgroundColor(colors.black)
        for _, ctrl in ipairs(controls) do
            local line = ctrl.action .. " - " .. ctrl.description
            term.setCursorPos(math.floor((gw - #line) / 2) + 1, cy)
            term.write(line)
            cy = cy + 1
        end
    end

    return menuY
end

local function showTitleScreen(game)
    drawStatus(game.title())

    local gw, gh = gameWin.getSize()
    local title = game.title():upper()
    local words = {}
    for word in title:gmatch("%S+") do
        table.insert(words, word)
    end
    local controls = game.getControls and game.getControls() or nil

    local old = term.redirect(gameWin)
    term.setBackgroundColor(colors.black)
    term.clear()
    local menuY = drawTitleArt(gw, gh, words, controls)
    term.redirect(old)

    local titleMenu = Menu.new({
        x = 1,
        y = menuY,
        width = gw,
        centered = true,
        max_rows = 2,
        up_action = config.actions.menu_up,
        down_action = config.actions.menu_down,
        select_action = config.actions.menu_select,
        items = {
            { label = "Play", color = colors.white },
            { label = function()
                return "Sound: " .. (sound.isEnabled() and "ON" or "OFF")
              end,
              color = colors.gray, action = "toggle", value = sound.isEnabled() },
        },
    })

    old = term.redirect(gameWin)

    local timerId = os.startTimer(config.system.tickRate)
    while running and not resetFlag and not powerFlag do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            input.tick()
            local result = titleMenu:handleInput(input)
            if result then
                if result.type == "select" then
                    sound.menuSelect()
                    term.redirect(old)
                    return true
                elseif result.type == "toggle" then
                    sound.setEnabled(result.value)
                    sound.menuBeep()
                elseif result.type == "navigate" then
                    sound.menuBeep()
                end
            end
            term.setBackgroundColor(colors.black)
            term.clear()
            drawTitleArt(gw, gh, words, controls)
            titleMenu:draw()
            timerId = os.startTimer(config.system.tickRate)
        end
    end

    term.redirect(old)
    return false
end

local function showEndGameMenu()
    local gw, gh = gameWin.getSize()

    local endMenu = Menu.new({
        x = 1,
        y = gh,
        width = gw,
        centered = true,
        horizontal = true,
        max_columns = 2,
        highlight_fg = colors.black,
        highlight_bg = colors.white,
        default_color = colors.lightGray,
        up_action = "p1_left",
        down_action = "p1_right",
        select_action = config.actions.menu_select,
        items = {
            { label = "Replay", data = "replay" },
            { label = "Exit", data = "exit" },
        },
    })

    drawStatus("Game Over")

    local old = term.redirect(gameWin)
    local elapsed = 0
    local timeout = 20
    local timerId = os.startTimer(config.system.tickRate)

    while running and not resetFlag and not powerFlag do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            input.tick()
            elapsed = elapsed + config.system.tickRate

            if elapsed >= timeout then
                term.redirect(old)
                sound.menuSelect()
                return "replay"
            end

            local result = endMenu:handleInput(input)
            if result then
                if result.type == "select" then
                    term.redirect(old)
                    sound.menuSelect()
                    return result.item.data == "replay" and "replay" or "exit"
                elseif result.type == "navigate" then
                    sound.menuBeep()
                end
            end

            local countdownLabel = "(" .. math.max(0, math.floor(timeout - elapsed)) .. ")"
            term.setCursorPos(math.floor((gw - #countdownLabel) / 2), gh - 1)
            term.setTextColor(colors.lightGray)
            term.setBackgroundColor(colors.black)
            term.write(countdownLabel)

            endMenu:draw()
            timerId = os.startTimer(config.system.tickRate)
        end
    end

    term.redirect(old)
    return "exit"
end

function console.runGame(game)
    resetFlag = false

    while true do
        clearGame()

        if not showTitleScreen(game) then
            clearGame()
            return
        end

        clearGame()

        local old = term.redirect(gameWin)
        local ok, err = pcall(game.init, console)
        term.redirect(old)

        if not ok then
            drawStatus("Error: " .. tostring(err))
            os.sleep(3)
            return
        end

        drawStatus("Playing: " .. game.title())

        local tickRate = config.system.tickRate
        local timerId = os.startTimer(tickRate)
        local backHoldCount = 0
        local backAction1 = config.actions.back_hold1
        local backAction2 = config.actions.back_hold2
        local backThreshold = config.actions.back_ticks
        local gameEnded = false

        while running and not resetFlag and not powerFlag do
            local event, p1 = os.pullEvent()
            if event == "timer" and p1 == timerId then
                input.tick()

                if input.isDown(backAction1) and input.isDown(backAction2) then
                    backHoldCount = backHoldCount + 1
                    if backHoldCount >= backThreshold then
                        pcall(game.cleanup)
                        clearGame()
                        return
                    end
                else
                    backHoldCount = 0
                end

                old = term.redirect(gameWin)
                local gok, gerr = pcall(game.update, tickRate, input)
                if gok then
                    if gerr == "menu" then
                        pcall(game.draw)
                        term.redirect(old)
                        gameEnded = true
                        break
                    end
                    pcall(game.draw)
                end
                term.redirect(old)

                if not gok then
                    drawStatus("Crash: " .. tostring(gerr))
                    os.sleep(3)
                    pcall(game.cleanup)
                    clearGame()
                    return
                end

                timerId = os.startTimer(tickRate)
            end
        end

        pcall(game.cleanup)

        if not gameEnded then
            clearGame()
            return
        end

        local choice = showEndGameMenu()
        if choice ~= "replay" then
            clearGame()
            return
        end
    end
end

function console.networkListener()
    local modem = peripheral.find("modem")
    if not modem then
        while running do os.pullEvent() end
        return
    end
    modem.open(config.network.channel)

    while running do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
        if message and message.side and message.strength ~= nil and message.computerID then
            local mapping = config.keyMappings[message.computerID]
            if mapping then
                local action = mapping[message.side]
                if action then
                    input.set(action, message.strength > 0)
                end
            end
        end
    end
end

function console.redstoneListener()
    local resetSide = config.redstone.resetSide
    local powerSide = config.redstone.powerSide
    local debounce = config.redstone.debounceTicks

    while running do
        os.pullEvent("redstone")
        local now = os.clock()

        if redstone.getInput(resetSide) then
            if now - lastResetTime > debounce then
                lastResetTime = now
                resetFlag = true
            end
        end

        if redstone.getInput(powerSide) then
            if now - lastPowerTime > debounce then
                lastPowerTime = now
                powerFlag = true
                running = false
            end
        end
    end
end

function console.runTestMode(testName)
    local modPath = config.system.gameDir .. "." .. testName
    local ok, game = pcall(require, modPath)
    if not ok or type(game) ~= "table" then
        print("Failed to load test game: " .. tostring(game))
        return
    end
    console.runGame(game)
end

function console.isRunning()
    return running
end

function console.shutdown()
    running = false
    clearGame()
    local old = term.redirect(statusWin)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Goodbye.")
    term.redirect(old)
    if originalTerm then
        term.redirect(originalTerm)
    end
end

return console
