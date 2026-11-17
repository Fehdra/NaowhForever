-- UnitTips.lua: Quest Tooltips, a creature's tooltip names the quests it is for and where you and your party stand on each.
local ns = _G.NaowhForever

local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestObjectives = C_QuestLog.GetQuestObjectives
local GetTitle = C_QuestLog.GetTitleForQuestID
local IsComplete = C_QuestLog.IsComplete

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Objectives = Completo.Objectives
local Party = Completo.Party
local Style = Completo.Style
local D = ns.CompletoQuestData

local CREATURE, VEHICLE = "Creature", "Vehicle"
local STEP = 3
local QUEST_LINES = { [Enum.TooltipDataLineType.QuestObjective] = true, [Enum.TooltipDataLineType.QuestTitle] = true }
local TEXT_OBJECTIVE = "  - %s"
local TEXT_MEMBER = "  %s: %d/%d"
local NONE = {}

local hooked, tip, tipQuest
local named = {}

local function On()
    return S.Get("enabled") and S.Get("unitTips")
end

local function NpcID(guid)
    if issecretvalue(guid) or type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, entry = strsplit("-", guid)
    if kind ~= CREATURE and kind ~= VEHICLE then return nil end
    return tonumber(entry)
end

local function GameShowsQuests(data)
    for _, line in ipairs(data.lines or NONE) do
        if not issecretvalue(line.type) and QUEST_LINES[line.type] then return true end
    end
    return false
end

local function Name(tooltip, quest)
    if named[quest] then return end
    named[quest] = true
    local gold = Style.GOLD_RGB
    tooltip:AddLine(GetTitle(quest) or Q.Title(quest) or "", gold.r, gold.g, gold.b)
end

local function AddQuest(tooltip, quest, objective)
    Name(tooltip, quest)
    if objective then tooltip:AddLine(TEXT_OBJECTIVE:format(objective.text), 1, 1, 1) end
end

local function AddMember(name, objective)
    Name(tip, tipQuest)
    tip:AddLine(TEXT_MEMBER:format(name, objective.numFulfilled, objective.numRequired), Style.Hint())
end

local function OnUnit(tooltip, data)
    if tooltip ~= GameTooltip or tooltip:IsForbidden() or not On() or not data then return end
    local own = not GameShowsQuests(data)
    local npc = NpcID(data.guid)
    local list = npc and D.Creatures[npc]
    if not list then return end
    wipe(named)
    tip = tooltip
    for i = 1, #list, STEP do
        local quest, place, item = list[i], list[i + 1], list[i + 2] == 1
        if not Q.Hidden(quest) then
            if own and GetLogIndexForQuestID(quest) and not IsComplete(quest) then
                local objective, done = Objectives.Progress(GetQuestObjectives(quest) or NONE, place, item)
                if not done then AddQuest(tooltip, quest, objective) end
            end
            tipQuest = quest
            Party.Progress(quest, place, item, AddMember)
        end
    end
    if next(named) then tooltip:Show() end
end

local function Apply()
    if hooked or not On() then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
end

S.OnChange(function(key)
    if key == "enabled" or key == "unitTips" then Apply() end
end)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
