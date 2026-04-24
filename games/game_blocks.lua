local game = {}

local width, height
local boardW, boardH
local boardX
local board
local current, currentX, currentY, currentColor
local fallTimer, fallSpeed
local score, level, lines
local gameOver
local tickAccum

local pieces = {
    { shape = {{1,1,1,1}},             color = colors.cyan },
    { shape = {{1,1},{1,1}},           color = colors.yellow },
    { shape = {{0,1,0},{1,1,1}},       color = colors.purple },
    { shape = {{1,0,0},{1,1,1}},       color = colors.orange },
    { shape = {{0,0,1},{1,1,1}},       color = colors.blue },
    { shape = {{0,1,1},{1,1,0}},       color = colors.green },
    { shape = {{1,1,0},{0,1,1}},       color = colors.red },
}

local function rotate(shape)
    local rows = #shape
    local cols = #shape[1]
    local new = {}
    for c = 1, cols do
        new[c] = {}
        for r = rows, 1, -1 do
            new[c][rows - r + 1] = shape[r][c]
        end
    end
    return new
end

local function fits(shape, ox, oy)
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local bx = ox + c - 1
                local by = oy + r - 1
                if bx < 1 or bx > boardW or by > boardH then return false end
                if by >= 1 and board[by][bx] then return false end
            end
        end
    end
    return true
end

local function lock()
    for r = 1, #current do
        for c = 1, #current[r] do
            if current[r][c] == 1 then
                local bx = currentX + c - 1
                local by = currentY + r - 1
                if by >= 1 and by <= boardH then
                    board[by][bx] = currentColor
                end
            end
        end
    end
end

local function clearLines()
    local cleared = 0
    local row = boardH
    while row >= 1 do
        local full = true
        for x = 1, boardW do
            if not board[row][x] then full = false break end
        end
        if full then
            table.remove(board, row)
            local emptyRow = {}
            for x = 1, boardW do emptyRow[x] = false end
            table.insert(board, 1, emptyRow)
            cleared = cleared + 1
        else
            row = row - 1
        end
    end
    return cleared
end

local function spawn()
    local p = pieces[math.random(#pieces)]
    current = p.shape
    currentColor = p.color
    currentX = math.floor((boardW - #current[1]) / 2) + 1
    currentY = 1
    if not fits(current, currentX, currentY) then
        gameOver = true
    end
end

function game.title()
    return "Falling Blocks"
end

function game.getControls()
    return {
        { action = "left/right", description = "Move" },
        { action = "down",       description = "Soft drop" },
        { action = "action",     description = "Rotate" },
        { action = "alt",        description = "Hard drop" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    boardW = 10
    boardH = height - 1
    boardX = math.floor((width - boardW) / 2)

    board = {}
    for y = 1, boardH do
        board[y] = {}
        for x = 1, boardW do board[y][x] = false end
    end

    score = 0
    level = 1
    lines = 0
    fallSpeed = 0.5
    tickAccum = 0
    gameOver = false

    math.randomseed(os.clock() * 1000)
    spawn()
end

function game.update(dt, input)
    if gameOver then return end

    local p1 = input.getPlayer(1)
    tickAccum = tickAccum + dt

    if p1.wasPressed("left") then
        if fits(current, currentX - 1, currentY) then
            currentX = currentX - 1
        end
    elseif p1.wasPressed("right") then
        if fits(current, currentX + 1, currentY) then
            currentX = currentX + 1
        end
    end

    if p1.wasPressed("action") then
        local rotated = rotate(current)
        if fits(rotated, currentX, currentY) then
            current = rotated
        end
    end

    if p1.wasPressed("alt") then
        while fits(current, currentX, currentY + 1) do
            currentY = currentY + 1
            score = score + 1
        end
        lock()
        local cleared = clearLines()
        lines = lines + cleared
        score = score + ({0, 100, 300, 500, 800})[cleared + 1] * level
        level = math.floor(lines / 10) + 1
        fallSpeed = math.max(0.05, 0.5 - (level - 1) * 0.04)
        spawn()
        tickAccum = 0
        return
    end

    local speed = fallSpeed
    if p1.isDown("down") then speed = 0.05 end

    if tickAccum >= speed then
        tickAccum = tickAccum - speed
        if fits(current, currentX, currentY + 1) then
            currentY = currentY + 1
            if p1.isDown("down") then score = score + 1 end
        else
            lock()
            local cleared = clearLines()
            lines = lines + cleared
            score = score + ({0, 100, 300, 500, 800})[cleared + 1] * level
            level = math.floor(lines / 10) + 1
            fallSpeed = math.max(0.05, 0.5 - (level - 1) * 0.04)
            spawn()
            tickAccum = 0
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    local lx = boardX - 1
    local rx = boardX + boardW
    for y = 1, boardH do
        term.setCursorPos(lx, y)
        term.setBackgroundColor(colors.gray)
        term.write(" ")
        term.setCursorPos(rx + 1, y)
        term.write(" ")
    end
    term.setCursorPos(lx, boardH + 1)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", boardW + 2))
    term.setBackgroundColor(colors.black)

    for y = 1, boardH do
        for x = 1, boardW do
            if board[y][x] then
                term.setCursorPos(boardX + x - 1, y)
                term.setBackgroundColor(board[y][x])
                term.setTextColor(colors.white)
                term.write("#")
            end
        end
    end

    if current and not gameOver then
        for r = 1, #current do
            for c = 1, #current[r] do
                if current[r][c] == 1 then
                    local sx = boardX + currentX + c - 2
                    local sy = currentY + r - 1
                    if sy >= 1 then
                        term.setCursorPos(sx, sy)
                        term.setBackgroundColor(currentColor)
                        term.setTextColor(colors.white)
                        term.write("#")
                    end
                end
            end
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    local infoX = rx + 3
    if infoX + 10 <= width then
        term.setCursorPos(infoX, 2)
        term.write("Score")
        term.setCursorPos(infoX, 3)
        term.write(tostring(score))
        term.setCursorPos(infoX, 5)
        term.write("Level")
        term.setCursorPos(infoX, 6)
        term.write(tostring(level))
        term.setCursorPos(infoX, 8)
        term.write("Lines")
        term.setCursorPos(infoX, 9)
        term.write(tostring(lines))
    end

    if gameOver then
        local msg = "GAME OVER"
        local mx = math.floor((width - #msg) / 2)
        local my = math.floor(height / 2)
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
        term.setCursorPos(mx - 2, my + 1)
        term.write("Score: " .. score)
    end
end

function game.cleanup()
end

return game
