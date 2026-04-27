local Menu = require("lib.menu")

local game = {}

local width, height
local galaxy, quadrant
local playerQX, playerQY, playerSX, playerSY
local energy, maxEnergy, shields, torpedoes, maxTorpedoes
local klingonsLeft, stardate, maxStardate
local mode, submode
local selected, cursorX, cursorY
local messageLines
local gameOverFlag, gameOverTimer
local cmdMenu
local damageReport

local SZ = 8

local function wrap(text, maxW)
    local lines = {}
    local line = ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > maxW then
            table.insert(lines, line)
            line = word
        else
            line = #line > 0 and (line .. " " .. word) or word
        end
    end
    if #line > 0 then table.insert(lines, line) end
    return lines
end

local function setMsg(text)
    messageLines = wrap(text, width - 2)
end

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function generateGalaxy()
    galaxy = {}
    klingonsLeft = 0
    for qy = 1, SZ do
        galaxy[qy] = {}
        for qx = 1, SZ do
            local k = 0
            local r = math.random()
            if r > 0.92 then k = 3
            elseif r > 0.8 then k = 2
            elseif r > 0.6 then k = 1 end
            local b = math.random() > 0.88 and 1 or 0
            local s = math.random(1, 6)
            klingonsLeft = klingonsLeft + k
            galaxy[qy][qx] = {
                klingons = k,
                bases = b,
                stars = s,
                scanned = false,
            }
        end
    end
    if klingonsLeft < 5 then
        for i = 1, 5 - klingonsLeft do
            local qy = math.random(1, SZ)
            local qx = math.random(1, SZ)
            galaxy[qy][qx].klingons = galaxy[qy][qx].klingons + 1
            klingonsLeft = klingonsLeft + 1
        end
    end
    local hasBase = false
    for qy = 1, SZ do
        for qx = 1, SZ do
            if galaxy[qy][qx].bases > 0 then hasBase = true end
        end
    end
    if not hasBase then
        galaxy[math.random(1, SZ)][math.random(1, SZ)].bases = 1
    end
end

local function enterQuadrant()
    quadrant = {}
    for y = 1, SZ do
        quadrant[y] = {}
        for x = 1, SZ do
            quadrant[y][x] = "."
        end
    end
    local gq = galaxy[playerQY][playerQX]
    gq.scanned = true
    quadrant[playerSY][playerSX] = "E"

    local function placeRandom(ch, count)
        for i = 1, count do
            local tries = 0
            repeat
                local x = math.random(1, SZ)
                local y = math.random(1, SZ)
                tries = tries + 1
                if quadrant[y][x] == "." then
                    quadrant[y][x] = ch
                    break
                end
            until tries > 50
        end
    end

    placeRandom("K", gq.klingons)
    placeRandom("B", gq.bases)
    placeRandom("*", gq.stars)
end

local function klingonsInQuadrant()
    local list = {}
    for y = 1, SZ do
        for x = 1, SZ do
            if quadrant[y][x] == "K" then
                table.insert(list, { x = x, y = y, hp = 200 + math.random(200) })
            end
        end
    end
    return list
end

local klingons = {}

local function klingonsFire()
    local totalDmg = 0
    for _, k in ipairs(klingons) do
        if k.hp > 0 then
            local d = dist(playerSX, playerSY, k.x, k.y)
            local dmg = math.floor((k.hp / (d + 1)) * (0.5 + math.random() * 0.5))
            if shields >= dmg then
                shields = shields - dmg
            else
                local overflow = dmg - shields
                shields = 0
                energy = energy - overflow
            end
            totalDmg = totalDmg + dmg
        end
    end
    return totalDmg
end

local function adjacentToBase()
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx = playerSX + dx
            local ny = playerSY + dy
            if nx >= 1 and nx <= SZ and ny >= 1 and ny <= SZ then
                if quadrant[ny][nx] == "B" then return true end
            end
        end
    end
    return false
end

local function checkEnd()
    if energy <= 0 then
        setMsg("The Enterprise has been destroyed. All hands lost.")
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    if klingonsLeft <= 0 then
        setMsg("All enemy ships destroyed! The galaxy is safe. Stardates remaining: " .. string.format("%.1f", maxStardate - stardate))
        mode = "win"
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    if stardate >= maxStardate then
        setMsg("Time has run out. The enemy fleet conquers the galaxy.")
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    return false
end

local modeNames = { "nav", "warp", "phasers", "torpedo", "shields", "scan", "dock" }
local modeLabels = { "NAV", "WRP", "PHA", "TOR", "SHI", "SCN", "DCK" }

local function buildCmdMenu(y)
    local items = {}
    for i, label in ipairs(modeLabels) do
        table.insert(items, { label = label, data = modeNames[i] })
    end
    cmdMenu = Menu.new({
        x = 2,
        y = y + 1,
        width = width - 2,
        horizontal = true,
        max_columns = #modeLabels,
        highlight_fg = colors.white,
        highlight_bg = colors.gray,
        default_color = colors.lightGray,
        up_action = "p1_left",
        down_action = "p1_right",
        select_action = "p1_action",
        items = items,
    })
end

local function initGame()
    maxEnergy = 3000
    energy = maxEnergy
    shields = 0
    maxTorpedoes = 10
    torpedoes = maxTorpedoes
    stardate = 0
    maxStardate = 25 + math.random(10)
    gameOverFlag = false
    gameOverTimer = 0
    messageLines = {}

    generateGalaxy()

    playerQX = math.random(1, SZ)
    playerQY = math.random(1, SZ)
    playerSX = math.random(1, SZ)
    playerSY = math.random(1, SZ)

    enterQuadrant()
    klingons = klingonsInQuadrant()

    mode = "main"
    cursorX = playerSX
    cursorY = playerSY

    local sectorOY = 2
    buildCmdMenu(sectorOY + SZ + 1)

    local gq = galaxy[playerQY][playerQX]
    setMsg("Sector [" .. playerQX .. "," .. playerQY .. "]. " ..
        klingonsLeft .. " enemies remain. " ..
        string.format("%.0f", maxStardate - stardate) .. " stardates left.")
end

function game.title()
    return "Star Trek"
end

function game.getControls()
    return {
        { action = "up/down",    description = "Select / Aim" },
        { action = "left/right", description = "Adjust / Aim" },
        { action = "action",     description = "Confirm" },
        { action = "alt",        description = "Back / Cancel" },
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

    if gameOverFlag then return "menu" end

    if mode == "main" then
        local result = cmdMenu:handleInput(input)
        if result and result.type == "select" then
            local m = result.item.data
            if m == "nav" then
                mode = "nav"
                cursorX = playerSX
                cursorY = playerSY
                setMsg("Move cursor to destination. [action] to engage.")
            elseif m == "warp" then
                mode = "warp"
                cursorX = playerQX
                cursorY = playerQY
                setMsg("Select quadrant to warp to. [action] to engage.")
            elseif m == "phasers" then
                if #klingons == 0 or galaxy[playerQY][playerQX].klingons == 0 then
                    setMsg("No enemies in this quadrant.")
                else
                    mode = "phasers"
                    selected = math.min(500, energy)
                    setMsg("Set phaser energy. [up/down] adjust. [action] fire.")
                end
            elseif m == "torpedo" then
                if torpedoes <= 0 then
                    setMsg("No torpedoes remaining.")
                elseif #klingons == 0 or galaxy[playerQY][playerQX].klingons == 0 then
                    setMsg("No enemies in this quadrant.")
                else
                    mode = "torpedo"
                    cursorX = playerSX
                    cursorY = playerSY
                    setMsg("Aim torpedo. Move cursor to target. [action] fire.")
                end
            elseif m == "shields" then
                mode = "shields"
                selected = shields
                setMsg("Set shield energy. Total available: " .. (energy + shields))
            elseif m == "scan" then
                mode = "scan"
                setMsg("Long range scan. [alt] to return.")
            elseif m == "dock" then
                if adjacentToBase() then
                    energy = maxEnergy
                    shields = 0
                    torpedoes = maxTorpedoes
                    stardate = stardate + 0.5
                    setMsg("Docked at starbase. Repairs complete. Energy and torpedoes restored.")
                else
                    setMsg("No starbase adjacent to dock with.")
                end
            end
        end

    elseif mode == "nav" then
        if p1.wasPressed("up") and cursorY > 1 then cursorY = cursorY - 1 end
        if p1.wasPressed("down") and cursorY < SZ then cursorY = cursorY + 1 end
        if p1.wasPressed("left") and cursorX > 1 then cursorX = cursorX - 1 end
        if p1.wasPressed("right") and cursorX < SZ then cursorX = cursorX + 1 end
        if p1.wasPressed("alt") then
            mode = "main"
            setMsg("")
        elseif p1.wasPressed("action") then
            if cursorX == playerSX and cursorY == playerSY then
                setMsg("You're already here.")
            else
                local d = dist(playerSX, playerSY, cursorX, cursorY)
                local cost = math.floor(d * 100)
                if quadrant[cursorY][cursorX] == "*" or quadrant[cursorY][cursorX] == "K" then
                    setMsg("Cannot move there - sector occupied.")
                elseif cost > energy then
                    setMsg("Insufficient energy. Need " .. cost .. ", have " .. energy)
                else
                    quadrant[playerSY][playerSX] = "."
                    playerSX = cursorX
                    playerSY = cursorY
                    quadrant[playerSY][playerSX] = "E"
                    energy = energy - cost
                    stardate = stardate + 0.5

                    local msg = "Moved. -" .. cost .. " energy."
                    if #klingons > 0 and galaxy[playerQY][playerQX].klingons > 0 then
                        local dmg = klingonsFire()
                        msg = msg .. " Enemy fire: -" .. dmg
                    end
                    setMsg(msg)
                    if checkEnd() then return end
                    mode = "main"
                end
            end
        end

    elseif mode == "phasers" then
        if p1.wasPressed("up") then
            selected = math.min(energy, selected + 100)
        elseif p1.wasPressed("down") then
            selected = math.max(0, selected - 100)
        elseif p1.wasPressed("right") then
            selected = math.min(energy, selected + 25)
        elseif p1.wasPressed("left") then
            selected = math.max(0, selected - 25)
        elseif p1.wasPressed("alt") then
            mode = "main"
            setMsg("")
        elseif p1.wasPressed("action") and selected > 0 then
            energy = energy - selected
            local perTarget = selected / math.max(1, galaxy[playerQY][playerQX].klingons)
            local destroyed = 0
            local msgs = {}
            for _, k in ipairs(klingons) do
                if k.hp > 0 then
                    local d = dist(playerSX, playerSY, k.x, k.y)
                    local dmg = math.floor(perTarget / (d * 0.5 + 0.5))
                    k.hp = k.hp - dmg
                    if k.hp <= 0 then
                        quadrant[k.y][k.x] = "."
                        galaxy[playerQY][playerQX].klingons = galaxy[playerQY][playerQX].klingons - 1
                        klingonsLeft = klingonsLeft - 1
                        destroyed = destroyed + 1
                        table.insert(msgs, "Enemy at " .. k.x .. "," .. k.y .. " destroyed!")
                    else
                        table.insert(msgs, "Hit " .. k.x .. "," .. k.y .. " for " .. dmg .. " (HP:" .. k.hp .. ")")
                    end
                end
            end
            stardate = stardate + 0.5
            local msg = table.concat(msgs, " ")
            if galaxy[playerQY][playerQX].klingons > 0 then
                local dmg = klingonsFire()
                msg = msg .. " Return fire: -" .. dmg
            end
            setMsg(msg)
            if checkEnd() then return end
            mode = "main"
        end

    elseif mode == "torpedo" then
        if p1.wasPressed("up") and cursorY > 1 then cursorY = cursorY - 1 end
        if p1.wasPressed("down") and cursorY < SZ then cursorY = cursorY + 1 end
        if p1.wasPressed("left") and cursorX > 1 then cursorX = cursorX - 1 end
        if p1.wasPressed("right") and cursorX < SZ then cursorX = cursorX + 1 end
        if p1.wasPressed("alt") then
            mode = "main"
            setMsg("")
        elseif p1.wasPressed("action") then
            torpedoes = torpedoes - 1
            stardate = stardate + 0.25

            local dx = cursorX - playerSX
            local dy = cursorY - playerSY
            local steps = math.max(math.abs(dx), math.abs(dy))
            if steps == 0 then
                setMsg("Torpedo misfires!")
                mode = "main"
                return
            end
            local sx = dx / steps
            local sy = dy / steps

            local tx, ty = playerSX, playerSY
            local hit = false
            for i = 1, SZ * 2 do
                tx = tx + sx
                ty = ty + sy
                local ix = math.floor(tx + 0.5)
                local iy = math.floor(ty + 0.5)
                if ix < 1 or ix > SZ or iy < 1 or iy > SZ then break end
                local cell = quadrant[iy][ix]
                if cell == "K" then
                    quadrant[iy][ix] = "."
                    for _, k in ipairs(klingons) do
                        if k.x == ix and k.y == iy then k.hp = 0 end
                    end
                    galaxy[playerQY][playerQX].klingons = galaxy[playerQY][playerQX].klingons - 1
                    klingonsLeft = klingonsLeft - 1
                    local msg = "Torpedo destroys enemy at " .. ix .. "," .. iy .. "!"
                    if galaxy[playerQY][playerQX].klingons > 0 then
                        local dmg = klingonsFire()
                        msg = msg .. " Return fire: -" .. dmg
                    end
                    setMsg(msg)
                    hit = true
                    break
                elseif cell == "*" then
                    setMsg("Torpedo hits a star at " .. ix .. "," .. iy .. ". Wasted.")
                    hit = true
                    break
                elseif cell == "B" then
                    quadrant[iy][ix] = "."
                    galaxy[playerQY][playerQX].bases = 0
                    setMsg("Torpedo destroys starbase! That was friendly!")
                    hit = true
                    break
                end
            end
            if not hit then
                setMsg("Torpedo misses - lost in space.")
            end
            if checkEnd() then return end
            mode = "main"
        end

    elseif mode == "shields" then
        local total = energy + shields
        if p1.wasPressed("up") then
            selected = math.min(total, selected + 100)
        elseif p1.wasPressed("down") then
            selected = math.max(0, selected - 100)
        elseif p1.wasPressed("right") then
            selected = math.min(total, selected + 25)
        elseif p1.wasPressed("left") then
            selected = math.max(0, selected - 25)
        elseif p1.wasPressed("alt") then
            mode = "main"
            setMsg("")
        elseif p1.wasPressed("action") then
            energy = total - selected
            shields = selected
            setMsg("Shields set to " .. shields .. ". Energy: " .. energy)
            mode = "main"
        end

    elseif mode == "scan" then
        if p1.wasPressed("alt") or p1.wasPressed("action") then
            mode = "main"
            setMsg("")
        end

    elseif mode == "warp" then
        if p1.wasPressed("up") and cursorY > 1 then cursorY = cursorY - 1 end
        if p1.wasPressed("down") and cursorY < SZ then cursorY = cursorY + 1 end
        if p1.wasPressed("left") and cursorX > 1 then cursorX = cursorX - 1 end
        if p1.wasPressed("right") and cursorX < SZ then cursorX = cursorX + 1 end
        if p1.wasPressed("alt") then
            mode = "main"
            setMsg("")
        elseif p1.wasPressed("action") then
            if cursorX == playerQX and cursorY == playerQY then
                setMsg("Already in this quadrant.")
            else
                local d = dist(playerQX, playerQY, cursorX, cursorY)
                local cost = math.floor(d * 200)
                if cost > energy then
                    setMsg("Insufficient energy for warp. Need " .. cost)
                else
                    energy = energy - cost
                    stardate = stardate + 1
                    playerQX = cursorX
                    playerQY = cursorY
                    playerSX = math.random(1, SZ)
                    playerSY = math.random(1, SZ)
                    enterQuadrant()
                    quadrant[playerSY][playerSX] = "E"
                    klingons = klingonsInQuadrant()
                    local gq = galaxy[playerQY][playerQX]
                    setMsg("Warped to [" .. playerQX .. "," .. playerQY .. "]. " ..
                        gq.klingons .. " enemies, " .. gq.bases .. " bases.")
                    if checkEnd() then return end
                    mode = "main"
                end
            end
        end
    end
end

local function drawSector(ox, oy, sz)
    for y = 1, SZ do
        for x = 1, SZ do
            local sx = ox + (x - 1) * 2
            local sy = oy + y - 1
            term.setCursorPos(sx, sy)
            local cell = quadrant[y][x]
            if cell == "E" then
                term.setTextColor(colors.lime)
                term.write("E")
            elseif cell == "K" then
                term.setTextColor(colors.red)
                term.write("K")
            elseif cell == "B" then
                term.setTextColor(colors.cyan)
                term.write("B")
            elseif cell == "*" then
                term.setTextColor(colors.yellow)
                term.write("*")
            else
                term.setTextColor(colors.gray)
                term.write("\xB7")
            end
        end
    end

    if mode == "nav" or mode == "torpedo" then
        local cx = ox + (cursorX - 1) * 2
        local cy = oy + cursorY - 1
        term.setCursorPos(cx - 1, cy)
        term.setTextColor(mode == "torpedo" and colors.red or colors.white)
        term.write("[")
        term.setCursorPos(cx + 1, cy)
        term.write("]")
    end
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    local sectorOX = 2
    local sectorOY = 2
    drawSector(sectorOX, sectorOY, SZ)

    local infoX = sectorOX + SZ * 2 + 2

    term.setCursorPos(infoX, 2)
    term.setTextColor(colors.yellow)
    term.write("Q:" .. playerQX .. "," .. playerQY)

    term.setCursorPos(infoX, 3)
    term.setTextColor(colors.lime)
    term.write("E:" .. energy)

    term.setCursorPos(infoX, 4)
    term.setTextColor(colors.cyan)
    term.write("S:" .. shields)

    term.setCursorPos(infoX, 5)
    term.setTextColor(colors.orange)
    term.write("T:" .. torpedoes)

    term.setCursorPos(infoX, 6)
    term.setTextColor(colors.red)
    term.write("K:" .. klingonsLeft)

    term.setCursorPos(infoX, 7)
    term.setTextColor(colors.lightGray)
    term.write("D:" .. string.format("%.1f", maxStardate - stardate))

    local cmdY = sectorOY + SZ + 1

    if mode == "main" and cmdMenu then
        cmdMenu:draw()
    end

    local panelY = cmdY + 2

    if mode == "phasers" then
        term.setCursorPos(2, panelY)
        term.setTextColor(colors.yellow)
        term.write("Phaser energy: " .. selected)
        term.setCursorPos(2, panelY + 1)
        term.setTextColor(colors.lightGray)
        term.write("[v^] +/-100  [<>] +/-25  [action] Fire")
    end

    if mode == "shields" then
        term.setCursorPos(2, panelY)
        term.setTextColor(colors.cyan)
        term.write("Shields: " .. selected .. "  Energy: " .. (energy + shields - selected))
        term.setCursorPos(2, panelY + 1)
        term.setTextColor(colors.lightGray)
        term.write("[v^] +/-100  [<>] +/-25  [action] Set")
    end

    local mapX = infoX + 10

    if mode == "scan" then
        term.setCursorPos(mapX, sectorOY)
        term.setTextColor(colors.yellow)
        term.write("Long Range Scan")
        for dy = -1, 1 do
            for dx = -1, 1 do
                local qx = playerQX + dx
                local qy = playerQY + dy
                term.setCursorPos(mapX + (dx + 1) * 5, sectorOY + 1 + dy + 1)
                if qx >= 1 and qx <= SZ and qy >= 1 and qy <= SZ then
                    local gq = galaxy[qy][qx]
                    gq.scanned = true
                    local code = gq.klingons * 100 + gq.bases * 10 + gq.stars
                    if qx == playerQX and qy == playerQY then
                        term.setTextColor(colors.lime)
                    elseif gq.klingons > 0 then
                        term.setTextColor(colors.red)
                    else
                        term.setTextColor(colors.lightGray)
                    end
                    term.write(string.format("%03d", code))
                else
                    term.setTextColor(colors.gray)
                    term.write("---")
                end
            end
        end
        term.setCursorPos(mapX, sectorOY + 5)
        term.setTextColor(colors.gray)
        term.write("KBS = Klingons/Bases/Stars")
    end

    if mode == "warp" then
        term.setCursorPos(mapX, sectorOY)
        term.setTextColor(colors.yellow)
        term.write("Galaxy Map")
        for qy = 1, SZ do
            for qx = 1, SZ do
                term.setCursorPos(mapX + (qx - 1) * 2, sectorOY + qy)
                local gq = galaxy[qy][qx]
                if qx == playerQX and qy == playerQY then
                    term.setTextColor(colors.lime)
                    term.write("E")
                elseif gq.scanned and gq.klingons > 0 then
                    term.setTextColor(colors.red)
                    term.write(tostring(gq.klingons))
                elseif gq.scanned and gq.bases > 0 then
                    term.setTextColor(colors.cyan)
                    term.write("B")
                elseif gq.scanned then
                    term.setTextColor(colors.gray)
                    term.write(".")
                else
                    term.setTextColor(colors.gray)
                    term.write("?")
                end
            end
        end
        local cx = mapX + (cursorX - 1) * 2
        local cy = sectorOY + cursorY
        term.setCursorPos(cx - 1, cy)
        term.setTextColor(colors.yellow)
        term.write("[")
        term.setCursorPos(cx + 1, cy)
        term.write("]")

        local d = dist(playerQX, playerQY, cursorX, cursorY)
        local cost = math.floor(d * 200)
        term.setCursorPos(2, panelY)
        term.setTextColor(colors.lightGray)
        term.write("Warp to [" .. cursorX .. "," .. cursorY .. "]  Cost: " .. cost .. " energy")
    end

    local msgY = cmdY + 4
    term.setTextColor(colors.white)
    for i, line in ipairs(messageLines) do
        if msgY + i - 1 <= height then
            term.setCursorPos(2, msgY + i - 1)
            term.write(line)
        end
    end

    term.setCursorPos(2, 1)
    term.setTextColor(colors.blue)
    term.write("STAR TREK")

end

function game.cleanup()
end

return game
