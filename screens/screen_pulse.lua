local sc = require("lib.screen")

local scr = {}

local w, h
local rings
local spawnTimer

local ringColors = {
    colors.cyan, colors.lightBlue, colors.blue,
    colors.magenta, colors.purple, colors.pink,
    colors.lime, colors.green, colors.yellow,
    colors.orange, colors.red,
}

function scr.title()
    return "Pulse"
end

function scr.init(width, height)
    w = width
    h = height
    rings = {}
    spawnTimer = 0
end

function scr.update()
    spawnTimer = spawnTimer + 1
    if spawnTimer >= 8 then
        spawnTimer = 0
        table.insert(rings, {
            cx = math.random(3, w - 2),
            cy = math.random(3, h - 2),
            radius = 0,
            maxRadius = math.random(5, 12),
            color = ringColors[math.random(#ringColors)],
        })
    end

    for i = #rings, 1, -1 do
        rings[i].radius = rings[i].radius + 1
        if rings[i].radius > rings[i].maxRadius then
            table.remove(rings, i)
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, ring in ipairs(rings) do
        local r = ring.radius
        local fade = 1 - (r / ring.maxRadius)

        local ch
        if fade > 0.6 then ch = "#"
        elseif fade > 0.3 then ch = "+"
        else ch = "." end

        if fade > 0.5 then
            term.setTextColor(ring.color)
        else
            term.setTextColor(colors.gray)
        end

        for angle = 0, 62 do
            local a = angle * 0.1
            local px = math.floor(ring.cx + r * 2 * math.cos(a) + 0.5)
            local py = math.floor(ring.cy + r * math.sin(a) + 0.5)
            if px >= 1 and px <= w and py >= 1 and py <= h then
                term.setCursorPos(px, py)
                term.write(ch)
            end
        end
    end
end

return scr
