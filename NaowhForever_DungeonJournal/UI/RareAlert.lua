-- RareAlert.lua: Rare Alert: a toast and a chime when one of this dungeon's rares is seen alive; its Target button targets it and marks it with a skull.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Kills = J.Kills
local Parts = ns.Shared.Parts

local FIRST_GAP = 4
local GAP_GROWTH = 2
local CHIMES = 4
local CHIME = SOUNDKIT.MAP_PING
local CHANNEL = "Master"
local TOAST_SECONDS = 60
local TOAST_W, TOAST_ICONS = 360, 1
local TARGET_W, DISMISS_W = 100, 90
local GLOW_ALPHA = 0.15
local COVER_LIFT = 1
local FACES, NO_FACES = { "Interface\\Icons\\INV_Misc_QuestionMark" }, {}
local SKULL = 8
local TARGET_MACRO = "/cleartarget\n/targetexact %s"
local SKULL_MACRO = TARGET_MACRO .. "\n/tm [exists] !" .. SKULL
local CONTROL = "%c"
local NAMEPLATE = "^nameplate"
local TOAST_NAME = "NaowhForeverJournalRareToast"
local POS_KEY = "rareAlertPos"
local NO_DUNGEONS = {}
local DUNGEON_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local TEXT_LINE = ns.L("A rare of this dungeon is up")
local TEXT_COMBAT = ns.L("A rare of this dungeon is up. Leave combat to target it from here.")
local TEXT_TARGET, TEXT_DISMISS = "Target", "Dismiss"

local rares, seen = {}, {}
local events, toast, cover, timer
local activeBoss, activeNpc, activeName, activeUnit
local chimes, gap = 0, FIRST_GAP

local function On()
    return S.Get("enabled") and S.Get("rareAlert") and true or false
end

local function CanMark()
    return not IsInRaid() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function Silence()
    if timer then timer:Cancel() end
    timer = nil
end

local function Chime()
    PlaySound(CHIME, CHANNEL)
    chimes = chimes + 1
    if chimes >= CHIMES then
        timer = nil
        return
    end
    timer = C_Timer.NewTimer(gap, Chime)
    gap = gap * GAP_GROWTH
end

local function HideCover()
    if not cover or InCombatLockdown() then return end
    cover:Hide()
    cover:ClearAllPoints()
end

local function End()
    if not activeNpc then return end
    activeBoss, activeNpc, activeName, activeUnit = nil, nil, nil, nil
    Silence()
    HideCover()
    if toast:IsShown() then toast:Hide() end
end

local function OnCoverClick(_, _, down)
    if not down then End() end
end

local function BuildCover()
    cover = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    cover:SetFrameStrata(toast:GetFrameStrata())
    cover:RegisterForClicks("AnyUp", "AnyDown")
    cover:SetAttribute("type", "macro")
    ns.Solid(cover, "HIGHLIGHT", ns.THEME.fg, GLOW_ALPHA):SetAllPoints()
    cover:SetScript("PostClick", OnCoverClick)
    cover:Hide()
end

local function PlaceCover()
    if InCombatLockdown() or not (activeNpc and toast:IsShown()) then return end
    if not cover then BuildCover() end
    local button = toast.buttons[1]
    local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local macro = CanMark() and SKULL_MACRO or TARGET_MACRO
    cover:SetAttribute("macrotext", macro:format(activeName))
    cover:ClearAllPoints()
    cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", button:GetLeft() * scale, button:GetBottom() * scale)
    cover:SetSize(button:GetWidth() * scale, button:GetHeight() * scale)
    cover:SetFrameLevel(button:GetFrameLevel() + COVER_LIFT)
    cover:Show()
end

local function Fill(combat)
    local model = activeBoss.model
    Parts.FillToast(toast, activeName, combat and TEXT_COMBAT or TEXT_LINE, model and FACES or NO_FACES)
    if model then SetPortraitTextureFromCreatureDisplayID(toast.icons[1], model) end
end

local function Waiting()
    return activeNpc ~= nil
end

local function Build()
    toast = Parts.Toast({ name = TOAST_NAME, width = TOAST_W, icons = TOAST_ICONS, store = S, posKey = POS_KEY,
        on = Waiting, buttons = { { text = TEXT_TARGET, width = TARGET_W, click = Silence, accent = true },
            { text = TEXT_DISMISS, width = DISMISS_W, click = End } } })
    toast:HookScript("OnShow", PlaceCover)
    toast:HookScript("OnHide", End)
    toast:HookScript("OnDragStop", PlaceCover)
end

local function NpcOf(unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return nil end
    return J.NpcID(guid)
end

local function Alive(unit)
    local dead = UnitIsDead(unit)
    return not issecretvalue(dead) and not dead
end

local function NameOf(unit, boss)
    local name = UnitName(unit)
    if not name or issecretvalue(name) then return boss.name end
    return (name:gsub(CONTROL, ""))
end

local function Alert(boss, npc, unit)
    if not toast then Build() end
    End()
    activeBoss, activeNpc, activeName = boss, npc, NameOf(unit, boss)
    activeUnit = unit:find(NAMEPLATE) and unit or nil
    Fill(InCombatLockdown())
    Parts.ShowToast(toast, TOAST_SECONDS)
    if not S.Get("rareAlertSound") then return end
    chimes, gap = 0, FIRST_GAP
    Chime()
    if unit == "target" then Silence() end
end

local function Check(unit)
    local npc = NpcOf(unit)
    local boss = npc and rares[npc]
    if not boss then return end
    if npc == activeNpc then
        if unit == "target" or not Alive(unit) then
            End()
        elseif unit:find(NAMEPLATE) then
            activeUnit = unit
        end
        return
    end
    local run = Kills.RunStart()
    if not run or seen[npc] == run or not Alive(unit) then return end
    seen[npc] = run
    Alert(boss, npc, unit)
end

local function Combat(combat)
    if not activeNpc then return end
    Fill(combat)
    if combat then
        HideCover()
    else
        PlaceCover()
    end
end

local function Enter()
    wipe(rares)
    for _, dungeon in ipairs(J.Current() or NO_DUNGEONS) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.rare and boss.npc then rares[boss.npc] = boss end
            end
        end
    end
    if next(rares) then
        for _, event in ipairs(DUNGEON_EVENTS) do events:RegisterEvent(event) end
        return
    end
    for _, event in ipairs(DUNGEON_EVENTS) do events:UnregisterEvent(event) end
    End()
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        Enter()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Check(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if unit == activeUnit then End() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Check("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Check("mouseover")
    else
        Combat(event == "PLAYER_REGEN_DISABLED")
    end
end

local function Sync()
    local on = On()
    if not (on or events) then return end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    if not on then
        events:UnregisterAllEvents()
        End()
        return
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Enter()
end

function ns.JournalRareHere(npc)
    return On() and rares[npc] ~= nil and Kills.RunStart() ~= nil
end

local function OnSettingChanged(key, value)
    if key == "enabled" or key == "rareAlert" then Sync() end
    if key == "rareAlertSound" and not value then Silence() end
end

S.OnChange(OnSettingChanged)
ns.OnApply(Sync)
