-- FactionHome.lua: the new look's Reputation page: every faction as a card under its group (J.FactionHome).
local ns = _G.NaowhForever

local J = ns.Journal
local Loot = J.Loot
local Rep = J.Reputation
local S = J.Settings
local Parts = J.View.Parts
local LP = J.ListParts
local List = J.FactionList
local St = J.Style
local GROUP_H, SCROLLBAR = St.GROUP_H, St.SCROLLBAR
local CARD_H = Parts.FACTION_CARD_H

local COLUMNS = 3
local CARD_GAP, GROUP_GAP = 10, 6
local TAB = "reputation"

local frame, scroll, content
local cards, headers = {}, {}
local onSelect
local filters = {}
local width = 0

local Home = {}
J.FactionHome = Home

local function CardClicked(card)
    onSelect(card.page)
end

local function LayoutGroup(title, y, cardW)
    local header, count = headers[title], 0
    local closed = title == List.UNRELEASED and not S.Get("openUnreleased")
    for _, card in ipairs(cards) do
        if card.group == title then
            local listed = Rep.Shown(card.page)
            card:SetShown(listed and not closed)
            if listed then
                if count == 0 then
                    header:ClearAllPoints()
                    header:SetPoint("TOPLEFT", 0, -y)
                    y = y + GROUP_H + GROUP_GAP
                end
                if not closed then
                    local row = math.floor(count / COLUMNS)
                    card:SetWidth(cardW)
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", count % COLUMNS * (cardW + CARD_GAP), -(y + row * (CARD_H + CARD_GAP)))
                end
                count = count + 1
            end
        end
    end
    header:SetShown(count > 0)
    if count == 0 then return y end
    if header.arrow then LP.Fold(header, closed, count) end
    if not closed then y = y + math.ceil(count / COLUMNS) * (CARD_H + CARD_GAP) end
    return y + GROUP_GAP
end

local function Shown()
    frame:RegisterEvent("UPDATE_FACTION")
end

local function Hidden()
    frame:UnregisterEvent("UPDATE_FACTION")
end

function Home.Build(parent, select)
    onSelect = select
    frame = CreateFrame("Frame", nil, parent)
    frame:Hide()
    scroll = ns.UI.SlimScroll(frame)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 0)
    content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    for _, title in ipairs(List.GROUPS[TAB]) do
        headers[title] = LP.Header(content, ns.L(title), title == List.UNRELEASED and List.ToggleUnreleased or nil)
    end
    for i, faction in ipairs(J.Factions(TAB)) do
        local card = Parts.FactionCard(content, CardClicked)
        card.page, card.group = faction, List.GroupOf(faction)
        cards[i] = card
    end
    frame:SetScript("OnShow", Shown)
    frame:SetScript("OnHide", Hidden)
    frame:SetScript("OnEvent", Home.Paint)
    return frame
end

function Home.Layout(newWidth)
    width = newWidth or width
    local cardW = math.floor((width - CARD_GAP * (COLUMNS - 1)) / COLUMNS)
    content:SetWidth(width)
    local y = 0
    for _, title in ipairs(List.GROUPS[TAB]) do
        headers[title]:SetWidth(width)
        y = LayoutGroup(title, y, cardW)
    end
    content:SetHeight(math.max(1, y))
end

function Home.Paint()
    Loot.ReadFilters(filters)
    for _, card in ipairs(cards) do
        if card:IsShown() then Parts.SetFactionCard(card, card.page, filters) end
    end
end
