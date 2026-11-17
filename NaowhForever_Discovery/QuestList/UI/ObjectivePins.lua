-- ObjectivePins.lua: the quests in your log on the world map: a mark where each unfinished objective is, and a ? where a done quest is handed in.
local ns = _G.NaowhForever

local GetTitle = C_QuestLog.GetTitleForQuestID

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Objectives = Completo.Objectives
local Party = Completo.Party
local Style = Completo.Style
local OpenMap = ns.Shared.OpenMap

local TEMPLATE = "NaowhForeverQuestObjectivePinTemplate"
local OBJECTIVE_ATLAS, HAND_IN_ATLAS = "questobjective", "questturnin"
local PERCENT = Completo.C.PERCENT
local OBJECTIVE_PIN_SCALE = 0.5
local OBJECT = 2
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_REMOVED", "QUEST_WATCH_LIST_CHANGED" }
local OWN_KEYS = { enabled = true, mapObjectives = true, mapObjectivesTracked = true, mapObjectivePinSize = true }
local TEXT_HAND_IN = ns.L("Hand in:")
local TEXT_DROPPED = ns.L("Dropped by %s")
local TEXT_FOUND = ns.L("Found in %s")
local TEXT_WAYPOINT = ns.L("Click for a waypoint (again to remove it).")
local TEXT_MEMBER = "  %s: %d/%d"

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local list = Objectives.List()
local menuQuests, inMenu = {}, {}
local added, events

local function ScaleObjectivePin(pin)
    ns.Shared.ScalePin(pin, OBJECTIVE_PIN_SCALE)
end

NaowhForeverQuestObjectivePinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverQuestObjectivePinMixin.ApplyCurrentScale = ScaleObjectivePin

local function On()
    return S.Get("enabled") and S.Get("mapObjectives")
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function AddMember(name, objective)
    GameTooltip:AddLine(TEXT_MEMBER:format(name, objective.numFulfilled, objective.numRequired), Style.Hint())
end

local function Title(spot)
    local line = spot.lines[1]
    if spot.handIn or line.item ~= true then return line.source end
    return (line.kind == OBJECT and TEXT_FOUND or TEXT_DROPPED):format(line.source)
end

function NaowhForeverQuestObjectivePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverQuestObjectivePinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverQuestObjectivePinMixin:Paint(spot, size)
    self.target = spot
    self:SetSize(size, size)
    self.Icon:SetAtlas(spot.handIn and HAND_IN_ATLAS or OBJECTIVE_ATLAS)
end

function NaowhForeverQuestObjectivePinMixin:OnAcquired(spot, x, y)
    ns.Shared.PinClicks(self)
    self:Paint(spot, S.Get("mapObjectivePinSize"))
    self:SetPosition(x, y)
    self:ApplyCurrentScale()
end

function NaowhForeverQuestObjectivePinMixin:OnMouseEnter()
    local spot = self.target
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Title(spot), 1, 1, 1)
    if spot.handIn then GameTooltip:AddLine(TEXT_HAND_IN, gold.r, gold.g, gold.b) end
    for _, line in ipairs(spot.lines) do
        GameTooltip:AddLine(GetTitle(line.quest) or "", gold.r, gold.g, gold.b)
        if line.text then GameTooltip:AddLine(line.text, 1, 1, 1, true) end
        if line.place then Party.Progress(line.quest, line.place, line.item == true, AddMember) end
    end
    GameTooltip:AddLine(TEXT_WAYPOINT, Style.Hint())
    GameTooltip:AddLine(Completo.TEXT_HIDE_HINT, Style.Hint())
    GameTooltip:Show()
end

function NaowhForeverQuestObjectivePinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverQuestObjectivePinMixin:OnClick(button)
    local spot = self.target
    if button == "RightButton" then
        wipe(menuQuests)
        wipe(inMenu)
        for _, line in ipairs(spot.lines) do
            if not inMenu[line.quest] then
                inMenu[line.quest] = true
                menuQuests[#menuQuests + 1] = line.quest
            end
        end
        return Completo.HideMenu(self, menuQuests)
    end
    if button ~= "LeftButton" then return end
    ns.ToggleWaypoint(Title(spot), spot.map, spot.x, spot.y)
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    for _, spot in ipairs(list:ForMaps(OpenMap.Maps(map), S.Get("mapObjectivesTracked"))) do
        local x, y = OpenMap.Spot(map, spot.map, spot.x / PERCENT, spot.y / PERCENT)
        if x then map:AcquirePin(TEMPLATE, spot, x, y) end
    end
end

local function Apply()
    if On() then
        if not added then
            WorldMapFrame:AddDataProvider(provider)
            added = true
        end
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", Redraw)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Redraw()
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(Q, "SetHidden", Redraw)
hooksecurefunc(Q, "ShowHidden", Redraw)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
