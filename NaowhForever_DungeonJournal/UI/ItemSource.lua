-- ItemSource.lua: Where It Drops: the bosses that drop an item, their dungeon and the chance, on its tooltip anywhere.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings

local MAX_LINES = 3
local TEXT_DROPS = ns.L("Drops from %s")
local TEXT_MORE = ns.L("and %d more")
local TEXT_TRASH = ns.L("Trash")
local PLACE = "%s, %s"
local CHANCE = " (%d%%)"

local sources
local hooked = false

local function ByChance(a, b)
    return a.chance > b.chance
end

local function Index()
    sources = {}
    for _, dungeon in ipairs(J.Dungeons()) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                local where = PLACE:format(boss.trash and TEXT_TRASH or boss.name, dungeon.name)
                for i, id in ipairs(boss.loot or {}) do
                    local list = sources[id] or {}
                    list[#list + 1] = { where = where, chance = boss.chance and boss.chance[i] or 0 }
                    sources[id] = list
                end
            end
        end
    end
    for _, list in pairs(sources) do table.sort(list, ByChance) end
end

local function On()
    return S.Get("enabled") and S.Get("itemSources")
end

local function OnItemTooltip(tooltip, data)
    local id = data and data.id
    if not id or issecretvalue(id) or not On() then return end
    local owner = tooltip:GetOwner()
    if owner and owner.journalItem then return end
    if not sources then Index() end
    local list = sources[id]
    if not list then return end
    local muted = T.muted
    for i = 1, math.min(#list, MAX_LINES) do
        local source = list[i]
        local text = TEXT_DROPS:format(source.where)
        if source.chance > 0 then text = text .. CHANCE:format(source.chance) end
        tooltip:AddLine(text, muted.r, muted.g, muted.b)
    end
    if #list > MAX_LINES then tooltip:AddLine(TEXT_MORE:format(#list - MAX_LINES), muted.r, muted.g, muted.b) end
end

local function Sync()
    if hooked or not On() then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "itemSources" then Sync() end
end

S.OnChange(OnSettingChanged)
ns.OnApply(Sync)
