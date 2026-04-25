local sc = require("lib.screen")

local scr = {}

local w, h
local catX, catY, catDx
local catColor
local catBlink

local catArt = {
    "    /\\_/\\    ",
    "   ( o.o )   ",
    "    > ^ <    ",
    "   /|   |\\   ",
    "  (_|   |_)  ",
    "",
    "  zzZ  zzZ   ",
}

function scr.title()
    return "Cat"
end

function scr.init(width, height)
    w = width
    h = height
    catX = math.floor((w - 13) / 2)
    catY = math.floor((h - #catArt) / 2)
    catDx = sc.randomDir()
    catColor = sc.randomBright()
    catBlink = 0
end

function scr.update()
    catBlink = catBlink + 1

    if catBlink % 4 == 0 then
        catX = catX + catDx
        if catX <= 1 or catX + 13 >= w then
            catDx = -catDx
            catColor = sc.randomBright()
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    local eyes = (catBlink % 30 < 3) and "( -.- )" or "( o.o )"
    local frame = {}
    for i, line in ipairs(catArt) do
        frame[i] = line
    end
    frame[2] = "   " .. eyes .. "   "

    term.setTextColor(catColor)
    for i, line in ipairs(frame) do
        term.setCursorPos(catX, catY + i - 1)
        term.write(line)
    end

    term.setTextColor(colors.lightGray)
    if catBlink % 60 < 20 then
        term.setCursorPos(catX + 3, catY + #frame)
        term.write("meow.")
    end
end

return scr
