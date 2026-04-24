local game = {}

local width, height
local playerX, playerY
local bulletX, bulletY
local invaders
local invaderRows, invaderCols = 3, 8
local invaderDir
local invaderMoveTimer
local invaderSpeed = 10
local invaderOffsetX, invaderOffsetY
local invaderBulletX, invaderBulletY
local score
local gameOver
local gameOverTimer
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

local function initRound()
    playerX = math.floor(width / 2)
    playerY = height - 1
    bulletX = nil
    bulletY = nil
    invaderDir = 1
    invaderMoveTimer = 0
    invaderOffsetX = 0
    invaderOffsetY = 0
    invaderBulletX = nil
    invaderBulletY = nil
    tickCount = 0

    invaders = {}
    for row = 1, invaderRows do
        invaders[row] = {}
        for col = 1, invaderCols do
            invaders[row][col] = true
        end
    end
end

local function invaderScreenX(col)
    return (col - 1) * 3 + 2 + invaderOffsetX
end

local function invaderScreenY(row)
    return row + 2 + invaderOffsetY
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    score = 0
    gameOver = false
    gameOverTimer = 0
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOver then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            score = 0
            gameOver = false
            gameOverTimer = 0
            initRound()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 10 then
            return "menu"
        end
        return
    end

    tickCount = tickCount + 1

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
            for row = 1, invaderRows do
                for col = 1, invaderCols do
                    if invaders[row][col] then
                        local sx = invaderScreenX(col)
                        local sy = invaderScreenY(row)
                        if bulletY == sy and bulletX >= sx and bulletX <= sx + 1 then
                            invaders[row][col] = false
                            bulletX = nil
                            bulletY = nil
                            score = score + 10
                            goto bullet_done
                        end
                    end
                end
            end
            ::bullet_done::
        end
    end

    invaderMoveTimer = invaderMoveTimer + 1
    if invaderMoveTimer >= invaderSpeed then
        invaderMoveTimer = 0

        local minCol, maxCol = invaderCols + 1, 0
        for row = 1, invaderRows do
            for col = 1, invaderCols do
                if invaders[row][col] then
                    if col < minCol then minCol = col end
                    if col > maxCol then maxCol = col end
                end
            end
        end

        if maxCol >= minCol then
            local leftEdge = invaderScreenX(minCol)
            local rightEdge = invaderScreenX(maxCol) + 1

            if invaderDir == 1 and rightEdge + invaderDir >= width then
                invaderDir = -1
                invaderOffsetY = invaderOffsetY + 1
            elseif invaderDir == -1 and leftEdge + invaderDir <= 1 then
                invaderDir = 1
                invaderOffsetY = invaderOffsetY + 1
            else
                invaderOffsetX = invaderOffsetX + invaderDir
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
            invaderBulletX = invaderScreenX(shooter.col)
            invaderBulletY = invaderScreenY(shooter.row) + 1
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
        for row = invaderRows, 1, -1 do
            if invaders[row][col] then
                if invaderScreenY(row) >= playerY - 1 then
                    gameOver = true
                end
                break
            end
        end
    end

    local alive = false
    for row = 1, invaderRows do
        for col = 1, invaderCols do
            if invaders[row][col] then
                alive = true
                goto check_done
            end
        end
    end
    ::check_done::

    if not alive then
        initRound()
        invaderSpeed = math.max(3, invaderSpeed - 1)
    end
end

function game.draw()
    term.clear()

    term.setCursorPos(1, 1)
    term.write("Score: " .. score)

    for row = 1, invaderRows do
        for col = 1, invaderCols do
            if invaders[row][col] then
                local sx = invaderScreenX(col)
                local sy = invaderScreenY(row)
                if sx >= 1 and sx <= width and sy >= 1 and sy <= height then
                    term.setCursorPos(sx, sy)
                    term.write("W")
                end
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

        local countdown = math.max(0, 10 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setCursorPos(math.floor((width - #hint) / 2), math.floor(height / 2) + 2)
        term.write(hint)
    end
end

function game.cleanup()
end

return game
