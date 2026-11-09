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
    return link and tonumber(link:match("item:(%d+)"))
end

local function Remember(name, id)
    if DB and name and id then
        DB.names[name] = id
    end
end

-- Learn name -> ID for everything in the bags
local function LearnFromBags()
    for bag = 0, NUM_BAGS do
        for slot = 1, (GetNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                Remember(link:match("|h%[(.-)%]|h"), IDFromLink(link))
            end
        end
    end
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
    local cheapestTotal
    for _, b in ipairs(bundles) do
        b.id = ResolveItemID(b.name)
        b.have = b.id and GetItemCount(b.id) or 0
        local price = GetPrice(b.id)
        b.total = price and price * b.qty or nil
        if b.total and (not cheapestTotal or b.total < cheapestTotal) then
            cheapestTotal = b.total
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(COLOR_HEADER .. (hasAuctionator and "Bundle costs (Auctionator)" or "Bundles") .. "|r")
    for _, b in ipairs(bundles) do
        local isCheapest = b.total and b.total == cheapestTotal
        local color = isCheapest and COLOR_CHEAPEST or COLOR_NORMAL
        local left = string.format("%s%d %s|r %s[%d in bags]|r", color, b.qty, b.name, COLOR_BAGS, b.have)
        local right = ""
        if hasAuctionator then
            if b.total then
                right = color .. FormatMoney(b.total) .. "|r"
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
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        WaylaidCratesMadeEasyDB = WaylaidCratesMadeEasyDB or {}
        WaylaidCratesMadeEasyDB.names = WaylaidCratesMadeEasyDB.names or {}
        DB = WaylaidCratesMadeEasyDB
    elseif event == "BAG_UPDATE_DELAYED" and DB then
        LearnFromBags()
    end
end)
