local sprite = require("lib.sprite")
local sound = require("lib.sound")

local game = {}

local width, height
local CELL = 2

local numPlayers
local players
local homeSlots
local homeFilled
local level
local gameOverFlag
local modeSelected

local lanes
local tickAccum
local deathTimer
local dyingPlayer

local sprites = {}

local laneDefinitions = {
    { type = "river", dir = 1,  speed = 0.25 },
    { type = "river", dir = -1, speed = 0.35 },
    { type = "river", dir = 1,  speed = 0.20 },
    { type = "road",  dir = -1, speed = 0.30 },
    { type = "road",  dir = 1,  speed = 0.45 },
    { type = "road",  dir = -1, speed = 0.20 },
}

local HOME_SLOTS = 5
local LIVES_START = 3
local SCORE_HOP = 10
local SCORE_HOME = 50
local SCORE_LEVEL = 200

local gridW
local blankRow

local ROW_HUD = 1
local ROW_HOME = 2
local ROW_RIVER_START = 3
local ROW_SAFE = 6
local ROW_ROAD_START = 7
local ROW_START = 10

local function laneScreenY(laneIdx)
    if laneIdx <= 3 then
        return (ROW_RIVER_START + laneIdx - 1) * CELL
    else
        return (ROW_ROAD_START + laneIdx - 4) * CELL
    end
end

local function rowToScreenY(row)
    return row * CELL
end

local function makePlayer(num)
    return {
        num = num,
        gx = 0,
        gy = ROW_START,
        score = 0,
        lives = LIVES_START,
        alive = true,
        maxRow = ROW_START,
        facing = "up",
        color = num == 1 and colors.lime or colors.orange,
    }
end

local function resetPlayerPos(p)
    local mid = math.floor(gridW / 2)
    if numPlayers == 1 then
        p.gx = mid
    else
        p.gx = p.num == 1 and mid - 2 or mid + 2
    end
    p.gy = ROW_START
    p.maxRow = ROW_START
    p.facing = "up"
    p.alive = true
end

local function spawnRiverObjs(lane, laneW)
    lane.objs = {}
    local logLens = { 3, 4, 5 }
    local x = math.random(0, 3)
    while x < laneW + 10 do
        local len = logLens[math.random(#logLens)]
        table.insert(lane.objs, { x = x * CELL, w = len * CELL, kind = "log" })
        x = x + len + math.random(2, 4)
    end
end

local function spawnRoadObjs(lane, laneW)
    lane.objs = {}
    local x = math.random(0, 3)
    while x < laneW + 10 do
        local kind = math.random(3) == 1 and "truck" or "car"
        local w = kind == "truck" and CELL * 3 or CELL * 2
        table.insert(lane.objs, { x = x * CELL, w = w, kind = kind })
        x = x + (w / CELL) + math.random(3, 6)
    end
end

local function initLanes()
    lanes = {}
    local laneW = math.ceil(width / CELL)
    for i, def in ipairs(laneDefinitions) do
        local lane = {
            type = def.type,
            dir = def.dir,
            speed = def.speed,
            objs = {},
            accum = 0,
        }
        if def.type == "river" then
            spawnRiverObjs(lane, laneW)
        else
            spawnRoadObjs(lane, laneW)
        end
        lanes[i] = lane
    end
end

local function initHomeSlots()
    homeSlots = {}
    homeFilled = {}
    local totalW = width
    local spacing = math.floor(totalW / (HOME_SLOTS + 1))
    for i = 1, HOME_SLOTS do
        homeSlots[i] = { x = spacing * i - 1 }
        homeFilled[i] = false
    end
end

local function allHomeFilled()
    for i = 1, HOME_SLOTS do
        if not homeFilled[i] then return false end
    end
    return true
end

local function initLevel()
    initLanes()
    initHomeSlots()
    for _, lane in ipairs(lanes) do
        lane.speed = lane.speed + (level - 1) * 0.03
    end
end

local function playerOnLog(p)
    if p.gy < ROW_RIVER_START or p.gy > ROW_RIVER_START + 2 then
        return false, nil
    end
    local laneIdx = p.gy - ROW_RIVER_START + 1
    local lane = lanes[laneIdx]
    if not lane or lane.type ~= "river" then return false, nil end
    local px = math.floor(p.gx) * CELL + 1
    for _, obj in ipairs(lane.objs) do
        local ox = math.floor(obj.x)
        if px >= ox and px < ox + obj.w then
            return true, lane
        end
    end
    return false, nil
end

local function playerHitCar(p)
    if p.gy < ROW_ROAD_START or p.gy > ROW_ROAD_START + 2 then
        return false
    end
    local laneIdx = p.gy - ROW_ROAD_START + 1 + 3
    local lane = lanes[laneIdx]
    if not lane or lane.type ~= "road" then return false end
    local px = math.floor(p.gx) * CELL + 1
    for _, obj in ipairs(lane.objs) do
        local ox = math.floor(obj.x)
        if px + CELL > ox and px < ox + obj.w then
            return true
        end
    end
    return false
end

local function playerAtHome(p)
    if p.gy ~= ROW_HOME then return false, 0 end
    local px = p.gx * CELL
    for i, slot in ipairs(homeSlots) do
        if not homeFilled[i] and math.abs(px - slot.x) < CELL + 1 then
            return true, i
        end
    end
    return false, 0
end

local function killPlayer(p)
    p.alive = false
    p.lives = p.lives - 1
    dyingPlayer = p
    deathTimer = 0.6
    sound.playNote("bass", 1.0, 6)
end

local function anyAlive()
    for _, p in ipairs(players) do
        if p.lives > 0 then return true end
    end
    return false
end

function game.title()
    return "Frogger"
end

function game.getControls()
    return {
        { action = "arrows", description = "Move frog" },
        { action = "action", description = "Select" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    gridW = math.floor(width / CELL)
    blankRow = string.rep(" ", width)
    math.randomseed(os.clock() * 1000)
    sprites.frog = sprite.load("frog.sprite")
    modeSelected = false
    numPlayers = 1
    gameOverFlag = false
    level = 1
    tickAccum = 0
    deathTimer = 0
    dyingPlayer = nil
end

function game.update(dt, input)
    if gameOverFlag then return "menu" end

    local p1 = input.getPlayer(1)

    if not modeSelected then
        if p1.wasPressed("left") or p1.wasPressed("right") then
            numPlayers = numPlayers == 1 and 2 or 1
            sound.menuBeep()
        end
        if p1.wasPressed("action") then
            modeSelected = true
            players = {}
            for i = 1, numPlayers do
                table.insert(players, makePlayer(i))
            end
            for _, p in ipairs(players) do
                resetPlayerPos(p)
            end
            initLevel()
            sound.menuSelect()
        end
        return
    end

    if deathTimer > 0 then
        deathTimer = deathTimer - dt
        if deathTimer <= 0 then
            deathTimer = 0
            if dyingPlayer then
                if dyingPlayer.lives > 0 then
                    resetPlayerPos(dyingPlayer)
                end
                dyingPlayer = nil
            end
            if not anyAlive() then
                gameOverFlag = true
                sound.gameOver()
            end
        end
        return
    end

    tickAccum = tickAccum + dt
    if tickAccum < 0.05 then return end
    tickAccum = tickAccum - 0.05

    local wrapW = width + CELL * 20
    for li, lane in ipairs(lanes) do
        lane.accum = lane.accum + lane.speed
        if lane.accum >= 1 then
            local steps = math.floor(lane.accum)
            lane.accum = lane.accum - steps
            local pixelShift = steps * lane.dir
            for _, obj in ipairs(lane.objs) do
                obj.x = obj.x + pixelShift
                if lane.dir > 0 and obj.x > width + CELL * 8 then
                    obj.x = obj.x - wrapW
                elseif lane.dir < 0 and obj.x + obj.w < -CELL * 8 then
                    obj.x = obj.x + wrapW
                end
            end
            if lane.type == "river" then
                local rowForLane = ROW_RIVER_START + li - 1
                for _, p in ipairs(players) do
                    if p.alive and p.gy == rowForLane then
                        p.gx = p.gx + pixelShift / CELL
                    end
                end
            end
        end
    end

    for pi, p in ipairs(players) do
        if p.alive and p.lives > 0 then
            local inp = input.getPlayer(pi)
            local moved = false

            if inp.wasPressed("up") and p.gy > ROW_HOME then
                p.gy = p.gy - 1
                p.facing = "up"
                moved = true
            end
            if inp.wasPressed("down") and p.gy < ROW_START then
                p.gy = p.gy + 1
                p.facing = "down"
                moved = true
            end
            if inp.wasPressed("left") and p.gx > 0 then
                p.gx = p.gx - 1
                p.facing = "left"
                moved = true
            end
            if inp.wasPressed("right") and p.gx < gridW - 1 then
                p.gx = p.gx + 1
                p.facing = "right"
                moved = true
            end

            if moved then
                sound.playNote("hat", 0.3, 16)
                if p.gy < p.maxRow then
                    p.score = p.score + SCORE_HOP
                    p.maxRow = p.gy
                end
            end

            if p.gy >= ROW_RIVER_START and p.gy <= ROW_RIVER_START + 2 then
                local onLog = playerOnLog(p)
                if not onLog then
                    killPlayer(p)
                    break
                end
            end

            if playerHitCar(p) then
                killPlayer(p)
                break
            end

            local atHome, slotIdx = playerAtHome(p)
            if atHome and slotIdx > 0 then
                homeFilled[slotIdx] = true
                p.score = p.score + SCORE_HOME
                sound.playNote("harp", 0.8, 22)
                resetPlayerPos(p)

                if allHomeFilled() then
                    level = level + 1
                    for _, pl in ipairs(players) do
                        pl.score = pl.score + SCORE_LEVEL
                    end
                    sound.victory()
                    initLevel()
                    for _, pl in ipairs(players) do
                        resetPlayerPos(pl)
                    end
                end
            end

        end
    end
end

local function drawHUD()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.write(blankRow)

    if #players == 1 then
        local p = players[1]
        term.setCursorPos(2, 1)
        term.setTextColor(colors.lime)
        term.write("Score:" .. p.score)
        local livesStr = string.rep("\3 ", p.lives)
        term.setCursorPos(width - #livesStr, 1)
        term.setTextColor(colors.red)
        term.write(livesStr)
    else
        local p1 = players[1]
        term.setCursorPos(2, 1)
        term.setTextColor(colors.lime)
        term.write("P1:" .. p1.score)
        term.setTextColor(colors.red)
        term.write(" " .. string.rep("\3", p1.lives))

        local p2 = players[2]
        local p2Score = "P2:" .. p2.score
        local p2Lives = " " .. string.rep("\3", p2.lives)
        term.setCursorPos(width - #p2Score - #p2Lives, 1)
        term.setTextColor(colors.orange)
        term.write(p2Score)
        term.setTextColor(colors.red)
        term.write(p2Lives)
    end

    term.setCursorPos(math.floor(width / 2) - 2, 1)
    term.setTextColor(colors.white)
    term.write("Lv" .. level)
end

local function drawHome()
    local y = rowToScreenY(ROW_HOME)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.black)
    for row = 0, CELL - 1 do
        term.setCursorPos(1, y + row)
        term.write(blankRow)
    end

    for i, slot in ipairs(homeSlots) do
        if homeFilled[i] then
            term.setBackgroundColor(colors.green)
            sprite.draw(sprites.frog, slot.x, y, "up", 1, colors.yellow)
        else
            term.setBackgroundColor(colors.blue)
            for row = 0, CELL - 1 do
                term.setCursorPos(slot.x, y + row)
                term.write(string.rep(" ", CELL))
            end
        end
    end
end

local function drawRiverLanes()
    for li = 1, 3 do
        local y = laneScreenY(li)
        local lane = lanes[li]

        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.blue)
        for row = 0, CELL - 1 do
            term.setCursorPos(1, y + row)
            term.write(blankRow)
        end

        term.setBackgroundColor(colors.brown)
        term.setTextColor(colors.yellow)
        for _, obj in ipairs(lane.objs) do
            local ox = math.floor(obj.x)
            if ox + obj.w >= 1 and ox <= width then
                local startCol = math.max(1, ox)
                local endCol = math.min(width, ox + obj.w - 1)
                local visW = endCol - startCol + 1
                for row = 0, CELL - 1 do
                    term.setCursorPos(startCol, y + row)
                    term.write(string.rep(row == 0 and "=" or "-", visW))
                end
            end
        end
    end
end

local function drawSafeZone()
    local y = rowToScreenY(ROW_SAFE)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    for row = 0, CELL - 1 do
        term.setCursorPos(1, y + row)
        term.write(blankRow)
    end
    term.setCursorPos(math.floor(width / 2) - 3, y)
    term.setTextColor(colors.white)
    term.write(" SAFE ")
end

local function buildCarRow(w, row)
    if row == 0 then
        return "[" .. string.rep("=", math.max(0, w - 2)) .. "]"
    else
        return "o" .. string.rep("_", math.max(0, w - 2)) .. "o"
    end
end

local function drawRoadLanes()
    for li = 4, 6 do
        local y = laneScreenY(li)
        local lane = lanes[li]

        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.gray)
        for row = 0, CELL - 1 do
            term.setCursorPos(1, y + row)
            term.write(blankRow)
        end

        term.setTextColor(colors.yellow)
        term.setCursorPos(1, y)
        local dashes = {}
        for col = 1, width, 4 do
            dashes[#dashes + 1] = "--"
            if col + 2 <= width then
                dashes[#dashes + 1] = "  "
            end
        end
        term.write(table.concat(dashes):sub(1, width))

        for _, obj in ipairs(lane.objs) do
            local ox = math.floor(obj.x)
            if ox + obj.w >= 1 and ox <= width then
                local objColor = obj.kind == "truck" and colors.red or colors.white
                term.setTextColor(objColor)
                term.setBackgroundColor(colors.gray)
                for row = 0, CELL - 1 do
                    local full
                    if obj.kind == "truck" then
                        full = string.rep("#", obj.w)
                    else
                        full = buildCarRow(obj.w, row)
                    end
                    local startCol = math.max(1, ox)
                    local endCol = math.min(width, ox + obj.w - 1)
                    local clipStart = startCol - ox + 1
                    local clipEnd = endCol - ox + 1
                    term.setCursorPos(startCol, y + row)
                    term.write(full:sub(clipStart, clipEnd))
                end
            end
        end
    end
end

local function drawStartZone()
    local y = rowToScreenY(ROW_START)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    for row = 0, CELL - 1 do
        term.setCursorPos(1, y + row)
        if y + row <= height then
            term.write(blankRow)
        end
    end
end

local function drawPlayers()
    for _, p in ipairs(players) do
        if p.lives > 0 then
            local sx = math.floor(p.gx) * CELL + 1
            local sy = rowToScreenY(p.gy)

            if dyingPlayer and dyingPlayer.num == p.num and not p.alive then
                sprite.draw(sprites.frog, sx, sy, "dead", 1, colors.red)
            else
                sprite.draw(sprites.frog, sx, sy, p.facing or "up", 1, p.color)
            end
        end
    end
end

local function drawModeSelect()
    term.setBackgroundColor(colors.black)
    term.clear()

    term.setTextColor(colors.lime)
    local title = "F R O G G E R"
    term.setCursorPos(math.floor((width - #title) / 2) + 1, 3)
    term.write(title)

    term.setTextColor(colors.white)
    local sub = "Cross the road and river!"
    term.setCursorPos(math.floor((width - #sub) / 2) + 1, 5)
    term.write(sub)

    sprite.draw(sprites.frog, math.floor(width / 2), 7, "up", 1, colors.lime)

    local y = 11
    term.setTextColor(colors.lightGray)
    term.setCursorPos(math.floor(width / 2) - 6, y)
    term.write("Players: ")

    if numPlayers == 1 then
        term.setTextColor(colors.yellow)
        term.setBackgroundColor(colors.blue)
        term.write(" 1 ")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.write("  2 ")
    else
        term.setTextColor(colors.lightGray)
        term.write(" 1 ")
        term.setTextColor(colors.yellow)
        term.setBackgroundColor(colors.blue)
        term.write(" 2 ")
        term.setBackgroundColor(colors.black)
    end

    term.setTextColor(colors.gray)
    local hint = "[left/right] Toggle  [action] Start"
    term.setCursorPos(math.floor((width - #hint) / 2) + 1, y + 2)
    term.write(hint)
end

function game.draw()
    if not modeSelected then
        drawModeSelect()
        return
    end

    term.setBackgroundColor(colors.black)
    term.clear()

    drawHome()
    drawRiverLanes()
    drawSafeZone()
    drawRoadLanes()
    drawStartZone()
    drawPlayers()
    drawHUD()

    if gameOverFlag then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")

        term.setBackgroundColor(colors.gray)
        if #players == 1 then
            local scoreStr = " Score: " .. players[1].score .. " "
            term.setCursorPos(mx - 1, my + 1)
            term.write(scoreStr)
        else
            local scoreStr = " P1:" .. players[1].score .. "  P2:" .. players[2].score .. " "
            term.setCursorPos(math.floor((width - #scoreStr) / 2), my + 1)
            term.write(scoreStr)
        end
        term.setBackgroundColor(colors.black)
    end
end

function game.cleanup()
    sound.stop()
end

return game
