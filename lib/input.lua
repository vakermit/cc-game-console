local input = {}

local held = {}
local prev = {}
local pressed = {}
local released = {}
local playerCache = {}

local function clearTable(t)
    for k in pairs(t) do t[k] = nil end
end

function input.init()
    clearTable(held)
    clearTable(prev)
    clearTable(pressed)
    clearTable(released)
    clearTable(playerCache)
end

function input.set(action, value)
    held[action] = value
end

function input.tick()
    clearTable(pressed)
    clearTable(released)
    for action, v in pairs(held) do
        if v and not prev[action] then
            pressed[action] = true
        end
    end
    for action, v in pairs(prev) do
        if v and not held[action] then
            released[action] = true
        end
    end
    clearTable(prev)
    for k, v in pairs(held) do
        prev[k] = v
    end
end

function input.isDown(action)
    return held[action] == true
end

function input.wasPressed(action)
    return pressed[action] == true
end

function input.wasReleased(action)
    return released[action] == true
end

function input.anyPressed()
    return next(pressed) ~= nil
end

function input.getPlayer(playerNum)
    if playerCache[playerNum] then
        return playerCache[playerNum]
    end
    local prefix = "p" .. playerNum .. "_"
    local player = {
        isDown = function(action)
            return input.isDown(prefix .. action)
        end,
        wasPressed = function(action)
            return input.wasPressed(prefix .. action)
        end,
        wasReleased = function(action)
            return input.wasReleased(prefix .. action)
        end,
    }
    playerCache[playerNum] = player
    return player
end

return input
