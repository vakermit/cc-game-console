local sound = require("lib.sound")

local game = {}

local width, height
local state
local playerRoom, wumpusRoom
local pits, bats
local arrows
local selected
local mode
local message, messageLines
local gameOverFlag, gameOverTimer
local visited
local shootPath
local resultWait

local cave = {
    [1]  = {2, 5, 8},
    [2]  = {1, 3, 10},
    [3]  = {2, 4, 12},
    [4]  = {3, 5, 14},
    [5]  = {1, 4, 6},
    [6]  = {5, 7, 15},
    [7]  = {6, 8, 17},
    [8]  = {1, 7, 9},
    [9]  = {8, 10, 18},
    [10] = {2, 9, 11},
    [11] = {10, 12, 19},
    [12] = {3, 11, 13},
    [13] = {12, 14, 20},
    [14] = {4, 13, 15},
    [15] = {6, 14, 16},
    [16] = {15, 17, 20},
    [17] = {7, 16, 18},
    [18] = {9, 17, 19},
    [19] = {11, 18, 20},
    [20] = {13, 16, 19},
}

local hubOffsets = {
    {0, -3},
    {-6, 2},
    {6, 2},
}

local function wrap(text, maxW)
    local lines = {}
    local line = ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > maxW then
            table.insert(lines, line)
            line = word
        else
            line = #line > 0 and (line .. " " .. word) or word
        end
    end
    if #line > 0 then table.insert(lines, line) end
    return lines
end

local function setMessage(text)
    message = text
    messageLines = wrap(text, width - 4)
end

local function isAdjacent(room1, room2)
    for _, n in ipairs(cave[room1]) do
        if n == room2 then return true end
    end
    return false
end

local function hasPit(room)
    for _, p in ipairs(pits) do
        if p == room then return true end
    end
    return false
end

local function hasBat(room)
    for _, b in ipairs(bats) do
        if b == room then return true end
    end
    return false
end

local function randomSafeRoom(exclude)
    local room
    repeat
        room = math.random(1, 20)
        local blocked = false
        for _, ex in ipairs(exclude) do
            if room == ex then blocked = true; break end
        end
        if blocked then room = nil end
    until room
    return room
end

local function getWarnings()
    local warnings = {}
    for _, neighbor in ipairs(cave[playerRoom]) do
        if neighbor == wumpusRoom then
            warnings.wumpus = true
        end
        if hasPit(neighbor) then
            warnings.pit = true
        end
        if hasBat(neighbor) then
            warnings.bat = true
        end
    end
    return warnings
end

local function wakeWumpus()
    if math.random() < 0.75 then
        local neighbors = cave[wumpusRoom]
        wumpusRoom = neighbors[math.random(#neighbors)]
    end
end

local function endGame(newState, msg, soundFn)
    state = newState
    setMessage(msg)
    gameOverFlag = true
    gameOverTimer = 0
    soundFn()
end

local function initCave()
    wumpusRoom = math.random(1, 20)
    pits = {}
    bats = {}
    local taken = {wumpusRoom}

    for _ = 1, 2 do
        local r = randomSafeRoom(taken)
        table.insert(pits, r)
        table.insert(taken, r)
    end
    for _ = 1, 2 do
        local r = randomSafeRoom(taken)
        table.insert(bats, r)
        table.insert(taken, r)
    end

    playerRoom = randomSafeRoom(taken)
    arrows = 5
    visited = {}
    visited[playerRoom] = true
end

local function initGame()
    state = "intro"
    selected = 1
    mode = "move"
    gameOverFlag = false
    gameOverTimer = 0
    resultWait = 0
    shootPath = {}
    setMessage("")
    initCave()
end

local function movePlayer(room)
    playerRoom = room
    visited[room] = true

    if room == wumpusRoom then
        if math.random() < 0.25 then
            setMessage("The Wumpus was here! It startles and flees into the darkness.")
            wakeWumpus()
            if playerRoom == wumpusRoom then
                endGame("lose", "The fleeing Wumpus trampled you! Game over.", sound.gameOver)
                return
            end
            state = "result"
            resultWait = 0
            return
        else
            endGame("lose", "The Wumpus devours you! Its breath is worse than its bite. Game over.", sound.gameOver)
            return
        end
    end

    if hasPit(room) then
        endGame("lose", "YYYIIIEEE! You fell into a bottomless pit! Game over.", sound.gameOver)
        return
    end

    if hasBat(room) then
        setMessage("ZAP! Super Bats grab you and drop you somewhere random!")
        local safeRoom
        repeat
            safeRoom = math.random(1, 20)
        until safeRoom ~= wumpusRoom and not hasPit(safeRoom)
        playerRoom = safeRoom
        visited[safeRoom] = true
        state = "result"
        resultWait = 0
        sound.playNote("hat", 0.8, 18)
        return
    end

    state = "play"
    sound.playNote("harp", 0.3, 8)
end

local function shootArrow(path)
    local currentRoom = playerRoom
    for _, targetRoom in ipairs(path) do
        if isAdjacent(currentRoom, targetRoom) then
            currentRoom = targetRoom
        else
            local neighbors = cave[currentRoom]
            currentRoom = neighbors[math.random(#neighbors)]
        end

        if currentRoom == wumpusRoom then
            endGame("win", "AHA! You got the Wumpus! The beast falls with a mighty crash!", sound.victory)
            return
        end

        if currentRoom == playerRoom then
            endGame("lose", "OUCH! The arrow curved back and hit you! Game over.", sound.gameOver)
            return
        end
    end

    arrows = arrows - 1
    if arrows <= 0 then
        endGame("lose", "You've run out of arrows. The Wumpus will find you eventually. Game over.", sound.gameOver)
        return
    end

    setMessage("The arrow flies into the darkness... and misses. The Wumpus stirs! (" .. arrows .. " arrows left)")
    wakeWumpus()
    if playerRoom == wumpusRoom then
        endGame("lose", "The Wumpus, awakened by your arrow, stumbles into your room and eats you!", sound.gameOver)
        return
    end
    state = "result"
    resultWait = 0
end

function game.title()
    return "Hunt the Wumpus"
end

function game.getControls()
    return {
        { action = "up/down",  description = "Select room" },
        { action = "action",   description = "Move/Shoot" },
        { action = "alt",      description = "Toggle mode" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    initGame()
    sound.playNotes({
        { instrument = "bass", pitch = 5, rest = 6 },
        { instrument = "bass", pitch = 3, rest = 6 },
        { instrument = "bass", pitch = 1, rest = 8 },
        { instrument = "bass", pitch = 5, rest = 4 },
        { instrument = "bass", pitch = 3, rest = 10 },
    }, 2)
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            initGame()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 15 then
            return "menu"
        end
        return
    end

    if state == "intro" then
        setMessage("Deep in the caves beneath the earth lurks the dreaded Wumpus. " ..
            "Armed with 5 crooked arrows, you must hunt it through 20 rooms. " ..
            "Beware the bottomless pits and super bats!")
        if p1.wasPressed("action") then
            sound.stop()
            state = "play"
            selected = 1
        end

    elseif state == "play" then
        local neighbors = cave[playerRoom]
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = 3 end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > 3 then selected = 1 end
        elseif p1.wasPressed("alt") then
            if mode == "move" then
                if arrows > 0 then
                    mode = "shoot"
                else
                    setMessage("No arrows left! You can only move.")
                end
            else
                mode = "move"
            end
            sound.playNote("hat", 0.3, 12)
        elseif p1.wasPressed("action") then
            local targetRoom = neighbors[selected]
            if mode == "move" then
                movePlayer(targetRoom)
                selected = 1
            elseif arrows > 0 then
                shootPath = {targetRoom}
                state = "shoot_select"
                selected = 1
                setMessage("Arrow room 1: " .. targetRoom .. ". Select next room (action=add, alt=fire now)")
            end
        end

    elseif state == "shoot_select" then
        local lastRoom = shootPath[#shootPath]
        local neighbors = cave[lastRoom]
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = 3 end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > 3 then selected = 1 end
        elseif p1.wasPressed("action") then
            local nextRoom = neighbors[selected]
            table.insert(shootPath, nextRoom)
            if #shootPath >= 3 then
                shootArrow(shootPath)
                shootPath = {}
                mode = "move"
                selected = 1
            else
                setMessage("Arrow room " .. #shootPath .. ": " .. nextRoom .. ". Select next room (action=add, alt=fire now)")
                selected = 1
            end
        elseif p1.wasPressed("alt") then
            shootArrow(shootPath)
            shootPath = {}
            mode = "move"
            selected = 1
        end

    elseif state == "result" then
        resultWait = resultWait + dt
        if p1.wasPressed("action") and resultWait > 0.3 then
            state = "play"
            selected = 1
        end
    end
end

local function drawRoomAt(x, y, roomNum, isCurrent, isSelected, isVisited)
    if isCurrent then
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
    elseif isSelected then
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
    elseif isVisited then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
    end

    local label = string.format("%2d", roomNum)
    if x >= 1 and x <= width - 1 and y >= 1 and y <= height then
        term.setCursorPos(x, y)
        term.write(label)
    end
    term.setBackgroundColor(colors.black)
end

local function drawConnection(x1, y1, x2, y2)
    term.setTextColor(colors.gray)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps <= 2 then return end
    for i = 1, steps - 1 do
        local frac = i / steps
        local cx = math.floor(x1 + dx * frac + 0.5)
        local cy = math.floor(y1 + dy * frac + 0.5)
        if cx >= 1 and cx <= width and cy >= 1 and cy <= height then
            term.setCursorPos(cx, cy)
            if math.abs(dx) > math.abs(dy) then
                term.write("-")
            else
                term.write("|")
            end
        end
    end
end

local function drawHubView(centerRoom, neighbors, isShooting)
    local centerX = math.floor(width * 0.35)
    local centerY = math.floor(height * 0.45)

    for i, neighbor in ipairs(neighbors) do
        local nx = centerX + hubOffsets[i][1]
        local ny = centerY + hubOffsets[i][2]
        drawConnection(centerX + 1, centerY, nx + 1, ny)
    end

    if isShooting then
        term.setBackgroundColor(colors.orange)
        term.setTextColor(colors.white)
        local label = string.format("%2d", centerRoom)
        term.setCursorPos(centerX, centerY)
        term.write(label)
        term.setBackgroundColor(colors.black)
    else
        drawRoomAt(centerX, centerY, centerRoom, true, false, true)
    end

    for i, neighbor in ipairs(neighbors) do
        local nx = centerX + hubOffsets[i][1]
        local ny = centerY + hubOffsets[i][2]
        drawRoomAt(nx, ny, neighbor, false, i == selected, visited[neighbor])
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setBackgroundColor(colors.brown)
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", width))
    term.setCursorPos(2, 1)
    term.setTextColor(colors.white)
    term.write("WUMPUS")
    if state ~= "intro" then
        local info = "Room:" .. playerRoom .. "  Arrows:" .. arrows .. "  [" .. string.upper(mode) .. "]"
        term.setCursorPos(width - #info, 1)
        term.write(info)
    end
    term.setBackgroundColor(colors.black)

    if state == "intro" then
        local textY = 4
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, 3)
        term.write("HUNT THE WUMPUS")
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + i)
            term.write(line)
        end
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write("[action] Enter the caves")

    elseif state == "play" or state == "shoot_select" then
        local neighbors, centerRoom, isShooting
        if state == "play" then
            neighbors = cave[playerRoom]
            centerRoom = playerRoom
            isShooting = false
        else
            centerRoom = shootPath[#shootPath]
            neighbors = cave[centerRoom]
            isShooting = true
        end

        drawHubView(centerRoom, neighbors, isShooting)

        local infoX = math.floor(width * 0.62)
        local infoY = 3

        local warnings = getWarnings()
        term.setCursorPos(infoX, infoY)
        term.setTextColor(colors.yellow)
        term.write("Room " .. playerRoom)

        local wy = infoY + 1
        if warnings.wumpus then
            term.setCursorPos(infoX, wy)
            term.setTextColor(colors.red)
            term.write("I smell a Wumpus!")
            wy = wy + 1
        end
        if warnings.pit then
            term.setCursorPos(infoX, wy)
            term.setTextColor(colors.cyan)
            term.write("I feel a draft...")
            wy = wy + 1
        end
        if warnings.bat then
            term.setCursorPos(infoX, wy)
            term.setTextColor(colors.purple)
            term.write("Bats nearby!")
            wy = wy + 1
        end

        wy = wy + 1
        term.setCursorPos(infoX, wy)
        term.setTextColor(colors.lightGray)
        term.write("Tunnels:")
        for i, neighbor in ipairs(neighbors) do
            wy = wy + 1
            term.setCursorPos(infoX, wy)
            if i == selected then
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.gray)
                term.write(" " .. neighbor .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(" " .. neighbor)
            end
        end

        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        if state == "play" then
            if mode == "move" then
                term.write("[action] Move  [alt] Switch to SHOOT")
            else
                term.write("[action] Aim arrow  [alt] Switch to MOVE")
            end
        else
            local pathStr = ""
            for _, r in ipairs(shootPath) do
                pathStr = pathStr .. r .. " > "
            end
            term.setCursorPos(2, height - 2)
            term.setTextColor(colors.orange)
            term.write("Arrow: " .. pathStr .. "?")
            term.setCursorPos(2, height - 1)
            term.setTextColor(colors.lightGray)
            term.write("[action] Add room  [alt] Fire now!")
        end

    elseif state == "result" then
        term.setTextColor(colors.white)
        local textY = math.floor(height / 2) - math.floor(#messageLines / 2)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + i)
            term.write(line)
        end
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write("[action] Continue")

    elseif state == "win" then
        term.setTextColor(colors.lime)
        term.setCursorPos(2, 4)
        term.write("*** WUMPUS SLAIN! ***")
        term.setTextColor(colors.white)
        local textY = 6
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + i)
            term.write(line)
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY + #messageLines + 2)
        term.write("Arrows remaining: " .. arrows)

    elseif state == "lose" then
        term.setTextColor(colors.red)
        term.setCursorPos(2, 4)
        term.write("*** YOU DIED ***")
        term.setTextColor(colors.white)
        local textY = 6
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + i)
            term.write(line)
        end
        term.setTextColor(colors.gray)
        term.setCursorPos(2, textY + #messageLines + 2)
        term.write("The Wumpus was in room " .. wumpusRoom)
    end

    term.setBackgroundColor(colors.black)
end

function game.cleanup()
    sound.stop()
end

return game
