-- QuestLinks.lua: Quest Levels in Chat, a quest link said in chat shows the quest's level, as the quest log does.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL" }
local QUEST_MARK = "|Hquest:"
local LINK = "(|Hquest:%d+:(%-?%d+)[^|]*|h%[)([^%]]*)(%]|h)"
local LEVELED = "^%[%d+%+?%] "
local TEXT_LEVEL = "[%d] %s"

local AddFilter = ChatFrameUtil.AddMessageEventFilter
local RemoveFilter = ChatFrameUtil.RemoveMessageEventFilter
local filtering = false

local function On()
    return S.Get("enabled") and S.Get("questLinkLevels")
end

local function Leveled(head, level, title, tail)
    level = tonumber(level)
    if not level or level <= 0 or title:find(LEVELED) then return head .. title .. tail end
    return head .. TEXT_LEVEL:format(level, title) .. tail
end

local function Filter(_, _, msg, ...)
    if issecretvalue(msg) or type(msg) ~= "string" or not msg:find(QUEST_MARK, 1, true) then return false end
    return false, msg:gsub(LINK, Leveled), ...
end

local function Apply()
    local wanted = On() and true or false
    if wanted == filtering then return end
    filtering = wanted
    for _, event in ipairs(EVENTS) do
        if wanted then AddFilter(event, Filter) else RemoveFilter(event, Filter) end
    end
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "questLinkLevels" then Apply() end
end)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "questLinkLevels", name = "Quest Levels in Chat", order = 14, switch = "questLinkLevels",
    help = "Shows each quest's level on the quest links people say in chat.",
})
