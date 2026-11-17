-- Party.lua: Share Quest Progress, your party's quest objectives from the addon messages of everyone sharing them (Completo.Party).
local ns = _G.NaowhForever

local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local GetQuestObjectives = C_QuestLog.GetQuestObjectives

local Completo = ns.Completo
local S = Completo.Settings
local Objectives = Completo.Objectives

local PREFIX = "NaowhQuests"
local VERSION = "1"
local ASK = VERSION .. " ? %s"
local ASK_PATTERN = "^1 %? (%S+)$"
local HEAD = VERSION .. " %s"
local HEAD_PATTERN = "^1 (%S+) (.*)$"
local QUEST_PATTERN = "(%d+):([^;]*)"
local GONE = "-"
local OBJECTIVE_PATTERN = "([io])(%d+)/(%d+)"
local ITEM_MARK, OTHER_MARK = "i", "o"
local ITEM_TYPE, OTHER_TYPE = "item", "monster"
local CHANNELS = { PARTY = true, INSTANCE_CHAT = true }
local GUID_PATTERN = "^Player%-%d+%-%x+$"
local MESSAGE_MAX = 250
local MAX_QUESTS, MAX_OBJECTIVES, MAX_COUNT, MAX_QUEST_ID = 35, 10, 1000, 2 ^ 31
local SEND_DELAY = 2
local EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
    "QUEST_REMOVED", "PLAYER_REGEN_ENABLED" }

local events, prefixed, queued, afterCombat, asking
local sent, now, parts = {}, {}, {}
local members, names = {}, {}
local here, incoming = {}, {}
local NONE = {}
local PARTY_SIZE = 4

local Party = {}
Completo.Party = Party

local function On()
    return S.Get("enabled") and S.Get("partyProgress")
end

local function Channel()
    if IsInRaid() then return nil end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInGroup() then return "PARTY" end
end

local function Encode(quest)
    wipe(parts)
    for i, objective in ipairs(GetQuestObjectives(quest) or NONE) do
        if i > MAX_OBJECTIVES then break end
        parts[#parts + 1] = (objective.type == ITEM_TYPE and ITEM_MARK or OTHER_MARK)
            .. objective.numFulfilled .. "/" .. objective.numRequired
    end
    return table.concat(parts, ",")
end

local function ReadLog()
    wipe(now)
    for i = 1, GetNumQuestLogEntries() do
        local quest = GetQuestIDForLogIndex(i)
        if quest and quest > 0 then now[quest] = Encode(quest) end
    end
end

local function Said(text, channel)
    local result = C_ChatInfo.SendAddonMessage(PREFIX, text, channel)
    return result == nil or result == Enum.SendAddonMessageResult.Success
end

local function Flush(channel, body)
    if body == "" then return true end
    return Said(HEAD:format(UnitGUID("player")) .. " " .. body, channel)
end

local SendSoon

local function Send()
    queued = false
    if not On() then return end
    local channel = Channel()
    if not channel then
        wipe(sent)
        return
    end
    if InCombatLockdown() or C_ChatInfo.InChatMessagingLockdown() then
        afterCombat = true
        return
    end
    if asking then
        asking = false
        Said(ASK:format(UnitGUID("player")), channel)
    end
    ReadLog()
    local body, room, delivered = "", MESSAGE_MAX - #HEAD:format(UnitGUID("player")) - 1, true
    local function Put(entry)
        if #body + #entry + 1 > room then
            delivered = Flush(channel, body) and delivered
            body = ""
        end
        body = body == "" and entry or body .. ";" .. entry
    end
    for quest, text in pairs(now) do
        if sent[quest] ~= text then Put(quest .. ":" .. text) end
    end
    for quest in pairs(sent) do
        if not now[quest] then Put(quest .. ":" .. GONE) end
    end
    delivered = Flush(channel, body) and delivered
    wipe(sent)
    if not delivered then return SendSoon() end
    for quest, text in pairs(now) do sent[quest] = text end
end

function SendSoon(ask, fresh)
    if ask then asking = true end
    if fresh then wipe(sent) end
    if queued then return end
    queued = true
    C_Timer.After(SEND_DELAY, Send)
end

local function Decode(text)
    local list = {}
    for mark, have, need in text:gmatch(OBJECTIVE_PATTERN) do
        have, need = tonumber(have), tonumber(need)
        if #list >= MAX_OBJECTIVES or have > MAX_COUNT or need > MAX_COUNT then return nil end
        list[#list + 1] = { type = mark == ITEM_MARK and ITEM_TYPE or OTHER_TYPE, numFulfilled = have,
            numRequired = need, finished = have >= need }
    end
    return list
end

local function Member(guid, channel, sender)
    return guid:find(GUID_PATTERN) and guid ~= UnitGUID("player") and ns.SenderIs(sender, channel, guid)
end

local function Read(body, quests)
    wipe(incoming)
    local count = 0
    for _ in pairs(quests) do count = count + 1 end
    for quest, text in body:gmatch(QUEST_PATTERN) do
        quest = tonumber(quest)
        if quest > MAX_QUEST_ID then return false end
        local list = false
        if text ~= GONE then
            list = Decode(text)
            if not list then return false end
        end
        if list and not quests[quest] then count = count + 1 end
        if not list and quests[quest] then count = count - 1 end
        incoming[#incoming + 1] = quest
        incoming[#incoming + 1] = list
    end
    return count <= MAX_QUESTS
end

local function OnMessage(msg, channel, sender)
    local asker = msg:match(ASK_PATTERN)
    if asker then
        if Member(asker, channel, sender) then SendSoon(false, true) end
        return
    end
    local guid, body = msg:match(HEAD_PATTERN)
    if not guid or not Member(guid, channel, sender) then return end
    local quests = members[guid] or {}
    if not Read(body, quests) then return end
    for i = 1, #incoming, 2 do quests[incoming[i]] = incoming[i + 1] or nil end
    members[guid] = quests
    names[guid] = Ambiguate(sender, "short")
end

local function Prune()
    local joined = false
    for guid in pairs(here) do here[guid] = false end
    for i = 1, PARTY_SIZE do
        local guid = UnitGUID("party" .. i)
        if guid and not issecretvalue(guid) then
            joined = joined or here[guid] == nil
            here[guid] = true
        end
    end
    for guid, present in pairs(here) do
        if not present then here[guid] = nil end
    end
    for guid in pairs(members) do
        if not here[guid] then members[guid], names[guid] = nil, nil end
    end
    return joined
end

local function OnEvent(_, event, prefix, msg, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if issecretvalue(prefix) or issecretvalue(msg) or issecretvalue(channel) or issecretvalue(sender) then return end
        if prefix == PREFIX and CHANNELS[channel] then OnMessage(msg, channel, sender) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Prune()
        SendSoon(true, true)
    elseif event == "GROUP_ROSTER_UPDATE" then
        if Prune() then SendSoon(true, true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if afterCombat then
            afterCombat = false
            SendSoon()
        end
    else
        SendSoon()
    end
end

function Party.Progress(quest, place, item, fn)
    for guid, quests in pairs(members) do
        local list = quests[quest]
        if list then
            local objective, done = Objectives.Progress(list, place, item)
            if objective and not done then fn(names[guid], objective) end
        end
    end
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        wipe(members)
        wipe(sent)
        wipe(here)
        return
    end
    if not prefixed then
        prefixed = true
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Prune()
    SendSoon(true, true)
end

S.OnChange(function(key)
    if key == "enabled" or key == "partyProgress" then Apply() end
end)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
