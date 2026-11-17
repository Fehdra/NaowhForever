-- AttuneSettings.lua: Discovery's Attunements settings page (Discovery/Attunements), declared as cards.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local S = Discovery.Settings
local Attune = Discovery.Attune
local Settings = ns.Shared.Settings

local St = ns.Shared.Style

local SCALE = St.SCALE_RANGE
local PIN_SIZE = St.PIN_SIZE_RANGE
local OPACITY_RANGE = St.OPACITY_RANGE
local PERCENT_SCALE = St.PERCENT_SCALE
local ORDER_TRACKER = 10
local TEXT_SECTION = ns.L("Attunements")
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_PINS_OFF = ns.L("Turn on Attunement pins")
local TEXT_OPEN = ns.L("%d to work on")
local TEXT_NONE = ns.L("Nothing to work on at your level")
local TEXT_ABOUT = ns.L("The quest chain for each dungeon key and attunement, step by step.")

local function On() return S.Get("enabled") == true end
local function PinsOn() return On() and S.Get("attuneMapPins") == true end

local function Summary()
    local open = 0
    for _, key in ipairs(ns.Attunements.list) do
        if Attune.Next(key) then open = open + 1 end
    end
    if open == 0 then return TEXT_NONE end
    return TEXT_OPEN:format(open)
end

local function About()
    return TEXT_ABOUT
end

local function OpenAttunements()
    ns.OpenDiscoveryWindow("attune")
end

local page = Settings.Page("Discovery/Attunements", S)

page:Window({
    text = "Open Attunements",
    open = OpenAttunements,
    headline = Summary,
    detail = About,
})

page:Card({
    id = "attunetracker", name = "Tracker", order = ORDER_TRACKER, switch = "attuneTracker",
    help = "Shows the next quest of each key and attunement you can work on, with a waypoint.",
    search = "x close turn off keys",
    summary = Summary,
    rows = {
        { key = "attuneTrackerScale", label = "Scale", slider = SCALE, unit = "%", scale = PERCENT_SCALE, needs = On,
          why = TEXT_OFF, help = "How big the tracker is." },
        { key = "attuneTrackerAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE, needs = On, why = TEXT_OFF, help = "How solid the tracker is, in percent." },
    },
})

table.insert(ns.Shared.MapPins, {
    title = TEXT_SECTION, store = S, switch = "attuneMapPins",
    rows = {
        { key = "attuneMapPins", label = "Attunement Quests", toggle = true, store = S, needs = On, why = TEXT_OFF,
          help = "Shows the next quest of each key and attunement on your map; click one for a waypoint." },
        { key = "attuneMapPinSize", label = "Attunement Pin Size", slider = PIN_SIZE, store = S, always = true,
          needs = PinsOn, why = TEXT_PINS_OFF, help = "How big the pins are on the map." },
    },
})
