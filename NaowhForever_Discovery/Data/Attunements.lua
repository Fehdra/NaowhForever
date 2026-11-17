-- Attunements.lua: the keys and attunements dungeons and raids ask for, each with the quest that gives it.
local ns = _G.NaowhForever

local BLACKROCK_DEPTHS = "Blackrock Depths"
local BLACKROCK_SPIRE = "Lower Blackrock Spire"
local MARAUDON = "Maraudon"
local WINDSOR = "Marshal Windsor"
local INFILTRATOR = "Scarshield Infiltrator"

ns.Attunements = {
    list = {
        { dungeon = MARAUDON, item = 17191, quest = 7046 },
        { dungeon = BLACKROCK_DEPTHS, item = 11000, quest = 3802 },
        { dungeon = "Scholomance", item = 13704, quest = { A = 5505, H = 5511 } },
        { dungeon = "Molten Core", icon = 18412, quest = 7848, raid = true },
        { dungeon = "Upper Blackrock Spire", item = 12344, quest = 4743 },
        { dungeon = "Onyxia's Lair", item = 16309, quest = { A = 6502, H = 6602 }, raid = true },
    },
    inside = {
        [4242] = { BLACKROCK_DEPTHS, WINDSOR }, [4264] = { BLACKROCK_DEPTHS }, [4282] = { BLACKROCK_DEPTHS, WINDSOR },
        [4322] = { BLACKROCK_DEPTHS, WINDSOR },
        [4742] = { BLACKROCK_SPIRE, INFILTRATOR }, [4743] = { BLACKROCK_SPIRE, INFILTRATOR },
        [7046] = { MARAUDON, "Celebras the Redeemed" },
    },
}
