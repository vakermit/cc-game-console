local sound = require("lib.sound")

local game = {}

local width, height
local selected
local lastPlayed

local instruments = {
    "harp", "basedrum", "snare", "hat", "bass",
    "flute", "bell", "guitar", "chime", "xylophone",
    "iron_xylophone", "cow_bell", "didgeridoo", "bit", "banjo", "pling",
}

local mcSounds = {
    { name = "entity.experience_orb.pickup", label = "XP Orb" },
    { name = "entity.player.levelup",        label = "Level Up" },
    { name = "block.note_block.harp",        label = "Note Block" },
    { name = "entity.arrow.hit_player",      label = "Arrow Hit" },
    { name = "block.anvil.land",             label = "Anvil" },
    { name = "entity.lightning_bolt.thunder", label = "Thunder" },
    { name = "entity.ender_dragon.growl",    label = "Dragon Growl" },
    { name = "entity.wither.spawn",          label = "Wither Spawn" },
}

local melodies = {
    {
        label = "Scale Up",
        notes = {
            { pitch = 6 }, { pitch = 8 }, { pitch = 10 }, { pitch = 11 },
            { pitch = 13 }, { pitch = 15 }, { pitch = 17 }, { pitch = 18 },
        },
    },
    {
        label = "Fanfare",
        notes = {
            { pitch = 12, rest = 2 }, { pitch = 12, rest = 2 },
            { pitch = 12, rest = 3 }, { pitch = 16, rest = 2 },
            { pitch = 14, rest = 2 }, { pitch = 16, rest = 3 },
            { pitch = 19, rest = 6 },
        },
    },
    {
        label = "Alert",
        notes = {
            { instrument = "bit", pitch = 20, rest = 2 },
            { instrument = "bit", pitch = 16, rest = 2 },
            { instrument = "bit", pitch = 20, rest = 2 },
            { instrument = "bit", pitch = 16, rest = 4 },
        },
    },
    {
        label = "Game Over",
        fn = function() sound.gameOver() end,
    },
    {
        label = "Victory",
        fn = function() sound.victory() end,
    },
}

local dfpwmFiles = {}

local function discoverFiles()
    dfpwmFiles = {}
    if not fs.exists("sounds") or not fs.isDir("sounds") then return end
    local files = fs.list("sounds")
    for _, f in ipairs(files) do
        if f:sub(-6) == ".dfpwm" then
            table.insert(dfpwmFiles, f)
        end
    end
    table.sort(dfpwmFiles)
end

local sections = { "instruments", "sounds", "melodies", "files" }
local sectionNames = { "Instruments", "MC Sounds", "Melodies", "Files" }
local currentSection
local sectionSel
local pitch

function game.title()
    return "Audio Test"
end

function game.getControls()
    return {
        { action = "up/down",    description = "Select item" },
        { action = "left/right", description = "Pitch" },
        { action = "action",     description = "Play" },
        { action = "alt",        description = "Next section" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    currentSection = 1
    sectionSel = 1
    pitch = 12
    lastPlayed = ""
    selected = 1
    discoverFiles()
end

local function itemCount()
    if currentSection == 1 then return #instruments
    elseif currentSection == 2 then return #mcSounds
    elseif currentSection == 3 then return #melodies
    else return math.max(1, #dfpwmFiles) end
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if p1.wasPressed("up") then
        sectionSel = sectionSel - 1
        if sectionSel < 1 then sectionSel = itemCount() end
        sound.menuBeep()
    elseif p1.wasPressed("down") then
        sectionSel = sectionSel + 1
        if sectionSel > itemCount() then sectionSel = 1 end
        sound.menuBeep()
    end

    if p1.wasPressed("alt") then
        currentSection = currentSection + 1
        if currentSection > #sections then currentSection = 1 end
        sectionSel = 1
        sound.menuBeep()
    end

    if p1.wasPressed("left") then
        pitch = math.max(0, pitch - 1)
    elseif p1.wasPressed("right") then
        pitch = math.min(24, pitch + 1)
    end

    if p1.wasPressed("action") then
        sound.stop()
        if currentSection == 1 then
            local inst = instruments[sectionSel]
            sound.playNote(inst, 1.0, pitch)
            lastPlayed = inst .. " @ pitch " .. pitch
        elseif currentSection == 2 then
            local s = mcSounds[sectionSel]
            sound.playSound(s.name, 1.0, 1.0)
            lastPlayed = s.label
        elseif currentSection == 3 then
            local m = melodies[sectionSel]
            if m.fn then
                m.fn()
            else
                sound.playNotes(m.notes)
            end
            lastPlayed = m.label
        else
            if #dfpwmFiles > 0 then
                local f = dfpwmFiles[sectionSel]
                sound.playFile(f, 1.0)
                lastPlayed = f
            else
                lastPlayed = "No .dfpwm files in sounds/"
            end
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorPos(2, 1)
    term.setTextColor(colors.yellow)
    term.write("AUDIO TEST")

    term.setTextColor(colors.lightGray)
    term.setCursorPos(14, 1)
    term.write("Speaker: ")
    if sound.hasSpeaker() then
        term.setTextColor(colors.lime)
        term.write("YES")
    else
        term.setTextColor(colors.red)
        term.write("NO")
    end

    term.setCursorPos(28, 1)
    term.setTextColor(colors.lightGray)
    term.write("Sound: ")
    if sound.isEnabled() then
        term.setTextColor(colors.lime)
        term.write("ON")
    else
        term.setTextColor(colors.red)
        term.write("OFF")
    end

    for i, name in ipairs(sectionNames) do
        local sx = 2 + (i - 1) * 14
        term.setCursorPos(sx, 3)
        if i == currentSection then
            term.setTextColor(colors.white)
            term.write("[" .. name .. "]")
        else
            term.setTextColor(colors.gray)
            term.write(" " .. name)
        end
    end

    if currentSection == 1 then
        term.setCursorPos(2, 4)
        term.setTextColor(colors.lightGray)
        term.write("Pitch: " .. pitch .. " [<>]")

        for i, inst in ipairs(instruments) do
            local y = 5 + i
            if y > height - 2 then break end
            term.setCursorPos(4, y)
            if i == sectionSel then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. inst .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(inst)
            end
        end
    elseif currentSection == 2 then
        for i, s in ipairs(mcSounds) do
            local y = 4 + i
            if y > height - 2 then break end
            term.setCursorPos(4, y)
            if i == sectionSel then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. s.label .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(s.label)
            end
        end
    elseif currentSection == 3 then
        for i, m in ipairs(melodies) do
            local y = 4 + i
            if y > height - 2 then break end
            term.setCursorPos(4, y)
            if i == sectionSel then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. m.label .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(m.label)
            end
        end
    else
        if #dfpwmFiles == 0 then
            term.setCursorPos(4, 5)
            term.setTextColor(colors.gray)
            term.write("No .dfpwm files in sounds/")
        else
            for i, f in ipairs(dfpwmFiles) do
                local y = 4 + i
                if y > height - 2 then break end
                term.setCursorPos(4, y)
                if i == sectionSel then
                    term.setBackgroundColor(colors.gray)
                    term.setTextColor(colors.white)
                    term.write(" " .. f .. " ")
                    term.setBackgroundColor(colors.black)
                else
                    term.setTextColor(colors.lightGray)
                    term.write(f)
                end
            end
        end
    end

    term.setCursorPos(2, height)
    term.setTextColor(colors.lightGray)
    term.write("Last: ")
    term.setTextColor(colors.white)
    term.write(lastPlayed)
end

function game.cleanup()
    sound.stop()
end

return game
