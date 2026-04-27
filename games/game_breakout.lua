local game = {}

local width, height
local paddleX, paddleW
local ballX, ballY, ballDX, ballDY
local bricks, brickRows, brickCols
local score, lives
local gameOverFlag, gameOverTimer
local tickAccum, ballSpeed
local serving

local brickColors = {
    colors.red, colors.orange, colors.yellow,
    colors.green, colors.cyan,
}

local function initBricks()
    bricks = {}
    brickCols = math.floor((width - 2) / 3)
    brickRows = 5
    for row = 1, brickRows do
        bricks[row] = {}
        for col = 1, brickCols do
            bricks[row][col] = true
        end
    end
end

local function bricksLeft()
    local count = 0
    for row = 1, brickRows do
        for col = 1, brickCols do
            if bricks[row][col] then count = count + 1 end
        end
    end
    return count
end

local function serveBall()
    ballX = paddleX + math.floor(paddleW / 2)
    ballY = height - 3
    ballDX = ({-1, 1})[math.random(2)]
    ballDY = -1
    serving = true
end

local function initRound()
    paddleW = 7
    paddleX = math.floor((width - paddleW) / 2)
    ballSpeed = 0.08
    tickAccum = 0
    serveBall()
end

function game.title()
    return "Breakout"
end

function game.getControls()
    return {
        { action = "left/right", description = "Move paddle" },
        { action = "action",     description = "Launch ball" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    score = 0
    lives = 3
    gameOverFlag = false
    gameOverTimer = 0
    math.randomseed(os.clock() * 1000)
    initBricks()
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOverFlag then return "menu" end

    if p1.isDown("left") and paddleX > 1 then
        paddleX = paddleX - 1
    elseif p1.isDown("right") and paddleX + paddleW <= width then
        paddleX = paddleX + 1
    end

    if serving then
        ballX = paddleX + math.floor(paddleW / 2)
        ballY = height - 3
        if p1.wasPressed("action") then
            serving = false
        end
        return
    end

    tickAccum = tickAccum + dt
    if tickAccum < ballSpeed then return end
    tickAccum = tickAccum - ballSpeed

    ballX = ballX + ballDX
    ballY = ballY + ballDY

    if ballX <= 1 or ballX >= width then
        ballDX = -ballDX
        ballX = math.max(1, math.min(width, ballX))
    end

    if ballY <= 1 then
        ballDY = -ballDY
        ballY = 1
    end

    if ballY >= height - 1 then
        if ballX >= paddleX and ballX < paddleX + paddleW then
            ballDY = -1
            local hitPos = (ballX - paddleX) / paddleW
            if hitPos < 0.3 then ballDX = -1
            elseif hitPos > 0.7 then ballDX = 1
            end
            ballY = height - 2
        else
            lives = lives - 1
            if lives <= 0 then
                gameOverFlag = true
                gameOverTimer = 0
            else
                serveBall()
            end
            return
        end
    end

    local brickStartY = 3
    local brickH = 1
    local brickW = 3
    local brow = ballY - brickStartY + 1
    local bcol = math.floor((ballX - 1) / brickW) + 1

    if brow >= 1 and brow <= brickRows and bcol >= 1 and bcol <= brickCols then
        if bricks[brow][bcol] then
            bricks[brow][bcol] = false
            ballDY = -ballDY
            score = score + (brickRows - brow + 1) * 10

            if bricksLeft() == 0 then
                initBricks()
                initRound()
                ballSpeed = math.max(0.03, ballSpeed - 0.01)
            end
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorPos(2, 1)
    term.write("Score:" .. score)
    term.setCursorPos(width - 8, 1)
    term.write("Lives:" .. lives)

    local brickStartY = 3
    local brickW = 3
    for row = 1, brickRows do
        local col_color = brickColors[((row - 1) % #brickColors) + 1]
        for col = 1, brickCols do
            if bricks[row][col] then
                local bx = (col - 1) * brickW + 1
                local by = brickStartY + row - 1
                term.setCursorPos(bx, by)
                term.setBackgroundColor(col_color)
                term.setTextColor(colors.white)
                term.write(string.rep(" ", brickW))
            end
        end
    end
    term.setBackgroundColor(colors.black)

    term.setCursorPos(paddleX, height - 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.white)
    term.write(string.rep(" ", paddleW))
    term.setBackgroundColor(colors.black)

    term.setCursorPos(ballX, ballY)
    term.setTextColor(colors.white)
    term.write("O")

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
        term.write("Score: " .. score)

    end
end

function game.cleanup()
end

return game
