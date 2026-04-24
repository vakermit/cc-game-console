local game = {}

local width, height
local ballX, ballY, ballDirX, ballDirY
local paddle1Y, paddle2Y
local paddleHeight = 3
local paddle1X, paddle2X
local score1, score2
local winScore = 10
local gameOver
local gameOverTimer

local function resetBall()
    ballX = math.floor(width / 2)
    ballY = math.floor(height / 2)
    ballDirX = ({-1, 1})[math.random(2)]
    ballDirY = ({-1, 1})[math.random(2)]
end

local function initRound()
    paddle1X = 2
    paddle2X = width - 1
    paddle1Y = math.floor(height / 2)
    paddle2Y = math.floor(height / 2)
    score1 = 0
    score2 = 0
    gameOver = false
    gameOverTimer = 0
    resetBall()
end

function game.title()
    return "Pong"
end

function game.getControls()
    return {
        { action = "up/down", description = "Move paddle" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)
    local p2 = input.getPlayer(2)

    if gameOver then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            initRound()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 10 then
            return "menu"
        end
        return
    end

    if p1.isDown("up") and paddle1Y > 1 then
        paddle1Y = paddle1Y - 1
    elseif p1.isDown("down") and paddle1Y < height - paddleHeight + 1 then
        paddle1Y = paddle1Y + 1
    end

    if p2.isDown("up") and paddle2Y > 1 then
        paddle2Y = paddle2Y - 1
    elseif p2.isDown("down") and paddle2Y < height - paddleHeight + 1 then
        paddle2Y = paddle2Y + 1
    end

    ballX = ballX + ballDirX
    ballY = ballY + ballDirY

    if ballY <= 1 or ballY >= height then
        ballDirY = -ballDirY
    end

    if ballX == paddle1X + 1 and ballY >= paddle1Y and ballY < paddle1Y + paddleHeight then
        ballDirX = -ballDirX
    elseif ballX == paddle2X - 1 and ballY >= paddle2Y and ballY < paddle2Y + paddleHeight then
        ballDirX = -ballDirX
    end

    if ballX < 1 then
        score2 = score2 + 1
        if score2 >= winScore then
            gameOver = true
        else
            resetBall()
        end
    elseif ballX > width then
        score1 = score1 + 1
        if score1 >= winScore then
            gameOver = true
        else
            resetBall()
        end
    end
end

function game.draw()
    term.clear()

    for i = 0, paddleHeight - 1 do
        term.setCursorPos(paddle1X, paddle1Y + i)
        term.write("|")
        term.setCursorPos(paddle2X, paddle2Y + i)
        term.write("|")
    end

    if not gameOver then
        term.setCursorPos(ballX, ballY)
        term.write("O")
    end

    term.setCursorPos(math.floor(width / 2) - 2, 1)
    term.write(score1 .. " - " .. score2)

    if gameOver then
        local winner = score1 >= winScore and "Player 1" or "Player 2"
        local msg = winner .. " wins!"
        term.setCursorPos(math.floor((width - #msg) / 2), math.floor(height / 2))
        term.write(msg)

        local countdown = math.max(0, 10 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setCursorPos(math.floor((width - #hint) / 2), math.floor(height / 2) + 2)
        term.write(hint)
    end
end

function game.cleanup()
end

return game
