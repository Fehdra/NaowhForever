-- WeaponSkills.lua: the Weapon Skills panel: the level of the weapons you carry and where to learn the rest.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local WIDTH = 300
local MIN_MAX_H, SCREEN_SHARE = 300, 0.7
local ROW_H, ICON, ICON_EDGES, ICON_GAP = 32, 22, 2, 8
local TEXT_X = ICON + ICON_EDGES + ICON_GAP
local LINE_TOP, SUB_BOTTOM, BAR_BOTTOM, BAR_H = 3, 3, 6, 3
local SECTION_H, SECTION_GAP, NONE_TOP = 18, 6, 4
local ALL_W, ALL_H, BTN_GAP = 44, 20, 4
local FONT_LABEL, FONT_NAME, FONT_SUB = 11, 13, 11
local REDRAW_DELAY, NEXT_FRAME = 0.1, 0
local FIRST_LEVEL = 1
local CARRIED_GAP = "  "
local POSITION_KEY = "trainingWeaponsPanel"
local PLACE = { "TOPRIGHT", "TOPRIGHT", -260, -220 }
local ANCHOR, ANCHOR_TO = "TOPLEFT", "BOTTOMLEFT"
local SETTINGS_PAGE = "Leveling & Training > Skills"
local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
    "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "ZONE_CHANGED_NEW_AREA" }

local TEXT_TITLE = ns.L("WEAPON SKILLS")
local TEXT_TITLE_TIP = ns.L("Weapon Skills")
local TEXT_TITLE_HINT = ns.L("Click to open the Weapon Skills settings.")
local TEXT_COG_TIP = ns.L("Weapon Skills settings")
local TEXT_COG_HINT = ns.L("Opens the Weapon Skills settings.")
local TEXT_KNOWN, TEXT_LEARN = ns.L("KNOWN"), ns.L("TO LEARN")
local TEXT_ALL, TEXT_MINE = ns.L("All"), ns.L("Mine")
local TEXT_ALL_TIP = ns.L("Show every weapon skill you know.")
local TEXT_MINE_TIP = ns.L("Show only the weapons you wear or carry.")
local TEXT_EQUIPPED, TEXT_BAGS = ns.L("Equipped"), ns.L("In your bags")
local TEXT_LEARNED = ns.L("Learned")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_AT_TRAINER = ns.L("At the trainer")
local TEXT_NONE = ns.L("No weapon skills to show")
local TEXT_CLICK = ns.L("Click for a waypoint to where it is taught.")
local TEXT_CANT_YET = ns.L("You carry one but cannot use it until you learn the skill.")
local TEXT_SKILL = ns.L("Skill %d / %d")
local TEXT_OF = " / "

local panel
local rows, sections = {}, {}
local queued = false
local Render

local function Level(skill)
    return skill.rank + (skill.modifier or 0)
end

local function RowEnter(row)
    row.hover:Show()
    local data = row.data
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetSpellByID(data.spell)
    if data.skill then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_SKILL:format(Level(data.skill), data.skill.maxRank), T.fg.r, T.fg.g, T.fg.b)
    elseif not C_SpellBook.IsSpellKnown(data.spell) then
        local c = Style.WARN_RGB
        GameTooltip:AddLine(" ")
        if data.where then GameTooltip:AddLine(TEXT_CANT_YET, c.r, c.g, c.b, true) end
        GameTooltip:AddLine(TEXT_CLICK, T.muted.r, T.muted.g, T.muted.b, true)
    end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RowClick(row)
    if IsModifiedClick("CHATLINK") then
        ChatFrameUtil.InsertLink(C_Spell.GetSpellLink(row.data.spell))
    elseif not C_SpellBook.IsSpellKnown(row.data.spell) then
        Training.WaypointToMaster(row.data.entry)
    end
end

local function NewRow()
    local row = CreateFrame("Button", nil, panel.body)
    row:SetHeight(ROW_H)
    Parts.RowBands(row, TEXT_X)
    row.icon = Rows.Icon(row, ICON)
    row.icon.edge:SetPoint("LEFT", 0, 0)
    row.value = Rows.Text(row, FONT_NAME, nil)
    row.value:SetPoint("TOPRIGHT", 0, -LINE_TOP)
    row.name = Rows.Text(row, FONT_NAME, nil)
    row.name:SetPoint("TOPLEFT", TEXT_X, -LINE_TOP)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -ICON_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.sub = Rows.Text(row, FONT_SUB, nil, T.muted)
    row.sub:SetWordWrap(false)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetHeight(BAR_H)
    row.bar:SetStatusBarTexture(St.WHITE)
    row.bar.bg = ns.Solid(row.bar, "BACKGROUND", T.line, 1)
    row.bar.bg:SetAllPoints()
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    return row
end

local function Section(i, text, y)
    local fs = sections[i]
    if not fs then
        fs = Rows.Text(panel.body, FONT_LABEL, nil, T.muted)
        sections[i] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 0, -y)
    fs:SetText(text)
    fs:Show()
    return y + SECTION_H
end

local function Where(where)
    if where == "equipped" then return ns.Color("accent", TEXT_EQUIPPED) end
    if where == "bags" then return TEXT_BAGS end
end

local function FillKnown(row, data)
    local skill = data.skill
    row.sub:ClearAllPoints()
    row.sub:SetPoint("BOTTOMRIGHT", 0, SUB_BOTTOM)
    row.sub:SetJustifyH("RIGHT")
    row.sub:SetText(Where(data.where) or "")
    row.bar:ClearAllPoints()
    row.bar:SetPoint("BOTTOMLEFT", TEXT_X, BAR_BOTTOM)
    row.bar:SetPoint("RIGHT", row.sub, "LEFT", data.where and -ICON_GAP or 0, 0)
    if not skill then
        row.value:SetText(ns.Color("muted", TEXT_LEARNED))
        row.bar:Hide()
        return
    end
    local max = skill.maxRank
    local capped = skill.rank >= max
    local level = capped and ns.Color(Style.UP_RGB, Level(skill)) or ns.Color("fg", Level(skill))
    row.value:SetText(level .. ns.Color("muted", TEXT_OF .. max))
    row.bar:SetMinMaxValues(0, max)
    row.bar:SetValue(math.min(skill.rank, max))
    local c = capped and Style.UP_RGB or T.accent
    row.bar:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, 1)
    row.bar:Show()
end

local function FillLearn(row, data)
    row.bar:Hide()
    row.sub:ClearAllPoints()
    row.sub:SetPoint("BOTTOMLEFT", TEXT_X, SUB_BOTTOM)
    row.sub:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.sub:SetJustifyH("LEFT")
    local carried = data.where and (ns.Color(Style.WARN_RGB, TEXT_BAGS) .. CARRIED_GAP) or ""
    row.sub:SetText(carried .. Training.MasterPlace(data.entry))
    if (data.level or FIRST_LEVEL) > UnitLevel("player") then
        row.value:SetText(ns.Color(Style.WARN_RGB, TEXT_LEVEL:format(data.level)))
        return
    end
    local price = Training.WeaponPrice(data.entry)
    row.value:SetText(price and Training.Coins(price) or ns.Color("muted", TEXT_AT_TRAINER))
end

function Render()
    if not (panel and panel:IsShown()) then return end
    local all = S.Get("weaponsAll")
    ns.SetButtonText(panel.all, all and TEXT_MINE or TEXT_ALL)
    local list = Training.WeaponSkills(all)
    for _, row in ipairs(rows) do row:Hide() end
    for _, fs in ipairs(sections) do fs:Hide() end
    local y, used, titles = 0, 0, 0
    local function Add(data, fill)
        used = used + 1
        local row = rows[used] or NewRow()
        rows[used] = row
        row.data = data
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", panel.body, "RIGHT", 0, 0)
        row.stripe:SetShown(used % 2 == 0)
        row.hover:Hide()
        row.icon:SetTexture(C_Spell.GetSpellTexture(data.spell))
        row.name:SetText(C_Spell.GetSpellName(data.spell) or "")
        fill(row, data)
        row:Show()
        y = y + ROW_H
    end
    if #list.known > 0 then
        titles = titles + 1
        y = Section(titles, TEXT_KNOWN, y)
        for _, data in ipairs(list.known) do Add(data, FillKnown) end
    end
    if #list.learn > 0 and S.Get("weaponsUnlearned") then
        titles = titles + 1
        y = Section(titles, TEXT_LEARN, y + (titles > 1 and SECTION_GAP or 0))
        for _, data in ipairs(list.learn) do Add(data, FillLearn) end
    end
    panel.none:SetShown(used == 0)
    if used == 0 then y = y + SECTION_H end
    panel.body:SetHeight(math.max(y, 1))
    if panel:Fit(y) then
        panel:SetTrackerWidth(WIDTH)
        C_Timer.After(NEXT_FRAME, Render)
    end
end

local function MaxH()
    local screen = (UIParent:GetHeight() or 0) * SCREEN_SHARE / ns.UIScale()
    return math.max(MIN_MAX_H, math.floor(screen))
end

local function Redraw()
    queued = false
    Render()
end

local function Queue()
    if queued or not (panel and panel:IsShown()) then return end
    queued = true
    C_Timer.After(REDRAW_DELAY, Redraw)
end

local function OnShow(self)
    for _, event in ipairs(EVENTS) do self:RegisterEvent(event) end
    Render()
end

local function OnHide(self)
    self:UnregisterAllEvents()
end

local function OpenSettings()
    ns.OpenOptionsWindow(SETTINGS_PAGE)
end

local function SavePosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not left then return end
    panel:ClearAllPoints()
    panel:SetPoint(ANCHOR, UIParent, ANCHOR_TO, left, top)
    ns.AccountSettings()[POSITION_KEY] = { ANCHOR, ANCHOR_TO, left, top }
end

local function LoadPosition()
    local saved = ns.AccountSettings()[POSITION_KEY]
    if type(saved) == "table" then return saved[1], saved[2], saved[3], saved[4] end
end

local function Close()
    S.Set("weaponsShown", false)
end

local function ToggleAll()
    S.Set("weaponsAll", not S.Get("weaponsAll"))
end

local function AllEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(S.Get("weaponsAll") and TEXT_MINE_TIP or TEXT_ALL_TIP, nil, nil, nil, nil, true)
    GameTooltip:Show()
end

local function Build()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        width = WIDTH, titleRoom = ALL_W + BTN_GAP, maxHeight = MaxH,
        onTitle = OpenSettings, titleTip = TEXT_TITLE_TIP, titleHint = TEXT_TITLE_HINT,
        settings = { page = SETTINGS_PAGE, tip = TEXT_COG_TIP, hint = TEXT_COG_HINT },
        load = LoadPosition, save = SavePosition, place = PLACE, onClose = Close,
    })
    panel.all = ns.Button(panel, TEXT_ALL, ALL_W, ALL_H, ToggleAll)
    panel.all:SetPoint("RIGHT", panel.close, "LEFT", -BTN_GAP, 0)
    panel.all:HookScript("OnEnter", AllEnter)
    panel.all:HookScript("OnLeave", GameTooltip_Hide)
    panel.none = Rows.Text(panel.body, FONT_SUB, nil, T.muted)
    panel.none:SetPoint("TOPLEFT", 0, -NONE_TOP)
    panel.none:SetText(TEXT_NONE)
    panel:SetScript("OnShow", OnShow)
    panel:SetScript("OnHide", OnHide)
    panel:SetScript("OnEvent", Queue)
    panel:Hide()
    panel:Place()
end

local function Apply()
    local want = S.Get("enabled") and S.Get("weaponsShown")
    if want and not panel then Build() end
    if not panel then return end
    if want then
        panel:SetScale(ns.UIScale())
        panel:Paint()
        panel:Show()
    else
        panel:Hide()
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "weaponsShown" then
        Apply()
    elseif key == "weaponsAll" or key == "weaponsUnlearned" then
        Render()
    end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Training.OnChange(Queue)
S.OnChange(OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
