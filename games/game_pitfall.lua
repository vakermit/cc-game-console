local sprite = require("lib.sprite")
local sound = require("lib.sound")

local game = {}

local width, height
local groundY

local playerX, playerY, playerVelY
local playerState, playerFrame, playerAnimTimer
local playerLives, playerScore, playerInvuln
local onGround, onVine, onLadder
local vineDir

local worldOffset, worldSpeed
local tickAccum

local segments
local segmentWidth
local nextSegmentX

local enemies
local enemySpawnTimer
local enemySpawnInterval

local sprites = {}
local gameOverFlag
local started
local GRAVITY = 0.8
local JUMP_STRENGTH = -1.0
local VINE_SPEED = 0.15
local LADDER_SPEED = 0.15
local BASE_WORLD_SPEED = 0.6
local ANIM_SPEED = 0.15
local INVULN_TIME = 2.0
local ENEMY_ANIM_SPEED = 0.2
local VINE_JUMP_HORIZONTAL = 1.5

local enemyTypes = {
    {
        name = "alligator",
        file = "alligator.sprite",
        state = "idle",
        speed = 0.2,
        color = colors.green,
        ground = true,
    },
    {
        name = "snake",
        file = "snake.sprite",
        state = "slither",
        speed = 0.35,
        color = colors.lime,
        ground = true,
    },
    {
        name = "scorpion",
        file = "scorpion.sprite",
        state = "idle",
        speed = 0.15,
        color = colors.orange,
        ground = true,
    },
}

local function loadSprites()
    sprites.player = sprite.load("player.sprite")
    for _, etype in ipairs(enemyTypes) do
        sprites[etype.name] = sprite.load(etype.file)
    end
end

local function generateSegment(startX)
    local seg = {
        x = startX,
        ground = true,
        pit = false,
        vine = false,
        ladder = false,
        vineY = 0,
        ladderY = 0,
    }

    local roll = math.random(100)
    if roll <= 15 then
        seg.pit = true
        seg.ground = false
    elseif roll <= 25 then
        seg.vine = true
        seg.vineY = 3
    elseif roll <= 33 then
        seg.ladder = true
        seg.ladderY = groundY - 5
    end

    return seg
end

local function spawnEnemy()
    local etype = enemyTypes[math.random(#enemyTypes)]
    local eDef = sprites[etype.name]
    local eHeight = sprite.getHeight(eDef, etype.state)

    local enemy = {
        type = etype,
        x = width + 2,
        y = groundY - eHeight,
        frame = 1,
        animTimer = 0,
        alive = true,
    }

    table.insert(enemies, enemy)
end

local function playerGroundY()
    return groundY - sprite.getHeight(sprites.player, "standing")
end

local function resetPlayer()
    playerX = 10
    playerY = playerGroundY()
    playerVelY = 0
    playerState = "standing"
    playerFrame = 1
    playerAnimTimer = 0
    onGround = true
    onVine = false
    onLadder = false
    vineDir = 1
end

local function initRound()
    worldOffset = 0
    worldSpeed = BASE_WORLD_SPEED
    tickAccum = 0
    playerScore = 0
    playerLives = 3
    playerInvuln = 0
    gameOverFlag = false
    started = false

    segments = {}
    segmentWidth = 4
    nextSegmentX = 0
    for i = 1, math.ceil(width / segmentWidth) + 3 do
        local seg = generateSegment(nextSegmentX)
        if i <= 4 then
            seg.pit = false
            seg.ground = true
        end
        table.insert(segments, seg)
        nextSegmentX = nextSegmentX + segmentWidth
    end

    enemies = {}
    enemySpawnTimer = 0
    enemySpawnInterval = 3.0

    resetPlayer()
end

local function getSegmentAt(worldX)
    for _, seg in ipairs(segments) do
        local segWorldX = seg.x - worldOffset
        if worldX >= segWorldX and worldX < segWorldX + segmentWidth then
            return seg
        end
    end
    return nil
end

local function checkGroundBelow(screenX)
    local pw = sprite.getWidth(sprites.player, "standing")
    local segL = getSegmentAt(screenX)
    local segR = getSegmentAt(screenX + pw - 1)
    local groundL = segL ~= nil and segL.ground
    local groundR = segR ~= nil and segR.ground
    return groundL or groundR
end

local function findSafeX(startX)
    for offset = 0, width do
        local x = startX - offset
        if x >= 1 and checkGroundBelow(x) then return x end
        x = startX + offset
        if x <= width and checkGroundBelow(x) then return x end
    end
    return startX
end

local function checkVineAt(screenX, screenY)
    for _, seg in ipairs(segments) do
        local segScreenX = seg.x - worldOffset
        if seg.vine and screenX >= segScreenX and screenX < segScreenX + segmentWidth then
            local vineBottom = groundY - 8
            if screenY <= vineBottom and screenY >= seg.vineY then
                return true, seg
            end
        end
    end
    return false, nil
end

local function checkLadderAt(screenX, screenY)
    for _, seg in ipairs(segments) do
        local segScreenX = seg.x - worldOffset
        if seg.ladder and screenX >= segScreenX and screenX < segScreenX + 2 then
            if screenY >= seg.ladderY and screenY <= groundY then
                return true, seg
            end
        end
    end
    return false, nil
end

local function playerBBox()
    local pw = sprite.getWidth(sprites.player, playerState)
    local ph = sprite.getHeight(sprites.player, playerState)
    return playerX, playerY, pw, ph
end

local function enemyBBox(enemy)
    local eDef = sprites[enemy.type.name]
    local ew = sprite.getWidth(eDef, enemy.type.state)
    local eh = sprite.getHeight(eDef, enemy.type.state)
    return math.floor(enemy.x), enemy.y, ew, eh
end

local function boxOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function game.title()
    return "Pitfall"
end

function game.getControls()
    return {
        { action = "left/right", description = "Run" },
        { action = "up",         description = "Climb / Grab vine" },
        { action = "down",       description = "Descend" },
        { action = "action",     description = "Jump" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    groundY = height - 2
    math.randomseed(os.clock() * 1000)
    loadSprites()
    initRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOverFlag then return "menu" end

    if not started then
        if p1.wasPressed("action") then
            started = true
        end
        return
    end

    tickAccum = tickAccum + dt
    if tickAccum < 0.05 then return end
    tickAccum = tickAccum - 0.05

    if playerInvuln > 0 then
        playerInvuln = playerInvuln - 0.05
        if playerInvuln < 0 then playerInvuln = 0 end
    end

    local moving = false

    if onVine then
        playerState = "swinging"
        if p1.wasPressed("left") then
            vineDir = -1
            playerFrame = 2
        end
        if p1.wasPressed("right") then
            vineDir = 1
            playerFrame = 1
        end
        if p1.isDown("up") then
            playerY = playerY - VINE_SPEED
        end
        if p1.isDown("down") then
            playerY = playerY + VINE_SPEED
        end
        if p1.wasPressed("action") then
            onVine = false
            playerVelY = JUMP_STRENGTH * 0.7
            worldOffset = worldOffset + VINE_JUMP_HORIZONTAL * vineDir
            onGround = false
        end
    elseif onLadder then
        playerState = "climbing"
        if p1.isDown("up") then
            playerY = playerY - LADDER_SPEED
        end
        if p1.isDown("down") then
            playerY = playerY + LADDER_SPEED
            if playerY >= playerGroundY() then
                playerY = playerGroundY()
                onLadder = false
                onGround = true
            end
        end
        if p1.wasPressed("action") then
            onLadder = false
            playerVelY = JUMP_STRENGTH * 0.5
            onGround = false
        end
        if p1.isDown("left") or p1.isDown("right") then
            onLadder = false
            onGround = false
        end
    else
        if p1.isDown("right") then
            worldOffset = worldOffset + worldSpeed
            moving = true
            playerScore = playerScore + 1
        end
        if p1.isDown("left") then
            worldOffset = worldOffset - worldSpeed * 0.5
            moving = true
        end

        if p1.wasPressed("action") and onGround then
            playerVelY = JUMP_STRENGTH
            onGround = false
            sound.playNote("hat", 0.5, 18)
        end

        if not onGround then
            playerVelY = playerVelY + GRAVITY * 0.05
            playerY = playerY + playerVelY

            if playerY >= playerGroundY() then
                if checkGroundBelow(playerX) then
                    playerY = playerGroundY()
                    playerVelY = 0
                    onGround = true
                end
            end

            if playerY > height + 2 then
                playerLives = playerLives - 1
                sound.playNote("bass", 1.0, 4)
                if playerLives <= 0 then
                    gameOverFlag = true
                    sound.gameOver()
                    return
                end
                resetPlayer()
                playerX = findSafeX(playerX)
                playerInvuln = INVULN_TIME
                return
            end

            playerState = "jumping"
        else
            if checkGroundBelow(playerX) then
                playerY = playerGroundY()
            else
                onGround = false
            end

            if moving then
                playerState = "running"
            else
                playerState = "standing"
            end
        end

        if p1.isDown("up") then
            local hasVine = checkVineAt(playerX, playerY)
            if hasVine then
                onVine = true
                vineDir = 1
                playerFrame = 1
                onGround = false
                playerVelY = 0
                playerState = "swinging"
            else
                local hasLadder = checkLadderAt(playerX, playerY)
                if hasLadder then
                    onLadder = true
                    onGround = false
                    playerVelY = 0
                    playerState = "climbing"
                end
            end
        end
    end

    if not onVine then
        playerAnimTimer = playerAnimTimer + 0.05
    end
    if playerAnimTimer >= ANIM_SPEED then
        playerAnimTimer = playerAnimTimer - ANIM_SPEED
        local fc = sprite.getFrameCount(sprites.player, playerState)
        if fc > 0 and not onVine then
            playerFrame = (playerFrame % fc) + 1
        end
    end

    while #segments > 0 and segments[1].x - worldOffset < -segmentWidth * 2 do
        table.remove(segments, 1)
    end
    local lastSeg = segments[#segments]
    while lastSeg and lastSeg.x - worldOffset < width + segmentWidth * 2 do
        nextSegmentX = lastSeg.x + segmentWidth
        local seg = generateSegment(nextSegmentX)
        table.insert(segments, seg)
        lastSeg = segments[#segments]
    end

    enemySpawnTimer = enemySpawnTimer + 0.05
    if enemySpawnTimer >= enemySpawnInterval then
        enemySpawnTimer = 0
        enemySpawnInterval = 2.0 + math.random() * 3.0
        spawnEnemy()
    end

    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        enemy.x = enemy.x - (enemy.type.speed + worldSpeed * 0.3)

        enemy.animTimer = enemy.animTimer + 0.05
        if enemy.animTimer >= ENEMY_ANIM_SPEED then
            enemy.animTimer = enemy.animTimer - ENEMY_ANIM_SPEED
            local eDef = sprites[enemy.type.name]
            local fc = sprite.getFrameCount(eDef, enemy.type.state)
            if fc > 0 then
                enemy.frame = (enemy.frame % fc) + 1
            end
        end

        if enemy.x < -10 then
            table.remove(enemies, i)
        elseif enemy.alive and playerInvuln <= 0 then
            local px, py, pw, ph = playerBBox()
            local ex, ey, ew, eh = enemyBBox(enemy)
            if boxOverlap(px, py, pw, ph, ex, ey, ew, eh) then
                enemy.alive = false
                playerLives = playerLives - 1
                playerInvuln = INVULN_TIME
                sound.playNote("bass", 1.0, 6)

                if playerLives <= 0 then
                    gameOverFlag = true
                    sound.gameOver()
                    return
                end
            end
        end
    end

    worldSpeed = BASE_WORLD_SPEED + (playerScore / 5000) * 0.3

end

local function drawGround()
    term.setBackgroundColor(colors.brown)
    term.setTextColor(colors.green)

    for _, seg in ipairs(segments) do
        local screenX = math.floor(seg.x - worldOffset)
        if screenX >= -segmentWidth and screenX <= width + segmentWidth then
            if seg.ground then
                for col = 0, segmentWidth - 1 do
                    local sx = screenX + col
                    if sx >= 1 and sx <= width then
                        term.setCursorPos(sx, groundY)
                        term.write("=")
                        term.setCursorPos(sx, groundY + 1)
                        term.setTextColor(colors.brown)
                        term.setBackgroundColor(colors.brown)
                        term.write(" ")
                        term.setTextColor(colors.green)
                        term.setBackgroundColor(colors.brown)
                    end
                end
            end

            if seg.vine then
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.green)
                local vx = screenX + 1
                local vineBottom = groundY - 8
                if vx >= 1 and vx <= width then
                    for vy = 1, vineBottom do
                        term.setCursorPos(vx, vy)
                        if vy <= seg.vineY then
                            term.write("|")
                        else
                            term.write("}")
                        end
                    end
                end
            end

            if seg.ladder then
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.yellow)
                local lx = screenX
                if lx >= 1 and lx <= width then
                    for ly = seg.ladderY, groundY - 1 do
                        term.setCursorPos(lx, ly)
                        term.write("H")
                        if lx + 1 <= width then
                            term.setCursorPos(lx + 1, ly)
                            term.write("H")
                        end
                    end
                end
            end
        end
    end
end

local function drawPlayer()
    if playerInvuln > 0 then
        local blink = math.floor(playerInvuln / 0.1) % 2
        if blink == 0 then return end
    end

    term.setBackgroundColor(colors.black)
    sprite.draw(sprites.player, math.floor(playerX), math.floor(playerY), playerState, playerFrame, colors.white)
end

local function drawEnemies()
    term.setBackgroundColor(colors.black)
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local eDef = sprites[enemy.type.name]
            local ex = math.floor(enemy.x)
            if ex >= -6 and ex <= width + 2 then
                sprite.draw(eDef, ex, enemy.y, enemy.type.state, enemy.frame, enemy.type.color)
            end
        end
    end
end

local function drawHUD()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, height)
    term.write(string.rep(" ", width))

    term.setCursorPos(2, height)
    term.setTextColor(colors.red)
    for i = 1, playerLives do
        term.write("\3 ")
    end

    local scoreStr = "Score: " .. math.floor(playerScore / 10)
    term.setCursorPos(width - #scoreStr, height)
    term.setTextColor(colors.yellow)
    term.write(scoreStr)
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    if not started and not gameOverFlag then
        term.setTextColor(colors.yellow)
        local title = "P I T F A L L"
        term.setCursorPos(math.floor((width - #title) / 2), 3)
        term.write(title)

        term.setTextColor(colors.white)
        local sub = "A Jungle Adventure"
        term.setCursorPos(math.floor((width - #sub) / 2), 5)
        term.write(sub)

        term.setTextColor(colors.lime)
        sprite.draw(sprites.player, math.floor(width / 2) - 1, 8, "standing", 1, colors.white)

        term.setTextColor(colors.green)
        sprite.draw(sprites.alligator, 8, 12, "idle", 1, colors.green)
        sprite.draw(sprites.snake, 22, 13, "slither", 1, colors.lime)
        sprite.draw(sprites.scorpion, 36, 13, "idle", 1, colors.orange)

        term.setTextColor(colors.lightGray)
        local prompt = "[action] Start"
        term.setCursorPos(math.floor((width - #prompt) / 2), height - 2)
        term.write(prompt)

        return
    end

    drawGround()
    drawEnemies()
    drawPlayer()
    drawHUD()

    if gameOverFlag then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2) - 1
        term.setCursorPos(mx - 1, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")

        term.setBackgroundColor(colors.gray)
        term.setCursorPos(mx - 2, my + 1)
        term.write(" Score: " .. math.floor(playerScore / 10) .. " ")
        term.setBackgroundColor(colors.black)

    end
end

function game.cleanup()
    sound.stop()
end

return game
