-- BiS Auto list: each slot gets the items worth most to the spec's weights, from what you wear and
-- the pool, that need no more than 5 levels over yours; a one-hander counts the best off hand beside
-- it; Ring 2 skips Ring 1's pick; an item not loaded yet is asked for and waited on; a kept slot is
-- never refilled.
local Load = dofile("Tools/regression/load_files.lua")
local FILES = { "NaowhForever_BiS/BiS/BiS.lua", "NaowhForever_BiS/BiS/Constants.lua", "NaowhForever_BiS/BiS/Auto.lua" }

local EQUIP = {
    [1] = "head", [2] = "head", [3] = "head", [4] = "head", [5] = "head",
    [10] = "ring", [11] = "ring", [12] = "ring",
    [20] = "one", [21] = "two", [22] = "off",
}
local SLOTS = { head = { 1 }, ring = { 11, 12 }, one = { 16, 17 }, two = { 16 }, off = { 17 } }

local function Fixture(o)
    local requested, timers, frame = {}, {}, { events = {} }
    local list = o.list or { auto = true, slots = {}, extra = {} }
    local spec = { key = "arms-warrior", slots = o.ranked or {} }
    local ns = { QoLSettings = { Get = function() return true end, OnChange = function() end },
        BiSLeveling = { levels = { 30 } }, Apply = function() end }
    ns.Shared = { Items = {
        GEAR_SLOTS = { { 1 }, { 11 }, { 12 }, { 16 }, { 17 } },
        SlotsFor = function(id) return SLOTS[EQUIP[id]] end,
        IsTwoHand = function(id) return EQUIP[id] == "two" end,
        PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 },
    } }
    ns.UI = {}
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        UnitLevel = function() return o.level or 20 end,
        GetInventoryItemID = function(_, slot) return (o.worn or {})[slot] end,
        GetInventoryItemLink = function(_, slot) return (o.worn or {})[slot] and "worn:" .. o.worn[slot] end,
        C_Item = { RequestLoadItemDataByID = function(id) requested[id] = true end },
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        CreateFrame = function()
            function frame.SetScript(_, _, fn) frame.script = fn end
            function frame.RegisterEvent(_, event) frame.events[event] = true end
            function frame.UnregisterEvent(_, event) frame.events[event] = nil end
            return frame
        end,
        hooksecurefunc = function() end,
        GetTime = function() return o.now or 0 end,
    }, { __index = _G })
    env.ns = ns
    Load({ FILES[1], FILES[2] }, env)
    local B = ns.BiS
    B.Rankings = {
        Candidates = function(slot, s) return s.slots[slot] or {} end,
        DungeonDrops = function(slot) return (o.drops or {})[slot] or {} end,
        LevelPicks = function() return o.levelPicks end,
        Wieldable = function() return true end,
        ReqLevel = function(id) return (o.req or {})[id] or 1 end,
    }
    B.Lists = { CurrentSpec = function() return spec end, List = function() return o.list or list end,
        Changed = function() end }
    local loading = o.loading or {}
    ns.StatWeights = {
        For = function() return { str = 1 } end,
        Usable = function(id) if loading[id] then return nil end return true end,
        Stats = function(item)
            local id = type(item) == "number" and item or tonumber(item:match("%d+"))
            if loading[id] then return nil end
            return { str = o.worth[id] or 0 }
        end,
        Worth = function(stats, weights) return stats.str * weights.str end,
        DpsShare = function() return 1 end,
        OnChange = function(fn) o.onWeights = fn end,
    }
    Load({ FILES[3] }, env)
    return { Auto = B.Auto, list = list, spec = spec, requested = requested, B = B, timers = timers, frame = frame }
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end
local function Join(t) return table.concat(t, ",") end

Case("a slot's picks are best first, up to three, and none past 5 levels over yours", function()
    local m = Fixture({ level = 20, ranked = { [1] = { 1, 2, 3, 4, 5 } },
        req = { [5] = 26, [4] = 25 }, worth = { [1] = 1, [2] = 4, [3] = 3, [4] = 9, [5] = 20 } })
    local picks = m.Auto.Build(m.spec)
    assert(Join(picks[1]) == "4,2,3", Join(picks[1]))
end)

Case("what you wear competes, so the list never asks you to wear worse", function()
    local m = Fixture({ worn = { [1] = 3 }, ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 2, [3] = 5 } })
    assert(m.Auto.Build(m.spec)[1][1] == 3)
end)

Case("the pool is the ranking, the dungeon drops and the leveling lists", function()
    local m = Fixture({ drops = { [1] = { 1 } }, levelPicks = { [1] = 2 }, worth = { [1] = 1, [2] = 2 } })
    assert(Join(m.Auto.Build(m.spec)[1]) == "2,1")
end)

Case("Ring 2 skips Ring 1's pick, and a worn ring counts for either", function()
    local m = Fixture({ worn = { [12] = 12 }, ranked = { [11] = { 10, 11 } }, worth = { [10] = 2, [11] = 1, [12] = 5 } })
    local picks = m.Auto.Build(m.spec)
    assert(picks[11][1] == 12 and picks[12][1] == 10, Join(picks[11]) .. " / " .. Join(picks[12]))
end)

Case("a two-hander wins only when it beats a one-hander and the best off hand together", function()
    local m = Fixture({ ranked = { [16] = { 20, 21 }, [17] = { 22 } }, worth = { [20] = 3, [21] = 5, [22] = 3 } })
    local picks = m.Auto.Build(m.spec)
    assert(picks[16][1] == 20 and picks[17][1] == 22, Join(picks[16]))
    m = Fixture({ ranked = { [16] = { 20, 21 }, [17] = { 22 } }, worth = { [20] = 3, [21] = 7, [22] = 3 } })
    assert(m.Auto.Build(m.spec)[16][1] == 21)
end)

Case("an item not loaded yet is asked for and waited on, not picked", function()
    local m = Fixture({ ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 9 }, loading = { [2] = true } })
    local picks, waiting = m.Auto.Build(m.spec)
    assert(waiting and m.requested[2] and Join(picks[1]) == "1")
end)

Case("filling leaves a kept slot as you set it, and says when nothing changed", function()
    local list = { auto = true, slots = { [1] = 1 }, extra = {}, kept = { [1] = true } }
    local m = Fixture({ list = list, ranked = { [1] = { 1, 2 }, [11] = { 10 } }, worth = { [1] = 1, [2] = 9, [10] = 1 } })
    assert(m.Auto.Fill(list) == true)
    assert(list.slots[1] == 1 and list.extra[1] == nil, "kept slot untouched")
    assert(list.slots[11] == 10)
    assert(m.Auto.Fill(list) == false, "the same picks again are no change")
end)

Case("the Leveling page's preview is built again only when your level, gear or weights change", function()
    local o = { level = 20, worn = {}, ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 2 } }
    local m = Fixture(o)
    local first = m.Auto.Preview(m.spec)
    o.worth[2] = 0
    assert(m.Auto.Preview(m.spec)[1][1] == 2, "same level and gear: kept")
    o.level = 21
    assert(m.Auto.Preview(m.spec)[1][1] == 1, "a level up builds it again")
    o.worth[1] = 0
    o.worth[2] = 5
    o.worn[1] = 1
    assert(m.Auto.Preview(m.spec)[1][1] == 2, "new gear builds it again")
    o.worth[2] = 0
    o.onWeights()
    assert(m.Auto.Preview(m.spec)[1][1] == 1 and first, "new weights build it again")
end)

Case("a worn item not loaded yet is asked for and waited on too", function()
    local m = Fixture({ worn = { [1] = 3 }, ranked = { [1] = { 1 } }, worth = { [1] = 1, [3] = 5 }, loading = { [3] = true } })
    local _, waiting = m.Auto.Build(m.spec)
    assert(waiting and m.requested[3] and m.frame.events.GET_ITEM_INFO_RECEIVED)
end)

Case("only an awaited item the server sends wakes it; a refused one does not", function()
    local m = Fixture({ ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 9 }, loading = { [2] = true } })
    m.Auto.Build(m.spec)
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 2, false)
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 99, true)
    assert(#m.timers == 0, "refused or unawaited: nothing queued")
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 2, true)
    assert(#m.timers == 1)
end)

Case("switching to another Auto list refills it", function()
    local o = { ranked = { [1] = { 1 } }, worth = { [1] = 1 } }
    o.list = { id = 1, auto = true, slots = {}, extra = {} }
    local m = Fixture(o)
    m.B.ListChanged()
    assert(#m.timers == 1 and m.frame.events.PLAYER_LEVEL_UP)
    m.timers[1]()
    o.list = { id = 2, auto = true, slots = {}, extra = {} }
    m.B.ListChanged()
    assert(#m.timers == 2, "a second Auto list is refilled")
    m.timers[2]()
    assert(o.list.slots[1] == 1)
    o.list = { id = 3, slots = {}, extra = {} }
    m.B.ListChanged()
    assert(not m.frame.events.PLAYER_LEVEL_UP, "an own list stops the listening")
end)

print(("bis auto: %d cases passed"):format(count))
