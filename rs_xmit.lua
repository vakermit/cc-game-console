-- Signal Transmitter Program
local debug = true
local channel = 123
local modem = peripheral.find("modem") or error("No modem attached", 0)
local computerID = os.getComputerID()
modem.open(computerID)

local sides = {"left", "right", "back", "top"}  -- 4 sides only, skipping front and bottom
local previousState = {}

-- Initialize previous state for each side
for _, side in ipairs(sides) do
    previousState[side] = redstone.getAnalogInput(side)
end

-- Main loop
while true do
    -- Wait for a redstone event
    os.pullEvent("redstone")

    for _, side in ipairs(sides) do
        local signalStrength = redstone.getAnalogInput(side)
        if signalStrength ~= previousState[side] then
            -- Send the side and signal strength to the master computer
            local message = {
                side = side,
                strength = signalStrength,
                computerID = computerID
            }
            modem.transmit(channel, computerID, message)
            if debug then
                print(textutils.serialize(message))
            end
            previousState[side] = signalStrength  -- Update the previous state
        end
    end
end