local game = {}

local width, height
local playerX, playerY
local currentRoom
local inventory
local rooms
local dragons
local gameOverFlag, gameOverTimer, wonFlag
local chaliceRoom, chaliceX, chaliceY

local items = {
    key_gold   = { char = "k", color = colors.yellow, name = "Gold Key" },
    key_black  = { char = "k", color = colors.gray, name = "Black Key" },
    sword      = { char = "!", color = colors.white, name = "Sword" },
    chalice    = { char = "Y", color = colors.yellow, name = "Chalice" },
}

local function makeRoom(name, color, walls, gates, roomItems, desc)
    return {
        name = name,
        color = color,
        walls = walls or {},
        gates = gates or {},
        items = roomItems or {},
        desc = desc or "",
    }
end

local function px(frac) return math.floor(frac * width + 0.5) end
local function py(frac) return math.floor(frac * height + 0.5) end

local function initRooms()
    local mid = py(0.5)
    local midX = px(0.5)

    rooms = {
        castle = makeRoom("Gold Castle", colors.yellow, {}, {
            { x = midX, y = 2, dir = "up", dest = "courtyard", dx = midX, dy = nil },
        }, {}, "Your quest begins here."),

        courtyard = makeRoom("Courtyard", colors.green, {}, {
            { x = midX, y = nil, dir = "down", dest = "castle", dx = midX, dy = 3 },
            { x = 1, y = mid, dir = "left", dest = "forest", dx = nil, dy = mid },
            { x = nil, y = mid, dir = "right", dest = "maze1", dx = 2, dy = mid },
            { x = midX, y = 2, dir = "up", dest = "mountain", dx = midX, dy = nil },
        }, { { item = "sword", x = px(0.3), y = py(0.4) } }),

        forest = makeRoom("Dark Forest", colors.green, {
            { x1 = px(0.2), y1 = py(0.25), x2 = px(0.2), y2 = py(0.7) },
            { x1 = px(0.45), y1 = py(0.2), x2 = px(0.45), y2 = py(0.5) },
            { x1 = px(0.7), y1 = py(0.4), x2 = px(0.7), y2 = py(0.8) },
        }, {
            { x = nil, y = mid, dir = "right", dest = "courtyard", dx = 2, dy = mid },
            { x = 1, y = py(0.35), dir = "left", dest = "dark_castle", dx = nil, dy = py(0.35) },
        }, { { item = "key_gold", x = px(0.85), y = py(0.7) } }),

        maze1 = makeRoom("Maze", colors.gray, {
            { x1 = px(0.15), y1 = py(0.2), x2 = px(0.15), y2 = py(0.55) },
            { x1 = px(0.15), y1 = py(0.55), x2 = px(0.4), y2 = py(0.55) },
            { x1 = px(0.3), y1 = py(0.2), x2 = px(0.3), y2 = py(0.4) },
            { x1 = px(0.45), y1 = py(0.35), x2 = px(0.45), y2 = py(0.8) },
            { x1 = px(0.6), y1 = py(0.2), x2 = px(0.6), y2 = py(0.55) },
            { x1 = px(0.6), y1 = py(0.55), x2 = px(0.85), y2 = py(0.55) },
            { x1 = px(0.75), y1 = py(0.7), x2 = px(0.75), y2 = py(0.95) },
        }, {
            { x = 1, y = py(0.35), dir = "left", dest = "courtyard", dx = nil, dy = py(0.35) },
            { x = nil, y = py(0.35), dir = "right", dest = "maze2", dx = 2, dy = py(0.35) },
        }),

        maze2 = makeRoom("Deep Maze", colors.gray, {
            { x1 = px(0.2), y1 = py(0.15), x2 = px(0.2), y2 = py(0.7) },
            { x1 = px(0.2), y1 = py(0.7), x2 = px(0.55), y2 = py(0.7) },
            { x1 = px(0.4), y1 = py(0.25), x2 = px(0.4), y2 = py(0.55) },
            { x1 = px(0.6), y1 = py(0.2), x2 = px(0.6), y2 = py(0.7) },
            { x1 = px(0.8), y1 = py(0.35), x2 = px(0.8), y2 = py(0.85) },
        }, {
            { x = 1, y = py(0.35), dir = "left", dest = "maze1", dx = nil, dy = py(0.35) },
        }, { { item = "key_black", x = px(0.9), y = py(0.85) } }),

        mountain = makeRoom("Mountain Pass", colors.brown, {
            { x1 = px(0.25), y1 = py(0.4), x2 = px(0.5), y2 = py(0.4) },
            { x1 = px(0.6), y1 = py(0.55), x2 = px(0.9), y2 = py(0.55) },
        }, {
            { x = midX, y = nil, dir = "down", dest = "courtyard", dx = midX, dy = 3 },
            { x = 1, y = py(0.35), dir = "left", dest = "dragon_lair", dx = nil, dy = py(0.35) },
        }),

        dragon_lair = makeRoom("Dragon's Lair", colors.red, {}, {
            { x = nil, y = py(0.35), dir = "right", dest = "mountain", dx = 2, dy = py(0.35) },
        }),

        dark_castle = makeRoom("Black Castle", colors.gray, {}, {
            { x = nil, y = py(0.35), dir = "right", dest = "forest", dx = 2, dy = py(0.35) },
        }),
    }

    chaliceRoom = "dragon_lair"
    chaliceX = midX
    chaliceY = mid
end

local function initDragons()
    dragons = {
        { name = "Yorgle", room = "forest", x = px(0.55), y = py(0.55), color = colors.yellow, alive = true, speed = 3, tick = 0 },
        { name = "Grundle", room = "maze2", x = px(0.45), y = py(0.4), color = colors.green, alive = true, speed = 2, tick = 0 },
        { name = "Rhindle", room = "dragon_lair", x = px(0.45), y = py(0.35), color = colors.red, alive = true, speed = 1, tick = 0 },
    }
end

local function isWall(room, x, y)
    for _, w in ipairs(room.walls) do
        if x >= w.x1 and x <= w.x2 and y >= w.y1 and y <= w.y2 then
            return true
        end
    end
    return false
end

local function hasItem(itemName)
    for _, inv in ipairs(inventory) do
        if inv == itemName then return true end
    end
    return false
end

local function removeItem(itemName)
    for i, inv in ipairs(inventory) do
        if inv == itemName then
            table.remove(inventory, i)
            return
        end
    end
end

local function dropItem(itemName, room, x, y)
    local r = rooms[room]
    if r then
        table.insert(r.items, { item = itemName, x = x, y = y })
    end
end

local function initGame()
    initRooms()
    initDragons()
    currentRoom = "castle"
    playerX = px(0.5)
    playerY = py(0.5)
    inventory = {}
    gameOverFlag = false
    gameOverTimer = 0
    wonFlag = false
end

function game.title()
    return "Adventure"
end

function game.getControls()
    return {
        { action = "arrows",  description = "Move" },
        { action = "action",  description = "Pick up / Use" },
        { action = "alt",     description = "Drop item" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    initGame()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            initGame()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 10 then
            return "menu"
        end
        return
    end

    local room = rooms[currentRoom]
    local nx, ny = playerX, playerY

    if p1.isDown("up") then ny = ny - 1 end
    if p1.isDown("down") then ny = ny + 1 end
    if p1.isDown("left") then nx = nx - 1 end
    if p1.isDown("right") then nx = nx + 1 end

    if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not isWall(room, nx, ny) then
        playerX = nx
        playerY = ny
    end

    for _, gate in ipairs(room.gates) do
        local gx = gate.x or (gate.dir == "right" and width or nil)
        local gy = gate.y or (gate.dir == "down" and height or nil)
        local match = false

        if gate.dir == "left" and playerX <= 1 and math.abs(playerY - (gy or playerY)) <= 2 then match = true end
        if gate.dir == "right" and playerX >= width and math.abs(playerY - (gy or playerY)) <= 2 then match = true end
        if gate.dir == "up" and playerY <= 1 and math.abs(playerX - (gx or playerX)) <= 2 then match = true end
        if gate.dir == "down" and playerY >= height and math.abs(playerX - (gx or playerX)) <= 2 then match = true end

        if match then
            local locked = false
            if gate.dest == "dark_castle" and not hasItem("key_black") then locked = true end
            if gate.dest == "castle" and gate.dir == "down" then
                if hasItem("chalice") then
                    wonFlag = true
                    gameOverFlag = true
                    gameOverTimer = 0
                    return
                end
            end

            if not locked then
                currentRoom = gate.dest
                playerX = gate.dx or (gate.dir == "left" and width - 1 or gate.dir == "right" and 2 or playerX)
                playerY = gate.dy or (gate.dir == "up" and height - 1 or gate.dir == "down" and 2 or playerY)
                break
            end
        end
    end

    if p1.wasPressed("action") then
        for i = #room.items, 1, -1 do
            local it = room.items[i]
            if math.abs(it.x - playerX) <= 1 and math.abs(it.y - playerY) <= 1 then
                if #inventory < 1 then
                    table.insert(inventory, it.item)
                    table.remove(room.items, i)
                else
                    local old = inventory[1]
                    inventory[1] = it.item
                    room.items[i].item = old
                end
                break
            end
        end

        if currentRoom == chaliceRoom and math.abs(chaliceX - playerX) <= 1 and math.abs(chaliceY - playerY) <= 1 then
            if #inventory < 1 then
                table.insert(inventory, "chalice")
                chaliceRoom = nil
            else
                local old = inventory[1]
                inventory[1] = "chalice"
                dropItem(old, currentRoom, chaliceX, chaliceY)
                chaliceRoom = nil
            end
        end
    end

    if p1.wasPressed("alt") and #inventory > 0 then
        local dropped = table.remove(inventory, 1)
        if dropped == "chalice" then
            chaliceRoom = currentRoom
            chaliceX = playerX
            chaliceY = playerY
        else
            dropItem(dropped, currentRoom, playerX + 1, playerY)
        end
    end

    for _, d in ipairs(dragons) do
        if d.alive and d.room == currentRoom then
            d.tick = d.tick + 1
            if d.tick >= d.speed then
                d.tick = 0
                local dx = playerX > d.x and 1 or playerX < d.x and -1 or 0
                local dy = playerY > d.y and 1 or playerY < d.y and -1 or 0
                if not isWall(room, d.x + dx, d.y + dy) then
                    d.x = d.x + dx
                    d.y = d.y + dy
                end
            end

            if math.abs(d.x - playerX) <= 1 and math.abs(d.y - playerY) <= 1 then
                if hasItem("sword") then
                    d.alive = false
                    removeItem("sword")
                    dropItem("sword", currentRoom, d.x, d.y)
                else
                    gameOverFlag = true
                    gameOverTimer = 0
                end
            end
        end
    end
end

function game.draw()
    local room = rooms[currentRoom]

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorPos(1, 1)
    term.setTextColor(room.color)
    term.write(room.name)

    if #inventory > 0 then
        local it = items[inventory[1]]
        if it then
            term.setCursorPos(width - #it.name - 1, 1)
            term.setTextColor(it.color)
            term.write(it.name)
        end
    end

    for _, w in ipairs(room.walls) do
        term.setTextColor(colors.gray)
        if w.x1 == w.x2 then
            for y = w.y1, w.y2 do
                term.setCursorPos(w.x1, y)
                term.write("|")
            end
        else
            term.setCursorPos(w.x1, w.y1)
            term.write(string.rep("-", w.x2 - w.x1 + 1))
        end
    end

    for _, gate in ipairs(room.gates) do
        local gx = gate.x or (gate.dir == "right" and width or 1)
        local gy = gate.y or (gate.dir == "down" and height or 1)
        term.setCursorPos(gx, gy)
        term.setTextColor(colors.white)
        term.write(" ")
    end

    for _, it in ipairs(room.items) do
        local def = items[it.item]
        if def then
            term.setCursorPos(it.x, it.y)
            term.setTextColor(def.color)
            term.write(def.char)
        end
    end

    if currentRoom == chaliceRoom then
        term.setCursorPos(chaliceX, chaliceY)
        term.setTextColor(colors.yellow)
        term.write("Y")
    end

    for _, d in ipairs(dragons) do
        if d.alive and d.room == currentRoom then
            term.setCursorPos(d.x, d.y)
            term.setTextColor(d.color)
            term.write("W")
            if d.y > 1 then
                term.setCursorPos(d.x - 1, d.y - 1)
                term.write("^ ^")
            end
        end
    end

    term.setCursorPos(playerX, playerY)
    term.setTextColor(colors.lime)
    term.write("@")

    if gameOverFlag then
        local msg, col
        if wonFlag then
            msg = "You returned the Chalice! YOU WIN!"
            col = colors.yellow
        else
            msg = "A dragon got you! GAME OVER"
            col = colors.red
        end
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(col == colors.yellow and colors.yellow or colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)

        local countdown = math.max(0, 10 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(math.floor((width - #hint) / 2), my + 2)
        term.write(hint)
    end
end

function game.cleanup()
end

return game
