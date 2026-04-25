local sc = require("lib.screen")

local scr = {}

local w, h
local drops
local puddles

function scr.title()
    return "Rain"
end

function scr.init(width, height)
    w = width
    h = height
    drops = {}
    puddles = {}
    for i = 1, 30 do
        table.insert(drops, {
            x = math.random(1, w),
            y = math.random(-h, 0),
            speed = math.random(1, 2),
            tick = 0,
        })
    end
end

function scr.update()
    for i = #puddles, 1, -1 do
        puddles[i].life = puddles[i].life - 1
        if puddles[i].life <= 0 then
            table.remove(puddles, i)
        end
    end

    for _, d in ipairs(drops) do
        d.tick = d.tick + 1
        if d.tick >= d.speed then
            d.tick = 0
            d.y = d.y + 1
            if d.y >= h then
                table.insert(puddles, {
                    x = d.x,
                    life = math.random(3, 6),
                })
                d.y = math.random(-5, 0)
                d.x = math.random(1, w)
                d.speed = math.random(1, 2)
            end
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, d in ipairs(drops) do
        if d.y >= 1 and d.y <= h then
            term.setCursorPos(d.x, d.y)
            term.setTextColor(colors.lightBlue)
            term.write("|")
            if d.y > 1 then
                term.setCursorPos(d.x, d.y - 1)
                term.setTextColor(colors.blue)
                term.write("'")
            end
        end
    end

    for _, p in ipairs(puddles) do
        if p.x >= 1 and p.x <= w then
            term.setCursorPos(math.max(1, p.x - 1), h)
            if p.life > 3 then
                term.setTextColor(colors.cyan)
                term.write("~.~")
            else
                term.setTextColor(colors.blue)
                term.write(" . ")
            end
        end
    end
end

return scr
