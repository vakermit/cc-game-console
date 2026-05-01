local sound = require("lib.sound")
local block_letters = require("lib.block_letters")

local game = {}

local width, height
local trampolineX
local trampolineW = 5
local babies, nextBabies
local score, lives, wave
local gameOverFlag, gameOverTimer
local spawnTimer, spawnInterval
local baseGravity, gravity
local blinkTimer
local groundY
local prevState, state
local babiesSaved, babiesInWave, waveSize
local pauseTimer

local BUILDING_W = 8
local AMBULANCE_W = 10
local AMBULANCE_X
local TRAMP_MIN
local TRAMP_MAX

local floorWindows = {}

local buildingArt = {
    "  ____  ",
    " |    | ",
    " | [] | ",
    " |    | ",
    " | [] | ",
    " |    | ",
    " | [] | ",
    " |    | ",
    " | [] | ",
    " |    | ",
    " | [] | ",
    " |    | ",
    " |____| ",
}

local ambulanceArt = {
    "  _______",
    " |  ___  |",
    " | | + | |",
    " | |___| |",
    " |   ____|",
    " |  |    ",
    " |__|____|",
    "  O    O  ",
}

local function initLayout()
    groundY = height - 1
    AMBULANCE_X = width - AMBULANCE_W
    TRAMP_MIN = BUILDING_W + 1
    TRAMP_MAX = AMBULANCE_X - trampolineW - 1

    floorWindows = {}
    local buildingTopY = groundY - #buildingArt
    for i, line in ipairs(buildingArt) do
        local col = line:find("%[%]")
        if col then
            table.insert(floorWindows, {
                x = BUILDING_W + 1,
                y = buildingTopY + i,
            })
        end
    end
end

local function spawnBaby()
    if #floorWindows == 0 then return end
    local window = floorWindows[math.random(#floorWindows)]
    table.insert(babies, {
        x = window.x,
        y = window.y,
        vx = 1,
        vy = -1.5,
        bounces = 0,
        active = true,
        saved = false,
        splat = false,
        splatTimer = 0,
    })
    babiesInWave = babiesInWave + 1
end

local function resetWave()
    wave = wave + 1
    babiesInWave = 0
    waveSize = 4 + wave
    if waveSize > 10 then waveSize = 10 end
    spawnInterval = math.max(1.5, 4.5 - wave * 0.3)
    gravity = baseGravity + wave * 0.2
    spawnTimer = 1.0
    pauseTimer = 0
end

function game.title()
    return "Bouncing Babies"
end

function game.getControls()
    return {
        { action = "left/right", description = "Move trampoline" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)

    initLayout()

    trampolineX = math.floor((TRAMP_MIN + TRAMP_MAX) / 2)
    babies = {}
    score = 0
    lives = 3
    wave = 0
    babiesSaved = 0
    babiesInWave = 0
    waveSize = 5
    baseGravity = 5
    gravity = baseGravity
    spawnTimer = 3.0
    spawnInterval = 2.5
    pauseTimer = 0
    gameOverFlag = false
    gameOverTimer = 0
    blinkTimer = 0
    state = "playing"
    prevState = nil
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)
    blinkTimer = blinkTimer + dt

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if gameOverTimer > 1.5 then
            return "menu"
        end
        return
    end

    if state == "playing" then
        if p1.isDown("left") and trampolineX > TRAMP_MIN then
            trampolineX = trampolineX - 1
        end
        if p1.isDown("right") and trampolineX < TRAMP_MAX then
            trampolineX = trampolineX + 1
        end

        if babiesInWave < waveSize then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                spawnBaby()
                spawnTimer = spawnInterval
            end
        end

        local allDone = true
        for _, b in ipairs(babies) do
            if b.active and not b.saved and not b.splat then
                allDone = false

                b.vy = b.vy + gravity * dt
                b.y = b.y + b.vy * dt
                b.x = b.x + b.vx * dt

                if b.x >= AMBULANCE_X - 1 and b.y >= groundY - #ambulanceArt and b.y <= groundY then
                    b.saved = true
                    b.active = false
                    score = score + 1
                    babiesSaved = babiesSaved + 1
                    sound.playNote("bell", 0.7, 20)
                elseif b.y >= groundY then
                    local bx = math.floor(b.x)
                    if bx >= trampolineX and bx <= trampolineX + trampolineW - 1 then
                        b.vy = -math.abs(b.vy) * 0.9 - 4
                        if b.vy > -5 then b.vy = -5 end
                        b.vx = b.vx + 1.0 + math.random() * 0.5
                        b.y = groundY - 0.5
                        b.bounces = b.bounces + 1
                        sound.playNote("snare", 0.6, 14)
                    else
                        b.splat = true
                        b.splatTimer = 0
                        b.y = groundY
                        lives = lives - 1
                        sound.playNote("bass", 1.0, 1)
                        if lives <= 0 then
                            state = "gameover"
                            gameOverTimer = 0
                            sound.gameOver()
                        end
                    end
                end

                if b.x < 1 then b.x = 1; b.vx = math.abs(b.vx) * 0.5 end
                if b.x > width then
                    b.active = false
                end
                if b.y < 1 then b.y = 1; b.vy = 0 end
            end

            if b.splat then
                b.splatTimer = b.splatTimer + dt
                if b.splatTimer > 1.0 then
                    b.active = false
                end
            end
        end

        local cleanBabies = {}
        for _, b in ipairs(babies) do
            if b.active then
                table.insert(cleanBabies, b)
            end
        end
        babies = cleanBabies

        if babiesInWave >= waveSize and allDone and #babies == 0 then
            resetWave()
        end

    elseif state == "gameover" then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") and gameOverTimer > 0.5 then
            gameOverFlag = true
            gameOverTimer = 0
        end
    end
end

local function clearRow(y, bg)
    term.setCursorPos(1, y)
    term.setBackgroundColor(bg or colors.black)
    term.write(string.rep(" ", width))
end

local function drawBuilding()
    local buildingTopY = groundY - #buildingArt
    local flameChars = {"^", "*", "~", "#"}

    for i, line in ipairs(buildingArt) do
        local y = buildingTopY + i
        if y >= 1 and y <= height then
            term.setCursorPos(1, y)
            term.setBackgroundColor(colors.black)
            for j = 1, #line do
                local ch = line:sub(j, j)
                if ch == "|" or ch == "_" then
                    term.setTextColor(colors.brown)
                    term.write(ch)
                elseif ch == "[" or ch == "]" then
                    term.setTextColor(colors.lightBlue)
                    term.write(ch)
                else
                    term.setTextColor(colors.black)
                    term.write(ch)
                end
            end
            if #line < BUILDING_W + 2 then
                term.write(string.rep(" ", BUILDING_W + 2 - #line))
            end
        end
    end

    local roofY = buildingTopY
    if roofY >= 1 and roofY <= height then
        term.setCursorPos(1, roofY)
        term.setBackgroundColor(colors.black)
        local flicker = math.floor(blinkTimer * 5) % #flameChars + 1
        term.setTextColor(colors.orange)
        local flames = ""
        for i = 1, BUILDING_W do
            flames = flames .. flameChars[(flicker + i) % #flameChars + 1]
        end
        term.write(flames)
    end
    if roofY - 1 >= 1 then
        term.setCursorPos(1, roofY - 1)
        term.setBackgroundColor(colors.black)
        local flicker2 = math.floor(blinkTimer * 3) % #flameChars + 1
        term.setTextColor(colors.red)
        local flames2 = ""
        for i = 1, BUILDING_W - 2 do
            flames2 = flames2 .. flameChars[(flicker2 + i + 2) % #flameChars + 1]
        end
        term.write(" " .. flames2)
    end
end

local function drawAmbulance()
    local ambTop = groundY - #ambulanceArt
    for i, line in ipairs(ambulanceArt) do
        local y = ambTop + i
        if y >= 1 and y <= height then
            term.setCursorPos(AMBULANCE_X, y)
            term.setBackgroundColor(colors.black)
            for j = 1, #line do
                local ch = line:sub(j, j)
                if ch == "+" then
                    term.setTextColor(colors.red)
                elseif ch == "O" then
                    term.setTextColor(colors.gray)
                elseif ch == "|" or ch == "_" or ch == "-" then
                    term.setTextColor(colors.white)
                else
                    term.setTextColor(colors.white)
                end
                term.write(ch)
            end
        end
    end
end

local function drawTrampoline()
    local y = groundY
    term.setCursorPos(trampolineX, y)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write("&")
    term.setTextColor(colors.white)
    term.write(string.rep("=", trampolineW - 2))
    term.setTextColor(colors.yellow)
    term.write("&")
end

local function drawBabies()
    for _, b in ipairs(babies) do
        local bx = math.floor(b.x)
        local by = math.floor(b.y)
        if bx >= 1 and bx <= width and by >= 1 and by <= height then
            term.setCursorPos(bx, by)
            term.setBackgroundColor(colors.black)
            if b.splat then
                term.setTextColor(colors.red)
                term.write("x")
            elseif b.saved then
                -- already removed
            else
                term.setTextColor(colors.pink)
                term.write("o")
            end
        end
    end
end

local function drawHUD()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    local hud = " Score:" .. score .. "  Lives:" .. lives .. "  Wave:" .. wave
    local pad = width - #hud
    if pad > 0 then hud = hud .. string.rep(" ", pad) end
    term.write(hud:sub(1, width))
end

local function drawGround()
    term.setCursorPos(1, groundY + 1)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.green)
    term.write(string.rep(" ", width))
end

function game.draw()
    local drawState = state
    if drawState ~= prevState then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        prevState = drawState
    end

    if state == "playing" then
        drawHUD()

        local fieldLeft = BUILDING_W + 1
        local fieldRight = AMBULANCE_X - 1
        term.setBackgroundColor(colors.black)
        for y = 2, groundY do
            term.setCursorPos(fieldLeft, y)
            term.setTextColor(colors.black)
            term.write(string.rep(" ", fieldRight - fieldLeft + 1))
        end

        drawBuilding()
        drawAmbulance()
        drawGround()
        drawTrampoline()
        drawBabies()

        term.setCursorPos(1, height)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        local hint = " [left/right] Move trampoline"
        local pad = width - #hint
        if pad > 0 then hint = hint .. string.rep(" ", pad) end
        term.write(hint:sub(1, width))

    elseif state == "gameover" then
        term.setBackgroundColor(colors.black)

        local titleY = 3
        term.setTextColor(colors.red)
        block_letters.draw(4, titleY, "GAME OVER")

        term.setTextColor(colors.white)
        term.setCursorPos(4, titleY + 7)
        term.write("Babies saved: " .. score)
        term.setCursorPos(4, titleY + 8)
        term.write("Waves completed: " .. (wave - 1))

        if score >= 20 then
            term.setTextColor(colors.lime)
            term.setCursorPos(4, titleY + 10)
            term.write("Hero of the city!")
        elseif score >= 10 then
            term.setTextColor(colors.yellow)
            term.setCursorPos(4, titleY + 10)
            term.write("Good effort, firefighter!")
        elseif score >= 5 then
            term.setTextColor(colors.orange)
            term.setCursorPos(4, titleY + 10)
            term.write("Keep practicing!")
        else
            term.setTextColor(colors.red)
            term.setCursorPos(4, titleY + 10)
            term.write("The fire chief is not pleased.")
        end

        if gameOverTimer > 0.5 then
            term.setTextColor(colors.gray)
            term.setCursorPos(4, height - 1)
            term.write("[action] Return to menu")
        end
    end
end

function game.cleanup()
    sound.stop()
end

return game
