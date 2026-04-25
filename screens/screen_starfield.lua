local scr = {}

local w, h
local stars

function scr.title()
    return "Starfield"
end

function scr.init(width, height)
    w = width
    h = height
    stars = {}
    for i = 1, 60 do
        table.insert(stars, {
            x = math.random(1, w),
            y = math.random(1, h),
            speed = math.random(1, 3),
            tick = 0,
        })
    end
end

function scr.update()
    for _, s in ipairs(stars) do
        s.tick = s.tick + 1
        if s.tick >= (4 - s.speed) then
            s.tick = 0
            s.x = s.x - 1
            if s.x < 1 then
                s.x = w
                s.y = math.random(1, h)
                s.speed = math.random(1, 3)
            end
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, s in ipairs(stars) do
        term.setCursorPos(s.x, s.y)
        if s.speed == 3 then
            term.setTextColor(colors.white)
            term.write("*")
        elseif s.speed == 2 then
            term.setTextColor(colors.lightGray)
            term.write("+")
        else
            term.setTextColor(colors.gray)
            term.write(".")
        end
    end
end

return scr
