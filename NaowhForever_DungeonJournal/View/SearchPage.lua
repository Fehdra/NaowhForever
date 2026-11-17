-- SearchPage.lua: a search over every boss, item and faction reward, by dungeon and faction, each with Open.
local ns = _G.NaowhForever

local J = ns.Journal
local Rep = J.Reputation
local ViewMixin = J.View.Mixin
local St = J.Style
local SECTION_SPACE = St.SECTION_SPACE

local PRICE_COLUMN = "price"

local TEXT_OPEN = "Open"
local TEXT_SEARCHING = ns.L("Searching...")
local TEXT_NO_MATCH = ns.L("Nothing in the journal matches %s.")
local TEXT_ITEMS = ns.L("%d |4item:items;")

local EMPTY = {}
local lowerNames = {}

local function LowerName(page)
    local lower = lowerNames[page]
    if not lower then
        lower = page.name:lower()
        lowerNames[page] = lower
    end
    return lower
end

function ViewMixin:DrawFound(page, onOpen)
    if self.grid.n == 0 then return end
    self:SectionLink(page.name, TEXT_OPEN, onOpen, page)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
end

function ViewMixin:SearchDungeon(dungeon, query)
    local found = 0
    local wings = J.FactionShown(dungeon) and dungeon.wings or EMPTY
    for _, wing in ipairs(wings) do
        for _, boss in ipairs(wing.bosses) do
            local byName = LowerName(boss):find(query, 1, true) ~= nil
            local itemQuery = not byName and query or nil
            local shown = self:ShownCount(boss, itemQuery)
            if byName or shown > 0 then
                found = found + 1
                self:Gather(boss, nil, shown, itemQuery)
            end
        end
    end
    return found
end

function ViewMixin:SearchFaction(faction, query)
    local found = 0
    local itemQuery = LowerName(faction):find(query, 1, true) == nil and query or nil
    for _, tier in ipairs(faction.tiers) do
        local shown = self:ListCount(tier.items, itemQuery)
        if shown > 0 then
            found = found + 1
            self:Gather(tier, nil, shown, itemQuery)
        end
    end
    return found
end

function ViewMixin:TableTitle(page, onOpen)
    if not self.itemRoom then self:AddFoundColumns(self:GetWidth()) end
    self:Space(SECTION_SPACE)
    self:SectionLink(page.name, TEXT_OPEN, onOpen, page)
end

function ViewMixin:TableDungeon(dungeon, query, onOpen)
    local found, width, record = 0, self:GetWidth(), self.searchRecord
    local wings = J.FactionShown(dungeon) and dungeon.wings or EMPTY
    record.dungeon, record.from = dungeon, nil
    for _, wing in ipairs(wings) do
        for _, boss in ipairs(wing.bosses) do
            local byName = LowerName(boss):find(query, 1, true) ~= nil
            local itemQuery = not byName and query or nil
            local shown = self:ShownCount(boss, itemQuery)
            if byName or shown > 0 then
                if found == 0 then self:TableTitle(dungeon, onOpen) end
                found = found + 1
                if byName then self:Add("line", St.SKULL, boss.name, TEXT_ITEMS:format(shown)) end
                local loot, chance = boss.loot or EMPTY, boss.chance
                record.boss = boss
                for i = 1, #loot do
                    if self:Listed(loot[i], itemQuery) then
                        record.item, record.chance = loot[i], chance and chance[i]
                        self:AddFound(record, dungeon.name, 0, width)
                    end
                end
            end
        end
    end
    return found
end

function ViewMixin:TableFaction(faction, query, onOpen)
    local found, width, record = 0, self:GetWidth(), self.searchRecord
    local itemQuery = LowerName(faction):find(query, 1, true) == nil and query or nil
    record.dungeon, record.boss, record.chance = faction, nil, nil
    self.column = PRICE_COLUMN
    for _, tier in ipairs(faction.tiers) do
        for _, id in ipairs(tier.items) do
            if self:Listed(id, itemQuery) then
                if found == 0 then self:TableTitle(faction, onOpen) end
                found = found + 1
                record.item, record.from = id, Rep.Label(tier.standing)
                self:AddFound(record, faction.name, 0, width, Rep.Price(faction, id))
            end
        end
    end
    self.column = nil
    return found
end

function ViewMixin:DrawSearch(query, onOpen)
    self:Begin(nil, nil, query)
    self.onOpen = onOpen
    local found, rows = 0, self.searchTable
    self.striped, self.itemRoom = rows, nil
    for _, dungeon in ipairs(J.Dungeons()) do
        if rows then
            found = found + self:TableDungeon(dungeon, query, onOpen)
        else
            found = found + self:SearchDungeon(dungeon, query)
            self:DrawFound(dungeon, onOpen)
        end
    end
    for _, tab in ipairs(J.TABS) do
        for _, faction in ipairs(J.Factions(tab)) do
            if Rep.Shown(faction) then
                if rows then
                    found = found + self:TableFaction(faction, query, onOpen)
                else
                    found = found + self:SearchFaction(faction, query)
                    self:DrawFound(faction, onOpen)
                end
            end
        end
    end
    self.itemRoom = nil
    if found == 0 then self:Note(self.waiting and TEXT_SEARCHING or TEXT_NO_MATCH:format(query)) end
    self:Finish()
end
