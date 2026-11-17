-- Home.lua: the new look's first page: every dungeon and raid as a card on its painting, grouped by your level (J.Home).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Quests = J.Quests
local S = J.Settings
local Parts = ns.Shared.Parts
local LP = J.ListParts
local List = J.DungeonList
local St = J.Style
local BORDER_RGB, TERRITORY_CODE, UNUSABLE, BIS_RGB = St.BORDER_RGB, St.TERRITORY_CODE, St.UNUSABLE, St.BIS_RGB
local STAR_TAG, DONE_MARK, GROUP_H, FOREVER_H = St.STAR_TAG, St.DONE_MARK, St.GROUP_H, St.FOREVER_H
local SCROLLBAR, TINY_SIZE, PLACE_DOT = St.SCROLLBAR, St.TINY_SIZE, St.PLACE_DOT
local GROUPS, CLOSED_KEYS = List.GROUPS, List.CLOSED_KEYS

local COLUMNS = 4
local CARD_GAP, CARD_H = 10, 122
local GROUP_GAP = 6
local NAME_SIZE, INFO_SIZE = 15, 12
local TEXT_PAD, LINE_GAP, COUNT_GAP = 9, 3, 10
local TAG_PAD, TAG_GAP = 6, 5
local BUTTON_ART = { left = 10 / 256, right = 164 / 256, top = 10 / 128, bottom = 86 / 128 }
local SCREEN_W, SCREEN_H, SCREEN_MIDDLE = 2992, 1684, 0.45
local SHADE_TOP, SHADE_BOTTOM = 0.05, 0.94
local SHADE_REST, SHADE_HOVER = 1, 0.8
local ORDER = { 1, 2, 3, 4 }
local CONTESTED_SIDE = "Contested"
local EMPTY = {}

local TEXT_HERE = "You are here"
local TEXT_KEY = "Key"
local TEXT_ATTUNEMENT = "Attunement"
local TEXT_PLAYERS = ns.L(" players")
local TEXT_PLACE = "%s%s|r"
local TEXT_QUESTS = "%s%d/%d"
local QUEST_MARK = Parts.Inline(St.BANG, T.fg)

local frame, scroll, content
local cards, groups = {}, {}
local onSelect
local filters = {}
local width = 0

local function Closed(g)
    return S.Get(CLOSED_KEYS[g]) == true
end

local function CardEnter(card)
    card.shade:SetAlpha(SHADE_HOVER)
    card.edge:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    List.Tip(card, card.dungeon, card.here:IsShown())
end

local function CardLeave(card)
    local edge = card.here:IsShown() and T.accent or BORDER_RGB
    card.shade:SetAlpha(SHADE_REST)
    card.edge:SetColor(edge.r, edge.g, edge.b, 1)
    GameTooltip:Hide()
end

local function CardClicked(card)
    onSelect(card.dungeon)
end

local function GroupClicked(header)
    S.Set(CLOSED_KEYS[header.group], not Closed(header.group))
end

local function Painting(card, dungeon)
    local art = card:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    local painting, screen = J.Paintings[dungeon.key], J.DungeonArt[dungeon.key]
    if painting then
        art:SetTexture(painting[1])
        art:SetTexCoord(BUTTON_ART.left, BUTTON_ART.right, BUTTON_ART.top, BUTTON_ART.bottom)
    elseif screen then
        art:SetTexture(screen)
        card.screen = art
    else
        art:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
    end
end

local function Shade(card)
    local shade = card:CreateTexture(nil, "BORDER")
    shade:SetAllPoints()
    shade:SetColorTexture(1, 1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(T.bg.r, T.bg.g, T.bg.b, SHADE_BOTTOM),
        CreateColor(T.bg.r, T.bg.g, T.bg.b, SHADE_TOP))
    return shade
end

local function NeedsKey(dungeon)
    for _, key in ipairs(J.Keys[dungeon.key] or EMPTY) do
        if not key.opens then return true end
    end
    return false
end

local function Tags(card, dungeon)
    card.here = Parts.Pill(card, TINY_SIZE, T.accent)
    card.here:SetPoint("TOPLEFT", TAG_PAD, -TAG_PAD)
    Parts.SetPill(card.here, TEXT_HERE)
    if dungeon.new then
        card.new = Parts.ForeverMark(card, FOREVER_H)
        card.new:SetPoint("TOPRIGHT", -TAG_PAD, -TAG_PAD)
    end
    if NeedsKey(dungeon) then
        card.key = Parts.Pill(card, TINY_SIZE, T.muted)
        Parts.SetPill(card.key, dungeon.raid and TEXT_ATTUNEMENT or TEXT_KEY)
    end
end

local function PlaceKey(card)
    if not card.key then return end
    card.key:ClearAllPoints()
    if card.here:IsShown() then
        card.key:SetPoint("LEFT", card.here, "RIGHT", TAG_GAP, 0)
    else
        card.key:SetPoint("TOPLEFT", TAG_PAD, -TAG_PAD)
    end
end

local function Where(dungeon)
    local range = dungeon.raid and dungeon.raid .. TEXT_PLAYERS or J.ColoredLevelRange(dungeon)
    local zone = dungeon.zone and TEXT_PLACE:format(TERRITORY_CODE[dungeon.territory or CONTESTED_SIDE], dungeon.zone)
    if range and zone then return range .. PLACE_DOT .. zone end
    return range or zone or ""
end

local function Card(parent, dungeon)
    local card = CreateFrame("Button", nil, parent)
    card.dungeon = dungeon
    card:SetHeight(CARD_H)
    Painting(card, dungeon)
    card.shade = Shade(card)
    card.edge = ns.Border(card, BORDER_RGB)
    Tags(card, dungeon)
    card.bis = ns.Font(card, INFO_SIZE, nil, BIS_RGB)
    card.bis:SetPoint("BOTTOMRIGHT", -TEXT_PAD, TEXT_PAD)
    card.quests = ns.Font(card, INFO_SIZE, nil, T.muted)
    card.quests:SetPoint("RIGHT", card.bis, "LEFT", -COUNT_GAP, 0)
    card.where = ns.Font(card, INFO_SIZE, nil, T.muted)
    card.where:SetPoint("BOTTOMLEFT", TEXT_PAD, TEXT_PAD)
    card.where:SetPoint("RIGHT", card.quests, "LEFT", -COUNT_GAP, 0)
    card.where:SetJustifyH("LEFT")
    card.where:SetWordWrap(false)
    card.name = ns.Font(card, NAME_SIZE)
    card.name:SetPoint("BOTTOMLEFT", card.where, "TOPLEFT", 0, LINE_GAP)
    card.name:SetPoint("RIGHT", -TEXT_PAD, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.name:SetText(dungeon.name)
    card:SetScript("OnClick", CardClicked)
    card:SetScript("OnEnter", CardEnter)
    card:SetScript("OnLeave", CardLeave)
    return card
end

local function SizeCard(card, cardW)
    card:SetWidth(cardW)
    if not card.screen then return end
    local half = CARD_H / cardW * SCREEN_W / SCREEN_H / 2
    card.screen:SetTexCoord(0, 1, SCREEN_MIDDLE - half, SCREEN_MIDDLE + half)
end

local function LayoutGroup(g, header, y, cardW)
    local count, closed = 0, Closed(g)
    for _, card in ipairs(cards) do
        if List.Group(card.dungeon) == g then
            local listed = List.Listed(card.dungeon)
            card:SetShown(listed and not closed)
            if listed then
                if count == 0 then
                    header:ClearAllPoints()
                    header:SetPoint("TOPLEFT", 0, -y)
                    y = y + GROUP_H + GROUP_GAP
                end
                if not closed then
                    local row = math.floor(count / COLUMNS)
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", count % COLUMNS * (cardW + CARD_GAP), -(y + row * (CARD_H + CARD_GAP)))
                end
                count = count + 1
            end
        end
    end
    header:SetShown(count > 0)
    if count == 0 then return y end
    LP.Fold(header, closed, count)
    if not closed then y = y + math.ceil(count / COLUMNS) * (CARD_H + CARD_GAP) end
    return y + GROUP_GAP
end

local function PaintCard(card, current)
    local dungeon = card.dungeon
    local here = dungeon == current
    card.here:SetShown(here)
    PlaceKey(card)
    local edge = here and T.accent or BORDER_RGB
    card.edge:SetColor(edge.r, edge.g, edge.b, 1)
    card:SetAlpha(J.HasBosses(dungeon) and 1 or UNUSABLE)
    card.where:SetText(Where(dungeon))
    local done, total = Quests.Progress(dungeon.quests)
    if total == 0 then
        card.quests:SetText("")
    else
        card.quests:SetText(done == total and DONE_MARK or TEXT_QUESTS:format(QUEST_MARK, done, total))
    end
    local bis, haveBis = Loot.DungeonBis(dungeon, filters)
    card.bis:SetText(bis > haveBis and STAR_TAG .. (bis - haveBis) or "")
end

local Home = {}
J.Home = Home

function Home.Build(parent, select)
    onSelect = select
    frame = CreateFrame("Frame", nil, parent)
    scroll = ns.UI.SlimScroll(frame)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 0)
    content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    for g, text in ipairs(GROUPS) do
        groups[g] = LP.Header(content, ns.L(text), GroupClicked)
        groups[g].group = g
    end
    for i, dungeon in ipairs(J.Dungeons()) do cards[i] = Card(content, dungeon) end
    return frame
end

function Home.Layout(newWidth)
    width = newWidth or width
    local cardW = math.floor((width - CARD_GAP * (COLUMNS - 1)) / COLUMNS)
    content:SetWidth(width)
    for _, card in ipairs(cards) do SizeCard(card, cardW) end
    local y = 0
    for _, g in ipairs(ORDER) do
        groups[g]:SetWidth(width)
        y = LayoutGroup(g, groups[g], y, cardW)
    end
    content:SetHeight(math.max(1, y))
end

function Home.Paint()
    local here = J.Current()
    local current = here and here[1]
    Loot.ReadFilters(filters)
    for _, card in ipairs(cards) do PaintCard(card, current) end
end
