local sprite = require("lib.sprite")
local sound = require("lib.sound")

local game = {}

local width, height
local mapW, mapH
local mapX, mapY
local CELL = 2

local player, playerDir, playerNext
local ghosts
local dots, totalDots
local powerDots
local powerTimer
local score, lives
local gameOver
local tickAccum, moveSpeed
local animFrame, animTimer
local blinkTimer, blinkOn

local sprites = {}

local map = {
    "#####################",
    "#....#.........#....#",
    "#.##.#.###.###.#.##.#",
    "#...................#",
    "###.##.#.....#.##.###",
    "#...................#",
    "#.##.#.###.###.#.##.#",
    "#....#.........#....#",
    "#####################",
}

mapW = #map[1]
mapH = #map

local wallGrid = {}
for y = 1, mapH do
    wallGrid[y] = {}
    for x = 1, mapW do
        wallGrid[y][x] = map[y]:sub(x, x) == "#"
    end
end

local WALL_FILL = string.rep(" ", CELL)

local ghostColors = { colors.red, colors.pink, colors.cyan, colors.orange }

local dirs = {
    up    = { dx = 0,  dy = -1 },
    down  = { dx = 0,  dy = 1 },
    left  = { dx = -1, dy = 0 },
    right = { dx = 1,  dy = 0 },
}
local opposites = { up = "down", down = "up", left = "right", right = "left" }

local function isWall(x, y)
    if y < 1 or y > mapH or x < 1 or x > mapW then return false end
    return wallGrid[y][x]
end

local function canMove(x, y, dir)
    local d = dirs[dir]
    local nx, ny = x + d.dx, y + d.dy
    if nx < 1 then nx = mapW end
    if nx > mapW then nx = 1 end
    return not isWall(nx, ny)
end

local function wrapX(x)
    if x < 1 then return mapW end
    if x > mapW then return 1 end
    return x
end

local function initDots()
    dots = {}
    totalDots = 0
    for y = 1, mapH do
        dots[y] = {}
        for x = 1, mapW do
            local ch = map[y]:sub(x, x)
            if ch == "." then
                dots[y][x] = true
                totalDots = totalDots + 1
            else
                dots[y][x] = false
            end
        end
    end
end

local function initPowerDots()
    powerDots = {
        { x = 2, y = 2 },
        { x = mapW - 1, y = 2 },
        { x = 2, y = mapH - 1 },
        { x = mapW - 1, y = mapH - 1 },
    }
    for _, pd in ipairs(powerDots) do
        if dots[pd.y] and dots[pd.y][pd.x] then
            dots[pd.y][pd.x] = false
            totalDots = totalDots - 1
        end
    end
end

local function initGhosts()
    ghosts = {}
    local starts = {
        { x = 10, y = 5 },
        { x = 11, y = 5 },
        { x = 12, y = 5 },
        { x = 11, y = 4 },
    }
    for i = 1, 4 do
        ghosts[i] = {
            x = starts[i].x,
            y = starts[i].y,
            color = ghostColors[i],
            dir = ({ "up", "down", "left", "right" })[math.random(4)],
            scared = false,
            moveTick = 0,
            animFrame = 1,
            animTimer = 0,
        }
    end
end

local function moveGhost(g)
    g.moveTick = g.moveTick + 1
    local spd = g.scared and 6 or 3
    if g.moveTick < spd then return end
    g.moveTick = 0

    local options = {}
    for name, _ in pairs(dirs) do
        if name ~= opposites[g.dir] and canMove(g.x, g.y, name) then
            table.insert(options, name)
        end
    end

    if #options == 0 then
        if canMove(g.x, g.y, opposites[g.dir]) then
            options = { opposites[g.dir] }
        else
            return
        end
    end

    if not g.scared and math.random() > 0.3 then
        local best = nil
        local bestDist = 99999
        for _, opt in ipairs(options) do
            local d = dirs[opt]
            local nx, ny = g.x + d.dx, g.y + d.dy
            local dist = math.abs(nx - player.x) + math.abs(ny - player.y)
            if dist < bestDist then
                bestDist = dist
                best = opt
            end
        end
        g.dir = best
    else
        g.dir = options[math.random(#options)]
    end

    local d = dirs[g.dir]
    g.x = wrapX(g.x + d.dx)
    g.y = g.y + d.dy
end

local function gridToScreen(gx, gy)
    return mapX + (gx - 1) * CELL, mapY + (gy - 1) * CELL
end

local function initRound()
    player = { x = 11, y = 6 }
    playerDir = "right"
    playerNext = nil
    powerTimer = 0
    tickAccum = 0
    moveSpeed = 0.12
    animFrame = 1
    animTimer = 0
    blinkTimer = 0
    blinkOn = true
    gameOver = false
    initGhosts()
end

function game.title()
    return "Paku Paku"
end

function game.getControls()
    return {
        { action = "up/down",    description = "Move" },
        { action = "left/right", description = "Move" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    mapX = math.floor((width - mapW * CELL) / 2) + 1
    mapY = math.floor((height - 1 - mapH * CELL) / 2) + 2
    score = 0
    lives = 3
    math.randomseed(os.clock() * 1000)
    sprites.paku = sprite.load("paku.sprite")
    sprites.ghost = sprite.load("ghost.sprite")
    initDots()
    initPowerDots()
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOver then return "menu" end

    if p1.wasPressed("up") then playerNext = "up" end
    if p1.wasPressed("down") then playerNext = "down" end
    if p1.wasPressed("left") then playerNext = "left" end
    if p1.wasPressed("right") then playerNext = "right" end

    tickAccum = tickAccum + dt
    if tickAccum < moveSpeed then return end
    tickAccum = tickAccum - moveSpeed

    animTimer = animTimer + 1
    if animTimer >= 2 then
        animTimer = 0
        animFrame = (animFrame % 2) + 1
    end

    blinkTimer = blinkTimer + 1
    if blinkTimer >= 3 then
        blinkTimer = 0
        blinkOn = not blinkOn
    end

    for _, g in ipairs(ghosts) do
        g.animTimer = g.animTimer + 1
        if g.animTimer >= 3 then
            g.animTimer = 0
            g.animFrame = (g.animFrame % 2) + 1
        end
    end

    if playerNext and canMove(player.x, player.y, playerNext) then
        playerDir = playerNext
        playerNext = nil
    end

    if canMove(player.x, player.y, playerDir) then
        local d = dirs[playerDir]
        player.x = wrapX(player.x + d.dx)
        player.y = player.y + d.dy
    end

    if player.y >= 1 and player.y <= mapH and dots[player.y][player.x] then
        dots[player.y][player.x] = false
        score = score + 10
        totalDots = totalDots - 1
        sound.playNote("hat", 0.3, 18)
    end

    for i = #powerDots, 1, -1 do
        if powerDots[i].x == player.x and powerDots[i].y == player.y then
            table.remove(powerDots, i)
            score = score + 50
            powerTimer = 50
            for _, g in ipairs(ghosts) do
                g.scared = true
            end
            sound.playNote("harp", 0.6, 24)
        end
    end

    if powerTimer > 0 then
        powerTimer = powerTimer - 1
        if powerTimer <= 0 then
            for _, g in ipairs(ghosts) do
                g.scared = false
            end
        end
    end

    for _, g in ipairs(ghosts) do
        moveGhost(g)
    end

    for _, g in ipairs(ghosts) do
        if g.x == player.x and g.y == player.y then
            if g.scared then
                score = score + 200
                g.x = 11
                g.y = 4
                g.scared = false
                sound.playNote("harp", 0.8, 20)
            else
                lives = lives - 1
                sound.playNote("bass", 1.0, 6)
                if lives <= 0 then
                    gameOver = true
                    sound.gameOver()
                else
                    initRound()
                end
                return
            end
        end
    end

    if totalDots <= 0 and #powerDots <= 0 then
        sound.victory()
        initDots()
        initPowerDots()
        initRound()
    end
end

local function drawWalls()
    term.setTextColor(colors.blue)
    term.setBackgroundColor(colors.blue)
    for y = 1, mapH do
        for x = 1, mapW do
            if wallGrid[y][x] then
                local sx, sy = gridToScreen(x, y)
                for dy = 0, CELL - 1 do
                    term.setCursorPos(sx, sy + dy)
                    term.write(WALL_FILL)
                end
            end
        end
    end
    term.setBackgroundColor(colors.black)
end

local function drawDots()
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    for y = 1, mapH do
        for x = 1, mapW do
            if dots[y][x] then
                local sx, sy = gridToScreen(x, y)
                term.setCursorPos(sx, sy)
                term.write("\x07 ")
            end
        end
    end
end

local function drawPowerDots()
    term.setBackgroundColor(colors.black)
    for _, pd in ipairs(powerDots) do
        local sx, sy = gridToScreen(pd.x, pd.y)
        if blinkOn then
            term.setTextColor(colors.white)
            term.setCursorPos(sx, sy)
            term.write("OO")
            term.setCursorPos(sx, sy + 1)
            term.write("OO")
        end
    end
end

local function drawPlayer()
    local sx, sy = gridToScreen(player.x, player.y)
    term.setBackgroundColor(colors.black)
    sprite.draw(sprites.paku, sx, sy, playerDir, animFrame, colors.yellow)
end

local function drawGhosts()
    term.setBackgroundColor(colors.black)
    for _, g in ipairs(ghosts) do
        local sx, sy = gridToScreen(g.x, g.y)
        if g.scared then
            local col = colors.blue
            if powerTimer < 15 and powerTimer % 4 < 2 then
                col = colors.white
            end
            sprite.draw(sprites.ghost, sx, sy, "scared", g.animFrame, col)
        else
            sprite.draw(sprites.ghost, sx, sy, "normal", g.animFrame, g.color)
        end
    end
end

local function drawHUD()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.write("Score:" .. score)

    term.setTextColor(colors.yellow)
    local livesStr = string.rep("@ ", lives)
    term.setCursorPos(width - #livesStr, 1)
    term.write(livesStr)
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    drawWalls()
    drawDots()
    drawPowerDots()
    drawGhosts()
    drawPlayer()
    drawHUD()

    if gameOver then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(mx - 2, my + 1)
        term.write(" Score: " .. score .. " ")
        term.setBackgroundColor(colors.black)
    end
end

function game.cleanup()
    sound.stop()
end

return game
