-- Objectives.lua: where the quests in your log send you: each unfinished objective's spots, and the hand-in once done (Completo.Objectives).
local ns = _G.NaowhForever

local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local GetQuestObjectives = C_QuestLog.GetQuestObjectives
local GetQuestWatchType = C_QuestLog.GetQuestWatchType
local IsComplete = C_QuestLog.IsComplete
local IsFailed = C_QuestLog.IsFailed

local Completo = ns.Completo
local Q = Completo.Quests
local D = ns.CompletoQuestData
local SameMap = ns.Shared.Places.SameMap

local PLACE, ITEM, FIRST_SOURCE = 1, 2, 3
local KIND, NAME, MAP, FIRST_SPOT = 1, 2, 3, 4
local HAND_IN_NAME, HAND_IN_MAP, HAND_IN_X, HAND_IN_Y = 1, 2, 3, 4
local ITEM_TYPE = "item"
local SPOT_KEY = 1000
local NONE = {}

local Objectives = {}
Completo.Objectives = Objectives

local List = {}
List.__index = List

local function Recycle(list)
    local spots = list.spots
    for i = #spots, 1, -1 do
        local spot = spots[i]
        for j = #spot.lines, 1, -1 do
            list.linesSpare[#list.linesSpare + 1] = wipe(spot.lines[j])
            spot.lines[j] = nil
        end
        list.spare[#list.spare + 1] = spot
        spots[i] = nil
    end
    wipe(list.objectiveAt)
    wipe(list.handInAt)
end

local function SpotFor(list, map, x, y, handIn)
    local at = handIn and list.handInAt or list.objectiveAt
    local key = (map * SPOT_KEY + x) * SPOT_KEY + y
    local spot = at[key]
    if spot then return spot end
    spot = table.remove(list.spare) or { lines = {} }
    spot.map, spot.x, spot.y, spot.handIn = map, x, y, handIn
    list.spots[#list.spots + 1] = spot
    at[key] = spot
    return spot
end

local function AddLine(list, spot, quest, text, source, kind, item, place)
    local line = table.remove(list.linesSpare) or {}
    line.quest, line.text, line.source, line.kind, line.item, line.place = quest, text, source, kind, item, place
    spot.lines[#spot.lines + 1] = line
end

local function Kind(objective, item)
    return (objective.type == ITEM_TYPE) == item
end

local function Count(objectives, item)
    local n = 0
    for _, objective in ipairs(objectives) do
        if Kind(objective, item) then n = n + 1 end
    end
    return n
end

local function Nth(objectives, item, place)
    for _, objective in ipairs(objectives) do
        if Kind(objective, item) then
            place = place - 1
            if place == 0 then return objective end
        end
    end
    return nil
end

local function AllDone(objectives, item)
    for _, objective in ipairs(objectives) do
        if Kind(objective, item) and not objective.finished then return false end
    end
    return Count(objectives, item) > 0
end

local function AddSources(list, quest, entry, objective)
    local text = objective and objective.text
    for i = FIRST_SOURCE, #entry do
        local source = entry[i]
        if list.hosts[SameMap(source[MAP])] then
            for s = FIRST_SPOT, #source, 2 do
                AddLine(list, SpotFor(list, source[MAP], source[s], source[s + 1], false), quest, text, source[NAME],
                    source[KIND], entry[ITEM] == 1, entry[PLACE])
            end
        end
    end
end

function Objectives.Progress(objectives, place, item)
    if place == 0 and Count(objectives, item) == 1 then place = 1 end
    local objective = place > 0 and Nth(objectives, item, place) or nil
    if objective then return objective, objective.finished end
    return nil, AllDone(objectives, item)
end

local function AddObjectives(list, quest)
    local entries = D.Objectives[quest]
    if not entries then return end
    local objectives = GetQuestObjectives(quest) or NONE
    for _, entry in ipairs(entries) do
        local objective, done = Objectives.Progress(objectives, entry[PLACE], entry[ITEM] == 1)
        if not done then AddSources(list, quest, entry, objective) end
    end
end

local function AddHandIn(list, quest)
    local hand = D.HandIns[quest]
    if hand and list.hosts[SameMap(hand[HAND_IN_MAP])] then
        AddLine(list, SpotFor(list, hand[HAND_IN_MAP], hand[HAND_IN_X], hand[HAND_IN_Y], true), quest, nil,
            hand[HAND_IN_NAME])
    end
end

function List:ForMaps(mapIDs, trackedOnly)
    Recycle(self)
    wipe(self.hosts)
    for _, mapID in ipairs(mapIDs) do self.hosts[SameMap(mapID)] = true end
    for i = 1, GetNumQuestLogEntries() do
        local quest = GetQuestIDForLogIndex(i)
        if quest and quest > 0 and not IsFailed(quest) and not Q.Hidden(quest)
            and (not trackedOnly or GetQuestWatchType(quest)) then
            if IsComplete(quest) then
                AddHandIn(self, quest)
            else
                AddObjectives(self, quest)
            end
        end
    end
    return self.spots
end

function Objectives.List()
    return setmetatable({ spots = {}, spare = {}, objectiveAt = {}, handInAt = {}, linesSpare = {}, hosts = {} }, List)
end
