-- ShareQuests.lua: sharing a dungeon's quests in your log with your group, one at a time (J.Sharing.ShareAll).
local ns = _G.NaowhForever

local J = ns.Journal
local Sharing = J.Sharing

local SENT_WAIT, ANSWER_WAIT, RETRIES = 2, 30, 2
local PUSH_RESULT = "^ERR_QUEST_PUSH_.+_S$"
local PUSH_SENT = "ERR_QUEST_PUSH_SUCCESS_S"
local MESSAGE_EVENTS = { "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE" }
local NAME_MARK = "\001"
local FORMAT_NAME = "%%%d?%$?s"
local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local CAPTURE = "(.+)"
local NAME_PART = "^([^%-]+)"
local PARTY = { "party1", "party2", "party3", "party4" }

local TEXT_BUSY = ns.L("Someone was busy for %s; sharing it again after the rest.")
local TEXT_NO_GROUP = ns.L("Stopped sharing: you are not in a group.")
local TEXT_DONE = ns.L("Done sharing.")
local TEXT_AFTER_COMBAT = ns.L("Sharing carries on after combat.")
local TEXT_JOIN = ns.L("Join a group to share quests.")
local TEXT_NONE = ns.L("None of your quests for this dungeon can be shared.")
local TEXT_ALL_HAVE = ns.L("Your group has these quests already, or cannot take them.")
local TEXT_ALREADY = ns.L("Those quests are being shared already.")
local TEXT_SHARING = ns.L("Sharing %s. Each one waits until your group has answered the one before.")
local TEXT_LIST = ", "
local TEXT_QUESTS = "; "
local TEXT_FOR = "%s (%s)"

local EMPTY = {}
local shareQueue, sharing = {}, nil
local shareFrame
local sentPattern, busyPattern, donePattern, answerPatterns
local questOf, doneBy, members = {}, {}, {}
local NextShare

local function QuestName(id)
    return C_QuestLog.GetTitleForQuestID(id) or tostring(id)
end

local function Pattern(fmt)
    fmt = fmt:gsub(FORMAT_NAME, NAME_MARK):gsub(MAGIC, "%%%0")
    return "^" .. fmt:gsub(NAME_MARK, CAPTURE) .. "$"
end

local function PushPatterns()
    if answerPatterns then return end
    answerPatterns = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" and key:find(PUSH_RESULT) and key ~= PUSH_SENT then
            answerPatterns[#answerPatterns + 1] = Pattern(value)
        end
    end
    sentPattern = ERR_QUEST_PUSH_SUCCESS_S and Pattern(ERR_QUEST_PUSH_SUCCESS_S)
    busyPattern = ERR_QUEST_PUSH_BUSY_S and Pattern(ERR_QUEST_PUSH_BUSY_S)
    donePattern = ERR_QUEST_PUSH_ALREADY_DONE_S and Pattern(ERR_QUEST_PUSH_ALREADY_DONE_S)
end

local function Members(quest, id)
    wipe(members)
    for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do
        local unit = PARTY[i]
        local name = UnitName(unit)
        if name and not issecretvalue(name) and UnitIsConnected(unit) and not (doneBy[name] and doneBy[name][id])
                and not J.Quests.UnitOnQuest(unit, quest, id) and J.Quests.ForUnit(quest, unit) then
            members[#members + 1] = name
        end
    end
    return members
end

local function FinishShare()
    local cur = sharing
    sharing = nil
    if cur.timer then cur.timer:Cancel() end
    if cur.busy and cur.tries < RETRIES then
        cur.tries, cur.busy = cur.tries + 1, nil
        shareQueue[#shareQueue + 1] = cur
        ns.Print(TEXT_BUSY:format(QuestName(cur.id)))
    end
    NextShare()
end

local function WaitForAnswers(cur)
    cur.timer = C_Timer.NewTimer(SENT_WAIT, function()
        if sharing ~= cur then return end
        if next(cur.sent) == nil then return FinishShare() end
        cur.timer = C_Timer.NewTimer(ANSWER_WAIT - SENT_WAIT, function()
            if sharing == cur then FinishShare() end
        end)
    end)
end

local function StopSharing(cur)
    ns.Print(cur and TEXT_NO_GROUP or TEXT_DONE)
    wipe(shareQueue)
    shareFrame:UnregisterAllEvents()
end

function NextShare()
    local cur = table.remove(shareQueue, 1)
    if not (cur and IsInGroup()) then return StopSharing(cur) end
    if InCombatLockdown() then
        table.insert(shareQueue, 1, cur)
        shareFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns.Print(TEXT_AFTER_COMBAT)
        return
    end
    local index = C_QuestLog.GetLogIndexForQuestID(cur.id)
    if not index or #Members(cur.quest, cur.id) == 0 then return NextShare() end
    QuestLogPushQuest(index)
    sharing, cur.sent, cur.answered = cur, {}, {}
    WaitForAnswers(cur)
end

local function AllAnswered(cur)
    for sent in pairs(cur.sent) do
        if not cur.answered[sent] then return false end
    end
    return next(cur.sent) ~= nil
end

local function OnAnswer(cur, msg)
    for _, pattern in ipairs(answerPatterns) do
        local name = msg:match(pattern)
        if name then
            cur.answered[name] = true
            if busyPattern and msg:match(busyPattern) then cur.busy = true end
            if donePattern and msg:match(donePattern) then
                local short = name:match(NAME_PART) or name
                doneBy[short] = doneBy[short] or {}
                doneBy[short][cur.id] = true
            end
            if AllAnswered(cur) then FinishShare() end
            return
        end
    end
end

local function OnShareEvent(_, event, a, b)
    if event == "PLAYER_REGEN_ENABLED" then
        shareFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if not sharing then NextShare() end
        return
    end
    local cur, msg = sharing, event == "CHAT_MSG_SYSTEM" and a or b
    if not cur or type(msg) ~= "string" or issecretvalue(msg) then return end
    local name = sentPattern and msg:match(sentPattern)
    if name then
        cur.sent[name] = true
        return
    end
    OnAnswer(cur, msg)
end

local function Queue(ids)
    local queued = { [sharing and sharing.id or 0] = true }
    for _, item in ipairs(shareQueue) do queued[item.id] = true end
    local names = {}
    local combat = InCombatLockdown()
    for _, id in ipairs(ids) do
        if not queued[id] then
            shareQueue[#shareQueue + 1] = { id = id, quest = questOf[id], tries = 0 }
            local name = QuestName(id)
            names[#names + 1] = combat and name or TEXT_FOR:format(name, table.concat(Members(questOf[id], id), TEXT_LIST))
        end
    end
    return names
end

local function Listen()
    PushPatterns()
    if not shareFrame then
        shareFrame = CreateFrame("Frame")
        shareFrame:SetScript("OnEvent", OnShareEvent)
    end
    for _, event in ipairs(MESSAGE_EVENTS) do shareFrame:RegisterEvent(event) end
end

function Sharing.Shareable(dungeon)
    local ids, pushable = {}, 0
    local combat = InCombatLockdown()
    for _, quest in ipairs(dungeon.quests and dungeon.quests.quests or EMPTY) do
        local id = J.Quests.LoggedID(quest)
        if id and C_QuestLog.IsPushableQuest(id) then
            pushable = pushable + 1
            questOf[id] = quest
            if combat or #Members(quest, id) > 0 then ids[#ids + 1] = id end
        end
    end
    return ids, pushable
end

function Sharing.ShareAll(dungeon)
    if not IsInGroup() then
        ns.Print(TEXT_JOIN)
        return
    end
    local ids, pushable = Sharing.Shareable(dungeon)
    if #ids == 0 then
        ns.Print(pushable > 0 and TEXT_ALL_HAVE or TEXT_NONE)
        return
    end
    local names = Queue(ids)
    if #names == 0 then
        ns.Print(TEXT_ALREADY)
        return
    end
    ns.Print(TEXT_SHARING:format(table.concat(names, TEXT_QUESTS)))
    Listen()
    if not sharing then NextShare() end
end
