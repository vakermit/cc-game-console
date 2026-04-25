local game = {}

local width, height
local snake, dir, nextDir
local foodX, foodY
local score
local gameOverFlag, gameOverTimer
local tickAccum, moveSpeed

local function placeFood()
    local occupied = {}
    for _, seg in ipairs(snake) do
        occupied[seg.y * 1000 + seg.x] = true
    end
    local tries = 0
    repeat
        foodX = math.random(2, width - 1)
        foodY = math.random(2, height - 1)
        tries = tries + 1
    until not occupied[foodY * 1000 + foodX] or tries > 200
end

local function initRound()
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)
    snake = {}
    for i = 0, 4 do
        table.insert(snake, { x = cx - i, y = cy })
    end
    dir = "right"
    nextDir = "right"
    score = 0
    moveSpeed = 0.12
    tickAccum = 0
    gameOverFlag = false
    gameOverTimer = 0
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
    initRound()
end

local opposites = { up = "down", down = "up", left = "right", right = "left" }

function game.update(dt, input)
    local p1 = input.getPlayer(1)

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

    if p1.wasPressed("up") and dir ~= "down" then nextDir = "up" end
    if p1.wasPressed("down") and dir ~= "up" then nextDir = "down" end
    if p1.wasPressed("left") and dir ~= "right" then nextDir = "left" end
    if p1.wasPressed("right") and dir ~= "left" then nextDir = "right" end

    tickAccum = tickAccum + dt
    if tickAccum < moveSpeed then return end
    tickAccum = tickAccum - moveSpeed

    dir = nextDir
    local head = snake[1]
    local nx, ny = head.x, head.y

    if dir == "up" then ny = ny - 1
    elseif dir == "down" then ny = ny + 1
    elseif dir == "left" then nx = nx - 1
    elseif dir == "right" then nx = nx + 1 end

    if nx < 1 or nx > width or ny < 1 or ny > height then
        gameOverFlag = true
        gameOverTimer = 0
        return
    end

    for _, seg in ipairs(snake) do
        if seg.x == nx and seg.y == ny then
            gameOverFlag = true
            gameOverTimer = 0
            return
        end
    end

    table.insert(snake, 1, { x = nx, y = ny })

    if nx == foodX and ny == foodY then
        score = score + 10
        moveSpeed = math.max(0.04, moveSpeed - 0.003)
        placeFood()
    else
        table.remove(snake)
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorPos(2, 1)
    term.write("Score:" .. score)
    term.setCursorPos(width - 6, 1)
    term.write("L:" .. #snake)

    term.setTextColor(colors.red)
    term.setCursorPos(foodX, foodY)
    term.write("@")

    for i, seg in ipairs(snake) do
        term.setCursorPos(seg.x, seg.y)
        if i == 1 then
            term.setTextColor(colors.lime)
            local faces = { up = "V", down = "^", left = ">", right = "<" }
            term.write(faces[dir])
        elseif i <= 3 then
            term.setTextColor(colors.lime)
            term.write("#")
        else
            term.setTextColor(colors.green)
            term.write("o")
        end
    end

    if gameOverFlag then
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
        term.write("Score: " .. score .. "  Length: " .. #snake)

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
