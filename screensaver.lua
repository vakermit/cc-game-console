local config = require("config")
local cfg = config.screensaver

local args = { ... }

local nativeTerm = term.current()

local function discoverScreens()
    local dir = cfg.screenDir
    local prefix = cfg.screenPrefix
    local screens = {}

    if not fs.exists(dir) or not fs.isDir(dir) then
        return screens
    end

    local files = fs.list(dir)
    for _, file in ipairs(files) do
        if file:sub(1, #prefix) == prefix and file:sub(-4) == ".lua" then
            local name = file:sub(1, -5)
            local modPath = dir .. "." .. name
            local ok, scr = pcall(require, modPath)
            if ok and type(scr) == "table" and type(scr.title) == "function" then
                table.insert(screens, scr)
            end
        end
    end

    table.sort(screens, function(a, b) return a.title():lower() < b.title():lower() end)
    return screens
end

local function randomDuration()
    local delta = math.random(0, cfg.deltaTime * 2) - cfg.deltaTime
    return math.max(cfg.minTime, cfg.baseTime + delta)
end

local function pickNext(screens, current)
    if #screens <= 1 then return 1 end
    local next
    repeat
        next = math.random(#screens)
    until next ~= current
    return next
end

local screens = discoverScreens()

if #screens == 0 then
    print("No screensavers found in " .. cfg.screenDir .. "/")
    return
end

-- Handle --list / -l
if args[1] == "--list" or args[1] == "-l" then
    print("Available screensavers:")
    for i, scr in ipairs(screens) do
        print("  " .. i .. ". " .. scr.title())
    end
    return
end

-- Handle single screensaver by name or number
local singleMode = nil
if args[1] then
    local num = tonumber(args[1])
    if num and num >= 1 and num <= #screens then
        singleMode = num
    else
        local name = args[1]:lower()
        for i, scr in ipairs(screens) do
            if scr.title():lower() == name then
                singleMode = i
                break
            end
        end
        if not singleMode then
            print("Unknown screensaver: " .. args[1])
            print("Use --list to see available screensavers.")
            return
        end
    end
end

local modem = peripheral.find("modem")
if modem then
    modem.open(config.network.channel)
end

local monitor = peripheral.find("monitor")
local output = monitor or nativeTerm
term.redirect(output)

local w, h = term.getSize()
math.randomseed(os.clock() * 1000)

local current = singleMode or math.random(#screens)
local nextScr = singleMode and current or pickNext(screens, current)
screens[current].init(w, h)

local modeTimer = 0
local modeDuration = singleMode and math.huge or randomDuration()
local tickRate = cfg.tickRate
local timer = os.startTimer(tickRate)
local lastStatusUpdate = -999

local function updateStatus()
    local old = term.redirect(nativeTerm)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    term.write("Screensaver")
    term.setCursorPos(1, 3)
    term.setTextColor(colors.lightGray)
    term.write("Now: ")
    term.setTextColor(colors.white)
    term.write(screens[current].title())
    if not singleMode then
        local remaining = math.max(0, math.floor(modeDuration - modeTimer))
        local mins = math.floor(remaining / 60)
        local secs = remaining % 60
        term.setCursorPos(1, 4)
        term.setTextColor(colors.lightGray)
        term.write("Time: ")
        term.setTextColor(colors.white)
        term.write(string.format("%d:%02d", mins, secs))
        term.setCursorPos(1, 5)
        term.setTextColor(colors.lightGray)
        term.write("Next: ")
        term.setTextColor(colors.white)
        term.write(screens[nextScr].title())
    end
    term.redirect(old)
end

updateStatus()

local running = true
while running do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" and p1 == timer then
        modeTimer = modeTimer + tickRate

        if modeTimer >= modeDuration then
            modeTimer = 0
            current = nextScr
            screens[current].init(w, h)
            nextScr = pickNext(screens, current)
            modeDuration = randomDuration()
            lastStatusUpdate = -999
        end

        screens[current].update()
        screens[current].draw()

        local elapsed = math.floor(modeTimer)
        if elapsed - lastStatusUpdate >= 60 or lastStatusUpdate < 0 then
            lastStatusUpdate = elapsed
            updateStatus()
        end

        timer = os.startTimer(tickRate)

    elseif event == "key" or event == "mouse_click" or event == "monitor_touch" then
        running = false
    elseif event == "modem_message" then
        if p2 == config.network.channel then
            running = false
        end
    elseif event == "redstone" then
        for _, side in ipairs({"top", "left", "right", "back"}) do
            if redstone.getInput(side) then
                running = false
                break
            end
        end
    end
end

if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    term.redirect(nativeTerm)
end
