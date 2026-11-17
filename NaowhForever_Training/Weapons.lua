-- Weapons.lua: your weapon skills, the weapons you carry, and a weapon master's price (Training.WeaponSkills).
local ns = _G.NaowhForever

local Training = ns.Training

local LEVEL, SPELL = Training.C.ENTRY_LEVEL, Training.C.ENTRY_SPELL
local ROUND = Training.C.ROUND
local NPC_NAME = 4
local WEAPON_CLASS = 2
local WANDS_SPELL = 5009
local BAG_FIRST, BAG_LAST = 0, 4
local MAIN_HAND, OFF_HAND, RANGED = 16, 17, 18
local WEAPON_SLOTS = { MAIN_HAND, OFF_HAND, RANGED }
local BASE_COST = 1000
local FRIENDLY, HONORED, REVERED, EXALTED = 5, 6, 7, 8
local DISCOUNT = { [FRIENDLY] = 0.05, [HONORED] = 0.10, [REVERED] = 0.15, [EXALTED] = 0.20 }
local STORMWIND, IRONFORGE, GNOMEREGAN, DARNASSUS = 72, 47, 54, 69
local ORGRIMMAR, THUNDER_BLUFF, UNDERCITY = 76, 81, 68
local MASTER_FACTION = {
    ["Woo Ping"] = STORMWIND, ["Buliwyf Stonehand"] = IRONFORGE, ["Bixi Wobblebonk"] = GNOMEREGAN,
    ["Ilyenia Moonfire"] = DARNASSUS, ["Hanashi"] = ORGRIMMAR, ["Sayoc"] = ORGRIMMAR,
    ["Ansekhwa"] = THUNDER_BLUFF, ["Archibald"] = UNDERCITY,
}
local SKILL_BY_SPELL = {
    [196] = 44, [197] = 172, [198] = 54, [199] = 160, [200] = 229, [201] = 43, [202] = 55, [227] = 136,
    [264] = 45, [266] = 46, [1180] = 173, [2567] = 176, [5011] = 226, [15590] = 473, [WANDS_SPELL] = 228,
}
local SPELL_BY_SUBCLASS = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201, [8] = 202,
    [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = WANDS_SPELL,
}
local EQUIPPED, BAGS = "equipped", "bags"

local function Weapon(itemID)
    if not itemID then return end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID == WEAPON_CLASS then return SPELL_BY_SUBCLASS[subClassID] end
end

local function Carried()
    local where = {}
    for _, slot in ipairs(WEAPON_SLOTS) do
        local spell = Weapon(GetInventoryItemID("player", slot))
        if spell then where[spell] = EQUIPPED end
    end
    for bag = BAG_FIRST, BAG_LAST do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local spell = Weapon(C_Container.GetContainerItemID(bag, slot))
            if spell and not where[spell] then where[spell] = BAGS end
        end
    end
    return where
end

local function Reaction(factionID)
    local data = C_Reputation.GetFactionDataByID(factionID)
    return data and data.reaction
end

local function Skill(spell)
    local line = SKILL_BY_SPELL[spell]
    local info = line and C_SkillInfo.GetSkillLineInfoByID(line)
    if info and info.maxRank and info.maxRank > 0 then return info end
end

local function ClassWeapons()
    local _, _, classID = UnitClass("player")
    local list = {}
    for _, entry in ipairs(ns.TrainingWeapons[classID] or {}) do list[#list + 1] = entry end
    if C_SpellBook.IsSpellKnown(WANDS_SPELL) then list[#list + 1] = { 1, WANDS_SPELL, 0 } end
    return list
end

local function ByWhere(a, b)
    if (a.where == EQUIPPED) ~= (b.where == EQUIPPED) then return a.where == EQUIPPED end
    if (a.where ~= nil) ~= (b.where ~= nil) then return a.where ~= nil end
    return (C_Spell.GetSpellName(a.spell) or "") < (C_Spell.GetSpellName(b.spell) or "")
end

function Training.WeaponPrice(entry)
    if not entry.masters then return end
    local npc = Training.NearestMaster(entry)
    local faction = npc and MASTER_FACTION[npc[NPC_NAME]]
    local discount = faction and DISCOUNT[Reaction(faction) or 0] or 0
    return math.floor(BASE_COST * (1 - discount) + ROUND)
end

function Training.WeaponSkills(all)
    local where = Carried()
    local known, learn = {}, {}
    for _, entry in ipairs(ClassWeapons()) do
        local spell = entry[SPELL]
        local row = { entry = entry, spell = spell, where = where[spell] }
        if C_SpellBook.IsSpellKnown(spell) then
            row.skill = Skill(spell)
            if all or row.where then known[#known + 1] = row end
        else
            row.level = entry[LEVEL]
            learn[#learn + 1] = row
        end
    end
    table.sort(known, ByWhere)
    table.sort(learn, ByWhere)
    return { known = known, learn = learn }
end
