local sc = require("lib.screen")

local scr = {}

local w, h
local snakes

function scr.title()
    return "Snakes"
end

function scr.init(width, height)
    w = width
    h = height
    snakes = {}
    for i = 1, 4 do
        local sx = math.random(5, w - 4)
        local sy = math.random(5, h - 4)
        local body = {}
        for j = 1, 12 do
            table.insert(body, { x = sx, y = sy })
        end
        table.insert(snakes, {
            body = body,
            dx = sc.randomDir(),
            dy = 0,
            color = sc.randomBright(),
            tick = 0,
            speed = math.random(1, 2),
        })
    end
end

function scr.update()
    for _, s in ipairs(snakes) do
        s.tick = s.tick + 1
        if s.tick < s.speed then goto continue end
        s.tick = 0

        if math.random() > 0.7 then
            if s.dx ~= 0 then
                s.dx = 0
                s.dy = sc.randomDir()
            else
                s.dy = 0
                s.dx = sc.randomDir()
            end
        end

        local head = s.body[1]
        local nx = head.x + s.dx
        local ny = head.y + s.dy

        if nx < 1 then nx = w end
        if nx > w then nx = 1 end
        if ny < 1 then ny = h end
        if ny > h then ny = 1 end

        table.insert(s.body, 1, { x = nx, y = ny })
        table.remove(s.body)

        ::continue::
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, s in ipairs(snakes) do
        for i, seg in ipairs(s.body) do
            term.setCursorPos(seg.x, seg.y)
            if i == 1 then
                term.setTextColor(colors.white)
                term.write("@")
            elseif i <= 3 then
                term.setTextColor(s.color)
                term.write("#")
            else
                term.setTextColor(s.color)
                term.write("o")
            end
        end
    end
end

return scr
