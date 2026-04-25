local monitor = peripheral.find("monitor")
local output = monitor or term.current()
term.redirect(output)

local w, h = term.getSize()
local mode = 1
local modeCount = 4
local modeTimer = 0
local modeDuration = 150

local brightColors = {
    colors.red, colors.orange, colors.yellow, colors.lime,
    colors.cyan, colors.lightBlue, colors.magenta, colors.pink,
    colors.white,
}

math.randomseed(os.clock() * 1000)

-- Mode 1: Bouncing Ball
local ball = {}

local function initBall()
    ball.x = math.random(3, w - 2)
    ball.y = math.random(3, h - 2)
    ball.dx = ({-1, 1})[math.random(2)]
    ball.dy = ({-1, 1})[math.random(2)]
    ball.color = brightColors[math.random(#brightColors)]
    ball.trail = {}
end

local function updateBall()
    table.insert(ball.trail, { x = ball.x, y = ball.y, color = ball.color, life = 8 })
    if #ball.trail > 20 then table.remove(ball.trail, 1) end

    ball.x = ball.x + ball.dx
    ball.y = ball.y + ball.dy

    if ball.x <= 1 or ball.x >= w then
        ball.dx = -ball.dx
        ball.color = brightColors[math.random(#brightColors)]
    end
    if ball.y <= 1 or ball.y >= h then
        ball.dy = -ball.dy
        ball.color = brightColors[math.random(#brightColors)]
    end

    ball.x = math.max(1, math.min(w, ball.x))
    ball.y = math.max(1, math.min(h, ball.y))
end

local function drawBall()
    term.setBackgroundColor(colors.black)
    term.clear()

    for i, t in ipairs(ball.trail) do
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

-- Mode 2: Fireworks
local fireworks = {}
local particles = {}

local function launchFirework()
    table.insert(fireworks, {
        x = math.random(5, w - 4),
        y = h,
        targetY = math.random(3, math.floor(h / 2)),
        color = brightColors[math.random(#brightColors)],
    })
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

local function updateFireworks()
    for i = #fireworks, 1, -1 do
        fireworks[i].y = fireworks[i].y - 1
        if fireworks[i].y <= fireworks[i].targetY then
            explode(fireworks[i])
            table.remove(fireworks, i)
        end
    end

    for i = #particles, 1, -1 do
        particles[i].life = particles[i].life - 1
        if particles[i].life <= 0 then
            table.remove(particles, i)
        end
    end

    if math.random() > 0.7 then
        launchFirework()
    end
end

local function drawFireworks()
    term.setBackgroundColor(colors.black)
    term.clear()

    for _, fw in ipairs(fireworks) do
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

-- Mode 3: Matrix
local columns = {}

local function initMatrix()
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

local function updateMatrix()
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

local function drawMatrix()
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

-- Mode 4: ASCII Cat
local catArt = {
    "    /\\_/\\    ",
    "   ( o.o )   ",
    "    > ^ <    ",
    "   /|   |\\   ",
    "  (_|   |_)  ",
    "",
    "  zzZ  zzZ   ",
}

local catX, catY, catDx
local catColor
local catBlink

local function initCat()
    catX = math.floor((w - 13) / 2)
    catY = math.floor((h - #catArt) / 2)
    catDx = ({-1, 1})[math.random(2)]
    catColor = brightColors[math.random(#brightColors)]
    catBlink = 0
end

local function updateCat()
    catBlink = catBlink + 1

    if catBlink % 4 == 0 then
        catX = catX + catDx
        if catX <= 1 or catX + 13 >= w then
            catDx = -catDx
            catColor = brightColors[math.random(#brightColors)]
        end
    end
end

local function drawCat()
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
    local msg = "meow."
    if catBlink % 60 < 20 then
        term.setCursorPos(catX + 3, catY + #frame)
        term.write(msg)
    end
end

-- Init all modes
initBall()
initMatrix()
initCat()

-- Main loop
local timer = os.startTimer(0.15)

while true do
    local event, p1 = os.pullEvent()

    if event == "timer" and p1 == timer then
        modeTimer = modeTimer + 0.15

        if modeTimer >= modeDuration then
            modeTimer = 0
            mode = (mode % modeCount) + 1
            if mode == 1 then initBall() end
            if mode == 2 then fireworks = {} particles = {} end
            if mode == 3 then initMatrix() end
            if mode == 4 then initCat() end
        end

        if mode == 1 then
            updateBall()
            drawBall()
        elseif mode == 2 then
            updateFireworks()
            drawFireworks()
        elseif mode == 3 then
            updateMatrix()
            drawMatrix()
        elseif mode == 4 then
            updateCat()
            drawCat()
        end

        timer = os.startTimer(0.15)

    elseif event == "key" or event == "mouse_click" or event == "monitor_touch" then
        break
    end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
