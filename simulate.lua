----------------------------------------------------------------------------
-- CC:Tweaked Emulator for local development
-- Usage: lua simulate.lua <game_name>
-- Example: lua simulate.lua pong
--          lua simulate.lua game_pong
--          lua simulate.lua --console  (run full game-console)
----------------------------------------------------------------------------

local args = {...}
if #args == 0 then args = arg end
if not args or #args == 0 then
    print("Usage: lua simulate.lua <game_name>")
    print("       lua simulate.lua --console")
    print("       lua simulate.lua --list")
    print("       lua simulate.lua --test <game_name>  (headless init test)")
    os.exit(1)
end

-- Save real os/io references BEFORE any overrides
local _real_os_clock = os.clock
local _real_os_time = os.time
local _real_os_date = os.date
local _real_os_execute = os.execute
local _real_os_rename = os.rename
local _real_os_remove = os.remove
local _real_os_exit = os.exit
local _real_io_open = io.open
local _real_io_popen = io.popen
local _real_io_write = io.write
local _real_io_flush = io.flush
local _real_io_read = io.read

local function busySleep(seconds)
    local deadline = _real_os_clock() + seconds
    while _real_os_clock() < deadline do end
end

----------------------------------------------------------------------------
-- Simulation config
----------------------------------------------------------------------------
local SIM_CONFIG = {
    monitor_width  = 6,   -- monitor blocks wide
    monitor_height = 4,   -- monitor blocks tall
    chars_per_block_x = 7,
    chars_per_block_y = 5,
    tick_rate = 0.05,
}

local SCREEN_W = SIM_CONFIG.monitor_width * SIM_CONFIG.chars_per_block_x   -- 42
local SCREEN_H = SIM_CONFIG.monitor_height * SIM_CONFIG.chars_per_block_y  -- 20

----------------------------------------------------------------------------
-- ANSI terminal helpers
----------------------------------------------------------------------------
local ansi = {}

function ansi.write(s)
    _real_io_write(s)
end

function ansi.flush()
    _real_io_flush()
end

function ansi.esc(code)
    _real_io_write("\27[" .. code)
end

function ansi.moveTo(x, y)
    _real_io_write(string.format("\27[%d;%dH", y, x))
end

function ansi.clear()
    _real_io_write("\27[2J")
end

function ansi.clearLine()
    _real_io_write("\27[2K")
end

function ansi.hideCursor()
    _real_io_write("\27[?25l")
end

function ansi.showCursor()
    _real_io_write("\27[?25h")
end

function ansi.reset()
    _real_io_write("\27[0m")
end

function ansi.fg256(n)
    _real_io_write(string.format("\27[38;5;%dm", n))
end

function ansi.bg256(n)
    _real_io_write(string.format("\27[48;5;%dm", n))
end

----------------------------------------------------------------------------
-- CC Color System
----------------------------------------------------------------------------
local cc_colors = {}
cc_colors.white     = 0x1
cc_colors.orange    = 0x2
cc_colors.magenta   = 0x4
cc_colors.lightBlue = 0x8
cc_colors.yellow    = 0x10
cc_colors.lime      = 0x20
cc_colors.pink      = 0x40
cc_colors.gray      = 0x80
cc_colors.lightGray = 0x100
cc_colors.cyan      = 0x200
cc_colors.purple    = 0x400
cc_colors.blue      = 0x800
cc_colors.brown     = 0x1000
cc_colors.green     = 0x2000
cc_colors.red       = 0x4000
cc_colors.black     = 0x8000

cc_colors.grey      = cc_colors.gray
cc_colors.lightGrey = cc_colors.lightGray

function cc_colors.combine(...)
    local r = 0
    for _, c in ipairs({...}) do r = r | c end
    return r
end

function cc_colors.subtract(cols, ...)
    for _, c in ipairs({...}) do cols = cols & (~c) end
    return cols
end

function cc_colors.test(cols, color)
    return (cols & color) ~= 0
end

local cc_to_ansi256 = {
    [0x1]    = 15,   -- white
    [0x2]    = 208,  -- orange
    [0x4]    = 13,   -- magenta
    [0x8]    = 111,  -- lightBlue
    [0x10]   = 11,   -- yellow
    [0x20]   = 10,   -- lime
    [0x40]   = 217,  -- pink
    [0x80]   = 8,    -- gray
    [0x100]  = 7,    -- lightGray
    [0x200]  = 6,    -- cyan
    [0x400]  = 5,    -- purple
    [0x800]  = 4,    -- blue
    [0x1000] = 130,  -- brown
    [0x2000] = 2,    -- green
    [0x4000] = 1,    -- red
    [0x8000] = 0,    -- black
}

local cc_color_to_blit = {}
local blit_to_cc_color = {}
do
    local hex = "0123456789abcdef"
    local vals = {0x1,0x2,0x4,0x8,0x10,0x20,0x40,0x80,0x100,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000}
    for i, v in ipairs(vals) do
        local ch = hex:sub(i, i)
        cc_color_to_blit[v] = ch
        blit_to_cc_color[ch] = v
    end
end

local function applyFg(cc_color)
    local a = cc_to_ansi256[cc_color]
    if a then ansi.fg256(a) end
end

local function applyBg(cc_color)
    local a = cc_to_ansi256[cc_color]
    if a then ansi.bg256(a) end
end

----------------------------------------------------------------------------
-- Terminal object factory (used for both root term and windows)
----------------------------------------------------------------------------
local function makeCellBuffer(w, h)
    local buf = { w = w, h = h, chars = {}, fg = {}, bg = {} }
    for y = 1, h do
        buf.chars[y] = {}
        buf.fg[y] = {}
        buf.bg[y] = {}
        for x = 1, w do
            buf.chars[y][x] = " "
            buf.fg[y][x] = cc_colors.white
            buf.bg[y][x] = cc_colors.black
        end
    end
    return buf
end

local activeTerminal = nil
local rootTerminal = nil

local function makeTermObject(w, h, offsetX, offsetY, parentObj, isVisible)
    local obj = {}
    local curX, curY = 1, 1
    local textColor = cc_colors.white
    local bgColor = cc_colors.black
    local buf = makeCellBuffer(w, h)
    local visible = isVisible ~= false
    local cursorBlink = false

    function obj.getSize()
        return w, h
    end

    function obj.setCursorPos(x, y)
        curX = math.floor(x)
        curY = math.floor(y)
    end

    function obj.getCursorPos()
        return curX, curY
    end

    function obj.setCursorBlink(b)
        cursorBlink = b
    end

    function obj.getCursorBlink()
        return cursorBlink
    end

    function obj.setTextColor(c)
        textColor = c
    end
    obj.setTextColour = obj.setTextColor

    function obj.getTextColor()
        return textColor
    end
    obj.getTextColour = obj.getTextColor

    function obj.setBackgroundColor(c)
        bgColor = c
    end
    obj.setBackgroundColour = obj.setBackgroundColor

    function obj.getBackgroundColor()
        return bgColor
    end
    obj.getBackgroundColour = obj.getBackgroundColor

    function obj.isColor()
        return true
    end
    obj.isColour = obj.isColor

    function obj.write(text)
        text = tostring(text)
        for i = 1, #text do
            local cx = curX + i - 1
            if cx >= 1 and cx <= w and curY >= 1 and curY <= h then
                buf.chars[curY][cx] = text:sub(i, i)
                buf.fg[curY][cx] = textColor
                buf.bg[curY][cx] = bgColor
            end
        end
        curX = curX + #text
    end

    function obj.blit(text, fgStr, bgStr)
        for i = 1, #text do
            local cx = curX + i - 1
            if cx >= 1 and cx <= w and curY >= 1 and curY <= h then
                buf.chars[curY][cx] = text:sub(i, i)
                buf.fg[curY][cx] = blit_to_cc_color[fgStr:sub(i, i)] or cc_colors.white
                buf.bg[curY][cx] = blit_to_cc_color[bgStr:sub(i, i)] or cc_colors.black
            end
        end
        curX = curX + #text
    end

    function obj.clear()
        for y = 1, h do
            for x = 1, w do
                buf.chars[y][x] = " "
                buf.fg[y][x] = textColor
                buf.bg[y][x] = bgColor
            end
        end
    end

    function obj.clearLine()
        if curY >= 1 and curY <= h then
            for x = 1, w do
                buf.chars[curY][x] = " "
                buf.fg[curY][x] = textColor
                buf.bg[curY][x] = bgColor
            end
        end
    end

    function obj.scroll(n)
        if n > 0 then
            for y = 1, h do
                local srcY = y + n
                for x = 1, w do
                    if srcY <= h then
                        buf.chars[y][x] = buf.chars[srcY][x]
                        buf.fg[y][x] = buf.fg[srcY][x]
                        buf.bg[y][x] = buf.bg[srcY][x]
                    else
                        buf.chars[y][x] = " "
                        buf.fg[y][x] = textColor
                        buf.bg[y][x] = bgColor
                    end
                end
            end
        elseif n < 0 then
            for y = h, 1, -1 do
                local srcY = y + n
                for x = 1, w do
                    if srcY >= 1 then
                        buf.chars[y][x] = buf.chars[srcY][x]
                        buf.fg[y][x] = buf.fg[srcY][x]
                        buf.bg[y][x] = buf.bg[srcY][x]
                    else
                        buf.chars[y][x] = " "
                        buf.fg[y][x] = textColor
                        buf.bg[y][x] = bgColor
                    end
                end
            end
        end
    end

    function obj.getLine(y)
        if y < 1 or y > h then return nil end
        local text, fgBlit, bgBlit = {}, {}, {}
        for x = 1, w do
            table.insert(text, buf.chars[y][x])
            table.insert(fgBlit, cc_color_to_blit[buf.fg[y][x]] or "0")
            table.insert(bgBlit, cc_color_to_blit[buf.bg[y][x]] or "f")
        end
        return table.concat(text), table.concat(fgBlit), table.concat(bgBlit)
    end

    function obj.setVisible(v)
        visible = v
    end

    function obj.redraw()
        if visible then obj._flush() end
    end

    function obj.reposition(nx, ny, nw, nh)
        offsetX = nx or offsetX
        offsetY = ny or offsetY
        if nw and nh then
            w = nw
            h = nh
            buf = makeCellBuffer(w, h)
        end
    end

    function obj._flush()
        local ox = offsetX or 1
        local oy = offsetY or 1
        local out = {}
        local prevFg, prevBg = -1, -1
        for y = 1, h do
            out[#out+1] = string.format("\27[%d;%dH", oy + y - 1, ox)
            for x = 1, w do
                local fg = buf.fg[y][x]
                local bg = buf.bg[y][x]
                if fg ~= prevFg then
                    local a = cc_to_ansi256[fg]
                    if a then out[#out+1] = string.format("\27[38;5;%dm", a) end
                    prevFg = fg
                end
                if bg ~= prevBg then
                    local a = cc_to_ansi256[bg]
                    if a then out[#out+1] = string.format("\27[48;5;%dm", a) end
                    prevBg = bg
                end
                out[#out+1] = buf.chars[y][x]
            end
        end
        _real_io_write(table.concat(out))
        _real_io_flush()
    end

    function obj._getBuffer()
        return buf
    end

    return obj
end

----------------------------------------------------------------------------
-- Window API
----------------------------------------------------------------------------
local cc_window = {}

function cc_window.create(parent, x, y, w, h, visible)
    local win = makeTermObject(w, h, x, y, parent, visible)

    local origFlush = win._flush
    win._flush = function()
        if parent and parent._flush then
            local buf = win._getBuffer()
            local parentBuf = parent._getBuffer()
            if parentBuf then
                for row = 1, h do
                    for col = 1, w do
                        local py = y + row - 1
                        local px = x + col - 1
                        if py >= 1 and py <= parentBuf.h and px >= 1 and px <= parentBuf.w then
                            parentBuf.chars[py][px] = buf.chars[row][col]
                            parentBuf.fg[py][px] = buf.fg[row][col]
                            parentBuf.bg[py][px] = buf.bg[row][col]
                        end
                    end
                end
            end
            parent._flush()
        else
            origFlush()
        end
    end

    return win
end

----------------------------------------------------------------------------
-- Peripheral API
----------------------------------------------------------------------------
local cc_peripheral = {}

local stubSpeaker = {
    playNote = function() return true end,
    playSound = function() return true end,
    playAudio = function() return true end,
    stop = function() end,
}

function cc_peripheral.find(pType)
    if pType == "speaker" then
        return stubSpeaker
    end
    return nil
end

function cc_peripheral.getType(side)
    return nil
end

function cc_peripheral.isPresent(side)
    return false
end

function cc_peripheral.getNames()
    return {}
end

function cc_peripheral.getMethods(name)
    return {}
end

function cc_peripheral.call(name, method, ...)
    return nil
end

function cc_peripheral.wrap(name)
    return nil
end

----------------------------------------------------------------------------
-- Filesystem API
----------------------------------------------------------------------------
local gameDir = "."

local cc_fs = {}

local function resolvePath(path)
    if path:sub(1, 1) == "/" then
        return gameDir .. path
    end
    return gameDir .. "/" .. path
end

function cc_fs.exists(path)
    local real = resolvePath(path)
    local f = _real_io_open(real, "r")
    if f then
        f:close()
        return true
    end
    local ok, _, code = _real_os_rename(real, real)
    if ok then return true end
    if code == 13 then return true end
    return false
end

function cc_fs.isDir(path)
    local real = resolvePath(path)
    local ok, err, code = _real_os_rename(real .. "/.", real .. "/.")
    if ok then return true end
    if code == 13 then return true end
    return false
end

function cc_fs.list(path)
    local real = resolvePath(path)
    local entries = {}
    local p = _real_io_popen('ls -1 "' .. real .. '" 2>/dev/null')
    if p then
        for line in p:lines() do
            if line ~= "" then
                table.insert(entries, line)
            end
        end
        p:close()
    end
    return entries
end

function cc_fs.makeDir(path)
    local real = resolvePath(path)
    _real_os_execute('mkdir -p "' .. real .. '"')
end

function cc_fs.open(path, mode)
    local real = resolvePath(path)
    local ioMode = "r"
    if mode == "w" then ioMode = "w"
    elseif mode == "a" then ioMode = "a"
    elseif mode == "rb" then ioMode = "rb"
    elseif mode == "wb" then ioMode = "wb"
    end

    local f = _real_io_open(real, ioMode)
    if not f then return nil end

    local handle = {}
    function handle.readAll()
        return f:read("*a")
    end
    function handle.readLine()
        return f:read("*l")
    end
    function handle.read(count)
        if count then return f:read(count) end
        return f:read("*l")
    end
    function handle.writeLine(text)
        f:write(text .. "\n")
    end
    function handle.write(text)
        f:write(text)
    end
    function handle.close()
        f:close()
    end
    function handle.flush()
        f:flush()
    end
    return handle
end

function cc_fs.delete(path)
    local real = resolvePath(path)
    _real_os_remove(real)
end

function cc_fs.getName(path)
    return path:match("[^/]+$") or path
end

function cc_fs.getDir(path)
    return path:match("(.+)/[^/]+$") or ""
end

function cc_fs.combine(base, child)
    if base == "" then return child end
    return base .. "/" .. child
end

function cc_fs.getSize(path)
    local real = resolvePath(path)
    local f = _real_io_open(real, "r")
    if not f then return 0 end
    local size = f:seek("end")
    f:close()
    return size
end

----------------------------------------------------------------------------
-- Redstone API (stub)
----------------------------------------------------------------------------
local cc_redstone = {}

function cc_redstone.getInput(side) return false end
function cc_redstone.getOutput(side) return false end
function cc_redstone.setOutput(side, value) end
function cc_redstone.getAnalogInput(side) return 0 end
function cc_redstone.getAnalogOutput(side) return 0 end
function cc_redstone.setAnalogOutput(side, value) end
local cc_rs = cc_redstone

----------------------------------------------------------------------------
-- Textutils API
----------------------------------------------------------------------------
local cc_textutils = {}

function cc_textutils.serialize(t, opts)
    local seen = {}
    local function ser(val, indent)
        if type(val) == "string" then
            return string.format("%q", val)
        elseif type(val) == "number" or type(val) == "boolean" then
            return tostring(val)
        elseif type(val) == "nil" then
            return "nil"
        elseif type(val) == "table" then
            if seen[val] then return "{...}" end
            seen[val] = true
            local parts = {}
            local pad = string.rep("  ", indent + 1)
            local isArray = true
            local maxN = 0
            for k in pairs(val) do
                if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    isArray = false
                    break
                end
                if k > maxN then maxN = k end
            end
            if isArray then
                for i = 1, maxN do
                    table.insert(parts, pad .. ser(val[i], indent + 1) .. ",")
                end
            else
                for k, v in pairs(val) do
                    local key
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        key = k
                    else
                        key = "[" .. ser(k, indent + 1) .. "]"
                    end
                    table.insert(parts, pad .. key .. " = " .. ser(v, indent + 1) .. ",")
                end
            end
            seen[val] = nil
            local closePad = string.rep("  ", indent)
            return "{\n" .. table.concat(parts, "\n") .. "\n" .. closePad .. "}"
        end
        return tostring(val)
    end
    return ser(t, 0)
end

cc_textutils.serialise = cc_textutils.serialize

function cc_textutils.unserialize(s)
    local fn = load("return " .. s, "unserialize", "t", {})
    if fn then
        local ok, val = pcall(fn)
        if ok then return val end
    end
    return nil
end
cc_textutils.unserialise = cc_textutils.unserialize

function cc_textutils.formatTime(time, twentyFour)
    local h = math.floor(time)
    local m = math.floor((time - h) * 60)
    if twentyFour then
        return string.format("%02d:%02d", h, m)
    end
    local suffix = h >= 12 and "PM" or "AM"
    h = h % 12
    if h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, m, suffix)
end

----------------------------------------------------------------------------
-- Keys API
----------------------------------------------------------------------------
local cc_keys = {
    a = 30, b = 48, c = 46, d = 32, e = 18, f = 33, g = 34, h = 35,
    i = 23, j = 36, k = 37, l = 38, m = 50, n = 49, o = 24, p = 25,
    q = 16, r = 19, s = 31, t = 20, u = 22, v = 47, w = 17, x = 45,
    y = 21, z = 44,
    one = 2, two = 3, three = 4, four = 5, five = 6, six = 7,
    seven = 8, eight = 9, nine = 10, zero = 11,
    space = 57, enter = 28, backspace = 14, tab = 15,
    leftShift = 42, rightShift = 54, leftCtrl = 29, rightCtrl = 157,
    leftAlt = 56, rightAlt = 184,
    up = 200, down = 208, left = 203, right = 205,
    escape = 1, delete = 211, home = 199, ["end"] = 207,
    pageUp = 201, pageDown = 209,
    f1 = 59, f2 = 60, f3 = 61, f4 = 62, f5 = 63,
    f6 = 64, f7 = 65, f8 = 66, f9 = 67, f10 = 68,
    f11 = 87, f12 = 88,
    capsLock = 58, numLock = 69, scrollLock = 70,
}

local keyNames = {}
for name, code in pairs(cc_keys) do
    if type(code) == "number" then
        keyNames[code] = name
    end
end

function cc_keys.getName(code)
    return keyNames[code]
end

----------------------------------------------------------------------------
-- Input: raw terminal + keyboard mapping
----------------------------------------------------------------------------
local rawModeActive = false

local function enableRawMode()
    _real_os_execute("stty raw -echo -icanon min 0 time 0 2>/dev/null")
    rawModeActive = true
end

local function disableRawMode()
    if rawModeActive then
        _real_os_execute("stty sane 2>/dev/null")
        rawModeActive = false
    end
end

local keyStates = {}
local keyReleaseTimers = {}
local KEY_HOLD_DURATION = 0.15

local keyMapping = {
    w         = "p1_up",
    a         = "p1_left",
    s         = "p1_down",
    d         = "p1_right",
    [" "]     = "p1_action",
    z         = "p1_alt",
    UP        = "p2_up",
    LEFT      = "p2_left",
    DOWN      = "p2_down",
    RIGHT     = "p2_right",
    ENTER     = "p2_action",
    RSHIFT    = "p2_alt",
}

local function readKey()
    local ch = _real_io_read(1)
    if not ch then return nil end

    local byte = string.byte(ch)

    if byte == 27 then
        local ch2 = _real_io_read(1)
        if not ch2 then return "ESCAPE" end
        if ch2 == "[" then
            local ch3 = _real_io_read(1)
            if not ch3 then return "ESCAPE" end
            if ch3 == "A" then return "UP"
            elseif ch3 == "B" then return "DOWN"
            elseif ch3 == "C" then return "RIGHT"
            elseif ch3 == "D" then return "LEFT"
            elseif ch3 == "Z" then return "RSHIFT"
            else
                return nil
            end
        end
        return "ESCAPE"
    end

    if byte == 10 or byte == 13 then return "ENTER" end
    if byte == 9 then return "TAB" end
    if byte == 127 then return "BACKSPACE" end
    if byte == 3 then return "ESCAPE" end

    return ch
end

local specialKeyMap = {
    UP = cc_keys.up, DOWN = cc_keys.down,
    LEFT = cc_keys.left, RIGHT = cc_keys.right,
    ENTER = cc_keys.enter, TAB = cc_keys.tab,
    BACKSPACE = cc_keys.backspace,
}

local activeInputModule = nil

local function pollKeyboard(_, eventQueue)
    while true do
        local key = readKey()
        if not key then break end

        if key == "ESCAPE" then
            table.insert(eventQueue, {"sim_quit"})
            return
        end

        local action = keyMapping[key]
        if action then
            keyStates[action] = true
            keyReleaseTimers[action] = _real_os_clock() + KEY_HOLD_DURATION
            if activeInputModule then
                activeInputModule.set(action, true)
            end
        end

        local ccKey = specialKeyMap[key] or (#key == 1 and cc_keys[key:lower()] or nil)

        if ccKey then
            table.insert(eventQueue, {"key", ccKey, false})
            if #key == 1 then
                table.insert(eventQueue, {"char", key})
            end
        end
    end

    local now = _real_os_clock()
    for action, deadline in pairs(keyReleaseTimers) do
        if now >= deadline then
            keyStates[action] = false
            keyReleaseTimers[action] = nil
            if activeInputModule then
                activeInputModule.set(action, false)
            end
        end
    end
end

----------------------------------------------------------------------------
-- Event system + coroutine scheduler
----------------------------------------------------------------------------
local eventQueue = {}
local timerRegistry = {}
local nextTimerId = 1
local startClock = _real_os_clock()

local cc_os = {}

function cc_os.clock()
    return _real_os_clock()
end

function cc_os.epoch(kind)
    return math.floor(_real_os_clock() * 1000)
end

function cc_os.time(timezone)
    local t = _real_os_date("*t")
    return t.hour + t.min / 60 + t.sec / 3600
end

function cc_os.day()
    return math.floor(_real_os_time() / 86400)
end

function cc_os.startTimer(interval)
    local id = nextTimerId
    nextTimerId = nextTimerId + 1
    timerRegistry[id] = _real_os_clock() + interval
    return id
end

function cc_os.cancelTimer(id)
    timerRegistry[id] = nil
end

function cc_os.setAlarm(time)
    return cc_os.startTimer(1)
end

function cc_os.cancelAlarm(id)
    cc_os.cancelTimer(id)
end

function cc_os.getComputerID()
    return 1
end
cc_os.getComputerLabel = function() return "simulator" end
cc_os.setComputerLabel = function() end
cc_os.computerID = cc_os.getComputerID

local function pumpTimers()
    local now = _real_os_clock()
    local fired = {}
    for id, deadline in pairs(timerRegistry) do
        if now >= deadline then
            table.insert(fired, id)
        end
    end
    for _, id in ipairs(fired) do
        timerRegistry[id] = nil
        table.insert(eventQueue, {"timer", id})
    end
end

function cc_os.pullEvent(filter)
    return coroutine.yield(filter)
end

function cc_os.pullEventRaw(filter)
    return coroutine.yield(filter)
end

function cc_os.queueEvent(event, ...)
    table.insert(eventQueue, {event, ...})
end

function cc_os.sleep(seconds)
    local timerId = cc_os.startTimer(seconds or 0)
    while true do
        local event, p1 = cc_os.pullEvent("timer")
        if event == "timer" and p1 == timerId then
            return
        end
    end
end

function cc_os.shutdown()
    table.insert(eventQueue, {"sim_quit"})
end

function cc_os.reboot()
    table.insert(eventQueue, {"sim_quit"})
end

function cc_os.run(env, path, ...)
end

function cc_os.version()
    return "CraftOS 1.8 (Simulator)"
end

----------------------------------------------------------------------------
-- Parallel API
----------------------------------------------------------------------------
local cc_parallel = {}

function cc_parallel.waitForAny(...)
    local funcs = {...}
    local cos = {}
    for i, fn in ipairs(funcs) do
        cos[i] = { co = coroutine.create(fn), filter = nil }
    end

    while true do
        pollKeyboard(nil, eventQueue)
        pumpTimers()

        if #eventQueue == 0 then
            local sleepTime = SIM_CONFIG.tick_rate / 4
            local minDeadline = math.huge
            for _, dl in pairs(timerRegistry) do
                if dl < minDeadline then minDeadline = dl end
            end
            local remaining = minDeadline - _real_os_clock()
            if remaining > 0 and remaining < sleepTime then
                sleepTime = remaining
            end

            busySleep(sleepTime)

            pollKeyboard(nil, eventQueue)
            pumpTimers()
        end

        while #eventQueue > 0 do
            local event = table.remove(eventQueue, 1)

            if event[1] == "sim_quit" then
                return
            end

            local allDead = true
            for i, entry in ipairs(cos) do
                if entry.co and coroutine.status(entry.co) ~= "dead" then
                    if entry.filter == nil or entry.filter == event[1] then
                        local ok, result = coroutine.resume(entry.co, table.unpack(event))
                        if not ok then
                            ansi.moveTo(1, SCREEN_H + 2)
                            ansi.reset()
                            _real_io_write("Coroutine error: " .. tostring(result) .. "\n")
                            return
                        end
                        if coroutine.status(entry.co) == "dead" then
                            return
                        end
                        entry.filter = result
                    end
                    allDead = false
                end
            end

            if allDead then return end
        end
    end
end

function cc_parallel.waitForAll(...)
    local funcs = {...}
    local cos = {}
    for i, fn in ipairs(funcs) do
        cos[i] = { co = coroutine.create(fn), filter = nil }
    end

    while true do
        pollKeyboard(nil, eventQueue)
        pumpTimers()

        if #eventQueue == 0 then
            busySleep(SIM_CONFIG.tick_rate / 4)
            pollKeyboard(nil, eventQueue)
            pumpTimers()
        end

        while #eventQueue > 0 do
            local event = table.remove(eventQueue, 1)

            if event[1] == "sim_quit" then return end

            local allDead = true
            for i, entry in ipairs(cos) do
                if entry.co and coroutine.status(entry.co) ~= "dead" then
                    if entry.filter == nil or entry.filter == event[1] then
                        local ok, result = coroutine.resume(entry.co, table.unpack(event))
                        if not ok then
                            ansi.moveTo(1, SCREEN_H + 2)
                            ansi.reset()
                            _real_io_write("Coroutine error: " .. tostring(result) .. "\n")
                            return
                        end
                        if coroutine.status(entry.co) ~= "dead" then
                            allDead = false
                        end
                        entry.filter = result
                    else
                        allDead = false
                    end
                end
            end

            if allDead then return end
        end
    end
end

----------------------------------------------------------------------------
-- Shell API (stub)
----------------------------------------------------------------------------
local cc_shell = {}
function cc_shell.run(program, ...) end
function cc_shell.dir() return "" end
function cc_shell.setDir(d) end
function cc_shell.path() return "./" end
function cc_shell.setPath(p) end
function cc_shell.resolve(path) return path end
function cc_shell.resolveProgram(name) return name end
function cc_shell.programs() return {} end
function cc_shell.complete(prefix) return {} end
function cc_shell.completeProgram(prefix) return {} end

----------------------------------------------------------------------------
-- Term redirect stack
----------------------------------------------------------------------------
local cc_term = {}

local function proxyToActive(method)
    return function(...)
        local t = activeTerminal
        if t and t[method] then
            return t[method](...)
        end
    end
end

cc_term.write = proxyToActive("write")
cc_term.blit = proxyToActive("blit")
cc_term.clear = proxyToActive("clear")
cc_term.clearLine = proxyToActive("clearLine")
cc_term.setCursorPos = proxyToActive("setCursorPos")
cc_term.getCursorPos = proxyToActive("getCursorPos")
cc_term.setCursorBlink = proxyToActive("setCursorBlink")
cc_term.getCursorBlink = proxyToActive("getCursorBlink")
cc_term.setTextColor = proxyToActive("setTextColor")
cc_term.setTextColour = proxyToActive("setTextColor")
cc_term.getTextColor = proxyToActive("getTextColor")
cc_term.getTextColour = proxyToActive("getTextColor")
cc_term.setBackgroundColor = proxyToActive("setBackgroundColor")
cc_term.setBackgroundColour = proxyToActive("setBackgroundColor")
cc_term.getBackgroundColor = proxyToActive("getBackgroundColor")
cc_term.getBackgroundColour = proxyToActive("getBackgroundColor")
cc_term.getSize = proxyToActive("getSize")
cc_term.scroll = proxyToActive("scroll")
cc_term.isColor = proxyToActive("isColor")
cc_term.isColour = proxyToActive("isColor")

function cc_term.current()
    return activeTerminal
end

function cc_term.redirect(target)
    local prev = activeTerminal
    activeTerminal = target
    return prev
end

function cc_term.native()
    return rootTerminal
end

----------------------------------------------------------------------------
-- Inject all globals and set up require path
----------------------------------------------------------------------------
local function setupEnvironment(gamePath)
    gameDir = gamePath

    package.path = gamePath .. "/?.lua;" .. gamePath .. "/?/init.lua;" .. package.path

    rootTerminal = makeTermObject(SCREEN_W, SCREEN_H, 1, 1, nil, true)
    activeTerminal = rootTerminal

    _G.colors = cc_colors
    _G.colours = cc_colors
    _G.term = cc_term
    _G.window = cc_window
    _G.peripheral = cc_peripheral
    _G.fs = cc_fs
    _G.redstone = cc_redstone
    _G.rs = cc_rs
    _G.textutils = cc_textutils
    _G.keys = cc_keys
    _G.parallel = cc_parallel
    _G.shell = cc_shell

    -- Build a new os table that has CC functions + real os passthrough
    local cc_os_table = {}
    for k, v in pairs(cc_os) do
        cc_os_table[k] = v
    end
    -- Preserve real os functions that CC doesn't override
    cc_os_table.execute = _real_os_execute
    cc_os_table.rename = _real_os_rename
    cc_os_table.remove = _real_os_remove
    cc_os_table.exit = _real_os_exit
    cc_os_table.date = _real_os_date
    cc_os_table.getenv = os.getenv
    cc_os_table.tmpname = os.tmpname
    cc_os_table.difftime = os.difftime
    _G.os = cc_os_table

    -- Lua 5.5 math.randomseed requires integer; CC games pass floats
    local _real_randomseed = math.randomseed
    math.randomseed = function(seed)
        if type(seed) == "number" then
            seed = math.floor(seed)
            if seed == 0 then seed = 1 end
        end
        return _real_randomseed(seed)
    end

    _G.sleep = function(n) cc_os.sleep(n) end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        local text = table.concat(parts, "\t")
        cc_term.write(text)
        local tw, th = cc_term.getSize()
        local _, cy = cc_term.getCursorPos()
        if cy >= th then
            cc_term.scroll(1)
            cc_term.setCursorPos(1, th)
        else
            cc_term.setCursorPos(1, cy + 1)
        end
    end
    _G.write = function(text)
        cc_term.write(tostring(text))
    end
    _G.read = function()
        return ""
    end
    _G.printError = function(...)
        local old = cc_term.getTextColor()
        cc_term.setTextColor(cc_colors.red)
        _G.print(...)
        cc_term.setTextColor(old)
    end

    package.loaded["cc.audio.dfpwm"] = {
        make_decoder = function()
            return function(chunk)
                return {}
            end
        end,
        make_encoder = function()
            return function(samples)
                return ""
            end
        end,
    }
end

----------------------------------------------------------------------------
-- Main: render loop + status line
----------------------------------------------------------------------------
local function cleanupTerminal()
    disableRawMode()
    ansi.showCursor()
    ansi.reset()
    ansi.clear()
    ansi.moveTo(1, 1)
end

local function normalizeGameName(name)
    name = name:gsub("%.lua$", "")
    if not name:match("^game_") then
        name = "game_" .. name
    end
    return name
end

local stubInput = {
    tick = function() end,
    isDown = function() return false end,
    wasPressed = function() return false end,
    wasReleased = function() return false end,
    anyPressed = function() return false end,
    getPlayer = function()
        return {
            isDown = function() return false end,
            wasPressed = function() return false end,
            wasReleased = function() return false end,
        }
    end,
}

local function makeConsoleProxy()
    return {
        getWidth = function() return SCREEN_W end,
        getHeight = function() return SCREEN_H - 1 end,
    }
end

local function drawStatusLine()
    ansi.moveTo(1, SCREEN_H + 1)
    ansi.bg256(4)
    ansi.fg256(15)
    local status = " CC:Tweaked Simulator | " .. SCREEN_W .. "x" .. SCREEN_H
    status = status .. " | P1: WASD+Space+Z | P2: Arrows+Enter"
    status = status .. " | ESC: Quit"
    local pad = SCREEN_W - #status
    if pad > 0 then status = status .. string.rep(" ", pad) end
    _real_io_write(status:sub(1, SCREEN_W))
    ansi.reset()
    ansi.flush()
end

local function runSimulation(gamePath, gameName)
    setupEnvironment(gamePath)

    enableRawMode()
    ansi.hideCursor()
    ansi.clear()

    drawStatusLine()

    local inputModule = nil
    pcall(function()
        inputModule = require("lib.input")
    end)
    activeInputModule = inputModule

    if gameName == "--console" then
        local ok, err = pcall(dofile, gamePath .. "/game-console.lua")

        if not ok then
            cleanupTerminal()
            print("Error running console: " .. tostring(err))
        end
    else
        local gameModPath = "games." .. gameName
        local ok, game = pcall(require, gameModPath)
        if not ok then
            cleanupTerminal()
            print("Failed to load game: " .. tostring(game))
            return
        end

        if type(game) ~= "table" or type(game.title) ~= "function" then
            cleanupTerminal()
            print("Invalid game module: missing title() function")
            return
        end

        local function gameLoop()
            if inputModule then inputModule.init() end

            rootTerminal.setBackgroundColor(cc_colors.black)
            rootTerminal.setTextColor(cc_colors.white)
            rootTerminal.clear()
            rootTerminal.setCursorPos(1, 1)

            local initOk, initErr = pcall(game.init, makeConsoleProxy())
            if not initOk then
                ansi.moveTo(1, SCREEN_H + 2)
                ansi.reset()
                _real_io_write("Init error: " .. tostring(initErr) .. "\n")
                return
            end

            local tickRate = SIM_CONFIG.tick_rate
            local timerId = cc_os.startTimer(tickRate)

            while true do
                local event, p1 = cc_os.pullEvent()
                if event == "timer" and p1 == timerId then
                    if inputModule then inputModule.tick() end

                    local uok, uerr = pcall(game.update, tickRate, inputModule or stubInput)
                    if uok then
                        if uerr == "menu" then
                            pcall(game.draw)
                            rootTerminal._flush()
                            break
                        end
                        pcall(game.draw)
                        rootTerminal._flush()
                    else
                        ansi.moveTo(1, SCREEN_H + 2)
                        ansi.reset()
                        _real_io_write("Update error: " .. tostring(uerr) .. "\n")
                        break
                    end

                    timerId = cc_os.startTimer(tickRate)
                elseif event == "sim_quit" then
                    break
                end
            end

            pcall(game.cleanup)
        end

        cc_parallel.waitForAny(gameLoop)
    end
end

----------------------------------------------------------------------------
-- Entry point
----------------------------------------------------------------------------
local function main()
    local gamePath = debug.getinfo(1, "S").source:match("@(.+)/[^/]+$") or "."

    local gameName = args[1]

    if gameName == "--test" then
        local realPrint = print
        local testGame = normalizeGameName(args[2] or "pong")

        setupEnvironment(gamePath)

        local gameModPath = "games." .. testGame
        local ok, game = pcall(require, gameModPath)
        if not ok then
            realPrint("FAIL: Could not load " .. testGame .. ": " .. tostring(game))
            _real_os_exit(1)
        end
        realPrint("OK: Loaded " .. testGame .. " - " .. game.title())

        local initOk, initErr = pcall(game.init, makeConsoleProxy())
        if not initOk then
            realPrint("FAIL: init() error: " .. tostring(initErr))
            _real_os_exit(1)
        end
        realPrint("OK: init() succeeded")

        local inputModule = require("lib.input")
        inputModule.init()
        inputModule.tick()

        local drawOk, drawErr = pcall(game.draw)
        if not drawOk then
            realPrint("FAIL: draw() error: " .. tostring(drawErr))
            _real_os_exit(1)
        end
        realPrint("OK: draw() succeeded")

        for i = 1, 5 do
            inputModule.tick()
            local uok, uerr = pcall(game.update, 0.05, inputModule)
            if not uok then
                realPrint("FAIL: update() frame " .. i .. " error: " .. tostring(uerr))
                _real_os_exit(1)
            end
            pcall(game.draw)
        end
        realPrint("OK: 5 frames updated successfully")

        pcall(game.cleanup)
        realPrint("OK: cleanup() done")

        local line = rootTerminal.getLine(1)
        if line and #line > 0 then
            realPrint("OK: Screen buffer has content (line 1: " .. line:sub(1, 30):gsub("%s+$", "") .. ")")
        else
            realPrint("WARN: Screen buffer line 1 is empty")
        end

        realPrint("PASS: All tests passed for " .. testGame)
        return
    end

    if gameName == "--list" then
        local gamesDir = gamePath .. "/games"
        local p = _real_io_popen('ls -1 "' .. gamesDir .. '" 2>/dev/null')
        if p then
            print("Available games:")
            for line in p:lines() do
                local name = line:match("^game_(.+)%.lua$")
                if name and not line:find("_test_") then
                    print("  " .. name)
                end
            end
            p:close()
        end
        return
    end

    if gameName ~= "--console" then
        gameName = normalizeGameName(gameName)

        local gameFile = gamePath .. "/games/" .. gameName .. ".lua"
        local f = _real_io_open(gameFile, "r")
        if not f then
            print("Game not found: " .. gameFile)
            print("Use --list to see available games")
            return
        end
        f:close()
    end

    local ok, err = pcall(runSimulation, gamePath, gameName)

    cleanupTerminal()

    if not ok then
        print("Simulator error: " .. tostring(err))
    else
        print("Simulator exited.")
    end
end

main()
