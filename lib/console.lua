local input = require("lib.input")
local config = require("config")
local block_letters = require("lib.block_letters")

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

    local testGame = config.system.testGame
    local files = fs.list(gameDir)
    for _, file in ipairs(files) do
        if file:sub(1, #prefix) == prefix and file:sub(-4) == ".lua" then
            local name = file:sub(1, -5)
            if name ~= testGame then
                local path = gameDir .. "/" .. file
                local ok, game = pcall(dofile, path)
                if ok and type(game) == "table" and type(game.title) == "function" then
                    table.insert(games, game)
                end
            end
        end
    end

    return games
end

function console.showMenu(games)
    local selected = 1
    local menuItems = {}
    for i, game in ipairs(games) do
        menuItems[i] = game.title()
    end
    table.insert(menuItems, "Shutdown")

    drawStatus("vgame - Select a game")
    local timerId = os.startTimer(config.system.tickRate)

    while running and not powerFlag do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            input.tick()

            if input.wasPressed(config.actions.menu_up) then
                selected = selected - 1
                if selected < 1 then selected = #menuItems end
            elseif input.wasPressed(config.actions.menu_down) then
                selected = selected + 1
                if selected > #menuItems then selected = 1 end
            elseif input.wasPressed(config.actions.menu_select) then
                if selected == #menuItems then
                    return nil
                end
                return games[selected]
            end

            local old = term.redirect(gameWin)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()

            local gw, gh = gameWin.getSize()
            local startY = math.max(1, math.floor((gh - #menuItems) / 2))

            for i, item in ipairs(menuItems) do
                term.setCursorPos(math.floor((gw - #item) / 2), startY + i - 1)
                if i == selected then
                    term.setBackgroundColor(colors.white)
                    term.setTextColor(colors.black)
                    term.write(" " .. item .. " ")
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                else
                    term.write(item)
                end
            end

            term.redirect(old)
            timerId = os.startTimer(config.system.tickRate)
        end
    end

    return nil
end

local function showTitleScreen(game)
    drawStatus(game.title())

    local old = term.redirect(gameWin)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    local gw, gh = gameWin.getSize()
    local title = game.title():upper()
    local words = {}
    for word in title:gmatch("%S+") do
        table.insert(words, word)
    end

    local lineHeight = 6
    local totalHeight = #words * lineHeight - 1
    local ty = math.max(1, math.floor((gh - totalHeight) / 2) - 2)

    for i, word in ipairs(words) do
        local wordW = block_letters.width(word)
        local wx = math.max(1, math.floor((gw - wordW) / 2) + 1)
        local wy = ty + (i - 1) * lineHeight
        block_letters.draw(wx, wy, word)
    end

    local belowTitle = ty + totalHeight + 2
    local prompt = "Press any button to start"
    term.setCursorPos(math.floor((gw - #prompt) / 2) + 1, belowTitle)
    term.write(prompt)

    if game.getControls then
        local controls = game.getControls()
        local cy = belowTitle + 2
        for _, ctrl in ipairs(controls) do
            local line = ctrl.action .. " - " .. ctrl.description
            term.setCursorPos(math.floor((gw - #line) / 2) + 1, cy)
            term.write(line)
            cy = cy + 1
        end
    end

    term.redirect(old)

    local timerId = os.startTimer(config.system.tickRate)
    while running and not resetFlag and not powerFlag do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            input.tick()
            if input.anyPressed() then return true end
            timerId = os.startTimer(config.system.tickRate)
        end
    end
    return false
end

function console.runGame(game)
    resetFlag = false
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

    while running and not resetFlag and not powerFlag do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            input.tick()

            if input.isDown(backAction1) and input.isDown(backAction2) then
                backHoldCount = backHoldCount + 1
                if backHoldCount >= backThreshold then
                    break
                end
            else
                backHoldCount = 0
            end

            old = term.redirect(gameWin)
            local gok, gerr = pcall(game.update, tickRate, input)
            if gok then
                pcall(game.draw)
            end
            term.redirect(old)

            if not gok then
                drawStatus("Crash: " .. tostring(gerr))
                os.sleep(3)
                break
            end

            timerId = os.startTimer(tickRate)
        end
    end

    pcall(game.cleanup)
    clearGame()
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

function console.runTestMode()
    local testFile = config.system.gameDir .. "/" .. config.system.testGame .. ".lua"
    if not fs.exists(testFile) then
        print("Test game not found: " .. testFile)
        return
    end
    local ok, game = pcall(dofile, testFile)
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
