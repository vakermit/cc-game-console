local game = {}

local width, height
local snakes, dirs, nextDirs
local foodX, foodY
local scores
local numPlayers
local gameOverFlag, gameOverTimer, deadPlayer
local tickAccum, moveSpeed
local state, selected

local playerColors = {
    { head = colors.lime, body = colors.green, name = "P1" },
    { head = colors.orange, body = colors.brown, name = "P2" },
}

local function occupied()
    local occ = {}
    for _, s in ipairs(snakes) do
        for _, seg in ipairs(s) do
            occ[seg.y * 1000 + seg.x] = true
        end
    end
    return occ
end

local function placeFood()
    local occ = occupied()
    local tries = 0
    repeat
        foodX = math.random(2, width - 1)
        foodY = math.random(3, height - 1)
        tries = tries + 1
    until not occ[foodY * 1000 + foodX] or tries > 200
end

local function initRound()
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)

    snakes = {}
    dirs = {}
    nextDirs = {}
    scores = {}

    local s1 = {}
    local startY1 = numPlayers == 2 and cy - 2 or cy
    for i = 0, 4 do
        table.insert(s1, { x = cx - i, y = startY1 })
    end
    snakes[1] = s1
    dirs[1] = "right"
    nextDirs[1] = "right"
    scores[1] = 0

    if numPlayers == 2 then
        local s2 = {}
        for i = 0, 4 do
            table.insert(s2, { x = cx + i, y = cy + 2 })
        end
        snakes[2] = s2
        dirs[2] = "left"
        nextDirs[2] = "left"
        scores[2] = 0
    end

    moveSpeed = 0.12
    tickAccum = 0
    gameOverFlag = false
    gameOverTimer = 0
    deadPlayer = nil
    placeFood()
end

function game.title()
    return "Snake"
end

function game.getControls()
    return {
        { action = "arrows", description = "Direction" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    numPlayers = nil
    state = "select"
    selected = 1
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if state == "select" then
        if p1.wasPressed("up") or p1.wasPressed("down") then
            selected = selected == 1 and 2 or 1
        elseif p1.wasPressed("action") then
            numPlayers = selected
            state = "play"
            initRound()
        end
        return
    end

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            initRound()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 10 then
            return "menu"
        end
        return
    end

    if p1.wasPressed("up") and dirs[1] ~= "down" then nextDirs[1] = "up" end
    if p1.wasPressed("down") and dirs[1] ~= "up" then nextDirs[1] = "down" end
    if p1.wasPressed("left") and dirs[1] ~= "right" then nextDirs[1] = "left" end
    if p1.wasPressed("right") and dirs[1] ~= "left" then nextDirs[1] = "right" end

    if numPlayers == 2 then
        local p2 = input.getPlayer(2)
        if p2.wasPressed("up") and dirs[2] ~= "down" then nextDirs[2] = "up" end
        if p2.wasPressed("down") and dirs[2] ~= "up" then nextDirs[2] = "down" end
        if p2.wasPressed("left") and dirs[2] ~= "right" then nextDirs[2] = "left" end
        if p2.wasPressed("right") and dirs[2] ~= "left" then nextDirs[2] = "right" end
    end

    tickAccum = tickAccum + dt
    if tickAccum < moveSpeed then return end
    tickAccum = tickAccum - moveSpeed

    for pn = 1, numPlayers do
        dirs[pn] = nextDirs[pn]
        local head = snakes[pn][1]
        local nx, ny = head.x, head.y

        if dirs[pn] == "up" then ny = ny - 1
        elseif dirs[pn] == "down" then ny = ny + 1
        elseif dirs[pn] == "left" then nx = nx - 1
        elseif dirs[pn] == "right" then nx = nx + 1 end

        if nx < 1 or nx > width or ny < 1 or ny > height then
            gameOverFlag = true
            gameOverTimer = 0
            deadPlayer = pn
            return
        end

        for sn = 1, numPlayers do
            for _, seg in ipairs(snakes[sn]) do
                if seg.x == nx and seg.y == ny then
                    gameOverFlag = true
                    gameOverTimer = 0
                    deadPlayer = pn
                    return
                end
            end
        end

        table.insert(snakes[pn], 1, { x = nx, y = ny })

        if nx == foodX and ny == foodY then
            scores[pn] = scores[pn] + 10
            moveSpeed = math.max(0.04, moveSpeed - 0.002)
            placeFood()
        else
            table.remove(snakes[pn])
        end
    end
end

local function drawSnake(s, d, pc)
    local faces = { up = "V", down = "^", left = ">", right = "<" }
    for i, seg in ipairs(s) do
        term.setCursorPos(seg.x, seg.y)
        if i == 1 then
            term.setTextColor(pc.head)
            term.write(faces[d])
        elseif i <= 3 then
            term.setTextColor(pc.head)
            term.write("#")
        else
            term.setTextColor(pc.body)
            term.write("o")
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    if state == "select" then
        local cy = math.floor(height / 2) - 2
        term.setCursorPos(math.floor((width - 13) / 2), cy)
        term.setTextColor(colors.yellow)
        term.write("Choose players:")

        local opts = { "1 Player", "2 Players" }
        for i, opt in ipairs(opts) do
            term.setCursorPos(math.floor((width - #opt) / 2), cy + 1 + i)
            if i == selected then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. opt .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(opt)
            end
        end
        return
    end

    term.setCursorPos(2, 1)
    term.setTextColor(playerColors[1].head)
    term.write("P1:" .. scores[1])
    term.setTextColor(colors.lightGray)
    term.write(" L:" .. #snakes[1])

    if numPlayers == 2 then
        local p2str = "P2:" .. scores[2] .. " L:" .. #snakes[2]
        term.setCursorPos(width - #p2str, 1)
        term.setTextColor(playerColors[2].head)
        term.write("P2:" .. scores[2])
        term.setTextColor(colors.lightGray)
        term.write(" L:" .. #snakes[2])
    end

    term.setTextColor(colors.red)
    term.setCursorPos(foodX, foodY)
    term.write("@")

    for pn = 1, numPlayers do
        drawSnake(snakes[pn], dirs[pn], playerColors[pn])
    end

    if gameOverFlag then
        local msg
        if numPlayers == 2 and deadPlayer then
            local winner = deadPlayer == 1 and 2 or 1
            msg = playerColors[deadPlayer].name .. " crashed! " .. playerColors[winner].name .. " wins!"
        else
            msg = "GAME OVER"
        end
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)

        local scoreLine
        if numPlayers == 2 then
            scoreLine = "P1:" .. scores[1] .. "  P2:" .. scores[2]
        else
            scoreLine = "Score: " .. scores[1] .. "  Length: " .. #snakes[1]
        end
        term.setCursorPos(math.floor((width - #scoreLine) / 2), my + 1)
        term.write(scoreLine)

        local countdown = math.max(0, 10 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(math.floor((width - #hint) / 2), my + 3)
        term.write(hint)
    end
end

function game.cleanup()
end

return game
