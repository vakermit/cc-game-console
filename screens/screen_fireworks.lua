local sc = require("lib.screen")

local scr = {}

local w, h
local rockets, particles

function scr.title()
    return "Fireworks"
end

function scr.init(width, height)
    w = width
    h = height
    rockets = {}
    particles = {}
end

local function explode(fw)
    local dirs = {
        {-2,-2},{-1,-2},{0,-2},{1,-2},{2,-2},
        {-3,-1},{-2,-1},{2,-1},{3,-1},
        {-3,0},{-2,0},{2,0},{3,0},
        {-3,1},{-2,1},{2,1},{3,1},
        {-2,2},{-1,2},{0,2},{1,2},{2,2},
    }
    for _, d in ipairs(dirs) do
        table.insert(particles, {
            x = fw.x + d[1],
            y = fw.y + d[2],
            color = fw.color,
            life = math.random(3, 7),
            char = ({"*", "+", ".", "x"})[math.random(4)],
        })
    end
end

function scr.update()
    for i = #rockets, 1, -1 do
        rockets[i].y = rockets[i].y - 1
        if rockets[i].y <= rockets[i].targetY then
            explode(rockets[i])
            table.remove(rockets, i)
        end
    end

    for i = #particles, 1, -1 do
        particles[i].life = particles[i].life - 1
        if particles[i].life <= 0 then
            table.remove(particles, i)
        end
    end

    if math.random() > 0.7 then
        table.insert(rockets, {
            x = math.random(5, w - 4),
            y = h,
            targetY = math.random(3, math.floor(h / 2)),
            color = sc.randomBright(),
        })
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, fw in ipairs(rockets) do
        if fw.y >= 1 and fw.y <= h then
            term.setCursorPos(fw.x, fw.y)
            term.setTextColor(fw.color)
            term.write("|")
        end
    end

    for _, p in ipairs(particles) do
        if p.x >= 1 and p.x <= w and p.y >= 1 and p.y <= h then
            term.setCursorPos(p.x, p.y)
            if p.life > 3 then
                term.setTextColor(p.color)
            else
                term.setTextColor(colors.gray)
            end
            term.write(p.char)
        end
    end
end

return scr
