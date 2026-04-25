local sc = require("lib.screen")

local scr = {}

local w, h
local blobs
local lavaColors

function scr.title()
    return "Lava Lamp"
end

function scr.init(width, height)
    w = width
    h = height
    lavaColors = { colors.red, colors.orange, colors.yellow, colors.magenta }
    blobs = {}
    for i = 1, 8 do
        table.insert(blobs, {
            x = math.random(2, w - 1),
            y = math.random(2, h - 1),
            dx = sc.randomDir() * (math.random() > 0.5 and 1 or 0),
            dy = sc.randomDir(),
            size = math.random(1, 3),
            color = lavaColors[math.random(#lavaColors)],
            tick = 0,
            speed = math.random(2, 4),
        })
    end
end

function scr.update()
    for _, b in ipairs(blobs) do
        b.tick = b.tick + 1
        if b.tick >= b.speed then
            b.tick = 0
            b.x = b.x + b.dx
            b.y = b.y + b.dy

            if b.x <= 2 or b.x >= w - 1 then
                b.dx = -b.dx
            end
            if b.y <= 1 then
                b.dy = 1
                b.color = lavaColors[math.random(#lavaColors)]
            elseif b.y >= h then
                b.dy = -1
                b.color = lavaColors[math.random(#lavaColors)]
            end

            if math.random() > 0.9 then
                b.dx = sc.randomDir() * (math.random() > 0.5 and 1 or 0)
            end
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, b in ipairs(blobs) do
        term.setTextColor(b.color)
        local chars = {"@", "O", "o"}
        for dy = -b.size, b.size do
            for dx = -b.size, b.size do
                local dist = math.abs(dx) + math.abs(dy)
                if dist <= b.size then
                    local px = b.x + dx
                    local py = b.y + dy
                    if px >= 1 and px <= w and py >= 1 and py <= h then
                        term.setCursorPos(px, py)
                        if dist == 0 then
                            term.setBackgroundColor(b.color)
                            term.setTextColor(colors.white)
                            term.write(" ")
                        else
                            term.setBackgroundColor(colors.black)
                            term.setTextColor(b.color)
                            term.write(chars[math.min(dist, #chars)])
                        end
                    end
                end
            end
        end
    end
    term.setBackgroundColor(colors.black)
end

return scr
