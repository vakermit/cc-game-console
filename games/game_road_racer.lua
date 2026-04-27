local game = {}

local width, height
local playerX, playerLane
local roadLeft, roadWidth
local scroll
local speed, maxSpeed
local score
local gameOver
local gameOverTimer
local tickAccum

local enemies
local enemySpawnTimer
local enemySpawnRate

local scenery
local sceneryTimer

local roadSegments
local curveDir, curveTimer

local laneCount = 3

local function laneX(lane)
    return roadLeft + math.floor((lane - 0.5) * (roadWidth / laneCount))
end

local function spawnEnemy()
    local lane = math.random(laneCount)
    table.insert(enemies, {
        x = laneX(lane),
        y = 0,
        lane = lane,
        char = "V",
        color = ({colors.red, colors.orange, colors.yellow, colors.magenta})[math.random(4)],
    })
end

local function spawnScenery(side)
    local chars = {"*", "T", "t", "#", "^"}
    local c = chars[math.random(#chars)]
    local x
    if side == "left" then
        x = math.random(1, roadLeft - 2)
    else
        x = roadLeft + roadWidth + math.random(1, width - roadLeft - roadWidth)
    end
    table.insert(scenery, {
        x = x,
        y = 0,
        char = c,
        color = ({colors.green, colors.lime, colors.brown})[math.random(3)],
    })
end

function game.title()
    return "Road Racer"
end

function game.getControls()
    return {
        { action = "left/right", description = "Change lane" },
        { action = "up",         description = "Accelerate" },
        { action = "down",       description = "Brake" },
        { action = "action",     description = "Boost" },
    }
end

local function initRound()
    roadLeft = math.floor((width - roadWidth) / 2)
    playerLane = 2
    playerX = laneX(playerLane)
    scroll = 0
    speed = 0.3
    score = 0
    gameOver = false
    gameOverTimer = 0
    tickAccum = 0
    enemies = {}
    enemySpawnTimer = 0
    enemySpawnRate = 1.5
    scenery = {}
    sceneryTimer = 0
    roadSegments = {}
    curveDir = 0
    curveTimer = 0
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    roadWidth = math.max(9, math.floor(width * 0.35))
    if roadWidth % 2 == 0 then roadWidth = roadWidth + 1 end
    maxSpeed = 0.08
    math.randomseed(os.clock() * 1000)
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOver then return "menu" end
    tickAccum = tickAccum + dt

    if p1.isDown("up") then
        speed = math.max(maxSpeed, speed - 0.005)
    elseif p1.isDown("down") then
        speed = math.min(0.5, speed + 0.01)
    end

    if p1.wasPressed("action") then
        speed = math.max(0.04, speed - 0.08)
    end

    if p1.wasPressed("left") then
        playerLane = math.max(1, playerLane - 1)
    elseif p1.wasPressed("right") then
        playerLane = math.min(laneCount, playerLane + 1)
    end
    playerX = laneX(playerLane)

    if tickAccum < speed then return end
    tickAccum = tickAccum - speed

    score = score + 1

    curveTimer = curveTimer - 1
    if curveTimer <= 0 then
        curveDir = ({-1, 0, 0, 0, 1})[math.random(5)]
        curveTimer = math.random(10, 30)
    end

    roadLeft = roadLeft + curveDir
    roadLeft = math.max(3, math.min(width - roadWidth - 2, roadLeft))

    playerX = laneX(playerLane)

    enemySpawnTimer = enemySpawnTimer + 1
    local spawnInterval = math.max(5, math.floor(enemySpawnRate / math.max(speed, 0.05)))
    if enemySpawnTimer >= spawnInterval then
        enemySpawnTimer = 0
        spawnEnemy()
    end

    for i = #enemies, 1, -1 do
        enemies[i].y = enemies[i].y + 1
        enemies[i].x = laneX(enemies[i].lane)
        if enemies[i].y > height then
            table.remove(enemies, i)
        end
    end

    sceneryTimer = sceneryTimer + 1
    if sceneryTimer >= 2 then
        sceneryTimer = 0
        if math.random() > 0.5 then spawnScenery("left") end
        if math.random() > 0.5 then spawnScenery("right") end
    end

    for i = #scenery, 1, -1 do
        scenery[i].y = scenery[i].y + 1
        if scenery[i].y > height then
            table.remove(scenery, i)
        end
    end

    local playerY = height - 2
    for _, e in ipairs(enemies) do
        if e.y >= playerY - 1 and e.y <= playerY + 1 and e.lane == playerLane then
            gameOver = true
            break
        end
    end

    speed = math.max(maxSpeed, speed - 0.0005)
end

function game.draw()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clear()

    for _, s in ipairs(scenery) do
        if s.y >= 1 and s.y <= height then
            term.setCursorPos(s.x, s.y)
            term.setBackgroundColor(colors.gray)
            term.setTextColor(s.color)
            term.write(s.char)
        end
    end

    for y = 1, height do
        term.setCursorPos(roadLeft, y)
        term.setBackgroundColor(colors.black)
        term.write(string.rep(" ", roadWidth))

        term.setBackgroundColor(colors.white)
        term.setCursorPos(roadLeft - 1, y)
        term.write(" ")
        term.setCursorPos(roadLeft + roadWidth, y)
        term.write(" ")
    end

    local centerX = roadLeft + math.floor(roadWidth / 2)
    term.setBackgroundColor(colors.black)
    for y = 1, height do
        local dashPhase = (y + math.floor(score / 1)) % 4
        if dashPhase < 2 then
            term.setCursorPos(centerX, y)
            term.setTextColor(colors.yellow)
            term.write("|")
        end
    end

    local laneW = math.floor(roadWidth / laneCount)
    for lane = 2, laneCount do
        local lx = roadLeft + (lane - 1) * laneW
        for y = 1, height do
            local dashPhase = (y + math.floor(score / 1)) % 4
            if dashPhase < 1 then
                term.setCursorPos(lx, y)
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.gray)
                term.write(":")
            end
        end
    end

    for _, e in ipairs(enemies) do
        if e.y >= 1 and e.y <= height then
            term.setCursorPos(e.x, e.y)
            term.setBackgroundColor(colors.black)
            term.setTextColor(e.color)
            term.write(e.char)
        end
    end

    local playerY = height - 2
    term.setCursorPos(playerX, playerY - 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.write("^")
    term.setCursorPos(playerX - 1, playerY)
    term.write("<#>")
    term.setCursorPos(playerX, playerY + 1)
    term.write("V")

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(roadLeft + 1, 1)
    term.write("Score:" .. score)

    local spdPct = math.floor((1 - (speed - maxSpeed) / (0.5 - maxSpeed)) * 100)
    local spdStr = spdPct .. "%"
    term.setCursorPos(roadLeft + roadWidth - #spdStr - 1, 1)
    term.write(spdStr)

    if gameOver then
        local msg = "CRASHED!"
        local mx = math.floor((width - #msg - 2) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(mx - 1, my + 1)
        term.write("Score: " .. score)

    end
end

function game.cleanup()
end

return game
