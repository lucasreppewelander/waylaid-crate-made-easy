# Changelog

## v1.0.3 (2026-11-10)

Packaging update, no changes in game.

- Added a `.pkgmeta` so CurseForge's automatic packager names the addon folder `WaylaidCratesMadeEasy` (matching the `.toc`) and leaves the tests and screenshots out.

## v1.0.2 (2026-11-10)

### New
- **Cost to buy what you're missing:** when you already have some of a bundle's item in your bags, the line also shows what the rest would cost, for example `1g 20s (81s to buy)`, or `(have all)` when your bags cover the whole bundle.
- **Coin icons:** prices now show gold, silver and copper coin icons, matching Auctionator's tooltip, instead of plain "18s 00c" text.

### Changed
- The green "cheapest" bundle is now the one that costs the least gold to buy, counting what's in your bags. A bundle your bags already cover counts as free.

## v1.0.1 (2026-11-09)

### Fixed
- Prices now show after an Auctionator full scan (summary mode). Before, a bundle item that wasn't in your bags said "no price" until you searched for it by hand.
  - Auctionator saves prices by item ID, but crate tooltips only list item names. The addon now learns the name of every item a scan sees and remembers it between sessions, so one full scan is enough.
  - Give it a few seconds after the scan finishes before hovering a crate, while it looks up the names.

## v1.0.0 (2026-11-09)

First release.

- Adds a block to every Waylaid Crate tooltip with the total Auctionator price of each bundle and how many of the item you have in your bags.
- The cheapest bundle is shown in green; bundles without a price show "no price".
- Works without Auctionator (bag counts only).
