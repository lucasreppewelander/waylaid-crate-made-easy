-- Pure text parsing for Waylaid Crate tooltips (no WoW API calls, so it can be
-- tested outside the game).

local _, ns = ...

-- The crate's "Use:" text. Everything after this heading that looks like
-- "- <qty> <name>" is a bundle option.
ns.HEADING = "Fill the crate with any bundle from the following list:"

local function StripCodes(text)
    -- Color codes (|cAARRGGBB ... |r) and texture/hyperlink escapes
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    return text
end

-- texts: array of tooltip line strings (a line may itself contain "\n").
-- Returns an array of { qty = number, name = string }, or nil if this is not a
-- crate tooltip.
function ns.ParseBundles(texts)
    local found = false
    local bundles = {}
    for _, raw in ipairs(texts) do
        local text = StripCodes(raw)
        for line in (text .. "\n"):gmatch("(.-)\r?\n") do
            if not found then
                if line:find(ns.HEADING, 1, true) then
                    found = true
                    -- In case the first bundle follows the heading on the same line
                    local rest = line:sub(line:find(ns.HEADING, 1, true) + #ns.HEADING)
                    local qty, name = rest:match("^%s*%-%s*(%d+)%s+(.-)%s*$")
                    if qty then
                        bundles[#bundles + 1] = { qty = tonumber(qty), name = name }
                    end
                end
            else
                local qty, name = line:match("^%s*%-%s*(%d+)%s+(.-)%s*$")
                if qty and name ~= "" then
                    bundles[#bundles + 1] = { qty = tonumber(qty), name = name }
                elseif line:match("%S") then
                    -- First non-bundle line ends the list
                    return bundles
                end
            end
        end
    end
    if found then
        return bundles
    end
    return nil
end

-- "|cff..|Hitem:3356:...|h[Kingsblood]|h|r" -> "Kingsblood", 3356
function ns.NameAndIDFromLink(link)
    if type(link) ~= "string" then return nil, nil end
    return link:match("|h%[(.-)%]|h"), tonumber(link:match("item:(%d+)"))
end

-- Unique item IDs from an Auctionator scan-complete payload. Handles both the
-- summary (browse) scan, whose entries have itemKey.itemID, and the
-- replicate/legacy full scan, whose entries have itemLink.
function ns.ItemIDsFromScan(scanData)
    local ids, seen = {}, {}
    if type(scanData) ~= "table" then return ids end
    for _, entry in ipairs(scanData) do
        local id
        if type(entry) == "table" then
            if type(entry.itemKey) == "table" then
                id = tonumber(entry.itemKey.itemID)
            end
            if not id then
                id = select(2, ns.NameAndIDFromLink(entry.itemLink))
            end
        end
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

-- Full bundle cost, and the cost of only the items you still need to buy.
-- Both nil when there is no price.
function ns.BundleCosts(qty, have, price)
    if not price then return nil, nil end
    local missing = math.max(qty - (have or 0), 0)
    return qty * price, missing * price
end

-- Copper -> "1 [g] 02 [s] 34 [c]" with coin icons, in the same style as
-- Auctionator's tooltip prices (lower units zero-padded after a higher one).
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

function ns.FormatMoney(copper)
    copper = math.floor(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("%d %s %02d %s %02d %s", g, GOLD_ICON, s, SILVER_ICON, c, COPPER_ICON)
    elseif s > 0 then
        return string.format("%d %s %02d %s", s, SILVER_ICON, c, COPPER_ICON)
    end
    return string.format("%d %s", c, COPPER_ICON)
end
