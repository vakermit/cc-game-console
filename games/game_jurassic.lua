local game = {}

local width, height
local state
local day, distance, totalDistance
local fuel, food, ammo, medkits
local pace, rations
local party
local eventQueue, currentEvent
local selected
local message, messageLines
local gameOverTimer, gameOverFlag
local travelAnim, travelTicks
local resultWait

local paceNames = { "Cautious", "Normal", "Reckless" }
local paceDist =  { 8, 15, 25 }
local paceFuel =  { 3, 5, 9 }
local paceRisk =  { 0.15, 0.35, 0.55 }

local rationNames = { "Full", "Half", "Scraps" }
local rationFood =  { 4, 2, 1 }
local rationHeal =  { 0.08, 0.02, -0.03 }

local roles = {
    { name = "Dr. Sattler", role = "Paleontologist", skill = "dino" },
    { name = "Muldoon",     role = "Security",       skill = "combat" },
    { name = "Ellie",       role = "Botanist",       skill = "forage" },
    { name = "Nedry Jr.",   role = "Engineer",       skill = "repair" },
}

local statusNames = { "Healthy", "Tired", "Injured", "Critical", "Dead" }
local statusColors = { colors.lime, colors.yellow, colors.orange, colors.red, colors.gray }

local dinoNames = {
    "T-Rex", "Velociraptor", "Dilophosaurus", "Triceratops",
    "Stegosaurus", "Pteranodon", "Compsognathus", "Spinosaurus",
    "Brachiosaurus", "Gallimimus",
}

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

local function setMessage(text)
    messageLines = wrap(text, width - 4)
end

local function alive()
    local count = 0
    for _, p in ipairs(party) do
        if p.status < 5 then count = count + 1 end
    end
    return count
end

local function hasSkill(skill)
    for _, p in ipairs(party) do
        if p.skill == skill and p.status < 4 then return true end
    end
    return false
end

local function hurtRandom(amount, cause)
    local targets = {}
    for i, p in ipairs(party) do
        if p.status < 5 then table.insert(targets, i) end
    end
    if #targets == 0 then return "" end
    local idx = targets[math.random(#targets)]
    local p = party[idx]
    p.health = math.max(0, p.health - amount)
    if p.health <= 0 then
        p.status = 5
        return p.name .. " " .. cause
    else
        p.status = math.max(p.status, amount > 30 and 3 or 2)
        return p.name .. " was hurt."
    end
end

local function healParty(amount)
    for _, p in ipairs(party) do
        if p.status < 5 then
            p.health = math.min(100, p.health + amount)
            if p.health > 70 then p.status = 1
            elseif p.health > 40 then p.status = 2
            elseif p.health > 0 then p.status = 3
            end
        end
    end
end

local events = {}

local function addEvent(e)
    table.insert(events, e)
end

addEvent({
    text = function()
        return "A " .. dinoNames[math.random(#dinoNames)] ..
            " blocks the road ahead. Its head swivels toward the jeep."
    end,
    choices = { "Fight", "Sneak past", "Floor it" },
    resolve = function(choice)
        if choice == 1 then
            if ammo >= 3 then
                ammo = ammo - 3
                return "You open fire. The beast retreats. (-3 ammo)"
            else
                return "Not enough ammo! " .. hurtRandom(35, "was trampled.")
            end
        elseif choice == 2 then
            if hasSkill("dino") and math.random() > 0.3 then
                return "Dr. Sattler reads its behavior. You slip past unnoticed."
            elseif math.random() > 0.5 then
                return "You hold your breath. It works. Barely."
            else
                return hurtRandom(25, "was spotted and charged.")
            end
        else
            fuel = fuel - 2
            if math.random() > 0.4 then
                return "You gun it! The jeep flies past. (-2 fuel)"
            else
                return "You clip a tree! " .. hurtRandom(20, "hit the dashboard.") .. " (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "Pack of Velociraptors spotted flanking the jeep. They're organized." end,
    choices = { "Defend", "Speed up", "Use flare" },
    resolve = function(choice)
        if choice == 1 then
            if ammo >= 5 then
                ammo = ammo - 5
                if hasSkill("combat") then
                    return "Muldoon takes point. Clean kills. (-5 ammo)"
                else
                    local r = hurtRandom(20, "was clawed.")
                    return "You hold them off but not cleanly. " .. r .. " (-5 ammo)"
                end
            else
                return "You're out of ammo! " .. hurtRandom(40, "was dragged from the jeep.")
            end
        elseif choice == 2 then
            fuel = fuel - 3
            if math.random() > 0.3 then
                return "The raptors can't keep up. For now. (-3 fuel)"
            else
                return "One leaps onto the hood! " .. hurtRandom(30, "was bitten.") .. " (-3 fuel)"
            end
        else
            if ammo >= 1 then
                ammo = ammo - 1
                return "The flare confuses them. They scatter. (-1 ammo)"
            else
                return "No flares left! " .. hurtRandom(35, "became a target.")
            end
        end
    end,
})

addEvent({
    text = function() return "You find an abandoned InGen lab. The power flickers on and off." end,
    choices = { "Search it", "Keep driving", "Siphon fuel" },
    resolve = function(choice)
        if choice == 1 then
            local find = math.random(3)
            if find == 1 then
                medkits = medkits + 2
                return "Jackpot! Medical supplies. (+2 medkits)"
            elseif find == 2 then
                ammo = ammo + 4
                return "Security locker was unlocked. (+4 ammo)"
            else
                return "Something moves in the dark. " .. hurtRandom(20, "was ambushed by a Dilophosaurus.")
            end
        elseif choice == 2 then
            return "You drive on. Better safe than eaten."
        else
            if hasSkill("repair") then
                fuel = fuel + 6
                return "Nedry Jr. rigs a fuel transfer. (+6 fuel)"
            else
                fuel = fuel + 3
                return "Crude but it works. (+3 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "A river blocks the path. The water is murky and something large moved under the surface." end,
    choices = { "Ford it", "Find a bridge", "Build a raft" },
    resolve = function(choice)
        if choice == 1 then
            fuel = fuel - 1
            if math.random() > 0.4 then
                return "The jeep powers through! Soggy but alive. (-1 fuel)"
            else
                food = math.max(0, food - 3)
                return "The Spinosaurus disagrees. Supplies soaked. (-3 food, -1 fuel)"
            end
        elseif choice == 2 then
            if math.random() > 0.5 then
                distance = distance + 5
                return "Found one, but it's a detour. (+5 miles added)"
            else
                return "No bridge. You wasted half a day."
            end
        else
            fuel = fuel - 1
            food = food - 1
            return "Slow but safe. The thing in the water watches you cross. (-1 food, -1 fuel)"
        end
    end,
})

addEvent({
    text = function() return "A herd of Gallimimus stampedes across the road!" end,
    choices = { "Wait it out", "Drive through" },
    resolve = function(choice)
        if choice == 1 then
            return "Beautiful and terrifying. You wait 20 minutes."
        else
            if math.random() > 0.5 then
                return "You weave through! Your driving impresses no one."
            else
                fuel = fuel - 1
                return hurtRandom(15, "was jolted hard.") .. " The jeep takes a hit. (-1 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "Tropical storm rolls in. Visibility drops to zero." end,
    choices = { "Camp here", "Push through" },
    resolve = function(choice)
        if choice == 1 then
            food = food - 2
            healParty(5)
            return "You rest through the storm. (-2 food, party rests)"
        else
            fuel = fuel - 2
            if math.random() > 0.5 then
                return "Rough driving but you made progress. (-2 fuel)"
            else
                return "You drove into a ditch. " .. hurtRandom(15, "hit their head.") .. " (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "A Brachiosaurus lumbers across the clearing. It seems docile." end,
    choices = { "Observe quietly", "Try to pass under" },
    resolve = function(choice)
        if choice == 1 then
            healParty(5)
            if hasSkill("dino") then
                return "Dr. Sattler is overjoyed. Morale improves."
            else
                return "A peaceful moment in an otherwise terrible trip."
            end
        else
            if math.random() > 0.3 then
                return "You drive under its belly. That was either brave or stupid."
            else
                return "It steps sideways! " .. hurtRandom(25, "was nearly crushed.")
            end
        end
    end,
})

addEvent({
    text = function() return "You spot supply crates from a crashed helicopter." end,
    choices = { "Investigate" },
    resolve = function(choice)
        local r = math.random(4)
        if r == 1 then
            food = food + 5
            return "MREs! They're terrible but edible. (+5 food)"
        elseif r == 2 then
            fuel = fuel + 4
            return "Fuel canisters intact! (+4 fuel)"
        elseif r == 3 then
            ammo = ammo + 3
            medkits = medkits + 1
            return "Ammo and a first aid kit. (+3 ammo, +1 medkit)"
        else
            food = food + 3
            fuel = fuel + 2
            return "Mixed supplies. Better than nothing. (+3 food, +2 fuel)"
        end
    end,
})

addEvent({
    text = function()
        local living = {}
        for _, p in ipairs(party) do
            if p.status < 5 then table.insert(living, p) end
        end
        if #living == 0 then return "The fever takes hold." end
        local p = living[math.random(#living)]
        return p.name .. " is showing signs of fever. Might be infected."
    end,
    choices = { "Use medkit", "Rest a day", "Tough it out" },
    resolve = function(choice)
        if choice == 1 then
            if medkits > 0 then
                medkits = medkits - 1
                healParty(20)
                return "Antibiotics do the trick. (-1 medkit)"
            else
                return "No medkits! " .. hurtRandom(20, "gets worse.")
            end
        elseif choice == 2 then
            food = food - 3
            healParty(10)
            return "A day of rest helps. (-3 food)"
        else
            if math.random() > 0.5 then
                return "They shake it off. Lucky."
            else
                return hurtRandom(25, "collapses with fever.")
            end
        end
    end,
})

addEvent({
    text = function() return "Compys surround the campsite. Tiny but bold. One is chewing your boot." end,
    choices = { "Shoo them", "Ignore them" },
    resolve = function(choice)
        if choice == 1 then
            food = math.max(0, food - 1)
            return "They scatter. One steals a granola bar. (-1 food)"
        else
            if math.random() > 0.6 then
                return "They lose interest eventually."
            else
                food = math.max(0, food - 3)
                return "They got into the food supply while you slept! (-3 food)"
            end
        end
    end,
})

addEvent({
    text = function() return "You find an abandoned jeep on the roadside. Keys still in it." end,
    choices = { "Strip it for parts", "Swap vehicles" },
    resolve = function(choice)
        if choice == 1 then
            fuel = fuel + 4
            return "Siphoned the tank and grabbed spares. (+4 fuel)"
        else
            if hasSkill("repair") then
                fuel = fuel + 8
                return "Nedry Jr. gets it running. Fresh ride! (+8 fuel)"
            else
                fuel = fuel + 3
                return "It's in rough shape but drivable. (+3 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "A Pteranodon swoops low, snatching at anything shiny." end,
    choices = { "Duck and cover", "Shoot it down" },
    resolve = function(choice)
        if choice == 1 then
            if math.random() > 0.3 then
                return "It grabs a hubcap and leaves. Could be worse."
            else
                return hurtRandom(15, "was clipped by talons.")
            end
        else
            if ammo >= 2 then
                ammo = ammo - 2
                return "Direct hit. It spirals away. (-2 ammo)"
            else
                return "Click. Click. No ammo. " .. hurtRandom(20, "was carried 10 feet.")
            end
        end
    end,
})

addEvent({
    text = function() return "The jeep's engine sputters and dies. Smoke pours from under the hood." end,
    choices = { "Attempt repair", "Scavenge nearby", "Wait and try again" },
    resolve = function(choice)
        if choice == 1 then
            if hasSkill("repair") then
                fuel = fuel - 1
                return "Nedry Jr. patches the fuel line. Good as new-ish. (-1 fuel)"
            else
                fuel = fuel - 3
                return "Trial and error. Mostly error. (-3 fuel)"
            end
        elseif choice == 2 then
            if math.random() > 0.4 then
                fuel = fuel + 2
                return "Found a toolbox and spare hose. (+2 fuel saved)"
            else
                return hurtRandom(15, "cut themselves on rusted metal.") .. " Nothing useful."
            end
        else
            if math.random() > 0.3 then
                return "It starts on the third try. You exhale."
            else
                fuel = fuel - 2
                return "Flooded the engine trying. (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "You hear a low rumble. The ground shakes. Volcanic activity?" end,
    choices = { "Detour left", "Detour right", "Gun it straight" },
    resolve = function(choice)
        if choice == 1 then
            distance = distance + 3
            return "Longer route but safe. (+3 miles added)"
        elseif choice == 2 then
            if math.random() > 0.5 then
                return "Clear path. Good call."
            else
                return "Landslide! " .. hurtRandom(20, "was hit by debris.") .. " Rough detour."
            end
        else
            fuel = fuel - 2
            if math.random() > 0.4 then
                return "You outrun the tremor. Barely. (-2 fuel)"
            else
                return hurtRandom(30, "was thrown from the jeep.") .. " (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "An electric fence still hums ahead. The gate is locked." end,
    choices = { "Cut the fence", "Find another way", "Ram through" },
    resolve = function(choice)
        if choice == 1 then
            if hasSkill("repair") then
                return "Nedry Jr. kills the power first. Clean cut."
            else
                return hurtRandom(20, "got shocked.") .. " But the fence is open now."
            end
        elseif choice == 2 then
            distance = distance + 4
            return "Long way around. (+4 miles added)"
        else
            fuel = fuel - 2
            if math.random() > 0.5 then
                return "The gate buckles. Freedom! (-2 fuel)"
            else
                return "Airbags deploy. " .. hurtRandom(15, "hit the steering wheel.") .. " (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "Ellie spots edible plants by the roadside. The area seems quiet." end,
    choices = { "Stop and forage", "Keep driving" },
    resolve = function(choice)
        if choice == 1 then
            if hasSkill("forage") then
                food = food + 6
                return "Ellie knows her stuff. Berries, tubers, wild greens. (+6 food)"
            else
                food = food + 2
                if math.random() > 0.7 then
                    return "Found some edible plants. (+2 food)"
                else
                    return hurtRandom(10, "ate something questionable.") .. " (+2 food)"
                end
            end
        else
            return "You press on. Probably the smart move."
        end
    end,
})

addEvent({
    text = function() return "A nest of eggs sits beside the road. They're warm. Something big laid these." end,
    choices = { "Take the eggs", "Leave them", "Study them" },
    resolve = function(choice)
        if choice == 1 then
            food = food + 4
            if math.random() > 0.4 then
                return "Protein is protein. (+4 food)"
            else
                return "The mother returns. " .. hurtRandom(35, "met an angry parent.") .. " (+4 food)"
            end
        elseif choice == 2 then
            return "You back away slowly. Wise."
        else
            healParty(3)
            if hasSkill("dino") then
                return "Dr. Sattler identifies them as Maiasaura. Gentle giants. Morale boost."
            else
                return "They're big eggs. That's all you've learned."
            end
        end
    end,
})

addEvent({
    text = function() return "You find a working radio in an old bunker. Static, then a voice." end,
    choices = { "Respond", "Listen only", "Take the radio" },
    resolve = function(choice)
        if choice == 1 then
            if math.random() > 0.5 then
                distance = distance - 5
                return "Rescue team gives coordinates for a shortcut! (-5 miles)"
            else
                return "The signal dies. At least someone knows you're here."
            end
        elseif choice == 2 then
            return "You learn the coast is clear. That's something."
        else
            if math.random() > 0.6 then
                return "Extra radio might come in handy later."
            else
                return "It sparks and dies when you unplug it. Worth nothing now."
            end
        end
    end,
})

addEvent({
    text = function() return "A Dilophosaurus rises from the bushes, frill expanding. It hisses." end,
    choices = { "Back away slowly", "Shoot it", "Throw food" },
    resolve = function(choice)
        if choice == 1 then
            if math.random() > 0.4 then
                return "It loses interest. Your pants may never recover."
            else
                return hurtRandom(25, "was sprayed with venom.") .. " Can't see!"
            end
        elseif choice == 2 then
            if ammo >= 2 then
                ammo = ammo - 2
                return "Two shots. It's down. (-2 ammo)"
            else
                return "No ammo! " .. hurtRandom(30, "was sprayed with blinding venom.")
            end
        else
            food = food - 2
            return "It takes the food and waddles off. (-2 food)"
        end
    end,
})

addEvent({
    text = function() return "Night falls fast. You need to decide about camp." end,
    choices = { "Camp with fire", "Sleep in jeep", "Drive through night" },
    resolve = function(choice)
        if choice == 1 then
            food = food - 1
            healParty(15)
            return "Warm and rested. The fire keeps most things away. (-1 food)"
        elseif choice == 2 then
            healParty(5)
            return "Cramped but safe. Something sniffs around at 3am."
        else
            fuel = fuel - 3
            if math.random() > 0.4 then
                distance = distance - 8
                return "Extra miles in the dark! (-3 fuel, -8 miles)"
            else
                return hurtRandom(15, "crashed into a fallen tree.") .. " (-3 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "Two Triceratops are fighting over territory. They're blocking the road." end,
    choices = { "Wait them out", "Honk the horn", "Off-road around" },
    resolve = function(choice)
        if choice == 1 then
            return "30 minutes later they move on. Time lost, dignity intact."
        elseif choice == 2 then
            if math.random() > 0.5 then
                return "They startle and scatter. Easy."
            else
                return "They charge the jeep! " .. hurtRandom(25, "was gored through the door.")
            end
        else
            fuel = fuel - 2
            if math.random() > 0.3 then
                return "Bumpy but you make it around. (-2 fuel)"
            else
                return "Stuck in mud. Lost time digging out. (-2 fuel)"
            end
        end
    end,
})

addEvent({
    text = function() return "You spot a Spinosaurus fishing in the shallows. It hasn't seen you yet." end,
    choices = { "Creep past", "Wait it out", "Reverse" },
    resolve = function(choice)
        if choice == 1 then
            if hasSkill("dino") then
                return "Dr. Sattler times it between catches. Flawless."
            elseif math.random() > 0.4 then
                return "You crawl past at 2mph. Longest minute of your life."
            else
                return "It heard you. " .. hurtRandom(40, "learned why Spinosaurus is apex.")
            end
        elseif choice == 2 then
            food = food - 1
            return "An hour passes. It finally leaves. (-1 food)"
        else
            fuel = fuel - 2
            distance = distance + 5
            return "Long backtrack to find another route. (-2 fuel, +5 miles)"
        end
    end,
})

addEvent({
    text = function() return "An InGen supply drop pod, still sealed, sits in a clearing." end,
    choices = { "Open it" },
    resolve = function(choice)
        local r = math.random(5)
        if r == 1 then
            ammo = ammo + 6
            return "Military grade. Jackpot. (+6 ammo)"
        elseif r == 2 then
            food = food + 4
            medkits = medkits + 2
            return "Rations and medical supplies. (+4 food, +2 medkits)"
        elseif r == 3 then
            fuel = fuel + 5
            return "Emergency fuel reserve. (+5 fuel)"
        elseif r == 4 then
            ammo = ammo + 2
            food = food + 2
            fuel = fuel + 2
            medkits = medkits + 1
            return "A little of everything. (+2 ammo, +2 food, +2 fuel, +1 medkit)"
        else
            return "Empty. Someone got here first. The lock was clawed open."
        end
    end,
})

addEvent({
    text = function() return "The road ahead is covered in thick webbing. Something large spun this." end,
    choices = { "Burn through it", "Cut through", "Find another way" },
    resolve = function(choice)
        if choice == 1 then
            if ammo >= 1 then
                ammo = ammo - 1
                return "A flare does the trick. The web burns fast. (-1 ammo)"
            else
                return "Nothing to light it with. You hack through instead. " .. hurtRandom(10, "got tangled.")
            end
        elseif choice == 2 then
            if math.random() > 0.5 then
                return "Slow going but you clear a path."
            else
                return hurtRandom(20, "disturbed the web's owner.")
            end
        else
            distance = distance + 3
            return "Smart. Whatever made that, you don't want to meet. (+3 miles)"
        end
    end,
})

addEvent({
    text = function() return "You pass a crashed tour vehicle. A camera is still recording." end,
    choices = { "Check for survivors", "Search for supplies", "Move on" },
    resolve = function(choice)
        if choice == 1 then
            if math.random() > 0.6 then
                healParty(5)
                return "No survivors but you find a journal. A reminder to keep going."
            else
                return "Something is using this as a nest. " .. hurtRandom(20, "was ambushed.")
            end
        elseif choice == 2 then
            local r = math.random(3)
            if r == 1 then
                food = food + 3
                return "Tourist snacks in the glovebox. (+3 food)"
            elseif r == 2 then
                medkits = medkits + 1
                return "First aid kit under the seat. (+1 medkit)"
            else
                fuel = fuel + 2
                return "Siphoned a bit of fuel. (+2 fuel)"
            end
        else
            return "Some things are best left alone."
        end
    end,
})

addEvent({
    text = function() return "Muldoon spots tracks. Big ones. Very fresh. They lead toward your route." end,
    choices = { "Set an ambush", "Change course", "Move fast and quiet" },
    resolve = function(choice)
        if choice == 1 then
            if hasSkill("combat") and ammo >= 4 then
                ammo = ammo - 4
                return "Muldoon sets a trap. It works. You won't be followed. (-4 ammo)"
            elseif ammo >= 4 then
                ammo = ammo - 4
                return hurtRandom(20, "misjudged the ambush timing.") .. " (-4 ammo)"
            else
                return "Not enough ammo for an ambush. " .. hurtRandom(25, "was caught off guard.")
            end
        elseif choice == 2 then
            distance = distance + 6
            fuel = fuel - 1
            return "Major detour but you avoid whatever made those. (+6 miles, -1 fuel)"
        else
            if math.random() > 0.5 then
                return "You slip through undetected. Heart rate: concerning."
            else
                return "It finds you. " .. hurtRandom(35, "met the thing that made the tracks.")
            end
        end
    end,
})

addEvent({
    text = function() return "A clearing full of sleeping herbivores. It's almost peaceful." end,
    choices = { "Rest here", "Forage the area", "Sneak through" },
    resolve = function(choice)
        if choice == 1 then
            food = food - 2
            healParty(20)
            return "Best rest in days. The dinos don't mind. (-2 food, party heals)"
        elseif choice == 2 then
            if hasSkill("forage") then
                food = food + 5
                return "Ellie finds edible ferns and fruit trees. (+5 food)"
            else
                food = food + 2
                return "Slim pickings but something. (+2 food)"
            end
        else
            if math.random() > 0.2 then
                return "You tiptoe through. One opens an eye and goes back to sleep."
            else
                return "You step on a tail! Stampede! " .. hurtRandom(20, "was trampled in the chaos.")
            end
        end
    end,
})

local function initParty()
    party = {}
    for i, r in ipairs(roles) do
        table.insert(party, {
            name = r.name,
            role = r.role,
            skill = r.skill,
            health = 100,
            status = 1,
        })
    end
end

local function initGame()
    day = 1
    totalDistance = 120
    distance = totalDistance
    fuel = 30
    food = 25
    ammo = 10
    medkits = 3
    pace = 2
    rations = 1
    selected = 1
    state = "intro"
    gameOverFlag = false
    gameOverTimer = 0
    travelAnim = 0
    travelTicks = 0
    resultWait = 0
    setMessage("")
    initParty()
end

local function advanceDay()
    local dist = paceDist[pace]
    local fc = paceFuel[pace]
    local fd = rationFood[rations] * alive()
    local heal = rationHeal[rations]

    fuel = fuel - fc
    food = food - fd
    distance = distance - dist
    healParty(heal * 100)

    if fuel < 0 then fuel = 0 end
    if food < 0 then food = 0 end
    if distance < 0 then distance = 0 end

    if math.random() < paceRisk[pace] then
        local e = events[math.random(#events)]
        currentEvent = {
            text = e.text(),
            choices = e.choices,
            resolve = e.resolve,
        }
        state = "event"
        setMessage(currentEvent.text)
        selected = 1
    else
        state = "evening"
        setMessage("Day " .. day .. " was uneventful. The jungle watches.")
    end
end

local function checkGameOver()
    if distance <= 0 then
        state = "win"
        setMessage("You reached the coast! A helicopter descends. " .. alive() .. " of 4 survived in " .. day .. " days.")
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    if alive() <= 0 then
        state = "lose"
        setMessage("No survivors. The island reclaims everything.")
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    if fuel <= 0 and distance > 0 then
        state = "lose"
        setMessage("Out of fuel. The jeep dies. So do you. Eventually.")
        gameOverFlag = true
        gameOverTimer = 0
        return true
    end
    return false
end

function game.title()
    return "Jurassic Trail"
end

function game.getControls()
    return {
        { action = "up/down",  description = "Select option" },
        { action = "action",   description = "Confirm" },
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

    if gameOverFlag then
        gameOverTimer = gameOverTimer + dt
        if p1.wasPressed("action") then
            initGame()
            return
        elseif p1.wasPressed("alt") or gameOverTimer >= 15 then
            return "menu"
        end
        return
    end

    if state == "intro" then
        setMessage("Isla Nubla has gone dark. Your team of 4 must cross " ..
            totalDistance .. " miles of jungle to reach the coast. " ..
            "You have a jeep, limited supplies, and very large problems.")
        if p1.wasPressed("action") then
            state = "pace"
            selected = pace
        end

    elseif state == "pace" then
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = 3 end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > 3 then selected = 1 end
        elseif p1.wasPressed("action") then
            pace = selected
            state = "rations"
            selected = rations
        end

    elseif state == "rations" then
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = 3 end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > 3 then selected = 1 end
        elseif p1.wasPressed("action") then
            rations = selected
            state = "travel"
            travelAnim = 0
            travelTicks = 20
        end

    elseif state == "travel" then
        travelAnim = travelAnim + 1
        if travelAnim >= travelTicks then
            advanceDay()
        end

    elseif state == "event" then
        local numChoices = #currentEvent.choices
        if p1.wasPressed("up") then
            selected = selected - 1
            if selected < 1 then selected = numChoices end
        elseif p1.wasPressed("down") then
            selected = selected + 1
            if selected > numChoices then selected = 1 end
        elseif p1.wasPressed("action") then
            local result = currentEvent.resolve(selected)
            setMessage(result)
            state = "result"
            resultWait = 0
        end

    elseif state == "result" then
        resultWait = resultWait + dt
        if p1.wasPressed("action") and resultWait > 0.3 then
            state = "evening"
        end

    elseif state == "evening" then
        if p1.wasPressed("action") then
            if not checkGameOver() then
                day = day + 1
                state = "pace"
                selected = pace
            end
        end
    end
end

local function drawBar(x, y, label, val, maxVal, col)
    term.setCursorPos(x, y)
    term.setTextColor(colors.lightGray)
    term.write(label .. ":")
    term.setCursorPos(x + #label + 1, y)
    term.setTextColor(col)
    term.write(tostring(val))
end

function game.draw()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setBackgroundColor(colors.green)
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", width))
    term.setCursorPos(2, 1)
    term.setTextColor(colors.white)
    local header = "Day " .. day .. "  |  " .. distance .. " mi left"
    term.write(header)

    local resY = 2
    term.setBackgroundColor(colors.black)
    drawBar(2, resY, "Fuel", fuel, 30, fuel > 8 and colors.lime or fuel > 3 and colors.yellow or colors.red)
    drawBar(14, resY, "Food", food, 25, food > 8 and colors.lime or food > 3 and colors.yellow or colors.red)
    drawBar(26, resY, "Ammo", ammo, 10, colors.cyan)

    local partyY = 3
    term.setCursorPos(2, partyY)
    for i, p in ipairs(party) do
        local nameW = math.floor((width - 2) / 4)
        local x = 2 + (i - 1) * nameW
        term.setCursorPos(x, partyY)
        term.setTextColor(statusColors[p.status])
        local display = p.name:sub(1, nameW - 1)
        term.write(display)
    end

    local textY = 5
    local choiceY

    if state == "intro" then
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY)
        term.write("JURASSIC TRAIL")
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + 1 + i)
            term.write(line)
        end
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write("[action] Begin expedition")

    elseif state == "pace" then
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY)
        term.write("Set travel pace:")
        for i, name in ipairs(paceNames) do
            term.setCursorPos(4, textY + 1 + i)
            if i == selected then
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.gray)
                term.write(" " .. name .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(name)
            end
            term.setTextColor(colors.gray)
            term.write("  ~" .. paceDist[i] .. "mi  -" .. paceFuel[i] .. "fuel")
        end

    elseif state == "rations" then
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY)
        term.write("Set rations:")
        for i, name in ipairs(rationNames) do
            term.setCursorPos(4, textY + 1 + i)
            if i == selected then
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.gray)
                term.write(" " .. name .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(name)
            end
            term.setTextColor(colors.gray)
            term.write("  -" .. rationFood[i] .. "food/person")
        end

    elseif state == "travel" then
        local progress = travelAnim / travelTicks
        local barW = width - 6
        local filled = math.floor(progress * barW)
        term.setCursorPos(2, textY + 2)
        term.setTextColor(colors.yellow)
        term.write("Driving...")
        term.setCursorPos(3, textY + 4)
        term.setTextColor(colors.green)
        term.write("[" .. string.rep("=", filled) .. string.rep(" ", barW - filled) .. "]")

        local jeepX = 3 + filled
        term.setCursorPos(math.max(3, jeepX - 2), textY + 3)
        term.setTextColor(colors.cyan)
        term.write("__")
        term.setCursorPos(math.max(3, jeepX - 3), textY + 4)

    elseif state == "event" then
        term.setTextColor(colors.red)
        term.setCursorPos(2, textY)
        term.write("! EVENT !")
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + 1 + i)
            term.write(line)
        end
        choiceY = textY + #messageLines + 3
        for i, ch in ipairs(currentEvent.choices) do
            term.setCursorPos(4, choiceY + i - 1)
            if i == selected then
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.gray)
                term.write(" " .. ch .. " ")
                term.setBackgroundColor(colors.black)
            else
                term.setTextColor(colors.lightGray)
                term.write(ch)
            end
        end

    elseif state == "result" then
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + i)
            term.write(line)
        end
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write("[action] Continue")

    elseif state == "evening" then
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY)
        term.write("End of Day " .. day)
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + 1 + i)
            term.write(line)
        end

        local sy = textY + #messageLines + 3
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, sy)
        term.write("Party status:")
        for i, p in ipairs(party) do
            term.setCursorPos(4, sy + i)
            term.setTextColor(statusColors[p.status])
            term.write(p.name .. " - " .. statusNames[p.status])
            if p.status < 5 then
                term.setTextColor(colors.gray)
                term.write(" (" .. p.health .. "%)")
            end
        end

        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write("[action] Next day")

    elseif state == "win" then
        term.setTextColor(colors.lime)
        term.setCursorPos(2, textY)
        term.write("*** RESCUED ***")
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + 1 + i)
            term.write(line)
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, textY + #messageLines + 3)
        term.write("Final score: " .. (alive() * 100 + food + fuel + ammo * 5))

        local countdown = math.max(0, 15 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write(hint)

    elseif state == "lose" then
        term.setTextColor(colors.red)
        term.setCursorPos(2, textY)
        term.write("*** EXPEDITION FAILED ***")
        term.setTextColor(colors.white)
        for i, line in ipairs(messageLines) do
            term.setCursorPos(2, textY + 1 + i)
            term.write(line)
        end
        term.setTextColor(colors.gray)
        term.setCursorPos(2, textY + #messageLines + 3)
        term.write("Survived " .. day .. " days. " .. alive() .. " of 4 remaining.")

        local countdown = math.max(0, 15 - math.floor(gameOverTimer))
        local hint = "[action] Restart  [alt] Menu  (" .. countdown .. ")"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, height - 1)
        term.write(hint)
    end

    term.setBackgroundColor(colors.black)
end

function game.cleanup()
end

return game
