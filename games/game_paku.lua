local game = {}

local width, height
local mapW, mapH
local mapX, mapY
local player, playerDir, playerNext
local ghosts
local dots, totalDots
local powerTimer
local score, lives
local gameOver, gameOverTimer
local tickAccum, moveSpeed
local mouthOpen

local map = {
    "###############",
    "#......#......#",
    "#.##.#.#.#.##.#",
    "#.............#",
    "#.##.#.#.#.##.#",
    "#....#...#....#",
    "###.##   ##.###",
    "  #.#     #.#  ",
    "###.#     #.###",
    "#.....#.#.....#",
    "#.###.#.#.###.#",
    "#.............#",
    "#.##.##.##.##.#",
    "#......#......#",
    "###############",
}

mapW = #map[1]
mapH = #map

local function isWall(x, y)
    if y < 1 or y > mapH or x < 1 or x > mapW then return true end
    return map[y]:sub(x, x) == "#"
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

local powerDots = {}

local function initPowerDots()
    powerDots = {
        { x = 2, y = 2 },
        { x = mapW - 1, y = 2 },
        { x = 2, y = mapH - 1 },
        { x = mapW - 1, y = mapH - 1 },
    }
end

local ghostColors = { colors.red, colors.pink, colors.cyan, colors.orange }

local function initGhosts()
    ghosts = {}
    local starts = {
        { x = 7, y = 8 },
        { x = 8, y = 8 },
        { x = 9, y = 8 },
        { x = 8, y = 9 },
    }
    for i = 1, 4 do
        ghosts[i] = {
            x = starts[i].x,
            y = starts[i].y,
            color = ghostColors[i],
            dir = ({ "up", "down", "left", "right" })[math.random(4)],
            scared = false,
            moveTick = 0,
        }
    end
end

local dirs = {
    up    = { dx = 0,  dy = -1 },
    down  = { dx = 0,  dy = 1 },
    left  = { dx = -1, dy = 0 },
    right = { dx = 1,  dy = 0 },
}

local function canMove(x, y, dir)
    local d = dirs[dir]
    return not isWall(x + d.dx, y + d.dy)
end

local function moveGhost(g)
    g.moveTick = g.moveTick + 1
    local spd = g.scared and 3 or 2
    if g.moveTick < spd then return end
    g.moveTick = 0

    local options = {}
    local opposites = { up = "down", down = "up", left = "right", right = "left" }
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
    g.x = g.x + d.dx
    g.y = g.y + d.dy
end

local function initRound()
    player = { x = 8, y = 12 }
    playerDir = "right"
    playerNext = nil
    powerTimer = 0
    tickAccum = 0
    moveSpeed = 0.12
    mouthOpen = true
    gameOver = false
    gameOverTimer = 0
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
    mapX = math.floor((width - mapW) / 2) + 1
    mapY = math.floor((height - mapH) / 2) + 1
    score = 0
    lives = 3
    math.randomseed(os.clock() * 1000)
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

    mouthOpen = not mouthOpen

    if playerNext and canMove(player.x, player.y, playerNext) then
        playerDir = playerNext
        playerNext = nil
    end

    if canMove(player.x, player.y, playerDir) then
        local d = dirs[playerDir]
        player.x = player.x + d.dx
        player.y = player.y + d.dy
    end

    if player.y >= 1 and player.y <= mapH and dots[player.y][player.x] then
        dots[player.y][player.x] = false
        score = score + 10
        totalDots = totalDots - 1
    end

    for i = #powerDots, 1, -1 do
        if powerDots[i].x == player.x and powerDots[i].y == player.y then
            table.remove(powerDots, i)
            score = score + 50
            powerTimer = 40
            for _, g in ipairs(ghosts) do
                g.scared = true
            end
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

    for i, g in ipairs(ghosts) do
        if g.x == player.x and g.y == player.y then
            if g.scared then
                score = score + 200
                g.x = 8
                g.y = 9
                g.scared = false
            else
                lives = lives - 1
                if lives <= 0 then
                    gameOver = true
                else
                    initRound()
                end
                return
            end
        end
    end

    if totalDots <= 0 and #powerDots <= 0 then
        initDots()
        initPowerDots()
        initRound()
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    for y = 1, mapH do
        for x = 1, mapW do
            local sx = mapX + x - 1
            local sy = mapY + y - 1
            local ch = map[y]:sub(x, x)

            if ch == "#" then
                term.setCursorPos(sx, sy)
                term.setTextColor(colors.blue)
                term.write("#")
            elseif dots[y][x] then
                term.setCursorPos(sx, sy)
                term.setTextColor(colors.white)
                term.write("\x07")
            end
        end
    end

    for _, pd in ipairs(powerDots) do
        term.setCursorPos(mapX + pd.x - 1, mapY + pd.y - 1)
        term.setTextColor(colors.white)
        term.write("O")
    end

    for _, g in ipairs(ghosts) do
        term.setCursorPos(mapX + g.x - 1, mapY + g.y - 1)
        if g.scared then
            if powerTimer < 10 and powerTimer % 2 == 0 then
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.blue)
            end
        else
            term.setTextColor(g.color)
        end
        term.write("M")
    end

    term.setCursorPos(mapX + player.x - 1, mapY + player.y - 1)
    term.setTextColor(colors.yellow)
    if mouthOpen then
        local faces = { up = "V", down = "^", left = ">", right = "<" }
        term.write(faces[playerDir])
    else
        term.write("@")
    end

    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.write("Score:" .. score)

    term.setTextColor(colors.yellow)
    local livesStr = string.rep("@ ", lives)
    term.setCursorPos(width - #livesStr, 1)
    term.write(livesStr)

    if gameOver then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(mx - 2, my + 1)
        term.write("Score: " .. score)

    end
end

function game.cleanup()
end

return game
