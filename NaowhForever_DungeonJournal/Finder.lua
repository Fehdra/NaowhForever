-- Finder.lua: the Loot Finder's rules: what each pick means, which dungeon loot matches, and its order (J.Finder).
local ns = _G.NaowhForever

local J = ns.Journal
local FACT = J.FACT
local INV = Enum.InventoryType

local ARMOR = J.C.ITEM_ARMOR
local NO_ARMOR_TYPE = 0
local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4
local SLOT = 1
local LOWEST_LEVEL = 1
local NO_CHANCE = -1
local STAT = {
    AGILITY = 3, STRENGTH = 4, INTELLECT = 5, SPIRIT = 6, STAMINA = 7, DEFENSE = 12, HIT = 31, CRIT = 32,
    ATTACK_POWER = 38, RANGED_ATTACK_POWER = 39, HEALING = 41, SPELL_DAMAGE = 42, MANA_PER_5 = 43, SPELL_POWER = 45,
    FIRE_RESISTANCE = 51, FROST_RESISTANCE = 52, SHADOW_RESISTANCE = 54, NATURE_RESISTANCE = 55,
    ARCANE_RESISTANCE = 56, FIRE_DAMAGE = 85, NATURE_DAMAGE = 86, FROST_DAMAGE = 87, SHADOW_DAMAGE = 88,
    ARCANE_DAMAGE = 89,
}
local LEVEL_BANDS = { { 1, 20 }, { 21, 30 }, { 31, 40 }, { 41, 50 }, { 51, 60 } }
local BAND_LABEL = "%d-%d"

local TEXT_YOUR_LEVEL = ns.L("Up to Your Level")

local function Set(...)
    local set = {}
    for i = 1, select("#", ...) do set[select(i, ...)] = true end
    return set
end

local function SlotPick(global, ...)
    return { global = global, slots = Set(...) }
end

local function StatPick(label, ...)
    return { label = ns.L(label), stats = Set(...) }
end

local GROUPS = {
    { kind = "slot", title = ns.L("Slot"), picks = {
        SlotPick("INVTYPE_HEAD", INV.IndexHeadType),
        SlotPick("INVTYPE_NECK", INV.IndexNeckType),
        SlotPick("INVTYPE_SHOULDER", INV.IndexShoulderType),
        SlotPick("INVTYPE_CLOAK", INV.IndexCloakType),
        SlotPick("INVTYPE_CHEST", INV.IndexChestType, INV.IndexRobeType),
        SlotPick("INVTYPE_WRIST", INV.IndexWristType),
        SlotPick("INVTYPE_HAND", INV.IndexHandType),
        SlotPick("INVTYPE_WAIST", INV.IndexWaistType),
        SlotPick("INVTYPE_LEGS", INV.IndexLegsType),
        SlotPick("INVTYPE_FEET", INV.IndexFeetType),
        SlotPick("INVTYPE_FINGER", INV.IndexFingerType),
        SlotPick("INVTYPE_TRINKET", INV.IndexTrinketType),
        SlotPick("INVTYPE_WEAPON", INV.IndexWeaponType, INV.IndexWeaponmainhandType, INV.IndexWeaponoffhandType),
        SlotPick("INVTYPE_2HWEAPON", INV.Index2HweaponType),
        SlotPick("INVTYPE_WEAPONOFFHAND", INV.IndexShieldType, INV.IndexWeaponoffhandType, INV.IndexHoldableType),
        SlotPick("INVTYPE_RANGED", INV.IndexRangedType, INV.IndexThrownType, INV.IndexRangedrightType,
            INV.IndexRelicType),
    } },
    { kind = "armor", title = ns.L("Armor"), picks = {
        { label = ns.L("Cloth"), subclass = CLOTH }, { label = ns.L("Leather"), subclass = LEATHER },
        { label = ns.L("Mail"), subclass = MAIL }, { label = ns.L("Plate"), subclass = PLATE },
    } },
    { kind = "stat", title = ns.L("Stats"), all = true, picks = {
        StatPick("Strength", STAT.STRENGTH),
        StatPick("Agility", STAT.AGILITY),
        StatPick("Stamina", STAT.STAMINA),
        StatPick("Intellect", STAT.INTELLECT),
        StatPick("Spirit", STAT.SPIRIT),
        StatPick("Attack Power", STAT.ATTACK_POWER, STAT.RANGED_ATTACK_POWER),
        StatPick("Spell Power", STAT.SPELL_POWER, STAT.SPELL_DAMAGE, STAT.FIRE_DAMAGE, STAT.NATURE_DAMAGE,
            STAT.FROST_DAMAGE, STAT.SHADOW_DAMAGE, STAT.ARCANE_DAMAGE),
        StatPick("Healing", STAT.HEALING, STAT.SPELL_POWER),
        StatPick("Crit", STAT.CRIT),
        StatPick("Hit", STAT.HIT),
        StatPick("Mana per 5", STAT.MANA_PER_5),
        StatPick("Defense", STAT.DEFENSE),
    } },
    { kind = "stat", title = ns.L("Resistances"), all = true, picks = {
        StatPick("Fire", STAT.FIRE_RESISTANCE),
        StatPick("Frost", STAT.FROST_RESISTANCE),
        StatPick("Nature", STAT.NATURE_RESISTANCE),
        StatPick("Shadow", STAT.SHADOW_RESISTANCE),
        StatPick("Arcane", STAT.ARCANE_RESISTANCE),
    } },
    { kind = "level", title = ns.L("Level"), picks = { { label = TEXT_YOUR_LEVEL, mine = true } } },
}

for _, band in ipairs(LEVEL_BANDS) do
    local picks = GROUPS[#GROUPS].picks
    picks[#picks + 1] = { label = BAND_LABEL:format(band[1], band[2]), low = band[1], high = band[2] }
end

for _, group in ipairs(GROUPS) do
    group.chosen = {}
    for _, pick in ipairs(group.picks) do pick.group = group end
end

local picked = {}
local active = {}
local entries
local hidden = {}

local function HasStat(stats, set)
    for i = SLOT + 1, #stats do
        if set[stats[i]] then return true end
    end
    return false
end

local function Fits(group, pick, facts, stats, level)
    local kind = group.kind
    if kind == "slot" then return pick.slots[stats[SLOT]] == true end
    if kind == "stat" then return HasStat(stats, pick.stats) end
    if kind == "armor" then
        local subclass = facts[FACT.SUBCLASS]
        return facts[FACT.CLASS] == ARMOR and (subclass == pick.subclass or subclass == NO_ARMOR_TYPE)
    end
    local required = math.max(facts[FACT.REQUIRED], LOWEST_LEVEL)
    if pick.mine then return required <= level end
    return required >= pick.low and required <= pick.high
end

local function GroupFits(group, facts, stats, level)
    local chosen = group.chosen
    local all = group.all == true
    for i = 1, #chosen do
        if Fits(group, chosen[i], facts, stats, level) ~= all then return not all end
    end
    return all
end

local function Before(a, b)
    if a.required ~= b.required then return a.required < b.required end
    if a.chance ~= b.chance then return a.chance > b.chance end
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    return a.order < b.order
end

local Finder = { GROUPS = GROUPS }
J.Finder = Finder

function Finder.Label(pick)
    return pick.label or _G[pick.global]
end

function Finder.Picked(pick)
    return picked[pick] == true
end

function Finder.Toggle(pick)
    picked[pick] = not picked[pick] or nil
    local group = pick.group
    wipe(group.chosen)
    for _, each in ipairs(group.picks) do
        if picked[each] then group.chosen[#group.chosen + 1] = each end
    end
    wipe(active)
    for _, each in ipairs(GROUPS) do
        if #each.chosen > 0 then active[#active + 1] = each end
    end
end

function Finder.Clear()
    wipe(picked)
    wipe(active)
    for _, group in ipairs(GROUPS) do wipe(group.chosen) end
end

function Finder.Any()
    return next(picked) ~= nil
end

local function Matches(entry, level)
    for i = 1, #active do
        if not GroupFits(active[i], entry.facts, entry.stats, level) then return false end
    end
    return true
end

local function Entry(itemID, chance, boss, dungeon)
    local facts = J.Facts(itemID)
    return { item = itemID, boss = boss, dungeon = dungeon, facts = facts, stats = J.ItemStats[itemID],
        chance = chance and chance > 0 and chance or NO_CHANCE, required = math.max(facts[FACT.REQUIRED], LOWEST_LEVEL),
        itemLevel = facts[FACT.ITEM_LEVEL] }
end

local function Entries()
    entries = {}
    for _, dungeon in ipairs(J.Dungeons()) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                local loot, chance = boss.loot, boss.chance
                for i = 1, loot and #loot or 0 do
                    if J.ItemStats[loot[i]] then
                        local entry = Entry(loot[i], chance and chance[i], boss, dungeon)
                        entry.order = #entries + 1
                        entries[entry.order] = entry
                    end
                end
            end
        end
    end
    table.sort(entries, Before)
end

function Finder.Collect(out, Shown, owner, level)
    wipe(out)
    if not entries then Entries() end
    for _, dungeon in ipairs(J.Dungeons()) do hidden[dungeon] = not J.FactionShown(dungeon) end
    local n = 0
    for i = 1, #entries do
        local entry = entries[i]
        if not hidden[entry.dungeon] and Matches(entry, level) and Shown(owner, entry.item) then
            n = n + 1
            out[n] = entry
        end
    end
    return n
end
