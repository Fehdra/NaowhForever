-- AttunePins.lua: each attunement's next quest on the world map, at who gives it, under the key's icon.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local Attune = Discovery.Attune
local Style = Discovery.Style
local OpenMap = ns.Shared.OpenMap

local GOLD = Style.GOLD_RGB
local TEMPLATE = "NaowhForeverAttunementPinTemplate"
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local OWN_KEYS = { enabled = true, attuneMapPins = true, attuneMapPinSize = true }
local ATTUNE_PIN_SCALE = 0.5
local TEXT_STEP = ns.L("%s, step %d of %d")
local TEXT_WAYPOINT = ns.L("Click for a waypoint.")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events

local function ScaleAttunePin(pin)
    ns.Shared.ScalePin(pin, ATTUNE_PIN_SCALE)
end

NaowhForeverAttunementPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverAttunementPinMixin.ApplyCurrentScale = ScaleAttunePin

local function On()
    return S.Get("enabled") and S.Get("attuneMapPins")
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function OnEvent(frame, event)
    if event ~= "QUEST_LOG_UPDATE" then
        frame:RegisterEvent("QUEST_LOG_UPDATE")
        return
    end
    frame:UnregisterEvent("QUEST_LOG_UPDATE")
    Redraw()
end

function NaowhForeverAttunementPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverAttunementPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverAttunementPinMixin:OnAcquired(entry, x, y)
    ns.Shared.PinClicks(self)
    self.entry = entry
    local size = S.Get("attuneMapPinSize")
    self:SetSize(size, size)
    self.Icon:SetTexture(Attune.Icon(entry.key) or C.FALLBACK_ICON)
    self.Icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    self:SetPosition(x, y)
    self:ApplyCurrentScale()
end

function NaowhForeverAttunementPinMixin:OnMouseEnter()
    local entry = self.entry
    local m, soft = T.muted, T.accentSoft
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TEXT_STEP:format(ns.L(entry.key.dungeon), entry.at, #Attune.Steps(entry.key)), 1, 1, 1)
    GameTooltip:AddLine(Attune.Name(entry.quest), GOLD.r, GOLD.g, GOLD.b)
    GameTooltip:AddLine(Attune.Where(entry.quest), m.r, m.g, m.b, true)
    GameTooltip:AddLine(TEXT_WAYPOINT, soft.r, soft.g, soft.b)
    GameTooltip:Show()
end

function NaowhForeverAttunementPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverAttunementPinMixin:OnClick(button)
    if button == "LeftButton" then Attune.Waypoint(self.entry.quest) end
end

local function AddKey(map, mapID, key)
    local quest, at = Attune.Next(key)
    if not quest then return end
    local questMap, questX, questY = ns.Completo.Quests.Spot(quest)
    if questMap ~= mapID then return end
    local x, y = OpenMap.Spot(map, mapID, questX / C.PERCENT, questY / C.PERCENT)
    if x then map:AcquirePin(TEMPLATE, { key = key, quest = quest, at = at }, x, y) end
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    for _, mapID in ipairs(OpenMap.Maps(map)) do
        for _, key in ipairs(ns.Attunements.list) do AddKey(map, mapID, key) end
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
            events:SetScript("OnEvent", OnEvent)
        end
        events:RegisterEvent("QUEST_ACCEPTED")
        events:RegisterEvent("QUEST_TURNED_IN")
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
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
