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
