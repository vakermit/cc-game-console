local game = {}

local width, height
local board
local cursorPos
local currentPlayer
local numPlayers
local state, selected
local winner, winLine
local gameOverTimer
local aiDelay, aiTimer
local p1Mark, p2Mark
local assignTimer

local batchTotal, batchPlayed
local batchResults
local batchSelected
local batchOpts = {1, 5, 10, 100}
local falkenMsg

local BATCH_ACCEL_START = 100
local BATCH_ACCEL_END = 37
local AI_DELAY_NORMAL = 0.4
local AI_DELAY_MIN = 0.02
local GAMEOVER_DELAY_NORMAL = 0.15
local GAMEOVER_DELAY_MIN = 0.02

local function batchSpeed(gamesLeft, normalVal, minVal)
    if not batchTotal or batchTotal < BATCH_ACCEL_START then return normalVal end
    if gamesLeft <= BATCH_ACCEL_END then return minVal end
    local t = (BATCH_ACCEL_START - gamesLeft) / (BATCH_ACCEL_START - BATCH_ACCEL_END)
    return normalVal + (minVal - normalVal) * t
end

local X, O, EMPTY = 1, 2, 0

local marks = { [X] = "X", [O] = "O" }
local markColors = { [X] = colors.cyan, [O] = colors.orange }

local lines = {
    {1,2,3}, {4,5,6}, {7,8,9},
    {1,4,7}, {2,5,8}, {3,6,9},
    {1,5,9}, {3,5,7},
}

local function checkWin(b)
    for _, line in ipairs(lines) do
        local a, b2, c = b[line[1]], b[line[2]], b[line[3]]
        if a ~= EMPTY and a == b2 and a == c then
            return a, line
        end
    end
    return nil, nil
end

local function boardFull(b)
    for i = 1, 9 do
        if b[i] == EMPTY then return false end
    end
    return true
end

local function minimax(b, player, alpha, beta)
    local w = checkWin(b)
    if w == O then return 1 end
    if w == X then return -1 end
    if boardFull(b) then return 0 end

    if player == O then
        local best = -math.huge
        for i = 1, 9 do
            if b[i] == EMPTY then
                b[i] = O
                local score = minimax(b, X, alpha, beta)
                b[i] = EMPTY
                best = math.max(best, score)
                alpha = math.max(alpha, score)
                if beta <= alpha then break end
            end
        end
        return best
    else
        local best = math.huge
        for i = 1, 9 do
            if b[i] == EMPTY then
                b[i] = X
                local score = minimax(b, O, alpha, beta)
                b[i] = EMPTY
                best = math.min(best, score)
                beta = math.min(beta, score)
                if beta <= alpha then break end
            end
        end
        return best
    end
end

local function aiMove(b, player)
    local bestScore = player == O and -math.huge or math.huge
    local bestMoves = {}
    for i = 1, 9 do
        if b[i] == EMPTY then
            b[i] = player
            local score = minimax(b, player == O and X or O, -math.huge, math.huge)
            b[i] = EMPTY
            if (player == O and score > bestScore) or (player == X and score < bestScore) then
                bestScore = score
                bestMoves = {i}
            elseif score == bestScore then
                table.insert(bestMoves, i)
            end
        end
    end
    return bestMoves[math.random(#bestMoves)]
end

local function checkGameEnd()
    local w, wl = checkWin(board)
    if w then
        winner = w
        winLine = wl
        state = "gameover"
        return true
    elseif boardFull(board) then
        state = "gameover"
        return true
    end
    return false
end

local function isAI(player)
    if numPlayers == 0 then return true end
    if numPlayers == 1 then return player == p2Mark end
    return false
end

local function initRound()
    board = {}
    for i = 1, 9 do board[i] = EMPTY end
    cursorPos = 5
    currentPlayer = X
    winner = nil
    winLine = nil
    gameOverTimer = 0
    aiTimer = 0
    if math.random(2) == 1 then
        p1Mark, p2Mark = X, O
    else
        p1Mark, p2Mark = O, X
    end
end

function game.title()
    return "Tic Tac Toe"
end

function game.getControls()
    return {
        { action = "arrows", description = "Move cursor" },
        { action = "action", description = "Place mark" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    numPlayers = nil
    state = "select"
    selected = 2
    aiDelay = 0.4
    batchSelected = 1
    batchTotal = nil
    batchPlayed = 0
    batchResults = nil
    falkenMsg = nil
    assignTimer = 0
end

local function cellToGrid(cell)
    local row = math.floor((cell - 1) / 3)
    local col = (cell - 1) % 3
    return col, row
end

local function moveCursor(dx, dy)
    local col, row = cellToGrid(cursorPos)
    col = math.max(0, math.min(2, col + dx))
    row = math.max(0, math.min(2, row + dy))
    cursorPos = row * 3 + col + 1
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if state == "select" then
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = 3 end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > 3 then selected = 1 end
        elseif p1.wasPressed("action") then
            numPlayers = selected - 1
            if numPlayers == 0 then
                state = "selectbatch"
                batchSelected = 1
            else
                initRound()
                assignTimer = 0
                state = "assign"
            end
        end
        return
    end

    if state == "selectbatch" then
        if p1.wasPressed("up") then
            batchSelected = batchSelected - 1
            if batchSelected < 1 then batchSelected = #batchOpts end
        elseif p1.wasPressed("down") then
            batchSelected = batchSelected + 1
            if batchSelected > #batchOpts then batchSelected = 1 end
        elseif p1.wasPressed("action") then
            batchTotal = batchOpts[batchSelected]
            batchPlayed = 0
            batchResults = { xWins = 0, oWins = 0, draws = 0 }
            falkenMsg = nil
            initRound()
            state = "play"
        end
        return
    end

    if state == "assign" then
        assignTimer = assignTimer + dt
        if assignTimer >= 2 then
            state = "play"
        end
        return
    end

    if state == "gameover" then
        gameOverTimer = gameOverTimer + dt
        if numPlayers == 0 and batchTotal then
            local goDelay = batchSpeed(batchTotal - batchPlayed, GAMEOVER_DELAY_NORMAL, GAMEOVER_DELAY_MIN)
            if gameOverTimer >= goDelay then
                if winner == X then batchResults.xWins = batchResults.xWins + 1
                elseif winner == O then batchResults.oWins = batchResults.oWins + 1
                else batchResults.draws = batchResults.draws + 1 end
                batchPlayed = batchPlayed + 1
                if batchPlayed >= batchTotal then
                    if batchTotal == 100 then
                        falkenMsg = "Professor Falken, the only winning move is not to play"
                    end
                    state = "batchresults"
                    gameOverTimer = 0
                    return
                end
                initRound()
                local gamesLeft = batchTotal - batchPlayed
                aiDelay = batchSpeed(gamesLeft, AI_DELAY_NORMAL, AI_DELAY_MIN)
                state = "play"
            end
            return
        end
        if gameOverTimer >= 3 then
            return "menu"
        end
        return
    end

    if state == "batchresults" then
        gameOverTimer = gameOverTimer + dt
        if gameOverTimer >= (falkenMsg and 8 or 5) then
            return "menu"
        end
        return
    end

    if isAI(currentPlayer) then
        aiTimer = aiTimer + dt
        if aiTimer >= aiDelay then
            local move = aiMove(board, currentPlayer)
            if move then
                board[move] = currentPlayer
                if checkGameEnd() then return end
                currentPlayer = currentPlayer == X and O or X
            end
            aiTimer = 0
        end
        return
    end

    local pi = currentPlayer == p1Mark and input.getPlayer(1) or input.getPlayer(2)

    if pi.wasPressed("up") then moveCursor(0, -1) end
    if pi.wasPressed("down") then moveCursor(0, 1) end
    if pi.wasPressed("left") then moveCursor(-1, 0) end
    if pi.wasPressed("right") then moveCursor(1, 0) end

    if pi.wasPressed("action") and board[cursorPos] == EMPTY then
        board[cursorPos] = currentPlayer
        if checkGameEnd() then return end
        currentPlayer = currentPlayer == X and O or X
        aiTimer = 0
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    if state == "select" then
        local cy = math.floor(height / 2) - 3
        term.setCursorPos(math.floor((width - 15) / 2) + 1, cy)
        term.setTextColor(colors.yellow)
        term.write("Choose players:")

        local opts = { "0 Players (AI)", "1 Player", "2 Players" }
        for i, opt in ipairs(opts) do
            term.setCursorPos(math.floor((width - #opt) / 2), cy + 1 + i)
            if i == selected then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. opt .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(opt)
            end
        end
        return
    end

    if state == "selectbatch" then
        local cy = math.floor(height / 2) - 3
        term.setCursorPos(math.floor((width - 18) / 2) + 1, cy)
        term.setTextColor(colors.yellow)
        term.write("How many games?")

        for i, count in ipairs(batchOpts) do
            local label = tostring(count) .. (count == 1 and " game" or " games")
            term.setCursorPos(math.floor((width - #label) / 2), cy + 1 + i)
            if i == batchSelected then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. label .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(label)
            end
        end
        return
    end

    if state == "assign" then
        local cy = math.floor(height / 2) - 2
        if numPlayers == 1 then
            local line1 = "You are " .. marks[p1Mark]
            local line2 = "AI is " .. marks[p2Mark]
            term.setCursorPos(math.floor((width - #line1) / 2) + 1, cy)
            term.setTextColor(markColors[p1Mark])
            term.write(line1)
            term.setCursorPos(math.floor((width - #line2) / 2) + 1, cy + 2)
            term.setTextColor(markColors[p2Mark])
            term.write(line2)
        elseif numPlayers == 2 then
            local line1 = "Player 1 is " .. marks[p1Mark]
            local line2 = "Player 2 is " .. marks[p2Mark]
            term.setCursorPos(math.floor((width - #line1) / 2) + 1, cy)
            term.setTextColor(markColors[p1Mark])
            term.write(line1)
            term.setCursorPos(math.floor((width - #line2) / 2) + 1, cy + 2)
            term.setTextColor(markColors[p2Mark])
            term.write(line2)
        end
        return
    end

    if state == "batchresults" then
        local cy = math.floor(height / 2) - 4
        term.setCursorPos(math.floor((width - 7) / 2) + 1, cy)
        term.setTextColor(colors.yellow)
        term.write("Results")

        local xLine = "X wins: " .. batchResults.xWins
        local oLine = "O wins: " .. batchResults.oWins
        local dLine = "Draws:  " .. batchResults.draws

        term.setCursorPos(math.floor((width - #xLine) / 2) + 1, cy + 2)
        term.setTextColor(markColors[X])
        term.write(xLine)
        term.setCursorPos(math.floor((width - #oLine) / 2) + 1, cy + 3)
        term.setTextColor(markColors[O])
        term.write(oLine)
        term.setCursorPos(math.floor((width - #dLine) / 2) + 1, cy + 4)
        term.setTextColor(colors.lightGray)
        term.write(dLine)

        if falkenMsg then
            term.setCursorPos(math.floor((width - #falkenMsg) / 2) + 1, cy + 7)
            term.setTextColor(colors.lime)
            term.write(falkenMsg)
        end
        return
    end

    local cellW = 5
    local cellH = 3
    local gridW = cellW * 3 + 2
    local gridH = cellH * 3 + 2
    local ox = math.floor((width - gridW) / 2) + 1
    local oy = math.floor((height - gridH) / 2) + 1

    local isWinCell = {}
    if winLine then
        for _, idx in ipairs(winLine) do
            isWinCell[idx] = true
        end
    end

    for row = 0, 2 do
        for col = 0, 2 do
            local idx = row * 3 + col + 1
            local cx = ox + col * (cellW + 1)
            local cy = oy + row * (cellH + 1)

            local bg = colors.black
            if state == "play" and not isAI(currentPlayer) and idx == cursorPos then
                bg = colors.gray
            end
            if isWinCell[idx] then
                bg = colors.green
            end

            for dy = 0, cellH - 1 do
                term.setCursorPos(cx, cy + dy)
                term.setBackgroundColor(bg)
                term.write(string.rep(" ", cellW))
            end

            if board[idx] ~= EMPTY then
                local mark = marks[board[idx]]
                local mx = cx + math.floor((cellW - 1) / 2)
                local my = cy + math.floor((cellH - 1) / 2)
                term.setCursorPos(mx, my)
                term.setBackgroundColor(bg)
                term.setTextColor(markColors[board[idx]])
                term.write(mark)
            end
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)

    for i = 1, 2 do
        local lx = ox + i * (cellW + 1) - 1
        for row = 0, gridH - 1 do
            term.setCursorPos(lx, oy + row)
            term.write("|")
        end
    end

    for i = 1, 2 do
        local ly = oy + i * (cellH + 1) - 1
        for col = 0, gridW - 1 do
            term.setCursorPos(ox + col, ly)
            term.write("-")
        end
    end

    term.setBackgroundColor(colors.black)
    term.setCursorPos(2, 1)
    term.setTextColor(markColors[X])
    term.write("X")
    term.setTextColor(colors.white)
    term.write(" vs ")
    term.setTextColor(markColors[O])
    term.write("O")

    if state == "play" then
        local turnMsg = marks[currentPlayer] .. "'s turn"
        if isAI(currentPlayer) then
            turnMsg = turnMsg .. " (AI)"
        end
        term.setCursorPos(width - #turnMsg, 1)
        term.setTextColor(markColors[currentPlayer])
        term.write(turnMsg)

        if numPlayers == 0 and batchTotal and batchTotal > 1 then
            local countMsg = "Game " .. (batchPlayed + 1) .. "/" .. batchTotal
            term.setCursorPos(math.floor((width - #countMsg) / 2) + 1, 1)
            term.setTextColor(colors.lightGray)
            term.write(countMsg)
        end
    end

    if state == "gameover" then
        local msg
        if winner then
            msg = marks[winner] .. " wins!"
        else
            msg = "Draw!"
        end
        local mx = math.floor((width - #msg - 2) / 2) + 1
        local my = oy + gridH + 1
        if my > height then my = height end
        term.setCursorPos(mx, my)
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.write(" " .. msg .. " ")
        term.setBackgroundColor(colors.black)
    end
end

function game.cleanup()
end

return game
