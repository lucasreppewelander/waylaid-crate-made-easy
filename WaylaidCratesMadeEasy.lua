-- Waylaid Crates Made Easy
-- Hover a Waylaid Crate and a block is added to the bottom of its tooltip with,
-- for each bundle it accepts: how many of the item you have in your bags and the
-- bundle's total Auctionator price. The cheapest priced bundle is green.

local ADDON_NAME, ns = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local NUM_BAGS = NUM_BAG_SLOTS or 4

local COLOR_HEADER = "|cffffd100"
local COLOR_CHEAPEST = "|cff40ff40"
local COLOR_NORMAL = "|cffffffff"
local COLOR_MISSING = "|cff808080"
local COLOR_BAGS = "|cffa0a0a0"

local DB -- WaylaidCratesMadeEasyDB: { names = { [itemName] = itemID } }

local function IDFromLink(link)
    return select(2, ns.NameAndIDFromLink(link))
end

local knownIDs = {}  -- itemID -> true for every ID already in DB.names

local function Remember(name, id)
    if DB and name and id then
        DB.names[name] = id
        knownIDs[id] = true
    end
end

local function RememberLink(link)
    Remember(ns.NameAndIDFromLink(link))
end

-- Learn name -> ID for everything in the bags
local function LearnFromBags()
    for bag = 0, NUM_BAGS do
        for slot = 1, (GetNumSlots(bag) or 0) do
            RememberLink(GetContainerItemLink(bag, slot))
        end
    end
end

---------------------------------------------------------------------------
-- Learning names from Auctionator scans
--
-- Auctionator's scans store prices by item ID only, and the game can't look
-- up an item by name unless it has loaded that item this session. So when a
-- scan finishes, look up the name of every item it saw (asking the server for
-- ones the client hasn't loaded) and remember name -> ID. Bundle names then
-- resolve to the prices that scan saved.
---------------------------------------------------------------------------

local GetItemNameByID = C_Item and C_Item.GetItemNameByID
local RequestLoadItemDataByID = C_Item and C_Item.RequestLoadItemDataByID

local queue = {}    -- item IDs waiting to be looked up
local pending = {}   -- itemID -> true while waiting for the server
local ticker

local LOOKUPS_PER_TICK = 50
local TICK_SECONDS = 0.1

local function ItemName(id)
    local name = GetItemNameByID and GetItemNameByID(id)
    if not name then
        name = GetItemInfo(id)
    end
    return name
end

-- Returns true if the name was known right away
local function LearnID(id)
    local name = ItemName(id)
    if name then
        Remember(name, id)
        pending[id] = nil
        return true
    end
    return false
end

local function ProcessQueue()
    local n = 0
    while n < LOOKUPS_PER_TICK and #queue > 0 do
        local id = table.remove(queue)
        if not knownIDs[id] and not LearnID(id) then
            pending[id] = true
            if RequestLoadItemDataByID then
                RequestLoadItemDataByID(id)
            end
            -- (GetItemInfo in ItemName already asked the server on old clients)
        end
        n = n + 1
    end
    if #queue == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function LearnFromScan(scanData)
    for _, id in ipairs(ns.ItemIDsFromScan(scanData)) do
        if not knownIDs[id] and not pending[id] then
            queue[#queue + 1] = id
        end
    end
    if #queue > 0 and not ticker then
        ticker = C_Timer.NewTicker(TICK_SECONDS, ProcessQueue)
    end
end

local function OnItemLoaded(id, success)
    id = tonumber(id)
    if id and pending[id] then
        pending[id] = nil
        if success ~= false then
            LearnID(id)
        end
    end
end

local function RegisterAuctionatorListener()
    if not (Auctionator and Auctionator.EventBus) then return end
    local events = {}
    -- Summary-mode full scan (modern auction house, which Forever uses)
    if Auctionator.IncrementalScan and Auctionator.IncrementalScan.Events then
        events[#events + 1] = Auctionator.IncrementalScan.Events.ScanComplete
    end
    -- Replicate / legacy full scan
    if Auctionator.FullScan and Auctionator.FullScan.Events then
        events[#events + 1] = Auctionator.FullScan.Events.ScanComplete
    end
    if #events == 0 then return end
    Auctionator.EventBus:Register({
        ReceiveEvent = function(_, _, scanData)
            LearnFromScan(scanData)
        end,
    }, events)
end

local function ResolveItemID(name)
    if DB and DB.names[name] then
        return DB.names[name]
    end
    local _, link = GetItemInfo(name)
    local id = IDFromLink(link)
    if not id then
        LearnFromBags()
        id = DB and DB.names[name]
    end
    Remember(name, id)
    return id
end

local function GetPrice(itemID)
    if not itemID then return nil end
    if not (Auctionator and Auctionator.API and Auctionator.API.v1) then return nil end
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
    if ok and type(price) == "number" then
        return price
    end
    return nil
end

local function FormatMoney(copper)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %02ds %02dc", g, s, c) end
    if s > 0 then return string.format("%ds %02dc", s, c) end
    return string.format("%dc", c)
end

local function TooltipTexts(tooltip)
    local texts = {}
    local name = tooltip:GetName()
    if not name then return texts end
    for i = 1, tooltip:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            texts[#texts + 1] = text
        end
    end
    return texts
end

local function AddCrateInfo(tooltip)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if tooltip.wcmeAdded then return end

    local bundles = ns.ParseBundles(TooltipTexts(tooltip))
    if not bundles or #bundles == 0 then return end
    tooltip.wcmeAdded = true

    local hasAuctionator = Auctionator and Auctionator.API and Auctionator.API.v1
    -- Cheapest = least gold to buy the missing items (bags count toward it)
    local cheapestToBuy
    for _, b in ipairs(bundles) do
        b.id = ResolveItemID(b.name)
        b.have = b.id and GetItemCount(b.id) or 0
        b.total, b.toBuy = ns.BundleCosts(b.qty, b.have, GetPrice(b.id))
        if b.toBuy and (not cheapestToBuy or b.toBuy < cheapestToBuy) then
            cheapestToBuy = b.toBuy
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(COLOR_HEADER .. (hasAuctionator and "Bundle costs (Auctionator)" or "Bundles") .. "|r")
    for _, b in ipairs(bundles) do
        local isCheapest = b.toBuy and b.toBuy == cheapestToBuy
        local color = isCheapest and COLOR_CHEAPEST or COLOR_NORMAL
        local left = string.format("%s%d %s|r %s[%d in bags]|r", color, b.qty, b.name, COLOR_BAGS, b.have)
        local right = ""
        if hasAuctionator then
            if b.total then
                right = color .. FormatMoney(b.total) .. "|r"
                if b.toBuy == 0 then
                    right = right .. COLOR_BAGS .. " (have all)|r"
                elseif b.toBuy < b.total then
                    right = right .. COLOR_BAGS .. " (" .. FormatMoney(b.toBuy) .. " to buy)|r"
                end
            else
                right = COLOR_MISSING .. "no price|r"
            end
        end
        tooltip:AddDoubleLine(left, right)
    end
end

local function OnCleared(tooltip)
    tooltip.wcmeAdded = nil
end

local function HookTooltip(tooltip)
    if tooltip and tooltip.HookScript then
        tooltip:HookScript("OnTooltipCleared", OnCleared)
        if not (TooltipDataProcessor and Enum and Enum.TooltipDataType)
            and tooltip:HasScript("OnTooltipSetItem") then
            tooltip:HookScript("OnTooltipSetItem", AddCrateInfo)
        end
    end
end

-- Remember every item name/ID shown in a tooltip, so bundle names resolve
-- even when the item is not in the client cache later.
local function LearnFromTooltip(tooltip)
    if tooltip.GetItem then
        local name, link = tooltip:GetItem()
        Remember(name, IDFromLink(link))
    end
end

HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        LearnFromTooltip(tooltip)
        AddCrateInfo(tooltip)
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", LearnFromTooltip)
    ItemRefTooltip:HookScript("OnTooltipSetItem", LearnFromTooltip)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
-- Item data arriving from the server; which event exists depends on the client
pcall(f.RegisterEvent, f, "GET_ITEM_INFO_RECEIVED")
pcall(f.RegisterEvent, f, "ITEM_DATA_LOAD_RESULT")
f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        WaylaidCratesMadeEasyDB = WaylaidCratesMadeEasyDB or {}
        WaylaidCratesMadeEasyDB.names = WaylaidCratesMadeEasyDB.names or {}
        DB = WaylaidCratesMadeEasyDB
        for _, id in pairs(DB.names) do
            knownIDs[id] = true
        end
        -- OptionalDeps guarantees Auctionator (if installed) loaded before us
        RegisterAuctionatorListener()
    elseif event == "BAG_UPDATE_DELAYED" and DB then
        LearnFromBags()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        OnItemLoaded(arg1, arg2)
    end
end)
