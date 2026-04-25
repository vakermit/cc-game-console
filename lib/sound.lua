local config = require("config")
local sound = {}

local speaker = nil
local enabled = true
local queue = {}

function sound.init()
    speaker = peripheral.find("speaker")
    enabled = config.sound.enabled
    queue = {}
end

function sound.setEnabled(val)
    enabled = val
    if not enabled and speaker then
        speaker.stop()
    end
end

function sound.isEnabled()
    return enabled
end

function sound.hasSpeaker()
    return speaker ~= nil
end

function sound.playFile(filename, volume)
    if not enabled or not speaker then return end
    local path = "sounds/" .. filename
    if not fs.exists(path) then return end
    table.insert(queue, { type = "file", path = path, volume = volume or 1.0 })
end

function sound.playNote(instrument, volume, pitch)
    if not enabled or not speaker then return end
    table.insert(queue, { type = "note", instrument = instrument, volume = volume or 1.0, pitch = pitch or 12 })
end

function sound.playSound(name, volume, pitch)
    if not enabled or not speaker then return end
    table.insert(queue, { type = "sound", name = name, volume = volume or 1.0, pitch = pitch or 1.0 })
end

function sound.playNotes(notes, tempo)
    if not enabled or not speaker then return end
    tempo = tempo or 4
    for _, n in ipairs(notes) do
        table.insert(queue, {
            type = "note",
            instrument = n.instrument or "harp",
            volume = n.volume or 1.0,
            pitch = n.pitch or 12,
        })
        if n.rest then
            table.insert(queue, { type = "rest", ticks = n.rest })
        else
            table.insert(queue, { type = "rest", ticks = tempo })
        end
    end
end

function sound.stop()
    queue = {}
    if speaker then speaker.stop() end
end

function sound.menuBeep()
    sound.playNote("hat", 0.5, 12)
end

function sound.menuSelect()
    sound.playNote("harp", 0.8, 18)
    table.insert(queue, { type = "rest", ticks = 1 })
    sound.playNote("harp", 0.8, 22)
end

function sound.gameOver()
    sound.playNotes({
        { instrument = "harp", pitch = 18, rest = 3 },
        { instrument = "harp", pitch = 15, rest = 3 },
        { instrument = "harp", pitch = 12, rest = 3 },
        { instrument = "bass", pitch = 6, rest = 6 },
    })
end

function sound.victory()
    sound.playNotes({
        { instrument = "harp", pitch = 12, rest = 2 },
        { instrument = "harp", pitch = 16, rest = 2 },
        { instrument = "harp", pitch = 19, rest = 2 },
        { instrument = "harp", pitch = 24, rest = 4 },
        { instrument = "bell", pitch = 24, rest = 6 },
    })
end

local function playDFPWM(path, volume)
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()
    for chunk in io.lines(path, 16 * 1024) do
        if not enabled then break end
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer, volume) do
            os.pullEvent("speaker_audio_empty")
            if not enabled then
                speaker.stop()
                return
            end
        end
    end
end

function sound.listener()
    while true do
        if #queue > 0 and speaker and enabled then
            local item = table.remove(queue, 1)
            if item.type == "note" then
                speaker.playNote(item.instrument, item.volume, item.pitch)
                os.sleep(0.05)
            elseif item.type == "sound" then
                speaker.playSound(item.name, item.volume, item.pitch)
                os.sleep(0.1)
            elseif item.type == "rest" then
                os.sleep(item.ticks * 0.05)
            elseif item.type == "file" then
                playDFPWM(item.path, item.volume)
            end
        else
            os.sleep(0.05)
        end
    end
end

return sound
