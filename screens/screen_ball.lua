local sc = require("lib.screen")

local scr = {}

local w, h
local ball

function scr.title()
    return "Bouncing Ball"
end

function scr.init(width, height)
    w = width
    h = height
    ball = {
        x = math.random(3, w - 2),
        y = math.random(3, h - 2),
        dx = sc.randomDir(),
        dy = sc.randomDir(),
        color = sc.randomBright(),
        trail = {},
    }
end

function scr.update()
    table.insert(ball.trail, { x = ball.x, y = ball.y, color = ball.color, life = 8 })
    if #ball.trail > 20 then table.remove(ball.trail, 1) end

    ball.x = ball.x + ball.dx
    ball.y = ball.y + ball.dy

    if ball.x <= 1 or ball.x >= w then
        ball.dx = -ball.dx
        ball.color = sc.randomBright()
    end
    if ball.y <= 1 or ball.y >= h then
        ball.dy = -ball.dy
        ball.color = sc.randomBright()
    end

    ball.x = math.max(1, math.min(w, ball.x))
    ball.y = math.max(1, math.min(h, ball.y))
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, t in ipairs(ball.trail) do
        t.life = t.life - 1
        if t.life > 0 then
            term.setCursorPos(t.x, t.y)
            if t.life > 4 then
                term.setTextColor(t.color)
                term.write("o")
            else
                term.setTextColor(colors.gray)
                term.write(".")
            end
        end
    end

    term.setCursorPos(ball.x, ball.y)
    term.setTextColor(ball.color)
    term.write("O")
end

return scr
