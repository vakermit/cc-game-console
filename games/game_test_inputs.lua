local input = require("lib.input")

local game = {}

local width, height
local actions = { "up", "down", "left", "right", "action", "alt" }

function game.title()
    return "Input Test"
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
end

function game.update(dt, inp)
end

local function drawIndicator(x, y, label, isDown)
    local pad = string.rep(" ", 8 - #label)
    term.setCursorPos(x, y)
    term.write(pad .. label .. " ")
    if isDown then
        term.setBackgroundColor(colors.lime)
        term.setTextColor(colors.black)
        term.write("[\x07]")
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        term.write("[ ]")
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    local colW = math.floor(width / 2)
    local startY = math.max(1, math.floor((height - #actions - 4) / 2))

    term.setCursorPos(math.floor(width / 2) - 7, startY)
    term.setTextColor(colors.yellow)
    term.write("INPUT TEST MODE")
    term.setTextColor(colors.white)

    local players = {
        { x = math.floor(colW / 2) - 5, prefix = "p1_", label = "PLAYER 1", color = colors.lightBlue },
        { x = colW + math.floor(colW / 2) - 5, prefix = "p2_", label = "PLAYER 2", color = colors.orange },
    }

    for _, p in ipairs(players) do
        term.setCursorPos(p.x, startY + 2)
        term.setTextColor(p.color)
        term.write(p.label)
        term.setTextColor(colors.white)
    end

    for i, action in ipairs(actions) do
        local y = startY + 3 + i
        local label = action .. ":"
        for _, p in ipairs(players) do
            drawIndicator(p.x, y, label, input.isDown(p.prefix .. action))
        end
    end

    local exitMsg = "Hold alt+action to exit"
    term.setCursorPos(math.floor((width - #exitMsg) / 2) + 1, startY + 4 + #actions + 2)
    term.setTextColor(colors.lightGray)
    term.write(exitMsg)
    term.setTextColor(colors.white)
end

function game.cleanup()
end

return game
