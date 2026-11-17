-- DungeonHeader.lua: the top of a dungeon's page: its name, entrance link, zone and stats.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local Kinds = J.View.Kinds
local Tip = ns.Shared.Parts.Tip
local St = J.Style
local BIS_CODE, LOOK_CODE, LOOK_RGB, TERRITORY_CODE = St.BIS_CODE, St.LOOK_CODE, St.LOOK_RGB, St.TERRITORY_CODE
local BANG, HANGER, PLACE_DOT = St.BANG, St.HANGER, St.PLACE_DOT
local STAR, BIS_RGB, DONE_MARK = St.STAR, St.BIS_RGB, St.DONE_MARK
local STAT_ICON, STAT_GAP, STAT_SPACE, STAT_LINE_H = St.STAT_ICON, St.STAT_GAP, St.STAT_SPACE, St.STAT_LINE_H
local TITLE_SIZE, TITLE_H, TITLE_GAP = St.TITLE_SIZE, St.TITLE_H, St.TITLE_GAP
local WHERE_H, HEADER_PAD, TEXT_SIZE = St.WHERE_H, St.HEADER_PAD, St.TEXT_SIZE
local ARROW, ACTION = St.ARROW, St.ACTION

local PIN_DROP = 0
local PIN_GAP, PIN_GAP_AFTER_MARK = 10, 6
local TITLE_ROOM = 10
local STAT_H = 16
local STAT_ICON_GAP = 2
local BANG_DROP = -1
local COMPACT_STAT_TOP, COMPACT_PAD = 6, 12
local FOREVER_H, FOREVER_GAP = 12, 8
local FOREVER_W = FOREVER_H * 2
local STEP_GAP = 4
local STEPS_W = ACTION * 2 + STEP_GAP
local PREVIOUS, NEXT = -1, 1
local STATS = { "quests", "bis", "looks" }
local CONTESTED = "Contested"
local ART_W, ART_H = 2992, 1684
local ART_MIDDLE = 0.45
local ART_SHADE, ART_ALPHA = 0.55, 0.9
local ART_ROOM = 16
local PAINT_W, PAINT_ALPHA = 420, 0.8
local PAINT = { left = 34 / 512, right = 360 / 512, top = 44, bottom = 292, size = 512, middle = 0.38 }
local FACTS_H, FACTS_GAP = 14, 5
local BUTTON_H, BUTTON_GAP, ENTRANCE_W, FIND_W = 22, 6, 84, 96
local HERE_GAP = 10
local COORDS = "%s %d, %d"

local TEXT_CLICK_BIS = ns.L("Click to see your BiS.")
local TEXT_ENTRANCE_LINK = ns.L("Entrance")
local TEXT_TO_DO = ns.L("%d to do")
local TEXT_SHOW_ENTRANCE = ns.L("Show the entrance on your map")
local TEXT_SHARE_ENTRANCE = ns.L("Right-click to share it in chat, or copy it.")
local TEXT_SHARE_TITLE = ns.L("Share the entrance")
local TEXT_ENTRANCE = ns.L(" entrance")
local TEXT_PLAYERS = ns.L(" players")
local TEXT_LEVEL = ns.L("Level ")
local TEXT_COUNT = "%s/%s"
local TEXT_CODE_END = "|r"
local TEXT_PREVIOUS = ns.L("Previous dungeon: %s")
local TEXT_NEXT = ns.L("Next dungeon: %s")
local TEXT_FIND_GROUP = "Find Group"
local TEXT_FIND_TIP = "Search the Group Finder for a group for this dungeon."
local TEXT_HERE = "You are here"
local TEXT_YOU_ARE = ns.L("you are %d")
local TEXT_KEYS_HELD = ns.L("%d of %d keys")
local TEXT_SAVED = ns.L("Saved, resets in %s")

local lockouts, lockoutsAt
local TERRITORY_TIP = {
    Alliance = ns.L("Alliance territory"), Horde = ns.L("Horde territory"),
    Contested = ns.L("Contested territory: both factions"),
}

local activities, activityOf, activitiesLevel = {}, {}, nil

local function StatEnter(stat)
    if not Tip(stat, "ANCHOR_BOTTOM") then return end
    local tip = stat.done and stat.doneTip or stat.total == 0 and stat.noneTip
        or stat.tipFormat:format(stat.have, stat.total)
    GameTooltip:SetText(tip, 1, 1, 1)
    if stat.onClick and stat.canClick() then
        GameTooltip:AddLine(stat.hint, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    end
    GameTooltip:Show()
end

local function StatClicked(stat, button)
    if button == "LeftButton" and stat.onClick and stat.canClick() then stat.onClick() end
end

local function StatIcon(stat, icon, tint, dy)
    stat.icon = stat:CreateTexture(nil, "ARTWORK")
    stat.icon:SetTexture(icon, nil, nil, "TRILINEAR")
    stat.icon:SetSize(STAT_ICON, STAT_ICON)
    stat.icon:SetPoint("LEFT", 0, dy)
    if tint then
        stat.icon:SetDesaturated(true)
        stat.icon:SetVertexColor(tint.r, tint.g, tint.b)
    end
    stat.text:SetPoint("LEFT", stat.icon, "RIGHT", stat.gap, -dy)
end

local function Stat(parent, label, tipFormat, doneTip, icon, tint, gap, dy)
    local stat = CreateFrame("Frame", nil, parent)
    stat:SetHeight(STAT_H)
    stat:EnableMouse(true)
    stat.tipFormat, stat.doneTip = tipFormat, doneTip
    stat.label = ns.Color("muted", " " .. label)
    stat.text = ns.Font(stat, TEXT_SIZE, nil, T.fg)
    stat.gap = icon and (gap or STAT_SPACE) or 0
    if icon then
        StatIcon(stat, icon, tint, dy or 0)
    else
        stat.text:SetPoint("LEFT")
    end
    stat:SetScript("OnEnter", StatEnter)
    stat:SetScript("OnLeave", GameTooltip_Hide)
    stat:SetScript("OnMouseUp", StatClicked)
    return stat
end

local function OpenBisList()
    ns.OpenBisWindow()
end

local function OpensBisList(stat)
    stat.onClick, stat.canClick, stat.hint = OpenBisList, Loot.BisOn, TEXT_CLICK_BIS
end

local function SetStat(stat, have, total, code, always)
    stat.have, stat.total, stat.done = have, total, total > 0 and have == total
    stat:SetShown(total > 0 or always == true)
    if not stat:IsShown() then return end
    local count = TEXT_COUNT:format(have, total)
    if code then count = code .. count .. TEXT_CODE_END end
    stat.text:SetText((stat.done and DONE_MARK or count) .. stat.label)
    stat:SetWidth((stat.icon and STAT_ICON + stat.gap or 0) + math.ceil(stat.text:GetStringWidth()))
end

local function SetQuests(stat, done, total)
    SetStat(stat, done, total)
    if not stat:IsShown() or stat.done then return end
    stat.text:SetText(TEXT_TO_DO:format(total - done))
    stat:SetWidth((stat.icon and STAT_ICON + stat.gap or 0) + math.ceil(stat.text:GetStringWidth()))
end

local function PinClicked(pin, mouse)
    local dungeon = pin:GetParent().dungeon
    if mouse ~= "RightButton" then
        J.ShowEntrance(dungeon)
        return
    end
    local entrance = dungeon.entrance
    J.View.Parts.SharePlace(pin, TEXT_SHARE_TITLE, dungeon.name, entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE)
end

local function PinEnter(pin)
    if not Tip(pin, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(TEXT_SHOW_ENTRANCE, 1, 1, 1)
    GameTooltip:AddLine(TEXT_SHARE_ENTRANCE, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function ActivityOf(dungeon)
    local GF = ns.GroupFinder
    if not (GF and GF.On()) then return nil end
    local level = UnitLevel("player")
    if level ~= activitiesLevel then
        wipe(activityOf)
        local count = GF.Search.Activities(activities)
        for i = 1, count do
            local key = GF.Listings.DungeonOf(activities[i])
            if key and not activityOf[key] then activityOf[key] = activities[i] end
        end
        if count > 0 then activitiesLevel = level end
    end
    return activityOf[dungeon.key]
end

local function FindClicked(link)
    ns.OpenGroupFinder(link.activity)
end

local function StepClicked(button)
    button:GetParent():GetParent().navigate(button.target)
end

local function ForeverEnter(mark)
    if not Tip(mark, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(ns.Shared.Parts.ForeverLine())
    GameTooltip:Show()
end

local function ZoneEnter(zone)
    if not Tip(zone, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetText(zone.name, 1, 1, 1)
    GameTooltip:AddLine(TERRITORY_CODE[zone.territory] .. TERRITORY_TIP[zone.territory] .. TEXT_CODE_END)
    GameTooltip:Show()
end

local function PlaceStat(row, stat, anchor, compact)
    if anchor then
        stat:SetPoint(compact and "LEFT" or "RIGHT", anchor, compact and "RIGHT" or "LEFT",
            compact and STAT_GAP or -STAT_GAP, 0)
    elseif compact then
        stat:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(TITLE_H + TITLE_GAP + WHERE_H + COMPACT_STAT_TOP))
    else
        stat:SetPoint("RIGHT", row, "TOPRIGHT", 0, -(TITLE_H + TITLE_GAP + WHERE_H / 2))
    end
end

local function PlaceStats(row, compact)
    local anchor, used = nil, 0
    for i = 1, #STATS do row.stats[STATS[i]]:ClearAllPoints() end
    local first, last, step = #STATS, 1, -1
    if compact then first, last, step = 1, #STATS, 1 end
    for i = first, last, step do
        local stat = row.stats[STATS[i]]
        if stat:IsShown() then
            PlaceStat(row, stat, anchor, compact)
            used = used + stat:GetWidth() + STAT_GAP
            anchor = stat
        end
    end
    return used, anchor ~= nil
end

local function NewForever(row)
    local mark = CreateFrame("Frame", nil, row)
    mark:SetSize(FOREVER_W, FOREVER_H)
    mark:SetPoint("LEFT", row.title, "RIGHT", FOREVER_GAP, 0)
    mark:EnableMouse(true)
    ns.Shared.Parts.ForeverMark(mark, FOREVER_H):SetAllPoints()
    mark:SetScript("OnEnter", ForeverEnter)
    mark:SetScript("OnLeave", GameTooltip_Hide)
    return mark
end

local function NewPin(row)
    local pin = ns.Shared.Parts.Link(row, PinClicked, true)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:HookScript("OnEnter", PinEnter)
    pin:HookScript("OnLeave", GameTooltip_Hide)
    ns.Shared.Parts.SetLink(pin, TEXT_ENTRANCE_LINK)
    return pin
end

local function NewFind(row)
    local link = ns.Shared.Parts.Link(row, FindClicked, true)
    link.tip, link.tipLine = TEXT_FIND_GROUP, TEXT_FIND_TIP
    ns.Shared.Parts.SetLink(link, TEXT_FIND_GROUP)
    return link
end

local function NewStep(row, by)
    local button = ns.Shared.Parts.IconButton(row, StepClicked, ARROW)
    if by == PREVIOUS then button.icon:SetRotation(math.pi) end
    return button
end

local function NewSteps(row)
    row.next = NewStep(row, NEXT)
    row.next:SetPoint("RIGHT", row, "TOPRIGHT", 0, -TITLE_H / 2)
    row.previous = NewStep(row, PREVIOUS)
    row.previous:SetPoint("RIGHT", row.next, "LEFT", -STEP_GAP, 0)
end

local function SetStep(button, view, dungeon, by, text)
    local target = view.step and view.navigate and view.step(dungeon, by)
    local shown = target ~= nil and target ~= dungeon
    button:SetShown(shown)
    if shown then button.target, button.tip = target, text:format(target.name) end
    return shown
end

local function NewZone(row)
    local zone = CreateFrame("Frame", nil, row)
    zone:SetHeight(WHERE_H)
    zone:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
    zone:EnableMouse(true)
    zone.text = ns.Font(zone, TEXT_SIZE)
    zone.text:SetPoint("LEFT")
    zone:SetScript("OnEnter", ZoneEnter)
    zone:SetScript("OnLeave", GameTooltip_Hide)
    return zone
end

local function NewStats(row)
    local stats = {
        quests = Stat(row, "Quests", ns.L("You have handed in %d of your %d quests here"),
            ns.L("Every quest here is done"), BANG, nil, 0, BANG_DROP),
        bis = Stat(row, "BiS", ns.L("You have %d of the %d BiS from your list that drop here"),
            ns.L("You have every BiS that drops here"), STAR, BIS_RGB, STAT_ICON_GAP),
        looks = Stat(row, "Transmog", ns.L("You have %d of the %d looks here"), ns.L("You have every look here"),
            HANGER, LOOK_RGB, STAT_ICON_GAP, BANG_DROP),
    }
    stats.bis.noneTip = ns.L("None of your BiS drops here")
    OpensBisList(stats.bis)
    stats.looks.noneTip = ns.L("Nothing listed here has a look to collect")
    return stats
end

local function SetFind(row, dungeon, view, after, gap)
    local find = row.find
    find.activity = not view.compact and ActivityOf(dungeon) or nil
    find:SetShown(find.activity ~= nil)
    if not find.activity then return 0 end
    find:ClearAllPoints()
    find:SetPoint("LEFT", after, "RIGHT", gap, -PIN_DROP)
    return find:GetWidth() + PIN_GAP
end

local function SetTitle(row, dungeon, view)
    local new = dungeon.new == true
    local pinned = dungeon.entrance ~= nil and not view.compact
    row.pin:SetShown(pinned)
    row.forever:SetShown(new)
    local after, gap = new and row.forever or row.title, new and PIN_GAP_AFTER_MARK or PIN_GAP
    row.pin:ClearAllPoints()
    row.pin:SetPoint("LEFT", after, "RIGHT", gap, -PIN_DROP)
    if pinned then after, gap = row.pin, PIN_GAP end
    local findW = SetFind(row, dungeon, view, after, gap)
    local stepped = SetStep(row.previous, view, dungeon, PREVIOUS, TEXT_PREVIOUS)
    SetStep(row.next, view, dungeon, NEXT, TEXT_NEXT)
    row.title:SetWidth(0)
    row.title:SetText(dungeon.name)
    row.title:SetWidth(math.min(math.ceil(row.title:GetStringWidth()) + 1,
        row:GetWidth() - (pinned and row.pin:GetWidth() + PIN_GAP or 0) - findW - (stepped and STEPS_W + PIN_GAP or 0)
            - TITLE_ROOM - (new and FOREVER_W + FOREVER_GAP or 0)))
end

local function WhereText(dungeon)
    local dot = dungeon.zone and PLACE_DOT or ""
    if dungeon.raid then return dot .. ns.Color("fg", dungeon.raid) .. TEXT_PLAYERS end
    local range = J.LevelRange(dungeon)
    return range and (dot .. TEXT_LEVEL .. ns.Color("fg", range)) or ""
end

local function SetWhere(row, dungeon)
    local zone = row.zone
    local territory = dungeon.territory or CONTESTED
    zone:SetShown(dungeon.zone ~= nil)
    row.where:ClearAllPoints()
    if dungeon.zone then
        zone.name, zone.territory = dungeon.zone, territory
        zone.text:SetText(TERRITORY_CODE[territory] .. dungeon.zone .. TEXT_CODE_END)
        zone:SetWidth(math.ceil(zone.text:GetStringWidth()))
        row.where:SetPoint("LEFT", zone, "RIGHT", 0, 0)
    else
        row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
    end
    row.where:SetText(WhereText(dungeon))
end

local function SetStats(row, dungeon, filters)
    local bis, haveBis = Loot.DungeonBis(dungeon, filters)
    local newLooks, looks = 0, 0
    if filters.showAppearance then newLooks, looks = Loot.DungeonNewLooks(dungeon, filters) end
    local stats = row.stats
    SetQuests(stats.quests, Quests.Progress(dungeon.quests))
    SetStat(stats.bis, haveBis, bis, BIS_CODE)
    SetStat(stats.looks, looks - newLooks, looks, LOOK_CODE, filters.showAppearance)
end

local function NewArt(row)
    local art = row:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetGradient("VERTICAL", CreateColor(ART_SHADE, ART_SHADE, ART_SHADE, 0),
        CreateColor(ART_SHADE, ART_SHADE, ART_SHADE, ART_ALPHA))
    return art
end

local function SetArt(row, dungeon, height)
    local file = S.Get("dungeonArt") and J.DungeonArt[dungeon.key]
    if not file then
        if row.art then row.art:Hide() end
        return height
    end
    height = height + ART_ROOM
    row.art = row.art or NewArt(row)
    local half = height / row:GetWidth() * ART_W / ART_H / 2
    row.art:SetTexture(file)
    row.art:SetTexCoord(0, 1, ART_MIDDLE - half, ART_MIDDLE + half)
    row.art:Show()
    return height
end

local function FindEnter(button)
    if not Tip(button, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetText(ns.L(TEXT_FIND_GROUP), 1, 1, 1)
    GameTooltip:AddLine(ns.L(TEXT_FIND_TIP), T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function NewButtons(row)
    row.enter = ns.Button(row, ns.L(TEXT_ENTRANCE_LINK), ENTRANCE_W, BUTTON_H, nil)
    row.enter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.enter:SetScript("OnClick", PinClicked)
    row.enter:HookScript("OnEnter", PinEnter)
    row.enter:HookScript("OnLeave", GameTooltip_Hide)
    row.group = ns.Button(row, ns.L(TEXT_FIND_GROUP), FIND_W, BUTTON_H, FindClicked)
    row.group:HookScript("OnEnter", FindEnter)
    row.group:HookScript("OnLeave", GameTooltip_Hide)
    row.here = ns.Shared.Parts.Pill(row, St.TINY_SIZE, T.accent)
    ns.Shared.Parts.SetPill(row.here, TEXT_HERE)
    row.facts = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.facts:SetJustifyH("LEFT")
    row.facts:SetWordWrap(false)
end

local function SetNewTitle(row, dungeon, view)
    local new = dungeon.new == true
    row.pin:Hide()
    row.find:Hide()
    row.forever:SetShown(new)
    local stepped = SetStep(row.previous, view, dungeon, PREVIOUS, TEXT_PREVIOUS)
    SetStep(row.next, view, dungeon, NEXT, TEXT_NEXT)
    local right = stepped and STEPS_W + BUTTON_GAP or 0
    local activity = ActivityOf(dungeon)
    row.group.activity = activity
    row.group:SetShown(activity ~= nil)
    row.group:ClearAllPoints()
    row.group:SetPoint("RIGHT", row, "TOPRIGHT", -right, -TITLE_H / 2)
    if activity then right = right + row.group:GetWidth() + BUTTON_GAP end
    row.enter:SetShown(dungeon.entrance ~= nil)
    row.enter:ClearAllPoints()
    row.enter:SetPoint("RIGHT", row, "TOPRIGHT", -right, -TITLE_H / 2)
    if dungeon.entrance then right = right + row.enter:GetWidth() + BUTTON_GAP end
    local here = J.Current()
    local inside = here ~= nil and here[1] == dungeon
    row.here:SetShown(inside)
    row.here:ClearAllPoints()
    row.here:SetPoint("LEFT", new and row.forever or row.title, "RIGHT", HERE_GAP, 0)
    row.title:SetWidth(0)
    row.title:SetText(dungeon.name)
    row.title:SetWidth(math.min(math.ceil(row.title:GetStringWidth()) + 1, row:GetWidth() - right - TITLE_ROOM
        - (new and FOREVER_W + FOREVER_GAP or 0) - (inside and row.here:GetWidth() + HERE_GAP or 0)))
end

local function KeysHeld(keys)
    local held = 0
    for _, key in ipairs(keys) do
        if Loot.Have(key.item) then held = held + 1 end
    end
    return TEXT_KEYS_HELD:format(held, #keys)
end

local function LockoutsRead()
    lockoutsAt = GetTime()
end

local function WatchLockouts()
    lockouts = CreateFrame("Frame")
    lockouts:RegisterEvent("UPDATE_INSTANCE_INFO")
    lockouts:SetScript("OnEvent", LockoutsRead)
    RequestRaidInfo()
end

local function LockoutLeft(dungeon)
    if not lockoutsAt then return nil end
    local elapsed = GetTime() - lockoutsAt
    for i = 1, GetNumSavedInstances() do
        local _, _, reset, _, locked, extended, _, _, _, _, _, _, _, map = GetSavedInstanceInfo(i)
        if map == dungeon.instance and (locked or extended) and reset > elapsed then return reset - elapsed end
    end
end

local function FactsText(dungeon)
    local facts = dungeon.raid and (ns.Color("fg", dungeon.raid) .. TEXT_PLAYERS) or nil
    local range = not dungeon.raid and J.ColoredLevelRange(dungeon)
    if range then facts = TEXT_LEVEL .. range .. "  " .. TEXT_YOU_ARE:format(UnitLevel("player")) end
    local keys = J.Keys[dungeon.key]
    if keys then facts = (facts and facts .. PLACE_DOT or "") .. KeysHeld(keys) end
    local saved = LockoutLeft(dungeon)
    if saved then
        facts = (facts and facts .. PLACE_DOT or "") .. St.RED_CODE
            .. TEXT_SAVED:format(J.Reputation.Duration(saved)) .. "|r"
    end
    local entrance = dungeon.entrance
    local map = entrance and C_Map.GetMapInfo(entrance.map)
    if map then
        facts = (facts and facts .. PLACE_DOT or "") .. COORDS:format(map.name, entrance.x + 0.5, entrance.y + 0.5)
    end
    return facts or ""
end

local function SetPainting(row, dungeon, height)
    local painting = S.Get("dungeonArt") and not J.DungeonArt[dungeon.key] and J.Paintings[dungeon.key]
    if not painting then
        if row.painting then row.painting:Hide() end
        return height
    end
    height = height + ART_ROOM
    if not row.painting then
        row.painting = row:CreateTexture(nil, "BACKGROUND")
        row.painting:SetPoint("TOPRIGHT")
        row.painting:SetWidth(PAINT_W)
        row.painting:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, PAINT_ALPHA))
    end
    local span = PAINT.bottom - PAINT.top
    local shown = math.min(span, (PAINT.right - PAINT.left) * PAINT.size * height / PAINT_W)
    local top = PAINT.top + (span - shown) * PAINT.middle
    row.painting:SetHeight(height)
    row.painting:SetTexture(painting[2])
    row.painting:SetTexCoord(PAINT.left, PAINT.right, top / PAINT.size, (top + shown) / PAINT.size)
    row.painting:Show()
    return height
end

local function SetNew(row, dungeon, view)
    if not row.enter then NewButtons(row) end
    if not lockouts then WatchLockouts() end
    view.watchLockouts = true
    SetNewTitle(row, dungeon, view)
    SetWhere(row, dungeon)
    local territory = dungeon.territory or CONTESTED
    row.where:SetText(dungeon.zone and PLACE_DOT .. TERRITORY_TIP[territory] or "")
    SetStats(row, dungeon, view.filters)
    row.where:SetWidth(math.max(1, row:GetWidth() - PAINT_W - (dungeon.zone and row.zone:GetWidth() or 0)))
    row.facts:ClearAllPoints()
    row.facts:SetPoint("TOPLEFT", row.zone, "BOTTOMLEFT", 0, -FACTS_GAP)
    row.facts:SetWidth(0)
    row.facts:SetText(FactsText(dungeon))
    row.facts:SetWidth(math.ceil(row.facts:GetStringWidth()) + 1)
    local after = row.facts
    for i = 1, #STATS do
        local stat = row.stats[STATS[i]]
        stat:ClearAllPoints()
        if stat:IsShown() then
            stat:SetPoint("LEFT", after, "RIGHT", STAT_GAP, 0)
            after = stat
        end
    end
    local height = TITLE_H + TITLE_GAP + WHERE_H + FACTS_GAP + FACTS_H + HEADER_PAD
    return SetPainting(row, dungeon, SetArt(row, dungeon, height))
end

J.View.Parts.Stat, J.View.Parts.SetStat, J.View.Parts.OpensBisList = Stat, SetStat, OpensBisList

Kinds.header = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = ns.Font(row, TITLE_SIZE, nil, T.fg)
        row.title:SetPoint("TOPLEFT")
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.forever = NewForever(row)
        row.pin = NewPin(row)
        row.find = NewFind(row)
        NewSteps(row)
        row.zone = NewZone(row)
        row.where = ns.Font(row, TEXT_SIZE, nil, T.muted)
        row.where:SetJustifyH("LEFT")
        row.where:SetWordWrap(false)
        row.stats = NewStats(row)
        return row
    end,
    Set = function(row, dungeon)
        local view = row:GetParent()
        row.dungeon = dungeon
        if view.newLook then return SetNew(row, dungeon, view) end
        SetTitle(row, dungeon, view)
        SetWhere(row, dungeon)
        SetStats(row, dungeon, view.filters)
        local used, any = PlaceStats(row, view.compact)
        local zoneW = dungeon.zone and row.zone:GetWidth() or 0
        local height = TITLE_H + TITLE_GAP + WHERE_H
        if view.compact then
            row.where:SetWidth(row:GetWidth() - zoneW)
            height = height + (any and STAT_LINE_H or 0) + COMPACT_PAD
        else
            row.where:SetWidth(row:GetWidth() - used - zoneW)
            height = height + HEADER_PAD
        end
        return SetArt(row, dungeon, height)
    end,
}
