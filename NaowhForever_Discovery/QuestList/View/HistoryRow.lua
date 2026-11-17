-- HistoryRow.lua: a line of Quest History: when, what happened (taken, handed in, dropped, a level), the quest, its experience.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local Style = Completo.Style
local H = Completo.History
local V = Completo.View

local ROW_H = 22
local TIME_W = 44
local MARK = 14
local XP_W = 90
local TIME_FORMAT, WHEN_FORMAT = "%H:%M", "%c"
local MARKS = { [H.TAKEN] = "QuestNormal", [H.HANDED_IN] = "questturnin", [H.DROPPED] = "Objective-Fail",
    [H.LEVEL] = "levelup-dot-gold" }
local TEXT_QUEST = "[%d] %s"
local TEXT_WHAT_WHEN = "%s, %s"
local TEXT_LEVEL = ns.L("Reached level %d")
local TEXT_XP = ns.L("%d XP")
local TEXT_TAKEN, TEXT_HANDED_IN, TEXT_DROPPED = ns.L("Taken"), ns.L("Handed in"), ns.L("Dropped")
local KIND_TEXT = { [H.TAKEN] = TEXT_TAKEN, [H.HANDED_IN] = TEXT_HANDED_IN, [H.DROPPED] = TEXT_DROPPED }

local function HistoryEnter(row)
    row.hover:Show()
    local entry = row.entry
    local kind = KIND_TEXT[entry[H.KIND]]
    if not kind then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry[H.TITLE], 1, 1, 1)
    GameTooltip:AddLine(TEXT_WHAT_WHEN:format(kind, date(WHEN_FORMAT, entry[H.WHEN])), V.Soft())
    local money = entry[H.MONEY]
    if money and money > 0 then GameTooltip:AddLine(GetMoneyString(money), 1, 1, 1) end
    GameTooltip:Show()
end

local function NewHistory(parent)
    local row = V.NewRow(parent)
    row.divider:Hide()
    row.time = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.time:SetPoint("LEFT", Style.INDENT, 0)
    row.time:SetWidth(TIME_W)
    row.time:SetJustifyH("LEFT")
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetSize(MARK, MARK)
    row.mark:SetPoint("LEFT", Style.INDENT + TIME_W, 0)
    row.name = V.Line(row, Style.TEXT_SIZE, T.fg)
    row.name:SetPoint("LEFT", row.mark, "RIGHT", Style.ICON_GAP, 0)
    row.xp = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.xp:SetPoint("RIGHT", -Style.PIN_RIGHT, 0)
    row.xp:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", HistoryEnter)
    row:SetScript("OnLeave", V.RowLeave)
    return row
end

local function SetHistory(row, entry, stripe)
    row.entry = entry
    V.Reset(row, stripe)
    local kind = entry[H.KIND]
    row.time:SetText(date(TIME_FORMAT, entry[H.WHEN]))
    row.mark:SetAtlas(MARKS[kind])
    if kind == H.LEVEL then
        row.name:SetText(TEXT_LEVEL:format(entry[H.ID]))
    else
        local level = entry[H.AT_LEVEL]
        row.name:SetText(level and level > 0 and TEXT_QUEST:format(level, entry[H.TITLE]) or entry[H.TITLE])
    end
    V.Paint(row.name, kind == H.DROPPED and T.muted or T.fg)
    local xp = entry[H.XP]
    row.xp:SetText(xp and xp > 0 and TEXT_XP:format(xp) or "")
    row.name:SetWidth(row:GetWidth() - Style.INDENT - TIME_W - MARK - Style.ICON_GAP - XP_W)
    return ROW_H
end

V.Kinds.history = { New = NewHistory, Set = SetHistory }
