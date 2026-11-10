-- Run from repo root: luajit tests/parse_test.lua
local ns = {}
assert(loadfile("Parse.lua"))("WaylaidCratesMadeEasy", ns)

local function check(name, got, want)
  local ok = (got == nil and want == nil) or (got and want and #got == #want)
  if ok and got then
    for i, w in ipairs(want) do
      ok = ok and got[i].qty == w.qty and got[i].name == w.name
    end
  end
  print((ok and "PASS " or "FAIL ") .. name)
  if not ok then os.exit(1) end
end

-- One wrapped text with embedded newlines and a white color code (as Wowhead renders it)
check("embedded newlines", ns.ParseBundles({
  "Waylaid Crate: Apprentice Textiles", "Requires Level 10",
  "Use: Fill the crate with any bundle from the following list:\n|cffffffff- 40 Linen Cloth\n- 20 Light Leather|r",
  "Crafting Reagent", "Max Stack: 5",
}), { {qty=40, name="Linen Cloth"}, {qty=20, name="Light Leather"} })

-- Each bundle on its own tooltip line
check("separate lines", ns.ParseBundles({
  "Use: Fill the crate with any bundle from the following list:",
  "- 40 Linen Cloth", "- 20 Light Leather", "Crafting Reagent",
}), { {qty=40, name="Linen Cloth"}, {qty=20, name="Light Leather"} })

-- Multi-word names with apostrophes
check("odd names", ns.ParseBundles({
  "Use: Fill the crate with any bundle from the following list:\n- 5 Elixir of Lion's Strength\n- 12 Bolt of Silk Cloth",
}), { {qty=5, name="Elixir of Lion's Strength"}, {qty=12, name="Bolt of Silk Cloth"} })

check("not a crate", ns.ParseBundles({ "Linen Cloth", "Max Stack: 20" }), nil)

-- Item links -> name, ID (used to learn names from bags and Auctionator scans)
local name, id = ns.NameAndIDFromLink("|cffffffff|Hitem:3356::::::::60:::::::::|h[Kingsblood]|h|r")
print(((name == "Kingsblood" and id == 3356) and "PASS " or "FAIL ") .. "link parse")
if not (name == "Kingsblood" and id == 3356) then os.exit(1) end
local n2, i2 = ns.NameAndIDFromLink(nil)
print(((n2 == nil and i2 == nil) and "PASS " or "FAIL ") .. "nil link")
if n2 or i2 then os.exit(1) end

-- Item IDs from both Auctionator scan payloads:
--   summary (browse) scan: { itemKey = { itemID = n }, ... }
--   legacy/replicate full scan: { itemLink = "...", ... }
local ids = ns.ItemIDsFromScan({
  { itemKey = { itemID = 3356, itemLevel = 1 }, minPrice = 100 },
  { itemLink = "|cffffffff|Hitem:3369::::::::60:::::::::|h[Grave Moss]|h|r" },
  { itemKey = { itemID = 3356 } },   -- duplicate, should appear once
  { somethingElse = true },
  "garbage",
})
table.sort(ids)
local okIds = #ids == 2 and ids[1] == 3356 and ids[2] == 3369
print((okIds and "PASS " or "FAIL ") .. "scan ids")
if not okIds then os.exit(1) end
local okNil = #ns.ItemIDsFromScan(nil) == 0
print((okNil and "PASS " or "FAIL ") .. "scan ids nil")
if not okNil then os.exit(1) end

-- Bundle costs: full cost and cost of the part you still need to buy
local function costs(name, qty, have, price, wantTotal, wantToBuy)
  local total, toBuy = ns.BundleCosts(qty, have, price)
  local ok = total == wantTotal and toBuy == wantToBuy
  print((ok and "PASS " or "FAIL ") .. name .. " (got " .. tostring(total) .. ", " .. tostring(toBuy) .. ")")
  if not ok then os.exit(1) end
end
costs("none in bags", 40, 0, 3, 120, 120)
costs("some in bags", 40, 13, 3, 120, 81)
costs("all in bags", 40, 40, 3, 120, 0)
costs("more than needed", 40, 55, 3, 120, 0)
costs("no price", 40, 13, nil, nil, nil)
