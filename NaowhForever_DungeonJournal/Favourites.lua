-- Favourites.lua: this character's favourite items, where each drops, and the line naming them on entering a dungeon (J.Favourites).
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local J = ns.Journal
local S = J.Settings
local Have = J.Loot.Have

local STORE = "journalFavourites"
local LIST_GAP = ", "

local TEXT_HERE = ns.L("Your favourites here: %s.")
local TEXT_ITEM = ns.L("Item ")

local found, named = {}, {}
local frame, saidFor

local function Mine(create)
    return J.CharacterData(STORE, create)
end

local function Entry(out, id, page, from, chance)
    found[id] = true
    out[#out + 1] = { id = id, page = page, from = from, chance = chance }
end

local function FromBosses(out, dungeon, mine)
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            local loot, chance = boss.loot, boss.chance
            for i = 1, loot and #loot or 0 do
                local id = loot[i]
                if mine[id] == true and not found[id] then Entry(out, id, dungeon, boss, chance and chance[i]) end
            end
        end
    end
end

local function FromFaction(out, faction, mine)
    for _, tier in ipairs(faction.tiers) do
        for _, id in ipairs(tier.items) do
            if mine[id] == true and not found[id] then Entry(out, id, faction, tier) end
        end
    end
end

local function LinkOf(id)
    local link = not J.IsNotYet(id) and select(2, GetItemInfo(id))
    return link or J.Loot.Name(id) or TEXT_ITEM .. id
end

local function SayHere(dungeons)
    local mine = Mine(false)
    if not mine then return end
    wipe(found)
    wipe(named)
    local list = {}
    for i = 1, #dungeons do FromBosses(list, dungeons[i], mine) end
    for _, entry in ipairs(list) do
        if not Have(entry.id) then named[#named + 1] = LinkOf(entry.id) end
    end
    if #named > 0 then ns.Print(TEXT_HERE:format(table.concat(named, LIST_GAP))) end
end

local function OnEnteringWorld(_, _, _, reloading)
    local here = J.Current()
    if not here then
        saidFor = nil
        return
    end
    if saidFor == here[1].key then return end
    saidFor = here[1].key
    if not reloading then SayHere(here) end
end

local Favourites = {}
J.Favourites = Favourites

function Favourites.On()
    return S.Get("enabled") == true and S.Get("favourites") == true
end

function Favourites.Is(itemID)
    if not S.Get("favourites") then return false end
    local mine = Mine(false)
    return mine ~= nil and mine[itemID] == true
end

function Favourites.Toggle(itemID)
    local mine = Mine(true)
    if not mine then return end
    mine[itemID] = not Favourites.Is(itemID) or nil
end

function Favourites.List(out)
    wipe(out)
    wipe(found)
    local mine = Mine(false)
    if not mine then return out end
    for _, dungeon in ipairs(J.Dungeons()) do FromBosses(out, dungeon, mine) end
    for _, tab in ipairs(J.TABS) do
        for _, faction in ipairs(J.Factions(tab)) do FromFaction(out, faction, mine) end
    end
    for id, on in pairs(mine) do
        if on == true and type(id) == "number" and not found[id] then Entry(out, id) end
    end
    return out
end

local function Sync()
    local on = Favourites.On()
    if not (on or frame) then return end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEnteringWorld)
    end
    if on then frame:RegisterEvent("PLAYER_ENTERING_WORLD") else frame:UnregisterAllEvents() end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "favourites" then Sync() end
end

S.OnChange(OnSettingChanged)
ns.OnApply(Sync)
