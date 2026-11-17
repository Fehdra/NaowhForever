-- FinderPicks.lua: one group of the Loot Finder's picks: its title, then a chip for each, edged in the accent while picked.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Finder = J.Finder
local Kinds = J.View.Kinds
local Tip = J.View.Parts.Tip
local St = J.Style
local BORDER_RGB, CHIP_H, CHIP_PAD, CHIP_GAP, SMALL_SIZE = St.BORDER_RGB, St.CHIP_H, St.CHIP_PAD, St.CHIP_GAP,
    St.SMALL_SIZE

local CHIP_FILL, PICKED_FILL = 0.04, 0.15
local TITLE_W = 96
local GROUP_BOTTOM = 6

local TEXT_EVERY = ns.L("Lists the loot that has every one you pick.")
local TEXT_ANY = ns.L("Lists the loot that fits any one you pick.")
local TEXT_RULE_ALL, TEXT_RULE_ANY = ns.L("all"), ns.L("any")
local TEXT_FOUND = ns.L("Found")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_COLUMNS = { ns.L("Item"), ns.L("For you"), ns.L("From"), ns.L("Chance") }
local TEXT_NO_UPGRADE = ns.L("No upgrade")
local STACK_TITLE_H = 20
local HEAD_H, HEAD_GAP, CLEAR_W = 28, 10, 56
local COLUMNS_H = 22
local FROM_GAP = 2

local function Paint(chip)
    local on = Finder.Picked(chip.pick)
    local edge = on and T.accent or BORDER_RGB
    chip.edge:SetColor(edge.r, edge.g, edge.b, 1)
    chip.picked:SetShown(on)
    local text = (on or chip.hovered) and T.fg or T.muted
    chip.label:SetTextColor(text.r, text.g, text.b)
end

local function ChipEnter(chip)
    chip.hovered = true
    Paint(chip)
    if not Tip(chip, "ANCHOR_TOP") then return end
    GameTooltip:SetText(chip.label:GetText(), 1, 1, 1)
    GameTooltip:AddLine(chip.group.all and TEXT_EVERY or TEXT_ANY, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function ChipLeave(chip)
    chip.hovered = false
    Paint(chip)
    GameTooltip:Hide()
end

local function ChipClicked(chip)
    Finder.Toggle(chip.pick)
    chip.view:Redraw()
end

local function NewChip(row)
    local chip = CreateFrame("Button", nil, row)
    chip.view = row.view
    chip:SetHeight(CHIP_H)
    ns.Solid(chip, "BACKGROUND", T.fg, CHIP_FILL):SetAllPoints()
    chip.picked = ns.Solid(chip, "BORDER", T.accent, PICKED_FILL)
    chip.picked:SetAllPoints()
    chip.edge = ns.Border(chip, BORDER_RGB)
    chip.label = ns.Font(chip, SMALL_SIZE, nil, T.muted)
    chip.label:SetPoint("LEFT", CHIP_PAD, 0)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", ChipLeave)
    chip:SetScript("OnClick", ChipClicked)
    return chip
end

Kinds.finderPicks = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.view = view
        row.title = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.title:SetPoint("LEFT", row, "TOPLEFT", 0, -CHIP_H / 2)
        row.rule = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.rule:SetPoint("RIGHT", row, "TOPRIGHT", 0, -CHIP_H / 2)
        row.chips = {}
        return row
    end,
    Set = function(row, group)
        local stacked = row.view.finderAside == true
        row.title:SetText(stacked and group.title or group.title:upper())
        row.rule:SetText(stacked and (group.all and TEXT_RULE_ALL or TEXT_RULE_ANY) or "")
        local width = row:GetWidth()
        local picks = group.picks
        local indent = stacked and 0 or TITLE_W
        local x, y = indent, stacked and STACK_TITLE_H or 0
        for i = 1, #picks do
            local chip = row.chips[i] or NewChip(row)
            row.chips[i] = chip
            chip.pick, chip.group, chip.hovered = picks[i], group, false
            chip.label:SetText(Finder.Label(picks[i]))
            local w = CHIP_PAD * 2 + math.ceil(chip.label:GetStringWidth())
            chip:SetWidth(w)
            if x + w > width and x > indent then x, y = indent, y + CHIP_H + CHIP_GAP end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, -y)
            chip:Show()
            Paint(chip)
            x = x + w + CHIP_GAP
        end
        for i = #picks + 1, #row.chips do row.chips[i]:Hide() end
        return y + CHIP_H + GROUP_BOTTOM
    end,
}

local function ClearClicked(button)
    Finder.Clear()
    button.view:Redraw()
end

Kinds.finderHead = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.view = view
        row.found = ns.Font(row, St.HEADING_SIZE, nil, T.fg)
        row.found:SetPoint("LEFT")
        row.clear = ns.Button(row, TEXT_CLEAR, CLEAR_W, CHIP_H + 2, ClearClicked)
        row.clear.view = view
        row.clear:SetPoint("RIGHT")
        row.chips = {}
        return row
    end,
    Set = function(row, count)
        row.found:SetText(TEXT_FOUND .. " " .. count)
        local x, used = math.ceil(row.found:GetStringWidth()) + HEAD_GAP, 0
        for _, group in ipairs(Finder.GROUPS) do
            for _, pick in ipairs(group.picks) do
                if Finder.Picked(pick) then
                    used = used + 1
                    local chip = row.chips[used] or NewChip(row)
                    row.chips[used] = chip
                    chip.pick, chip.group, chip.hovered = pick, group, false
                    chip.label:SetText(Finder.Label(pick))
                    chip:SetWidth(CHIP_PAD * 2 + math.ceil(chip.label:GetStringWidth()))
                    chip:ClearAllPoints()
                    chip:SetPoint("LEFT", x, 0)
                    chip:Show()
                    Paint(chip)
                    x = x + chip:GetWidth() + CHIP_GAP
                end
            end
        end
        for i = used + 1, #row.chips do row.chips[i]:Hide() end
        return HEAD_H
    end,
}

Kinds.finderColumns = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.cells = {}
        for i = 1, #TEXT_COLUMNS do
            row.cells[i] = ns.Font(row, SMALL_SIZE, nil, T.muted)
            row.cells[i]:SetText(TEXT_COLUMNS[i])
        end
        row.cells[#TEXT_COLUMNS]:SetPoint("RIGHT")
        local rule = ns.Solid(row, "ARTWORK", T.line, 1)
        rule:SetPoint("BOTTOMLEFT")
        rule:SetPoint("BOTTOMRIGHT")
        ns.Hairline(rule, "h")
        return row
    end,
    Set = function(row, forX, fromX)
        row.cells[1]:SetPoint("LEFT")
        row.cells[2]:SetPoint("LEFT", forX, 0)
        row.cells[3]:SetPoint("LEFT", fromX, 0)
        return COLUMNS_H
    end,
}

Kinds.foundCells = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.mark = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.mark:SetPoint("LEFT")
        row.mark:SetJustifyH("LEFT")
        row.boss = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
        row.boss:SetJustifyH("LEFT")
        row.boss:SetWordWrap(false)
        row.dungeon = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.dungeon:SetPoint("TOPLEFT", row.boss, "BOTTOMLEFT", 0, -FROM_GAP)
        row.dungeon:SetJustifyH("LEFT")
        row.dungeon:SetWordWrap(false)
        return row
    end,
    Set = function(row, record, rank, upgrade, fromX, height)
        local tags = J.View.Parts.RankTag(rank) .. J.View.Parts.UpgradeTag(upgrade)
        row.mark:SetText(tags ~= "" and tags or TEXT_NO_UPGRADE)
        row.boss:ClearAllPoints()
        row.boss:SetPoint("BOTTOMLEFT", row, "LEFT", fromX, FROM_GAP / 2)
        row.boss:SetWidth(row:GetWidth() - fromX)
        row.dungeon:SetWidth(row:GetWidth() - fromX)
        row.boss:SetText(record.from or record.boss.name)
        row.dungeon:SetText(record.dungeon.name)
        return height
    end,
}
