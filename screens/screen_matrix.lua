local scr = {}

local w, h
local columns

function scr.title()
    return "Matrix"
end

function scr.init(width, height)
    w = width
    h = height
    columns = {}
    for x = 1, w do
        columns[x] = {
            y = math.random(-h, 0),
            speed = math.random(1, 2),
            tick = 0,
            chars = {},
        }
        for row = 1, h do
            columns[x].chars[row] = string.char(math.random(33, 126))
        end
    end
end

function scr.update()
    for x = 1, w do
        local col = columns[x]
        col.tick = col.tick + 1
        if col.tick >= col.speed then
            col.tick = 0
            col.y = col.y + 1
            if col.y > h + 10 then
                col.y = math.random(-5, 0)
                col.speed = math.random(1, 2)
            end
            if math.random() > 0.7 then
                local row = math.random(1, h)
                col.chars[row] = string.char(math.random(33, 126))
            end
        end
    end
end

function scr.draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    for x = 1, w do
        local col = columns[x]
        local tailLen = math.random(8, 15)
        for i = 0, tailLen do
            local row = col.y - i
            if row >= 1 and row <= h then
                term.setCursorPos(x, row)
                if i == 0 then
                    term.setTextColor(colors.white)
                elseif i < 3 then
                    term.setTextColor(colors.lime)
                elseif i < tailLen - 2 then
                    term.setTextColor(colors.green)
                else
                    term.setTextColor(colors.gray)
                end
                term.write(col.chars[row])
            end
        end
    end
end

return scr
