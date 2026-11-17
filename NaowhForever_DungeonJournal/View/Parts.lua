-- Parts.lua: the Dungeon Journal's own small parts: a fight's length, a boss's level and portrait, a row's band to its card's edges, its side panels (J.View.Parts).
local ns = _G.NaowhForever

local J = ns.Journal
local Shared = ns.Shared
local View = J.View
local Parts = View.Parts

local CARD_PAD = J.Style.CARD_PAD

local SECONDS_PER_MINUTE = J.C.SECONDS_PER_MINUTE
local EDGE_INSET = 1
local BUST_RIGHT = 110 / 128
local FIGHT_LENGTH = "%d:%02d"
local FULL_OPACITY = 1
local INFO_LOW, INFO_HIGH = 1, 2
local MASK = ns.MEDIA .. "circle_mask.tga"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"

local TEXT_UNKNOWN_LEVEL = "??"
local TEXT_RANGE = "%s-%s"

local function Opacity()
    return FULL_OPACITY
end

function Parts.FightLength(seconds)
    return FIGHT_LENGTH:format(math.floor(seconds / SECONDS_PER_MINUTE), seconds % SECONDS_PER_MINUTE)
end

function Parts.BossLevel(info)
    local low, high = info[INFO_LOW], info[INFO_HIGH]
    if not low then return nil end
    if low < 0 or high < 0 then return TEXT_UNKNOWN_LEVEL end
    if low == high then return tostring(low) end
    return TEXT_RANGE:format(low, high)
end

function Parts.BossFace(row, size)
    local face = row:CreateTexture(nil, "ARTWORK")
    face:SetSize(size, size)
    local mask = row:CreateMaskTexture()
    mask:SetAllPoints(face)
    mask:SetTexture(MASK, MASK_WRAP, MASK_WRAP)
    face:AddMaskTexture(mask)
    face:Hide()
    return face
end

function Parts.SetBossFace(face, boss, always)
    local shown = boss.model ~= nil and (always or J.Settings.Get("bossPortraits") == true)
    if shown then SetPortraitTextureFromCreatureDisplayID(face, boss.model) end
    face:SetShown(shown)
    return shown
end

function Parts.Bust(row, width, height)
    local bust = row:CreateTexture(nil, "ARTWORK")
    bust:SetSize(width, height)
    bust:SetTexCoord(0, BUST_RIGHT, 0, 1)
    bust:Hide()
    return bust
end

function Parts.SetBust(bust, boss)
    local file = boss.npc and J.BossFaces[boss.npc]
    if file then bust:SetTexture(file) end
    bust:SetShown(file ~= nil)
    return file ~= nil
end

function Parts.CardStrip(row)
    local strip = row:CreateTexture(nil, "BACKGROUND")
    strip:SetPoint("TOPLEFT", -CARD_PAD + EDGE_INSET, -EDGE_INSET)
    strip:SetPoint("BOTTOMRIGHT", CARD_PAD - EDGE_INSET, 0)
    return strip
end

function Parts.CardBand(row, alpha)
    local band = ns.Solid(row, "BACKGROUND", ns.THEME.fg, alpha)
    band:SetPoint("TOPLEFT", -CARD_PAD + EDGE_INSET, 0)
    band:SetPoint("BOTTOMRIGHT", CARD_PAD - EDGE_INSET, 0)
    return band
end

function Parts.SidePanel(actions)
    return Shared.Parts.SidePanel(actions, View.New, Opacity)
end
