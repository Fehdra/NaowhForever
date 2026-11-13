-- Run with Lua 5.1 from the repository root: the Restock Reminder hides at the auction house, where it sat
-- over The Market's Up Next list (Rushtek), and comes back when the auction house closes.

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local source = Read("NaowhForever_QoL/Loot/Restock.lua")

local function Slice(a, b)
    local i = assert(source:find(a, 1, true), a)
    local j = assert(source:find(b, i, true), b)
    return source:sub(i, j - 1)
end

local state = { shown = false, checks = 0 }
local env = setmetatable({
    On = function() return true end,
    IsResting = function() return true end,
    InCombatLockdown = function() return false end,
    IsInInstance = function() return false end,
    Lines = function() return { "Drink  0 left" } end,
    ShowAlert = function() state.shown = true end,
    HideAlert = function() state.shown = false end,
    OnMerchantShow = function() end,
    OnRestingChanged = function() end,
    C_Timer = { After = function() end },
    events = {},
}, { __index = _G })

local code = "local atAuctionHouse = false\n"
    .. "local pendingItems = {}\n"
    .. Slice("local function Check()", "\nlocal function Repair(") .. "\n"
    .. Slice("local function OnEvent(", "\nlocal function MigrateFoodLevel(") .. "\n"
    .. "return Check, OnEvent"
local chunk = assert(loadstring(code, "Restock"))
setfenv(chunk, env)
local Check, OnEvent = chunk()

local count = 0
local function Expect(name, ok)
    assert(ok, name)
    count = count + 1
    print("PASS " .. name)
end

Check()
Expect("resting with no drink: the alert shows", state.shown)
OnEvent(nil, "AUCTION_HOUSE_SHOW")
Expect("the auction house opens: it hides", not state.shown)
OnEvent(nil, "BAG_UPDATE_DELAYED")
Expect("and stays hidden while it is open", not state.shown)
OnEvent(nil, "AUCTION_HOUSE_CLOSED")
Expect("the auction house closes: it is back", state.shown)

print(count .. " restock auction house checks passed")
