local config = {}

config.network = {
    channel = 123,
    modemSide = nil,
}

config.system = {
    tickRate = 0.05,
    gameDir = "games",
    gamePrefix = "game_",
    testGame = "game_test_inputs",
}

-- master computer have 2 redstone sides:
--              reset left  ( black glazed terracotta in red / freq #1 slot and white wool in blue / freq #2 slot)
--              power right ( black glazed terracotta in red / freq #1 slot and red wool in blue / freq #2 slot)

config.redstone = {
    resetSide = "left",
    powerSide = "right",
    debounceTicks = 0.3,
}

-- Player colors (Glazed Terracotta in the blue / freq #2 slot)
-- 1: Blue
-- 2: Orange

-- Action colors (wool in the red / freq #1 slot)
-- up: Yellow
-- down: Green
-- left: Blue
-- right: Red
-- action: White
-- alt: Black

-- Redstone sides per transmitter: top, left, right, back (4 sides)
-- Each player needs 2.5 computers to cover all 6 inputs



config.keyMappings = {
    [3] = {
        top   = "p1_up",
        left  = "p1_left",
        right = "p1_right",
        back  = "p1_down",
    },
    [4] = {
        top   = "p1_action",
        back  = "p1_alt",
        left   = "p2_action",
        right  = "p2_alt",
    },
    [5] = {
        top   = "p2_up",
        left  = "p2_left",
        right = "p2_right",
        back  = "p2_down",
    },
}

config.actions = {
    menu_up     = "p1_up",
    menu_down   = "p1_down",
    menu_select = "p1_action",
    back_hold1  = "p1_alt",
    back_hold2  = "p1_action",
    back_ticks  = 20,
}

config.sound = {
    enabled = true,
}

config.screensaver = {
    screenDir = "screens",
    screenPrefix = "screen_",
    tickRate = 0.15,
    baseTime = 300,
    deltaTime = 180,
    minTime = 60,
}

return config
