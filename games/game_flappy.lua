local game = {}

local width, height
local birdY, velocity
local pipes
local pipeTimer, pipeInterval
local gapSize
local score
local gameOverFlag, gameOverTimer
local tickAccum
local started

local gravity = 0.4
local flapStrength = -2.5
local pipeSpeed = 1

local function addPipe()
    local gapY = math.random(4, height - gapSize - 2)
    table.insert(pipes, {
        x = width,
        gapY = gapY,
    })
end

local function initRound()
    birdY = math.floor(height / 2)
    velocity = 0
    pipes = {}
    pipeTimer = 0
    pipeInterval = 12
    gapSize = 6
    score = 0
    tickAccum = 0
    gameOverFlag = false
    gameOverTimer = 0
    started = false
end

function game.title()
    return "Flappy Bird"
end

function game.getControls()
    return {
        { action = "action", description = "Flap" },
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

    if not started then
        if p1.wasPressed("action") then
            started = true
            velocity = flapStrength
        end
        return
    end

    tickAccum = tickAccum + dt
    if tickAccum < 0.08 then return end
    tickAccum = tickAccum - 0.08

    if p1.wasPressed("action") or p1.isDown("action") then
        velocity = flapStrength
    end

    velocity = velocity + gravity
    birdY = birdY + velocity

    if birdY < 1 then
        birdY = 1
        velocity = 0
    end
    if birdY >= height then
        gameOverFlag = true
        gameOverTimer = 0
        return
    end

    pipeTimer = pipeTimer + 1
    if pipeTimer >= pipeInterval then
        pipeTimer = 0
        addPipe()
    end

    local birdX = 8
    for i = #pipes, 1, -1 do
        pipes[i].x = pipes[i].x - pipeSpeed
        if pipes[i].x < -2 then
            table.remove(pipes, i)
        else
            if pipes[i].x == birdX - 1 then
                score = score + 1
            end

            if pipes[i].x >= birdX - 1 and pipes[i].x <= birdX + 1 then
                local by = math.floor(birdY + 0.5)
                if by <= pipes[i].gapY or by >= pipes[i].gapY + gapSize then
                    gameOverFlag = true
                    gameOverTimer = 0
                    return
                end
            end
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.white)
    term.clear()

    for y = height - 1, height do
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.green)
        term.write(string.rep(" ", width))
    end

    for _, p in ipairs(pipes) do
        local px = math.floor(p.x + 0.5)
        if px >= 1 and px <= width then
            term.setBackgroundColor(colors.green)
            for y = 1, p.gapY do
                term.setCursorPos(px, y)
                term.write("||")
            end
            for y = p.gapY + gapSize + 1, height - 2 do
                term.setCursorPos(px, y)
                term.write("||")
            end
        end
    end

    local birdX = 8
    local by = math.floor(birdY + 0.5)
    if by >= 1 and by <= height then
        term.setCursorPos(birdX, by)
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.yellow)
        if velocity < 0 then
            term.write("^>")
        else
            term.write("v>")
        end
    end

    term.setBackgroundColor(colors.cyan)
    term.setTextColor(colors.white)
    term.setCursorPos(2, 1)
    term.write(tostring(score))

    if not started and not gameOverFlag then
        local msg = "Press action to flap!"
        term.setCursorPos(math.floor((width - #msg) / 2), math.floor(height / 2))
        term.write(msg)
    end

    if gameOverFlag then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.white)
        term.setCursorPos(mx - 2, my + 1)
        term.write("Score: " .. score)

        local countdown = math.max(0, 10 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(math.floor((width - #hint) / 2), my + 3)
        term.write(hint)
    end

    term.setBackgroundColor(colors.black)
end

function game.cleanup()
end

return game
