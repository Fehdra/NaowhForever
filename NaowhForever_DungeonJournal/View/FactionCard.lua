-- FactionCard.lua: a faction as a card: its name, your standing as a meter, its rewards unlocked for you and your BiS left among them.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Rep = J.Reputation
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local BORDER_RGB, BIS_RGB, FOREVER_H = St.BORDER_RGB, St.BIS_RGB, St.FOREVER_H
local STAR_TAG, DONE_MARK = St.STAR_TAG, St.DONE_MARK

local CARD_H = 56
local PAD = 10
local NAME_SIZE, INFO_SIZE = 14, 12
local NAME_TOP, COUNTS_TOP, LINE_BOTTOM = 10, 11, 10
local STANDING_W, METER_H, METER_GAP = 84, 4, 8
local MARK_GAP, COUNT_GAP = 6, 10
local FOREVER_W = FOREVER_H * 2
local UNMET = 0.5

local TEXT_NOT_MET = ns.L("Not met yet")
local TEXT_VALUE = "%s / %s"
local TEXT_REWARDS = ns.L("%d/%d rewards")
local TEXT_GAP = "  "

local function CardEnter(card)
    card.edge:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    J.FactionList.Tip(card, card.page)
end

local function CardLeave(card)
    card.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
    GameTooltip:Hide()
end

local function Meter(card)
    card.track = ns.Solid(card, "BORDER", T.line, 1)
    card.track:SetHeight(METER_H)
    card.track:SetPoint("LEFT", card.standing, "LEFT", STANDING_W + METER_GAP, 0)
    card.fill = card:CreateTexture(nil, "ARTWORK")
    card.fill:SetColorTexture(1, 1, 1, 1)
    card.fill:SetPoint("TOPLEFT", card.track)
    card.fill:SetPoint("BOTTOMLEFT", card.track)
end

local function SetMeter(card, color, share)
    local value = math.ceil(card.value:GetStringWidth())
    local width = card:GetWidth() - 2 * PAD - STANDING_W - METER_GAP - (value > 0 and value + METER_GAP or 0)
    card.track:SetWidth(math.max(1, width))
    card.track:Show()
    card.fill:SetVertexColor(color.r, color.g, color.b, 1)
    card.fill:SetWidth(math.max(1, width * math.min(1, share)))
    card.fill:SetShown(share > 0)
end

local function CountsText(page, reaction, filters)
    local unlocked, total = Rep.Unlocked(page, reaction, filters)
    local text = total > 0 and TEXT_REWARDS:format(unlocked, total) or ""
    local bis, haveBis = Rep.Bis(page)
    if bis > haveBis then text = STAR_TAG .. J.Colored(BIS_RGB, bis - haveBis) .. TEXT_GAP .. text end
    return text
end

function Parts.FactionCard(parent, onClick)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(CARD_H)
    ns.Solid(card, "BACKGROUND", T.panel, 1):SetAllPoints()
    card.edge = ns.Border(card, BORDER_RGB)
    card.counts = ns.Font(card, INFO_SIZE, nil, T.muted)
    card.counts:SetPoint("TOPRIGHT", -PAD, -COUNTS_TOP)
    card.name = ns.Font(card, NAME_SIZE)
    card.name:SetPoint("TOPLEFT", PAD, -NAME_TOP)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.new = Parts.ForeverMark(card, FOREVER_H)
    card.new:SetPoint("LEFT", card.name, "RIGHT", MARK_GAP, 0)
    card.standing = ns.Font(card, INFO_SIZE)
    card.standing:SetPoint("BOTTOMLEFT", PAD, LINE_BOTTOM)
    card.value = ns.Font(card, INFO_SIZE, nil, T.muted)
    card.value:SetPoint("BOTTOMRIGHT", -PAD, LINE_BOTTOM)
    Meter(card)
    card:SetScript("OnClick", onClick)
    card:SetScript("OnEnter", CardEnter)
    card:SetScript("OnLeave", CardLeave)
    return card
end

function Parts.SetFactionCard(card, page, filters)
    card.page = page
    local reaction, value, max = Rep.Standing(page)
    card.counts:SetText(CountsText(page, reaction, filters))
    card.new:SetShown(page.new == true)
    card.name:SetWidth(0)
    card.name:SetText(reaction == Rep.EXALTED and page.name .. TEXT_GAP .. DONE_MARK or page.name)
    local room = card:GetWidth() - 2 * PAD - math.ceil(card.counts:GetStringWidth()) - COUNT_GAP
        - (page.new and FOREVER_W + MARK_GAP or 0)
    card.name:SetWidth(math.min(math.ceil(card.name:GetStringWidth()) + 1, room))
    card:SetAlpha(reaction and 1 or UNMET)
    if not reaction then
        card.standing:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        card.standing:SetText(TEXT_NOT_MET)
        card.value:SetText("")
        card.track:Hide()
        card.fill:Hide()
        return
    end
    local color = Rep.Color(reaction)
    card.standing:SetTextColor(color.r, color.g, color.b)
    card.standing:SetText(Rep.Label(reaction))
    card.value:SetText(reaction < Rep.EXALTED and TEXT_VALUE:format(BreakUpLargeNumbers(value),
        BreakUpLargeNumbers(max)) or "")
    SetMeter(card, color, value / max)
end

Parts.FACTION_CARD_H = CARD_H

local function RowClicked(card)
    local view = card:GetParent()
    if view.navigate then view.navigate(card.page) end
end

Kinds.factionCard = {
    New = function(view)
        return Parts.FactionCard(view, RowClicked)
    end,
    Set = function(card, page)
        Parts.SetFactionCard(card, page, card:GetParent().filters)
        return CARD_H
    end,
}
