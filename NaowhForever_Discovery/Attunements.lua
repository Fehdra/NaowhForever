-- Attunements.lua: the attunement rules: each one's quests in order, the one you are on, where a quest starts (Discovery.Attune).
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local Library = Discovery.Library

local INSIDE_DUNGEON, INSIDE_GIVER = 1, 2
local TEXT_WHERE = "%s, %s (%.1f, %.1f)"
local TEXT_INSIDE = ns.L("Inside %s")
local TEXT_GIVER_INSIDE = ns.L("%s, inside %s")
local TEXT_NOTE = " (%s)"

local steps = {}

local Attune = {}
Discovery.Attune = Attune

local function Before(Q, element)
    if type(element) == "number" then return Q.Mine(element) and element end
    for _, id in ipairs(element) do
        if Q.Mine(id) then return id end
    end
end

local function Walk(Q, id, out, seen)
    if seen[id] then return end
    seen[id] = true
    for _, element in ipairs(Q.Requires(id)) do
        local before = Before(Q, element)
        if before then Walk(Q, before, out, seen) end
    end
    out[#out + 1] = id
end

local function Quest(entry)
    local quest = entry.quest
    if type(quest) == "table" then return quest[Library.Side()] end
    return quest
end

function Attune.Steps(entry)
    local list = steps[entry]
    if not list then
        local Q = ns.Completo.Quests
        Q.Refresh()
        list = {}
        Walk(Q, Quest(entry), list, {})
        steps[entry] = list
    end
    return list
end

function Attune.At(entry)
    local list = Attune.Steps(entry)
    for i = #list, 1, -1 do
        if C_QuestLog.IsQuestFlaggedCompleted(list[i]) then return i + 1 end
    end
    return 1
end

function Attune.Have(entry)
    return entry.item ~= nil and C_Item.GetItemCount(entry.item, true) > 0
end

function Attune.Next(entry)
    local list = Attune.Steps(entry)
    local at = Attune.At(entry)
    if at > #list or Attune.Have(entry) then return nil end
    if at == 1 and UnitLevel("player") < ns.Completo.Quests.RequiredLevel(list[1]) then return nil end
    return list[at], at
end

function Attune.Open()
    for _, entry in ipairs(ns.Attunements.list) do
        if Attune.Next(entry) then return true end
    end
    return false
end

function Attune.State(id, i, at)
    if i < at then return "done" end
    if C_QuestLog.IsOnQuest(id) then return "log" end
    if i > at then return "later" end
    if UnitLevel("player") < ns.Completo.Quests.RequiredLevel(id) then return "low" end
    return "now"
end

function Attune.Name(id)
    return C_QuestLog.GetTitleForQuestID(id) or ns.Completo.Quests.Name(id)
end

function Attune.Title(entry)
    if entry.item then return C_Item.GetItemNameByID(entry.item) end
    return Attune.Name(Quest(entry))
end

function Attune.Icon(entry)
    return C_Item.GetItemIconByID(entry.icon or entry.item)
end

function Attune.Where(id)
    local Q = ns.Completo.Quests
    local map, x, y = Q.Spot(id)
    if map then return TEXT_WHERE:format(Q.Giver(id), Library.ZoneName(map), x, y) end
    local inside = ns.Attunements.inside[id]
    if not inside then return "" end
    local dungeon = ns.L(inside[INSIDE_DUNGEON])
    if inside[INSIDE_GIVER] then return TEXT_GIVER_INSIDE:format(inside[INSIDE_GIVER], dungeon) end
    return TEXT_INSIDE:format(dungeon)
end

function Attune.Waypoint(id)
    local Q = ns.Completo.Quests
    local map, x, y = Q.Spot(id)
    Library.Waypoint(Attune.Name(id), map, x, y, TEXT_NOTE:format(Q.Giver(id)))
end
