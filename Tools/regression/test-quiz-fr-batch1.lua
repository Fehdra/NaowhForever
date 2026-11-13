-- Offline check that the first 60 Naowh Quiz questions and answers have a French string.
-- Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local ns = {}
local chunk = assert(loadfile("NaowhForever_QoL/Travel/QuizData.lua"))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

local env = setmetatable({ NaowhForever = { LOCALE = "frFR" } }, { __index = _G })
local locale = assert(loadfile("NaowhForever_Locales/frFR.lua"))
setfenv(locale, env)
locale()
local L = env.NaowhForeverTranslation
check("French catalog loaded", type(L) == "table")

local BATCH = 502
check("the bank has the first batch", #ns.QUIZ_QUESTIONS >= BATCH)
for i = 1, BATCH do
    local item = ns.QUIZ_QUESTIONS[i]
    check("question " .. i .. " is translated", type(L[item.q]) == "string" and L[item.q] ~= "")
    for _, answer in ipairs(item.a) do
        check("answer translated: " .. answer, type(L[answer]) == "string" and L[answer] ~= "")
    end
end

print("test-quiz-fr-batch1: " .. checks .. " checks passed")
