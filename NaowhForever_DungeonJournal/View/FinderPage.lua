-- FinderPage.lua: the Loot Finder's page: its picks, then every dungeon item that fits them, with its boss and dungeon.
local ns = _G.NaowhForever

local J = ns.Journal
local Finder = J.Finder
local ViewMixin = J.View.Mixin
local St = J.Style
local SECTION_SPACE, PLACE_DOT = St.SECTION_SPACE, St.PLACE_DOT

local MAX_SHOWN = 50
local SIDE_W, SIDE_GAP = 236, 18
local FOR_W, CELLS_W, CHANCE_ROOM = 150, 360, 52

local TEXT_TITLE = ns.L("Loot Finder")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_PICK = ns.L("Pick a slot, an armor type or a stat to find the loot from every dungeon that has it.")
local TEXT_FOUND = ns.L("Found")
local TEXT_NONE = ns.L("No dungeon loot fits what you picked.")
local TEXT_FIRST = ns.L("The first %d of %d. Pick more to narrow it down.")

local whereText = {}

local function Where(boss, dungeon)
    local text = whereText[boss]
    if not text then
        text = boss.name .. PLACE_DOT .. dungeon.name
        whereText[boss] = text
    end
    return text
end

local function ClearPicks(view)
    Finder.Clear()
    view:Redraw()
end

function ViewMixin:AddFoundColumns(w)
    self:Add("finderColumns", w - CELLS_W - CHANCE_ROOM, w - CELLS_W - CHANCE_ROOM + FOR_W)
    self.itemRoom = CELLS_W
end

function ViewMixin:AddFound(record, where, x, w, price)
    local id, top = record.item, self.cursor
    local chance = record.chance
    local row = self:Add("item", id, chance and chance > 0 and chance or nil, nil, nil, price)
    row.boss, row.dungeon, row.where = record.boss, record.dungeon, where
    local bottom = self.cursor
    self:Column(x + w - CELLS_W - CHANCE_ROOM, CELLS_W, top)
    self:Add("foundCells", record, self:ItemRank(id), self:ItemUpgrade(id), FOR_W, bottom - top)
    self:Column(x, w, bottom)
end

function ViewMixin:DrawFinderAside(onFound)
    local width = self:GetWidth()
    local mainX, mainW = SIDE_W + SIDE_GAP, width - SIDE_W - SIDE_GAP
    self:Column(0, SIDE_W, 0)
    for _, group in ipairs(Finder.GROUPS) do self:Add("finderPicks", group) end
    local sideBottom = self.cursor
    self:Column(mainX, mainW, 0)
    if not Finder.Any() then
        self:Note(TEXT_PICK)
    else
        local found = self.found
        local n = Finder.Collect(found, self.ItemShown, self, self.playerLevel)
        self:Add("finderHead", n)
        self:AddFoundColumns(mainW)
        if n == 0 then self:Note(TEXT_NONE) end
        for i = 1, math.min(n, MAX_SHOWN) do
            local record = found[i]
            self:AddFound(record, Where(record.boss, record.dungeon), mainX, mainW)
        end
        self.itemRoom = nil
        if n > MAX_SHOWN then self:Note(TEXT_FIRST:format(MAX_SHOWN, n)) end
    end
    self:Column(0, width, math.max(sideBottom, self.cursor))
    self:Finish()
end

function ViewMixin:DrawFinder(onFound)
    self:Begin()
    self.finding, self.onFound, self.striped = true, onFound, true
    if self.finderAside then return self:DrawFinderAside(onFound) end
    self:SectionLink(TEXT_TITLE, Finder.Any() and TEXT_CLEAR or nil, ClearPicks, self)
    for _, group in ipairs(Finder.GROUPS) do self:Add("finderPicks", group) end
    self:Space(SECTION_SPACE)
    if not Finder.Any() then
        self:Note(TEXT_PICK)
        return self:Finish()
    end
    local found = self.found
    local n = Finder.Collect(found, self.ItemShown, self, self.playerLevel)
    self:Section(TEXT_FOUND, n)
    if n == 0 then self:Note(TEXT_NONE) end
    for i = 1, math.min(n, MAX_SHOWN) do
        local record = found[i]
        local id, boss = record.item, record.boss
        local chance = record.chance > 0 and record.chance or nil
        local row = self:Add("item", id, chance, self:ItemRank(id), self:ItemUpgrade(id), nil, Where(boss, record.dungeon))
        row.boss, row.dungeon = boss, record.dungeon
    end
    if n > MAX_SHOWN then self:Note(TEXT_FIRST:format(MAX_SHOWN, n)) end
    self:Finish()
end
