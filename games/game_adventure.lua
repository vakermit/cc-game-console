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

local function initRooms()
    rooms = {
        castle = makeRoom("Gold Castle", colors.yellow, {}, {
            { x = 20, y = 1, dir = "up", dest = "courtyard", dx = 20, dy = nil },
        }, {}, "Your quest begins here."),

        courtyard = makeRoom("Courtyard", colors.green, {}, {
            { x = 20, y = nil, dir = "down", dest = "castle", dx = 20, dy = 2 },
            { x = 1, y = 8, dir = "left", dest = "forest", dx = nil, dy = 8 },
            { x = nil, y = 8, dir = "right", dest = "maze1", dx = 2, dy = 8 },
            { x = 20, y = 1, dir = "up", dest = "mountain", dx = 20, dy = nil },
        }, { { item = "sword", x = 10, y = 6 } }),

        forest = makeRoom("Dark Forest", colors.green, {
            { x1 = 8, y1 = 4, x2 = 8, y2 = 10 },
            { x1 = 15, y1 = 3, x2 = 15, y2 = 7 },
            { x1 = 25, y1 = 6, x2 = 25, y2 = 12 },
        }, {
            { x = nil, y = 8, dir = "right", dest = "courtyard", dx = 2, dy = 8 },
            { x = 1, y = 5, dir = "left", dest = "dark_castle", dx = nil, dy = 5 },
        }, { { item = "key_gold", x = 30, y = 10 } }),

        maze1 = makeRoom("Maze", colors.gray, {
            { x1 = 5, y1 = 3, x2 = 5, y2 = 8 },
            { x1 = 5, y1 = 8, x2 = 15, y2 = 8 },
            { x1 = 10, y1 = 3, x2 = 10, y2 = 6 },
            { x1 = 15, y1 = 5, x2 = 15, y2 = 12 },
            { x1 = 20, y1 = 3, x2 = 20, y2 = 8 },
            { x1 = 20, y1 = 8, x2 = 30, y2 = 8 },
            { x1 = 25, y1 = 10, x2 = 25, y2 = 14 },
        }, {
            { x = 1, y = 5, dir = "left", dest = "courtyard", dx = nil, dy = 5 },
            { x = nil, y = 5, dir = "right", dest = "maze2", dx = 2, dy = 5 },
        }),

        maze2 = makeRoom("Deep Maze", colors.gray, {
            { x1 = 8, y1 = 2, x2 = 8, y2 = 10 },
            { x1 = 8, y1 = 10, x2 = 20, y2 = 10 },
            { x1 = 14, y1 = 4, x2 = 14, y2 = 8 },
            { x1 = 20, y1 = 3, x2 = 20, y2 = 10 },
            { x1 = 26, y1 = 5, x2 = 26, y2 = 12 },
        }, {
            { x = 1, y = 5, dir = "left", dest = "maze1", dx = nil, dy = 5 },
        }, { { item = "key_black", x = 30, y = 12 } }),

        mountain = makeRoom("Mountain Pass", colors.brown, {
            { x1 = 10, y1 = 6, x2 = 18, y2 = 6 },
            { x1 = 22, y1 = 8, x2 = 30, y2 = 8 },
        }, {
            { x = 20, y = nil, dir = "down", dest = "courtyard", dx = 20, dy = 2 },
            { x = 1, y = 5, dir = "left", dest = "dragon_lair", dx = nil, dy = 5 },
        }),

        dragon_lair = makeRoom("Dragon's Lair", colors.red, {}, {
            { x = nil, y = 5, dir = "right", dest = "mountain", dx = 2, dy = 5 },
        }),

        dark_castle = makeRoom("Black Castle", colors.gray, {}, {
            { x = nil, y = 5, dir = "right", dest = "forest", dx = 2, dy = 5 },
        }),
    }

    chaliceRoom = "dragon_lair"
    chaliceX = 20
    chaliceY = 8
end

local function initDragons()
    dragons = {
        { name = "Yorgle", room = "forest", x = 20, y = 8, color = colors.yellow, alive = true, speed = 3, tick = 0 },
        { name = "Grundle", room = "maze2", x = 15, y = 6, color = colors.green, alive = true, speed = 2, tick = 0 },
        { name = "Rhindle", room = "dragon_lair", x = 15, y = 5, color = colors.red, alive = true, speed = 1, tick = 0 },
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
    playerX = 20
    playerY = 8
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

    if p1.wasPressed("up") then ny = ny - 1 end
    if p1.wasPressed("down") then ny = ny + 1 end
    if p1.wasPressed("left") then nx = nx - 1 end
    if p1.wasPressed("right") then nx = nx + 1 end

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
