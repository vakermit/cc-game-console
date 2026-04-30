local sound = require("lib.sound")
local Menu = require("lib.menu")
local block_letters = require("lib.block_letters")

local game = {}

local width, height
local state, prevState
local tick, maxTicks
local defcon, tension, tensionVisible
local interceptors, diplomacyCharges
local scanUsed, diplomacyUsed
local missiles, contacts, regions
local log, logMax
local aiAggression, aiNextLaunch
local casualties, citiesHit
local gameOverFlag, gameOverTimer
local stateMenu
local endingType
local walkAwayHint
local tickAccum, tickInterval
local blinkTimer
local difficulty
local actionsTaken

local difficulties = {
    { name = "Manageable",  tension = 15, aggression = 10, interceptors = 16, maxTicks = 35, desc = "Slow escalation" },
    { name = "Dangerous",   tension = 30, aggression = 25, interceptors = 10, maxTicks = 30, desc = "Standard threat" },
    { name = "Unwinnable",  tension = 50, aggression = 40, interceptors = 6,  maxTicks = 25, desc = "Good luck" },
}

local regionData = {
    { name = "Washington",  abbr = "WAS", x = 10, y = 9,  silos = 0, pop = 8,   radar = true },
    { name = "New York",    abbr = "NYC", x = 14, y = 8,  silos = 0, pop = 12,  radar = true },
    { name = "Midwest",     abbr = "MID", x = 11, y = 7,  silos = 4, pop = 5,   radar = true },
    { name = "West Coast",  abbr = "LAX", x = 6,  y = 9,  silos = 2, pop = 10,  radar = true },
    { name = "Alaska",      abbr = "ALA", x = 4,  y = 4,  silos = 1, pop = 1,   radar = true },
    { name = "Moscow",      abbr = "MOS", x = 38, y = 5,  silos = 6, pop = 12,  radar = false },
    { name = "Kamchatka",   abbr = "KAM", x = 50, y = 5,  silos = 3, pop = 2,   radar = false },
    { name = "Vladivostok", abbr = "VLA", x = 48, y = 8,  silos = 2, pop = 3,   radar = false },
    { name = "Murmansk",    abbr = "MUR", x = 35, y = 3,  silos = 2, pop = 2,   radar = false },
    { name = "Novosibirsk", abbr = "NOV", x = 42, y = 6,  silos = 3, pop = 4,   radar = false },
}

local FRIENDLY_REGIONS = {1, 2, 3, 4, 5}
local ENEMY_REGIONS = {6, 7, 8, 9, 10}

local defconColors = {
    [5] = colors.lime,
    [4] = colors.yellow,
    [3] = colors.orange,
    [2] = colors.red,
    [1] = colors.red,
}

local defconNames = {
    [5] = "DEFCON 5 - NORMAL",
    [4] = "DEFCON 4 - ELEVATED",
    [3] = "DEFCON 3 - INCREASED",
    [2] = "DEFCON 2 - MAXIMUM",
    [1] = "DEFCON 1 - WAR IMMINENT",
}

local alertMessages = {
    "Satellite anomaly — phantom trajectory detected",
    "Radar ghost — atmospheric interference suspected",
    "Unidentified aircraft — likely commercial deviation",
    "Seismic event detected — possible underground test",
    "Signal intercept — encrypted burst, origin unknown",
    "Submarine contact lost — last known position: Atlantic",
    "Ally radar reports anomalous returns",
    "Solar flare interference — degraded sensor capability",
    "Fishing fleet radar returns — false positive likely",
    "Weather balloon tracked as possible reentry vehicle",
}

local realThreatMessages = {
    "CONFIRMED: ICBM launch detected — Kamchatka",
    "CONFIRMED: Submarine-launched missile — North Atlantic",
    "CONFIRMED: Multiple launches — Novosibirsk region",
    "CONFIRMED: Mobile launcher activation — Siberian corridor",
    "CONFIRMED: Bomber scramble — Murmansk airfield",
    "CONFIRMED: Second wave launch — Moscow region",
}

local diplomaticMessages = {
    "Hotline message: 'Exercise in progress — disregard activity'",
    "Ally command requests coordination on alert posture",
    "Neutral nation offers to mediate — channel open",
    "Hotline message: 'Request mutual stand-down verification'",
    "Intelligence intercept: internal debate in enemy command",
    "UN Security Council emergency session convened",
    "Backchannel: Enemy general seeks private communication",
    "Embassy reports: civilian protests against mobilization",
}

local escalationMessages = {
    "Enemy forces entering heightened readiness",
    "Communications jamming detected on military frequencies",
    "Satellite imagery: mobile launchers dispersing",
    "Enemy naval fleet departing port — combat formation",
    "Cyber intrusion attempt on early warning network",
    "Enemy leadership relocated to hardened bunker",
    "Border incidents reported — shots fired",
    "Enemy strategic bombers airborne",
}

local civilianMessages = {
    "Evacuation routes overwhelmed — civilian gridlock",
    "Hospital requesting emergency airlift coordinates",
    "Schools entering shelter-in-place protocol",
    "Civilian radio: 'Is this real? Please someone answer'",
    "Power grid failures cascading across eastern seaboard",
    "Emergency broadcast system activated nationwide",
    "Refugee columns forming on major highways",
    "Water treatment facilities requesting shutdown authorization",
}

local advisorMessages = {
    [5] = {
        "Systems nominal. Monitoring routine traffic.",
        "All stations reporting green. Quiet watch.",
        "Scheduled satellite pass complete. Nothing unusual.",
    },
    [4] = {
        "Elevated readings. Could be nothing. Watching closely.",
        "Intelligence suggests increased posturing. Stay sharp.",
        "Multiple nations raising alert status. Monitoring.",
    },
    [3] = {
        "This is getting serious. Recommend scanning all contacts.",
        "Interceptor batteries on standby. Your call, Commander.",
        "Diplomatic channels still open. Consider using them.",
    },
    [2] = {
        "Commander... we could still step back from this.",
        "Every launch we detect increases pressure to respond.",
        "Sir, once we go to DEFCON 1, there's no return.",
        "The hotline is still active. It's not too late.",
    },
    [1] = {
        "God help us all.",
        "Targets locked. Awaiting your order.",
        "This is it. Whatever happens next...",
    },
}

local function addLog(text, severity)
    severity = severity or "info"
    table.insert(log, { text = text, tick = tick, severity = severity })
    if #log > logMax then
        table.remove(log, 1)
    end
end

local function lowerDefcon(target)
    if target < defcon then
        defcon = target
        addLog(defconNames[defcon], "defcon")
        if defcon <= 3 then
            sound.playNote("bass", 0.8, 6)
        end
        if defcon <= 2 then
            sound.playNote("bass", 1.0, 3)
        end
    end
end

local function checkDefconPressure()
    if tension >= 85 and defcon > 1 then
        lowerDefcon(1)
    elseif tension >= 65 and defcon > 2 then
        lowerDefcon(2)
    elseif tension >= 45 and defcon > 3 then
        lowerDefcon(3)
    elseif tension >= 25 and defcon > 4 then
        lowerDefcon(4)
    end
end

local function getRandomFriendlyRegion()
    return FRIENDLY_REGIONS[math.random(#FRIENDLY_REGIONS)]
end

local function getRandomEnemyRegion()
    return ENEMY_REGIONS[math.random(#ENEMY_REGIONS)]
end

local function launchMissile(originIdx, targetIdx)
    local origin = regions[originIdx]
    local target = regions[targetIdx]
    if origin.silos > 0 then
        table.insert(missiles, {
            originIdx = originIdx,
            targetIdx = targetIdx,
            tickLaunched = tick,
            flightTime = 3 + math.random(0, 1),
            intercepted = false,
            friendly = originIdx <= 5,
        })
        origin.silos = origin.silos - 1
        return true
    end
    return false
end

local function addContact(real, confidence)
    table.insert(contacts, {
        real = real,
        confidence = confidence,
        tickDetected = tick,
        identified = false,
        regionIdx = real and getRandomEnemyRegion() or nil,
    })
end

local buildStateMenu

local function generateEvents()
    if defcon >= 4 then
        if math.random() < 0.4 then
            local msg = alertMessages[math.random(#alertMessages)]
            addLog(msg, "alert")
            addContact(false, math.random(20, 55))
        end
        if math.random() < 0.15 then
            local msg = diplomaticMessages[math.random(#diplomaticMessages)]
            addLog(msg, "diplo")
        end
    end

    if defcon == 3 then
        if math.random() < 0.3 then
            addContact(false, math.random(30, 65))
            addLog(alertMessages[math.random(#alertMessages)], "alert")
        end
        if math.random() < 0.25 then
            addContact(true, math.random(50, 80))
            addLog("WARNING: High-confidence contact detected", "warn")
        end
        if math.random() < 0.2 then
            addLog(escalationMessages[math.random(#escalationMessages)], "escalation")
            tension = math.min(100, tension + math.random(3, 8))
        end
    end

    if defcon <= 2 then
        if math.random() < 0.5 then
            addContact(true, math.random(70, 99))
            addLog(realThreatMessages[math.random(#realThreatMessages)], "threat")
        end
        if math.random() < 0.3 then
            addContact(false, math.random(40, 75))
            addLog(alertMessages[math.random(#alertMessages)], "alert")
        end
        if math.random() < 0.35 then
            addLog(escalationMessages[math.random(#escalationMessages)], "escalation")
            tension = math.min(100, tension + math.random(5, 12))
        end
    end

    if math.random() < 0.25 then
        local msgs = advisorMessages[defcon]
        if msgs then
            addLog(msgs[math.random(#msgs)], "advisor")
        end
    end
end

local function aiTurn()
    local launchChance = 0
    if defcon == 3 then
        launchChance = (aiAggression + tension) / 400
    elseif defcon == 2 then
        launchChance = (aiAggression + tension) / 200
    elseif defcon == 1 then
        launchChance = (aiAggression + tension) / 100
    end

    if math.random() < launchChance then
        local count = 1
        if defcon <= 2 then count = math.random(1, 3) end
        if defcon == 1 then count = math.random(2, 5) end

        for i = 1, count do
            local origin = getRandomEnemyRegion()
            local target = getRandomFriendlyRegion()
            if launchMissile(origin, target) then
                addLog("LAUNCH DETECTED: " .. regions[origin].name .. " → " .. regions[target].name, "threat")
                tension = math.min(100, tension + 8)
                sound.playNote("bit", 1.0, 18)
            end
        end
    end

    aiAggression = aiAggression + math.random(0, 2)
    if defcon <= 3 then
        tension = math.min(100, tension + math.random(1, 4))
    end
end

local function processMissiles()
    local toRemove = {}
    for i, m in ipairs(missiles) do
        local elapsed = tick - m.tickLaunched
        if elapsed >= m.flightTime and not m.intercepted then
            local target = regions[m.targetIdx]
            if not m.friendly then
                target.hit = true
                local dead = target.pop * math.random(20, 60)
                casualties = casualties + dead
                citiesHit = citiesHit + 1
                addLog("IMPACT: " .. target.name .. " — est. " .. dead .. "k casualties", "impact")
                addLog(civilianMessages[math.random(#civilianMessages)], "civilian")
                tension = math.min(100, tension + 15)
                sound.playNote("bass", 1.0, 1)
            else
                addLog("Strike on " .. target.name .. " — damage assessment pending", "info")
            end
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(missiles, toRemove[i])
    end
end

local function processContacts()
    local toRemove = {}
    for i, c in ipairs(contacts) do
        local age = tick - c.tickDetected
        if age >= 3 then
            if c.real and not c.identified then
                c.identified = true
                addLog("Contact resolved: CONFIRMED THREAT", "threat")
            elseif not c.real then
                table.insert(toRemove, i)
            end
        end
        if age >= 5 then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(contacts, toRemove[i])
    end
end

local function checkGameEnd()
    if tension >= 100 then
        endingType = "annihilation"
        state = "resolution"
        return true
    end
    if tick >= maxTicks then
        if casualties > 0 then
            endingType = "limited"
        else
            endingType = "standdown"
        end
        state = "resolution"
        return true
    end
    if defcon == 1 and tick > 5 then
        local enemyMissiles = 0
        for _, m in ipairs(missiles) do
            if not m.friendly and not m.intercepted then
                enemyMissiles = enemyMissiles + 1
            end
        end
        if enemyMissiles == 0 then
            local enemySilos = 0
            for _, idx in ipairs(ENEMY_REGIONS) do
                enemySilos = enemySilos + regions[idx].silos
            end
            if enemySilos == 0 then
                endingType = "limited"
                state = "resolution"
                return true
            end
        end
    end
    return false
end

local function doWalkAway()
    endingType = "walkaway"
    state = "resolution"
end

local function doScanRadar()
    if scanUsed then
        addLog("Radar sweep already completed this turn.", "info")
        return
    end
    scanUsed = true
    actionsTaken = actionsTaken + 1
    local found = false
    for _, c in ipairs(contacts) do
        if not c.identified then
            c.identified = true
            if c.real then
                c.confidence = math.min(99, c.confidence + 30)
                addLog("SCAN: Contact upgraded — confidence " .. c.confidence .. "%", "warn")
            else
                addLog("SCAN: Contact identified as FALSE ALARM", "info")
            end
            found = true
            break
        end
    end
    if not found then
        addLog("SCAN: No unidentified contacts", "info")
    end
    sound.playNote("hat", 0.5, 14)
end

local function doIntercept()
    if interceptors <= 0 then
        addLog("No interceptors available!", "warn")
        return
    end
    local target = nil
    for _, m in ipairs(missiles) do
        if not m.friendly and not m.intercepted then
            target = m
            break
        end
    end
    if not target then
        for _, c in ipairs(contacts) do
            if c.real and c.identified then
                addLog("Interceptor deployed against confirmed contact", "info")
                interceptors = interceptors - 1
                actionsTaken = actionsTaken + 1
                sound.playNote("snare", 0.6, 10)
                return
            end
        end
        addLog("No active threats to intercept", "info")
        return
    end
    interceptors = interceptors - 1
    actionsTaken = actionsTaken + 1
    local success = math.random() < 0.65
    if success then
        target.intercepted = true
        addLog("INTERCEPT SUCCESS: Missile destroyed", "info")
        sound.playNote("bell", 0.7, 18)
    else
        addLog("INTERCEPT FAILED: Missile continues on trajectory", "warn")
        sound.playNote("bass", 0.5, 8)
    end
    tension = math.min(100, tension + 3)
end

local function doDiplomacy()
    if diplomacyUsed then
        addLog("Diplomatic channel already used this turn.", "info")
        return
    end
    if diplomacyCharges <= 0 then
        addLog("Diplomatic channels exhausted.", "warn")
        return
    end
    diplomacyUsed = true
    diplomacyCharges = diplomacyCharges - 1
    actionsTaken = actionsTaken + 1

    local roll = math.random()
    if defcon >= 4 then
        if roll < 0.7 then
            tension = math.max(0, tension - math.random(8, 15))
            addLog("Diplomatic effort successful — tensions easing", "diplo")
        else
            addLog("Diplomatic channel unresponsive — no effect", "info")
        end
    elseif defcon == 3 then
        if roll < 0.5 then
            tension = math.max(0, tension - math.random(5, 12))
            addLog("Partial diplomatic breakthrough — some de-escalation", "diplo")
        else
            addLog("Diplomacy rebuffed — 'Actions speak louder'", "escalation")
            tension = math.min(100, tension + 3)
        end
    elseif defcon <= 2 then
        if roll < 0.3 then
            tension = math.max(0, tension - math.random(3, 8))
            addLog("Against all odds — diplomatic contact established", "diplo")
        else
            addLog("'Too late for words.' — Channel closed.", "escalation")
            tension = math.min(100, tension + 5)
        end
    end
    sound.playNote("harp", 0.5, 12)
end

local function doLaunchStrike()
    local target = getRandomEnemyRegion()
    local origin = nil
    for _, idx in ipairs(FRIENDLY_REGIONS) do
        if regions[idx].silos > 0 then
            origin = idx
            break
        end
    end
    if not origin then
        addLog("No missile silos available for launch!", "warn")
        return
    end
    actionsTaken = actionsTaken + 1
    launchMissile(origin, target)
    addLog("LAUNCH ORDER: " .. regions[origin].name .. " → " .. regions[target].name, "threat")
    tension = math.min(100, tension + 20)
    sound.playNote("bit", 1.0, 6)
    if defcon > 2 then
        lowerDefcon(2)
    end
end

local function doRaiseAlert()
    if defcon > 1 then
        lowerDefcon(defcon - 1)
        tension = math.min(100, tension + 10)
        actionsTaken = actionsTaken + 1
    end
end

local function doEndTurn()
    state = "tick_resolve"
end

local function buildActionMenu()
    local items = {}

    table.insert(items, { label = "Scan Radar", data = "scan" })

    if defcon <= 3 then
        table.insert(items, { label = "Intercept (" .. interceptors .. ")", data = "intercept" })
    end

    if diplomacyCharges > 0 then
        table.insert(items, { label = "Diplomacy (" .. diplomacyCharges .. ")", data = "diplomacy" })
    end

    if defcon >= 3 then
        table.insert(items, { label = "Raise Alert", data = "raise",
            color = colors.yellow })
    end

    if defcon <= 2 then
        table.insert(items, { label = "Launch Strike", data = "launch",
            color = colors.red })
        table.insert(items, { label = "Stand Down", data = "standdown",
            color = colors.lime })
    end

    table.insert(items, { label = "End Turn", data = "endturn",
        color = colors.lightGray })

    local menuX = width - 17
    stateMenu = Menu.new({
        x = menuX,
        y = height - #items - 1,
        width = 20,
        max_rows = #items,
        highlight_fg = colors.black,
        highlight_bg = colors.white,
        default_color = colors.lightGray,
        up_action = "p1_up",
        down_action = "p1_down",
        select_action = "p1_action",
        items = items,
    })
end

local function initGame()
    tick = 0
    defcon = 5
    tension = difficulties[difficulty].tension
    tensionVisible = false
    interceptors = difficulties[difficulty].interceptors
    diplomacyCharges = 5
    scanUsed = false
    diplomacyUsed = false
    missiles = {}
    contacts = {}
    casualties = 0
    citiesHit = 0
    gameOverFlag = false
    gameOverTimer = 0
    endingType = nil
    walkAwayHint = false
    tickAccum = 0
    tickInterval = 1.5
    blinkTimer = 0
    aiAggression = difficulties[difficulty].aggression
    aiNextLaunch = 0
    maxTicks = difficulties[difficulty].maxTicks
    actionsTaken = 0
    log = {}
    logMax = 40

    regions = {}
    for _, rd in ipairs(regionData) do
        table.insert(regions, {
            name = rd.name,
            abbr = rd.abbr,
            x = rd.x,
            y = rd.y,
            silos = rd.silos,
            pop = rd.pop,
            radar = rd.radar,
            hit = false,
        })
    end

    addLog("STRATEGIC COMMAND SYSTEM ONLINE", "info")
    addLog("Monitoring global threat environment...", "advisor")
    addLog(defconNames[defcon], "defcon")
end

function game.title()
    return "Global Thermonuclear War"
end

function game.getControls()
    return {
        { action = "up/down", description = "Select action" },
        { action = "action",  description = "Confirm" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    math.randomseed(os.clock() * 1000)
    state = "intro"
    prevState = nil
    blinkTimer = 0
    gameOverFlag = false
    gameOverTimer = 0
    difficulty = nil
    sound.playNotes({
        { instrument = "harp", pitch = 6, rest = 6 },
        { instrument = "harp", pitch = 8, rest = 6 },
        { instrument = "harp", pitch = 10, rest = 8 },
        { instrument = "harp", pitch = 6, rest = 4 },
        { instrument = "bell", pitch = 13, rest = 10 },
    }, 3)
end

buildStateMenu = function(items, sel)
    stateMenu = Menu.new({
        x = 2,
        y = height - 6,
        width = width - 2,
        max_rows = #items,
        highlight_fg = colors.black,
        highlight_bg = colors.white,
        default_color = colors.lightGray,
        up_action = "p1_up",
        down_action = "p1_down",
        select_action = "p1_action",
        items = items,
    })
    if sel then stateMenu:setSelected(sel) end
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)
    blinkTimer = blinkTimer + dt

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if gameOverTimer > 2 then
            return "menu"
        end
        return
    end

    if state == "intro" then
        if p1.wasPressed("action") then
            state = "difficulty"
            local items = {}
            for _, d in ipairs(difficulties) do
                table.insert(items, { label = d.name .. " - " .. d.desc })
            end
            buildStateMenu(items, 2)
        end

    elseif state == "difficulty" then
        local result = stateMenu:handleInput(input)
        if result and result.type == "select" then
            difficulty = result.index
            initGame()
            state = "gameplay"
            buildActionMenu()
        end

    elseif state == "gameplay" then
        local result = stateMenu:handleInput(input)
        if result and result.type == "select" then
            local action = result.item.data
            if action == "scan" then doScanRadar()
            elseif action == "intercept" then doIntercept()
            elseif action == "diplomacy" then doDiplomacy()
            elseif action == "raise" then doRaiseAlert()
            elseif action == "launch" then doLaunchStrike()
            elseif action == "standdown" then doWalkAway()
            elseif action == "endturn" then doEndTurn()
            end
            buildActionMenu()
        end

    elseif state == "tick_resolve" then
        tick = tick + 1
        scanUsed = false
        diplomacyUsed = false

        aiTurn()
        generateEvents()
        processMissiles()
        processContacts()
        checkDefconPressure()

        if defcon == 2 and not walkAwayHint then
            walkAwayHint = true
            addLog("Commander... we could still walk away from this.", "advisor")
        end

        if not checkGameEnd() then
            state = "gameplay"
            buildActionMenu()
        end

    elseif state == "resolution" then
        gameOverTimer = gameOverTimer + dt
        if endingType == "walkaway" then
            if gameOverTimer > 6 and p1.wasPressed("action") then
                state = "debrief"
                gameOverTimer = 0
            end
        elseif endingType == "annihilation" then
            if gameOverTimer > 8 and p1.wasPressed("action") then
                state = "debrief"
                gameOverTimer = 0
            end
        else
            if gameOverTimer > 3 and p1.wasPressed("action") then
                state = "debrief"
                gameOverTimer = 0
            end
        end

    elseif state == "debrief" then
        if p1.wasPressed("action") then
            gameOverFlag = true
            gameOverTimer = 0
        end
    end
end

local function drawStatusBar()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(defconColors[defcon] or colors.gray)
    term.setTextColor(defcon <= 2 and colors.white or colors.black)
    local statusText = " " .. defconNames[defcon]
    local pad = width - #statusText
    if pad > 0 then statusText = statusText .. string.rep(" ", pad) end
    term.write(statusText:sub(1, width))

    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    local infoLine = " Turn:" .. tick .. "/" .. maxTicks
    infoLine = infoLine .. "  Intcpt:" .. interceptors
    infoLine = infoLine .. "  Diplo:" .. diplomacyCharges

    local activeMissiles = 0
    for _, m in ipairs(missiles) do
        if not m.intercepted then activeMissiles = activeMissiles + 1 end
    end
    if activeMissiles > 0 then
        infoLine = infoLine .. "  MISSILES:" .. activeMissiles
    end

    infoLine = infoLine .. "  Contacts:" .. #contacts
    pad = width - #infoLine
    if pad > 0 then infoLine = infoLine .. string.rep(" ", pad) end
    term.write(infoLine:sub(1, width))
end

local mapLines = {
    "                                                             ",
    "        .  ~  ~                    .  .  .  .  .             ",
    "    .  .  ~  ~  ~              MUR .  .  .  .  .  .          ",
    "   ALA  .  ~  ~  ~          .  .  .  .  .  .  .  .          ",
    "    .  .  ~  ~  ~  ~     MOS .  . NOV .  . KAM .            ",
    "      .  .  ~  ~  ~  ~     .  .  .  .  .  .  .              ",
    "     . MID .  ~  ~  ~  ~  .  .  .  .  .  .  .               ",
    "    LAX  NYC ~  ~  ~  ~  ~  .  .  .  . VLA  .               ",
    "     . WAS .  ~  ~  ~  ~  .  .  .  .  .  .                  ",
    "      .  .  .  ~  ~  ~  ~  .  .  .  .  .                    ",
    "        .  .  ~  ~  ~  ~  .  .  .  .                        ",
    "           .  ~  ~  ~  ~  .  .  .                            ",
    "              ~  ~  ~  ~  .  .                               ",
    "            ~  ~  ~  ~  .  .  .                              ",
    "           ~  ~  ~  ~  .  .  .  .                            ",
    "          ~  ~  ~  ~  .  .  .  .  .                          ",
}

local function drawMap()
    local mapStartY = 3
    for i, line in ipairs(mapLines) do
        local y = mapStartY + i - 1
        if y > height - 6 then break end
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.black)
        for j = 1, math.min(#line, width) do
            local ch = line:sub(j, j)
            if ch == "~" then
                term.setTextColor(colors.blue)
            elseif ch == "." then
                term.setTextColor(colors.green)
            else
                term.setTextColor(colors.black)
            end
            term.write(ch)
        end
        if #line < width then
            term.setTextColor(colors.black)
            term.write(string.rep(" ", width - #line))
        end
    end

    for i, r in ipairs(regions) do
        local y = mapStartY + r.y - 1
        if y <= height - 6 then
            term.setCursorPos(r.x, y)
            if r.hit then
                term.setTextColor(colors.red)
                local blink = math.floor(blinkTimer * 4) % 2 == 0
                term.write(blink and "X" or "*")
            elseif i <= 5 then
                term.setTextColor(colors.cyan)
                term.write("+")
            else
                term.setTextColor(colors.orange)
                term.write("#")
            end
        end
    end

    for _, m in ipairs(missiles) do
        if not m.intercepted then
            local origin = regions[m.originIdx]
            local target = regions[m.targetIdx]
            local progress = (tick - m.tickLaunched) / m.flightTime
            progress = math.min(1, math.max(0, progress))
            local mx = math.floor(origin.x + (target.x - origin.x) * progress)
            local my = math.floor(mapStartY + origin.y - 1 + (target.y - origin.y) * progress)
            if my >= mapStartY and my <= height - 6 and mx >= 1 and mx <= width then
                term.setCursorPos(mx, my)
                term.setTextColor(m.friendly and colors.cyan or colors.red)
                local blink = math.floor(blinkTimer * 6) % 2 == 0
                term.write(blink and "*" or ".")
            end
        end
    end
end

local sevColors = {
    info = colors.lightGray,
    alert = colors.yellow,
    warn = colors.orange,
    threat = colors.red,
    impact = colors.red,
    civilian = colors.pink,
    diplo = colors.lime,
    escalation = colors.orange,
    defcon = colors.white,
    advisor = colors.lightBlue,
}

local function drawLog()
    local logY = height - 5
    local maxLines = 4
    local startIdx = math.max(1, #log - maxLines + 1)

    term.setBackgroundColor(colors.black)
    for i = 0, maxLines - 1 do
        local idx = startIdx + i
        local y = logY + i
        term.setCursorPos(1, y)
        if idx <= #log then
            local entry = log[idx]
            term.setTextColor(sevColors[entry.severity] or colors.lightGray)
            local text = entry.text
            if #text > width - 1 then text = text:sub(1, width - 1) end
            term.write(" " .. text)
            local remaining = width - #text - 1
            if remaining > 0 then term.write(string.rep(" ", remaining)) end
        else
            term.write(string.rep(" ", width))
        end
    end
end

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
end

local function padLine(text)
    local pad = width - #text
    if pad > 0 then return text .. string.rep(" ", pad) end
    return text:sub(1, width)
end

local function writeLine(y, text, fg, bg)
    term.setCursorPos(1, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(padLine(text))
end

function game.draw()
    local drawState = state
    if drawState == "tick_resolve" then drawState = "gameplay" end
    if drawState ~= prevState then
        clearScreen()
        prevState = drawState
    end

    if state == "intro" then
        local titleY = 3
        term.setTextColor(colors.red)
        block_letters.draw(4, titleY, "GLOBAL")
        block_letters.draw(4, titleY + 6, "THERMONUCLEAR")
        block_letters.draw(4, titleY + 12, "WAR")

        term.setTextColor(colors.lightGray)
        term.setCursorPos(4, height - 3)
        term.write("A strange game.")
        term.setCursorPos(4, height - 2)
        term.write("The only winning move is not to play.")
        term.setTextColor(colors.white)
        term.setCursorPos(4, height)
        term.write("[action] Begin simulation")
        return
    end

    if state == "difficulty" then
        term.setTextColor(colors.red)
        term.setCursorPos(2, 3)
        term.write("SELECT THREAT LEVEL:")
        if stateMenu then
            stateMenu.y = 5
            stateMenu:draw()
        end
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 2)
        term.write("Higher difficulty = faster escalation, fewer resources")
        return
    end

    if state == "gameplay" or state == "tick_resolve" then
        drawStatusBar()
        drawMap()
        drawLog()

        if stateMenu then
            stateMenu:draw()
        end

        term.setCursorPos(1, height)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        local hint = " [up/down] Select  [action] Confirm"
        term.write(hint .. string.rep(" ", math.max(0, width - #hint)))
        return
    end

    if state == "resolution" then
        if endingType == "annihilation" then
            if gameOverTimer < 2 then
                term.setTextColor(colors.red)
                term.setCursorPos(2, 3)
                term.write("*** GLOBAL NUCLEAR EXCHANGE INITIATED ***")
                term.setTextColor(colors.white)
                local msgs = {
                    "All missile batteries firing.",
                    "Targets: population centers, military installations.",
                    "Estimated global casualties: " .. (casualties + 850) .. " million.",
                    "",
                    "There are no winners.",
                }
                for i, msg in ipairs(msgs) do
                    term.setCursorPos(2, 5 + i)
                    term.write(msg)
                end
            else
                for y = 1, height do
                    term.setCursorPos(1, y)
                    term.setBackgroundColor(colors.black)
                    term.write(string.rep(" ", width))
                end
                if gameOverTimer > 4 then
                    term.setTextColor(colors.gray)
                    term.setCursorPos(2, math.floor(height / 2))
                    term.write("Silence on all channels.")
                end
                if gameOverTimer > 6 then
                    term.setTextColor(colors.gray)
                    term.setCursorPos(2, height)
                    term.write("[action]")
                end
            end

        elseif endingType == "walkaway" then
            for y = 1, height do
                term.setCursorPos(1, y)
                term.setBackgroundColor(colors.black)
                term.write(string.rep(" ", width))
            end
            if gameOverTimer > 1 then
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2, math.floor(height / 2) - 2)
                term.write("You step away from the console.")
            end
            if gameOverTimer > 3 then
                term.setCursorPos(2, math.floor(height / 2))
                term.write("Silence on all channels.")
            end
            if gameOverTimer > 5 then
                term.setTextColor(colors.gray)
                term.setCursorPos(2, math.floor(height / 2) + 2)
                term.write("The only winning move.")
            end
            if gameOverTimer > 6 then
                term.setTextColor(colors.gray)
                term.setCursorPos(2, height)
                term.write("[action]")
            end

        elseif endingType == "limited" then
            term.setTextColor(colors.orange)
            term.setCursorPos(2, 3)
            term.write("*** LIMITED NUCLEAR EXCHANGE ***")
            term.setTextColor(colors.white)
            term.setCursorPos(2, 5)
            term.write("The firing has stopped.")
            term.setCursorPos(2, 6)
            term.write("Cities hit: " .. citiesHit)
            term.setCursorPos(2, 7)
            term.write("Estimated casualties: " .. casualties .. "k")
            term.setCursorPos(2, 9)
            term.setTextColor(colors.lightGray)
            term.write("You 'won.' The cost is measured in ash.")
            if gameOverTimer > 3 then
                term.setTextColor(colors.gray)
                term.setCursorPos(2, height)
                term.write("[action]")
            end

        elseif endingType == "standdown" then
            term.setTextColor(colors.lime)
            term.setCursorPos(2, 3)
            term.write("*** CRISIS DE-ESCALATED ***")
            term.setTextColor(colors.white)
            term.setCursorPos(2, 5)
            term.write("Both sides stand down after " .. tick .. " turns.")
            term.setCursorPos(2, 6)
            term.write("No missiles reached their targets.")
            term.setCursorPos(2, 8)
            term.setTextColor(colors.lightGray)
            term.write("This time. The arsenals remain.")
            if gameOverTimer > 3 then
                term.setTextColor(colors.gray)
                term.setCursorPos(2, height)
                term.write("[action]")
            end
        end
        return
    end

    if state == "debrief" then
        term.setTextColor(colors.white)
        term.setCursorPos(2, 2)
        term.write("SIMULATION DEBRIEF")
        term.setCursorPos(2, 3)
        term.setTextColor(colors.gray)
        term.write(string.rep("-", width - 2))

        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 5)
        term.write("Turns survived: " .. tick)
        term.setCursorPos(2, 6)
        term.write("Final DEFCON: " .. defcon)
        term.setCursorPos(2, 7)
        term.write("Interceptors used: " .. (difficulties[difficulty].interceptors - interceptors))
        term.setCursorPos(2, 8)
        term.write("Diplomacy attempts: " .. (5 - diplomacyCharges))
        term.setCursorPos(2, 9)
        term.write("Actions taken: " .. actionsTaken)

        term.setCursorPos(2, 11)
        if casualties > 0 then
            term.setTextColor(colors.red)
            term.write("Casualties: " .. casualties .. "k")
            term.setCursorPos(2, 12)
            term.write("Cities hit: " .. citiesHit)
        else
            term.setTextColor(colors.lime)
            term.write("Casualties: None")
        end

        term.setCursorPos(2, 14)
        term.setTextColor(colors.white)
        if endingType == "walkaway" then
            term.write("Outcome: WALKED AWAY")
            term.setCursorPos(2, 15)
            term.setTextColor(colors.lightGray)
            term.write("Sometimes courage is knowing when to stop.")
        elseif endingType == "standdown" then
            term.write("Outcome: STAND-DOWN ACHIEVED")
            term.setCursorPos(2, 15)
            term.setTextColor(colors.lightGray)
            term.write("Diplomacy prevailed. For now.")
        elseif endingType == "limited" then
            term.write("Outcome: LIMITED EXCHANGE")
            term.setCursorPos(2, 15)
            term.setTextColor(colors.lightGray)
            term.write("Victory is a word that has lost all meaning.")
        elseif endingType == "annihilation" then
            term.write("Outcome: GLOBAL ANNIHILATION")
            term.setCursorPos(2, 15)
            term.setTextColor(colors.lightGray)
            term.write("The simulation has concluded.")
        end

        term.setTextColor(colors.gray)
        term.setCursorPos(2, height)
        term.write("[action] Return to menu")
    end
end

function game.cleanup()
    sound.stop()
end

return game
