local game = {}

local width, height
local playerX, playerY
local bulletX, bulletY
local invaders
local invaderRows, invaderCols = 3, 8
local invaderDir
local invaderMoveTimer
local invaderSpeed = 10
local invaderBulletX, invaderBulletY
local score
local gameOver
local tickCount

function game.title()
    return "Space Invaders"
end

function game.getControls()
    return {
        { action = "left/right", description = "Move ship" },
        { action = "action",     description = "Fire" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    playerX = math.floor(width / 2)
    playerY = height - 1
    bulletX = nil
    bulletY = nil
    invaderDir = 1
    invaderMoveTimer = 0
    invaderBulletX = nil
    invaderBulletY = nil
    score = 0
    gameOver = false
    tickCount = 0

    invaders = {}
    for row = 1, invaderRows do
        invaders[row] = {}
        for col = 1, invaderCols do
            invaders[row][col] = true
        end
    end
end

function game.update(dt, input)
    if gameOver then return end

    tickCount = tickCount + 1
    local p1 = input.getPlayer(1)

    if p1.isDown("left") and playerX > 1 then
        playerX = playerX - 1
    elseif p1.isDown("right") and playerX < width then
        playerX = playerX + 1
    end

    if p1.wasPressed("action") and not bulletX then
        bulletX = playerX
        bulletY = playerY - 1
    end

    if bulletX then
        bulletY = bulletY - 1
        if bulletY < 1 then
            bulletX = nil
            bulletY = nil
        else
            local row = bulletY - 2
            local col = math.floor(bulletX / 2)
            if row >= 1 and row <= invaderRows and col >= 1 and col <= invaderCols then
                if invaders[row] and invaders[row][col] then
                    invaders[row][col] = false
                    bulletX = nil
                    bulletY = nil
                    score = score + 10
                end
            end
        end
    end

    invaderMoveTimer = invaderMoveTimer + 1
    if invaderMoveTimer >= invaderSpeed then
        invaderMoveTimer = 0
        local shiftDown = false

        for row = 1, invaderRows do
            for col = 1, invaderCols do
                if invaders[row][col] then
                    local newCol = col + invaderDir
                    if newCol < 1 or newCol > math.floor(width / 2) then
                        shiftDown = true
                        break
                    end
                end
            end
            if shiftDown then break end
        end

        if shiftDown then
            invaderDir = -invaderDir
        end

        local startCol = invaderDir == 1 and invaderCols or 1
        local endCol = invaderDir == 1 and 1 or invaderCols
        local step = -invaderDir

        for row = 1, invaderRows do
            for col = startCol, endCol, step do
                if invaders[row][col] then
                    invaders[row][col] = false
                    local newCol = col + invaderDir
                    if newCol >= 1 and newCol <= invaderCols + 2 then
                        invaders[row][newCol] = true
                    end
                end
            end
        end
    end

    if not invaderBulletX and tickCount % 15 == 0 then
        local shooters = {}
        for col = 1, invaderCols do
            for row = invaderRows, 1, -1 do
                if invaders[row][col] then
                    table.insert(shooters, { row = row, col = col })
                    break
                end
            end
        end
        if #shooters > 0 then
            local shooter = shooters[math.random(#shooters)]
            invaderBulletX = shooter.col * 2
            invaderBulletY = shooter.row + 3
        end
    end

    if invaderBulletX then
        invaderBulletY = invaderBulletY + 1
        if invaderBulletY >= height then
            invaderBulletX = nil
            invaderBulletY = nil
        elseif invaderBulletX == playerX and invaderBulletY == playerY then
            gameOver = true
        end
    end

    for col = 1, invaderCols do
        if invaders[invaderRows] and invaders[invaderRows][col] then
            local invY = invaderRows + 2
            if invY >= playerY - 1 then
                gameOver = true
                break
            end
        end
    end

    local alive = false
    for row = 1, invaderRows do
        for col = 1, invaderCols do
            if invaders[row][col] then
                alive = true
                break
            end
        end
        if alive then break end
    end
    if not alive then
        gameOver = true
    end
end

function game.draw()
    term.clear()

    term.setCursorPos(1, 1)
    term.write("Score: " .. score)

    for row = 1, invaderRows do
        for col = 1, invaderCols do
            if invaders[row][col] then
                term.setCursorPos(col * 2, row + 2)
                term.write("W")
            end
        end
    end

    term.setCursorPos(playerX, playerY)
    term.write("^")

    if bulletX and bulletY then
        term.setCursorPos(bulletX, bulletY)
        term.write("|")
    end

    if invaderBulletX and invaderBulletY then
        term.setCursorPos(invaderBulletX, invaderBulletY)
        term.write("!")
    end

    if gameOver then
        local msg = "GAME OVER - Score: " .. score
        term.setCursorPos(math.floor((width - #msg) / 2), math.floor(height / 2))
        term.write(msg)
    end
end

function game.cleanup()
end

return game
