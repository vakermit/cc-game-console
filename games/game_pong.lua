local game = {}

local width, height
local ballX, ballY, ballDirX, ballDirY
local paddle1Y, paddle2Y
local paddleHeight = 3
local paddle1X, paddle2X
local score1, score2
local gameOver

function game.title()
    return "Pong"
end

function game.getControls()
    return {
        { action = "up/down", description = "Move paddle" },
        { action = "action",  description = "Start game" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    paddle1X = 2
    paddle2X = width - 1
    ballX = math.floor(width / 2)
    ballY = math.floor(height / 2)
    ballDirX = 1
    ballDirY = 1
    paddle1Y = math.floor(height / 2)
    paddle2Y = math.floor(height / 2)
    score1 = 0
    score2 = 0
    gameOver = false
end

function game.update(dt, input)
    if gameOver then return end

    local p1 = input.getPlayer(1)
    local p2 = input.getPlayer(2)

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
        ballX = math.floor(width / 2)
        ballY = math.floor(height / 2)
    elseif ballX > width then
        score1 = score1 + 1
        ballX = math.floor(width / 2)
        ballY = math.floor(height / 2)
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

    term.setCursorPos(ballX, ballY)
    term.write("O")

    term.setCursorPos(math.floor(width / 2) - 2, 1)
    term.write(score1 .. " - " .. score2)
end

function game.cleanup()
end

return game
