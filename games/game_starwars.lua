local game = {}

local width, height
local centerX, centerY
local shields
local score
local gameOver
local ties
local laserFrames
local spawnTimer, spawnRate
local wave, waveKills
local stars

local MAX_SHIELDS = 5

local tieSmall = { "H" }
local tieMid = { "|-|" }
local tieLarge = {
    "|   |",
    "|\\ /|",
    "| O |",
    "|/ \\|",
    "|   |",
}

local tieSprites = { [3] = tieSmall, [2] = tieMid, [1] = tieLarge }

function game.title()
    return "X-Wing Assault"
end

function game.getControls()
    return {
        { action = "up/down", description = "Pitch (inverted)" },
        { action = "left/right", description = "Roll (inverted)" },
        { action = "action", description = "Fire lasers" },
    }
end

local function spawnTie()
    local t = {
        x = math.random(4, width - 4),
        y = math.random(3, height - 3),
        dist = 3,
        timer = 0,
        approachRate = math.random(18, 30),
    }
    table.insert(ties, t)
end

local function getTieSprite(dist)
    return tieSprites[dist] or tieSmall
end

local function getTieWidth(dist)
    return #getTieSprite(dist)[1]
end

local function getTieHeight(dist)
    return #getTieSprite(dist)
end

local function hitTest(rx, ry, tie)
    local tw = getTieWidth(tie.dist)
    local th = getTieHeight(tie.dist)
    local tx = tie.x - math.floor(tw / 2)
    local ty = tie.y - math.floor(th / 2)
    return rx >= tx and rx <= tx + tw - 1 and ry >= ty and ry <= ty + th - 1
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    centerX = math.floor(width / 2)
    centerY = math.floor(height / 2)
    shields = MAX_SHIELDS
    score = 0
    gameOver = false
    ties = {}
    laserFrames = 0
    spawnTimer = 0
    spawnRate = 50
    wave = 1
    waveKills = 0

    stars = {}
    math.randomseed(42)
    for _ = 1, 12 do
        stars[#stars + 1] = { x = math.random(1, width), y = math.random(2, height) }
    end
    math.randomseed(os.clock() * 1000)
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOver then return "menu" end

    if laserFrames > 0 then
        laserFrames = laserFrames - 1
        return
    end

    -- Inverted: up pushes TIEs down, down pushes TIEs up
    local dx, dy = 0, 0
    if p1.isDown("up") then dy = 1 end
    if p1.isDown("down") then dy = -1 end
    if p1.isDown("left") then dx = 1 end
    if p1.isDown("right") then dx = -1 end

    if dx ~= 0 or dy ~= 0 then
        for _, t in ipairs(ties) do
            t.x = t.x + dx
            t.y = t.y + dy
        end
    end

    if p1.wasPressed("action") then
        laserFrames = 3

        for i = #ties, 1, -1 do
            if hitTest(centerX, centerY, ties[i]) then
                local dist = ties[i].dist
                table.remove(ties, i)
                score = score + (4 - dist) * 10
                waveKills = waveKills + 1
                if waveKills >= 5 then
                    wave = wave + 1
                    waveKills = 0
                    spawnRate = math.max(20, spawnRate - 8)
                end
                break
            end
        end
    end

    spawnTimer = spawnTimer + 1
    if spawnTimer >= spawnRate and #ties < 4 then
        spawnTimer = 0
        spawnTie()
    end

    for i = #ties, 1, -1 do
        local t = ties[i]
        t.timer = t.timer + 1
        if t.timer >= t.approachRate then
            t.timer = 0
            t.dist = t.dist - 1
            if t.dist <= 0 then
                table.remove(ties, i)
                shields = shields - 1
                if shields <= 0 then
                    shields = 0
                    gameOver = true
                end
            end
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorPos(1, 1)
    term.setTextColor(colors.green)
    term.write("SHD:")
    for i = 1, MAX_SHIELDS do
        if i <= shields then
            term.setTextColor(colors.green)
            term.write("|")
        else
            term.setTextColor(colors.gray)
            term.write(".")
        end
    end

    local scoreStr = "PTS:" .. score
    term.setCursorPos(width - #scoreStr + 1, 1)
    term.setTextColor(colors.yellow)
    term.write(scoreStr)

    local waveStr = "W" .. wave
    term.setCursorPos(math.floor((width - #waveStr) / 2) + 1, 1)
    term.setTextColor(colors.lightGray)
    term.write(waveStr)

    term.setTextColor(colors.gray)
    for _, s in ipairs(stars) do
        term.setCursorPos(s.x, s.y)
        term.write(".")
    end

    for _, t in ipairs(ties) do
        local sprite = getTieSprite(t.dist)
        local sw = getTieWidth(t.dist)
        local sh = getTieHeight(t.dist)
        local startX = t.x - math.floor(sw / 2)
        local startY = t.y - math.floor(sh / 2)

        term.setTextColor(colors.lightGray)
        for row = 1, #sprite do
            local drawY = startY + row - 1
            if drawY >= 2 and drawY <= height then
                local line = sprite[row]
                if startX >= 1 and startX + sw - 1 <= width then
                    term.setCursorPos(startX, drawY)
                    term.write(line)
                else
                    local clampX = math.max(1, startX)
                    term.setCursorPos(clampX, drawY)
                    if startX < 1 then
                        line = line:sub(2 - startX)
                    end
                    term.write(line:sub(1, width - clampX + 1))
                end
            end
        end
    end

    if laserFrames > 0 then
        term.setTextColor(colors.red)
        local tx, ty = centerX, centerY

        local bolts = {
            { ox = 1,         oy = 2,      dx = 1,  dy = 1,  char = "\\" },
            { ox = width,     oy = 2,      dx = -1, dy = 1,  char = "/" },
            { ox = 1,         oy = height, dx = 1,  dy = -1, char = "/" },
            { ox = width,     oy = height, dx = -1, dy = -1, char = "\\" },
        }

        for _, b in ipairs(bolts) do
            local stepsX = (b.dx == 1) and (tx - 1) or (width - tx)
            local stepsY = (b.dy == 1) and (ty - 2) or (height - ty)
            local steps = math.min(stepsX, stepsY)
            if steps > 0 then
                local progress = math.min(steps, 4 - laserFrames + 2)
                for s = 1, progress do
                    local bx = (b.dx == 1) and s or (width - s + 1)
                    local by = (b.dy == 1) and (1 + s) or (height - s)
                    if bx >= 1 and bx <= width and by >= 2 and by <= height then
                        term.setCursorPos(bx, by)
                        term.write(b.char)
                    end
                end
            end
        end
    end

    term.setTextColor(colors.lime)
    term.setCursorPos(centerX, centerY)
    term.write("+")
    term.setCursorPos(centerX - 1, centerY)
    term.write("[")
    term.setCursorPos(centerX + 1, centerY)
    term.write("]")
    term.setCursorPos(centerX, centerY - 1)
    term.write("|")
    term.setCursorPos(centerX, centerY + 1)
    term.write("|")

    if gameOver then
        local msg = "GAME OVER"
        local msg2 = "Score: " .. score
        local mx = math.floor((width - #msg) / 2) + 1
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
        term.setCursorPos(math.floor((width - #msg2) / 2) + 1, my + 1)
        term.setTextColor(colors.yellow)
        term.write(msg2)
    end
end

function game.cleanup()
end

return game
