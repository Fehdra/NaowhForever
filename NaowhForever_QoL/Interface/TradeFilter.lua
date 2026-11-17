-- TradeFilter.lua: Trade Spam Filter, hides portal, summon, guild recruiting and boost spam in Trade chat.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local GENERAL, TRADE, LFG = 1, 2, 26
local ZONE_CHANNEL_ARG, BASE_NAME_ARG, LINE_ARG, GUID_ARG = 5, 7, 9, 10
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local REPEAT_RANGE = { 1, 30, 1 }
local SEEN_MAX = 500
local HIDDEN_MAX = 30
local TRADE_NAME = "^Trade"
local LIST_SEP = "[^,]+"
local TEXT_NONE = ns.L("Nothing hidden yet.")
local TEXT_HEADER = ns.L("Messages Trade Spam Filter has hidden: %d. The last %d:")
local TEXT_LINE = "%s [%s] %s: %s"
local TEXT_SUMMARY = ns.L("%d hidden")
local REASON_PORTALS, REASON_GUILDS = ns.L("Portals"), ns.L("Guild")
local REASON_BOOSTS, REASON_WORDS, REASON_REPEAT = ns.L("Boosts"), ns.L("Your words"), ns.L("Repeat")

local PORTALS = { "%f[%w]portals?%f[%W]", "%f[%w]ports?%f[%W]", "%f[%w]summons?%f[%W]", "%f[%w]summoning%f[%W]",
    "%f[%w]tp%f[%W]", "%f[%w]teleports?%f[%W]" }
local NOT_PORTALS = { "dark portal", "%f[%w]ha[sv]e? summons", "%f[%w]got summons", "%f[%w]with summons" }
local GUILD_ALWAYS = { "%f[%w]recruit", "%f[%w]g ?inv%f[%W]" }
local GUILD_WITH = { "join us%f[%W]", "join our%f[%W]", "members", "all levels", "welcom", "progress", "discord" }
local GUILD_WORD = "%f[%w]guild%f[%W]"
local BOOSTS = { "%f[%w]boost", "%f[%w]carry%f[%W]", "%f[%w]carries%f[%W]", "%f[%w]wts gold%f[%W]",
    "%f[%w]selling gold%f[%W]", "%f[%w]cheap gold%f[%W]", "www%.", "%.com%f[%W]" }

local APPLY_KEYS = { enabled = true, tradeFilter = true, tradeFilterWords = true, tradeFilterAllow = true }

local seen, seenCount = {}, 0
local hidden, hiddenTotal = {}, 0
local lastLine, lastHide = nil, false
local words, allow = {}, {}
local filtering = false

local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
local RemoveFilter = (ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter) or ChatFrame_RemoveMessageEventFilter

local function On()
    return S.Get("enabled") and S.Get("tradeFilter")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function List(text, into)
    wipe(into)
    for item in (text or ""):gmatch(LIST_SEP) do
        item = strtrim(item):lower()
        if item ~= "" then into[#into + 1] = item end
    end
end

local function Plain(msg)
    return msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):lower()
end

local function Bare(msg)
    return msg:gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end

local function AnyOf(text, patterns)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then return true end
    end
end

local function Without(text, patterns)
    for _, pattern in ipairs(patterns) do text = text:gsub(pattern, "") end
    return text
end

local function AnyWord(text, list)
    for _, word in ipairs(list) do
        if text:find(word, 1, true) then return true end
    end
end

local function Watched(zoneChannel, baseName)
    if zoneChannel == TRADE or (type(baseName) == "string" and baseName:find(TRADE_NAME)) then return true end
    return S.Get("tradeFilterOthers") and (zoneChannel == GENERAL or zoneChannel == LFG)
end

local function Trusted(author, guid)
    local name = Ambiguate(author, "none")
    if name == UnitName("player") then return true end
    for _, allowed in ipairs(allow) do
        if name:lower() == allowed then return true end
    end
    if UnitInParty(name) or UnitInRaid(name) then return true end
    if guid and guid ~= "" and C_FriendList.IsFriend(guid) then return true end
    if guid and guid ~= "" and C_BattleNet.GetGameAccountInfoByGUID(guid) then return true end
    return IsInGuild() and C_GuildInfo.MemberExistsByName(name)
end

local function Repeated(author, text)
    local key = author .. "\t" .. text
    local now, last = GetTime(), seen[key]
    if not last then
        if seenCount >= SEEN_MAX then
            wipe(seen)
            seenCount = 0
        end
        seenCount = seenCount + 1
    end
    seen[key] = now
    return last and now - last < S.Get("tradeFilterRepeatMinutes") * SECONDS_PER_MINUTE
end

local function Reason(author, msg)
    local text, plain = Bare(msg), Plain(msg)
    if S.Get("tradeFilterPortals") and AnyOf(Without(text, NOT_PORTALS), PORTALS) then
        return REASON_PORTALS
    end
    if S.Get("tradeFilterGuilds") and (AnyOf(text, GUILD_ALWAYS) or (text:find(GUILD_WORD) and AnyOf(text, GUILD_WITH))) then
        return REASON_GUILDS
    end
    if S.Get("tradeFilterBoosts") and AnyOf(text, BOOSTS) then return REASON_BOOSTS end
    if AnyWord(plain, words) then return REASON_WORDS end
    if S.Get("tradeFilterRepeats") and Repeated(author, plain) then return REASON_REPEAT end
end

local function Remember(author, msg, reason)
    hiddenTotal = hiddenTotal + 1
    if #hidden >= HIDDEN_MAX then table.remove(hidden, 1) end
    hidden[#hidden + 1] = { at = date("%H:%M"), author = Ambiguate(author, "none"), msg = msg, reason = reason }
end

local function Decide(msg, author, ...)
    if Secret(msg) or Secret(author) or type(msg) ~= "string" or type(author) ~= "string" then return false end
    local zoneChannel, baseName = select(ZONE_CHANNEL_ARG, ...), select(BASE_NAME_ARG, ...)
    if Secret(zoneChannel) or Secret(baseName) or not Watched(zoneChannel, baseName) then return false end
    local guid = select(GUID_ARG, ...)
    if Secret(guid) or Trusted(author, guid) then return false end
    local reason = Reason(author, msg)
    if reason then Remember(author, msg, reason) end
    return reason ~= nil
end

local function Filter(_, _, msg, author, ...)
    local line = select(LINE_ARG, ...)
    if line and not Secret(line) and line == lastLine then return lastHide end
    lastLine, lastHide = line, Decide(msg, author, ...)
    return lastHide
end

local function ShowHidden()
    if #hidden == 0 then return ns.Print(TEXT_NONE) end
    ns.Print(TEXT_HEADER:format(hiddenTotal, #hidden))
    for _, h in ipairs(hidden) do
        DEFAULT_CHAT_FRAME:AddMessage(TEXT_LINE:format(ns.Color("muted", h.at), h.reason, h.author, h.msg))
    end
end

local function Summary()
    return TEXT_SUMMARY:format(hiddenTotal)
end

local function Apply()
    List(S.Get("tradeFilterWords"), words)
    List(S.Get("tradeFilterAllow"), allow)
    lastLine = nil
    if On() and not filtering then
        AddFilter("CHAT_MSG_CHANNEL", Filter)
        filtering = true
    elseif not On() and filtering then
        RemoveFilter("CHAT_MSG_CHANNEL", Filter)
        filtering = false
        wipe(seen)
        seenCount = 0
    end
end

local function OnSettingChanged(key)
    if APPLY_KEYS[key] then Apply() else lastLine = nil end
end

hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group

ns.Shared.Settings.Page("QoL/Interface", S):Card({
    id = "tradeFilter", name = "Trade Spam Filter", order = 25, switch = "tradeFilter",
    help = "Hides portal, summon, guild recruiting and boost spam in Trade chat.",
    summary = Summary,
    rows = {
        Group("Hide"),
        { key = "tradeFilterPortals", label = "Portals and Summons", toggle = true,
          help = "Messages selling or asking for portals, teleports and summons." },
        { key = "tradeFilterGuilds", label = "Guild Recruiting", toggle = true,
          help = "Guilds recruiting members or asking you to join." },
        { key = "tradeFilterBoosts", label = "Boosts and Gold Sellers", toggle = true,
          help = "Boosts, carries, gold selling and website links." },
        { key = "tradeFilterRepeats", label = "Repeated Messages", toggle = true,
          help = "The same message from the same player again within the time below." },
        { key = "tradeFilterRepeatMinutes", label = "Repeat Window", slider = REPEAT_RANGE, unit = " min",
          needs = "tradeFilterRepeats" },
        { key = "tradeFilterWords", label = "Your Own Words", text = true, wide = true,
          help = "Words or phrases to hide, separated by commas." },
        Group("Where"),
        { key = "tradeFilterOthers", label = "Also General and LFG", toggle = true,
          help = "Filters the General and LookingForGroup channels too." },
        { key = "tradeFilterAllow", label = "Never Hide", text = true, wide = true,
          help = "Player names never hidden, separated by commas." },
        Group("Hidden"),
        { label = "Hidden Messages", buttonText = "Show", button = ShowHidden,
          help = "Prints the last hidden messages to chat." },
    },
})
