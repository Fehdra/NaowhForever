-- ItemMenu.lua: an item's right-click menu: the BiS list, Favourites and its Wowhead link.
local ns = _G.NaowhForever

local J = ns.Journal
local Loot = J.Loot
local Favourites = J.Favourites

local BIS_ADDON = "NaowhForever_BiS"

local TEXT_ITEM = ns.L("Item ")
local TEXT_TURN_ON = ns.L("Turn on BiS List")
local TEXT_ADD = ns.L("Add to BiS List")
local TEXT_PROMOTE = ns.L("Make it #1")
local TEXT_REMOVE = ns.L("Remove from BiS List")
local TEXT_FAVOURITE_ADD = ns.L("Add to Favourites")
local TEXT_FAVOURITE_REMOVE = ns.L("Remove from Favourites")
local TEXT_WOWHEAD = ns.L("Wowhead Link")

local function AddBisButtons(root, itemID, Then, onChange)
    if not Loot.BisOn() then
        root:CreateButton(TEXT_TURN_ON, function()
            ns.TurnOnModule(BIS_ADDON)
            if onChange then onChange() end
        end)
        return
    end
    local rank = Loot.Rank(itemID)
    if not rank then
        root:CreateButton(TEXT_ADD, function() Then(ns.AddBisItem) end)
        return
    end
    if rank > 1 then root:CreateButton(TEXT_PROMOTE, function() Then(ns.PromoteBisItem) end) end
    root:CreateButton(TEXT_REMOVE, function() Then(ns.RemoveBisItem) end)
end

function J.View.ItemMenu(owner, itemID, onChange)
    local function Then(change)
        change(itemID)
        if onChange then onChange() end
    end
    local name = Loot.Name(itemID)
    ns.ContextMenu(owner, function(_, root)
        root:CreateTitle(name or (TEXT_ITEM .. itemID))
        if Loot.BisGear(itemID) and not J.IsNotYet(itemID) then
            AddBisButtons(root, itemID, Then, onChange)
            root:CreateDivider()
        end
        if Favourites.On() then
            root:CreateButton(Favourites.Is(itemID) and TEXT_FAVOURITE_REMOVE or TEXT_FAVOURITE_ADD,
                function() Then(Favourites.Toggle) end)
        end
        root:CreateButton(TEXT_WOWHEAD, function() J.View.Parts.CopyWowhead("item", itemID, name) end)
    end)
end
