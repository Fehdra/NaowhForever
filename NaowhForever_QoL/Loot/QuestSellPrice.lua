-- QuestSellPrice.lua: Quest Reward Sell Price, the vendor price on quest reward tooltips.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local S = ns.QoLSettings

local PAGE = "QoL/Loot & Items"
local ORDER = 17
local KEYS = { enabled = true, questSellPrice = true }
local SELL_PRICE = 11
local NUM_ITEMS = 3
local CHOICE = "choice"
local LOG_GETTER, GIVER_GETTER = "GetQuestLogItem", "GetQuestItem"
local SELL_LINE = Enum.TooltipDataLineType.SellPrice

local hooked = false

local function On()
    return S.Get("enabled") and S.Get("questSellPrice")
end

local function RewardCount(info)
    local args = info.getterArgs
    if info.getterName == GIVER_GETTER then return select(NUM_ITEMS, GetQuestItemInfo(args[1], args[2])) end
    if args[1] == CHOICE then return select(NUM_ITEMS, GetQuestLogChoiceInfo(args[2])) end
    return select(NUM_ITEMS, GetQuestLogRewardInfo(args[2], args[3]))
end

local function HasSellLine(data)
    for _, line in ipairs(data.lines) do
        if line.type == SELL_LINE then return true end
    end
    return false
end

local function OnItemTooltip(tooltip, data)
    if not On() or tooltip.isShopping then return end
    local info = tooltip:GetProcessingTooltipInfo()
    local getter = info and info.getterName
    if getter ~= LOG_GETTER and getter ~= GIVER_GETTER then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) or HasSellLine(data) then return end
    local price = select(SELL_PRICE, GetItemInfo(id))
    if not price or price <= 0 then return end
    GameTooltip_OnTooltipAddMoney(tooltip, price * math.max(RewardCount(info) or 1, 1))
end

local function Apply()
    if hooked or not On() then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "questRewardPrices", name = "Quest Rewards", order = ORDER, into = "lootTrade",
    rows = {
        { key = "questSellPrice", label = "Quest Reward Sell Price", toggle = true,
          help = "Quest reward tooltips show what the item sells to a vendor for." },
    },
})
