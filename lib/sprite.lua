local sprite = {}

local TRANSPARENT = "."

function sprite.load(filename)
    local path = "sprites/" .. filename
    if not fs.exists(path) then
        error("Sprite file not found: " .. path)
    end

    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()

    local def = {
        states = {},
        stateOrder = {},
        widths = {},
        heights = {},
        frameCounts = {},
    }

    local currentState = nil
    local currentFrame = {}
    local frames = {}

    local function finishFrame()
        if #currentFrame > 0 then
            table.insert(frames, currentFrame)
            currentFrame = {}
        end
    end

    local function finishState()
        finishFrame()
        if currentState and #frames > 0 then
            def.states[currentState] = frames
            table.insert(def.stateOrder, currentState)
        end
        frames = {}
        currentState = nil
    end

    for line in content:gmatch("[^\n]*") do
        local stateName = line:match("^@state%s+(.+)")
        if line == "---" then
            finishFrame()
        elseif line:match("^%-%-") then
        elseif stateName then
            finishState()
            currentState = stateName:match("^%s*(.-)%s*$")
        elseif currentState and line ~= "" then
            table.insert(currentFrame, line)
        end
    end
    finishState()

    for name, frames in pairs(def.states) do
        local maxW, maxH = 0, 0
        for _, frame in ipairs(frames) do
            if #frame > maxH then maxH = #frame end
            for _, line in ipairs(frame) do
                if #line > maxW then maxW = #line end
            end
        end
        def.widths[name] = maxW
        def.heights[name] = maxH
        def.frameCounts[name] = #frames
    end

    return def
end

function sprite.draw(def, x, y, stateName, frameNum, color)
    local state = def.states[stateName]
    if not state then return end

    local frame = state[((frameNum - 1) % #state) + 1]
    if not frame then return end

    if color then
        term.setTextColor(color)
    end

    for row, line in ipairs(frame) do
        local drawY = y + row - 1
        local runStart = nil
        for col = 1, #line do
            local ch = line:sub(col, col)
            if ch ~= TRANSPARENT then
                if not runStart then runStart = col end
            else
                if runStart then
                    term.setCursorPos(x + runStart - 1, drawY)
                    term.write(line:sub(runStart, col - 1))
                    runStart = nil
                end
            end
        end
        if runStart then
            term.setCursorPos(x + runStart - 1, drawY)
            term.write(line:sub(runStart))
        end
    end
end

function sprite.getWidth(def, stateName)
    return def.widths[stateName] or 0
end

function sprite.getHeight(def, stateName)
    return def.heights[stateName] or 0
end

function sprite.getFrameCount(def, stateName)
    return def.frameCounts[stateName] or 0
end

function sprite.getStates(def)
    return def.stateOrder
end

return sprite
