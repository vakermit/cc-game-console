local channel = 123
local sides = {"top", "left", "right", "back"}
local state = {}
local computerID = os.getComputerID()

local function drawState(msg)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    term.setTextColor(colors.yellow)
    term.write("TRANSMITTER")
    term.setTextColor(colors.lightGray)
    print("  ID: " .. computerID .. "  CH: " .. channel)
    print("")

    local allSides = {"top", "left", "right", "back", "front", "bottom"}
    for _, side in ipairs(allSides) do
        local strength = redstone.getAnalogInput(side)
        local active = strength > 0
        local monitored = false
        for _, s in ipairs(sides) do
            if s == side then monitored = true break end
        end

        term.setTextColor(colors.lightGray)
        local pad = string.rep(" ", 7 - #side)
        term.write("  " .. pad .. side .. "  ")

        if active then
            term.setTextColor(colors.lime)
            term.write("[" .. string.rep("|", math.min(strength, 15)) .. string.rep(" ", 15 - strength) .. "]")
        else
            term.setTextColor(colors.gray)
            term.write("[               ]")
        end

        if not monitored then
            term.setTextColor(colors.gray)
            term.write("  --")
        end

        print("")
    end

    print("")
    term.setTextColor(colors.white)
    print("  > " .. msg)
end

local modem = peripheral.find("modem")
if not modem then
    drawState("ERROR: No modem attached")
    return
end

drawState("Opening modem on channel " .. channel .. "...")
modem.open(computerID)

for _, side in ipairs(sides) do
    state[side] = redstone.getAnalogInput(side)
end

drawState("Ready - waiting for input")

while true do
    os.pullEvent("redstone")

    local changed = false
    for _, side in ipairs(sides) do
        local strength = redstone.getAnalogInput(side)
        if strength ~= state[side] then
            changed = true
            local message = {
                side = side,
                strength = strength,
                computerID = computerID,
            }
            modem.transmit(channel, computerID, message)
            state[side] = strength
        end
    end

    if changed then
        drawState("Signal sent")
    end
end
