# Waylaid Crates Made Easy

A World of Warcraft Forever addon that shows which bundle is cheapest to fill a Waylaid Crate with.

Hover any Waylaid Crate and a block is added to its tooltip. Each bundle the crate accepts gets its own line, showing how many of that item you have in your bags and what the whole bundle costs at the auction house, using [Auctionator](https://www.curseforge.com/wow/addons/auctionator) prices. The cheapest bundle is shown in green.

![Waylaid Crate tooltip with bundle costs, cheapest bundle in green](screenshots/tooltip-2.png)

## Features

- **Works on every Waylaid Crate.** It reads the bundle list straight from the crate's tooltip, so new crates work without an update.
- **Total cost per bundle:** quantity × Auctionator's latest price.
- **Cheapest bundle in green.** Bundles without a price are never marked cheapest.
- **Bag count:** how many of each item you already have in your bags (bank not included).
- **"no price"** appears when Auctionator has no scan data for the item, or the game hasn't loaded that item yet. The addon learns item names from your bags and from item tooltips you see, and remembers them between sessions.
- **Without Auctionator** you still get the bag counts.

![A crate where Auctionator has no prices yet](screenshots/tooltip.png)

## Installation

1. Download this repository (**Code → Download ZIP**) and extract it.
2. Rename the extracted folder to `WaylaidCratesMadeEasy`. WoW only loads an addon whose folder name matches its `.toc` file.
3. Move it to `World of Warcraft/_forever_/Interface/AddOns/`. You should end up with `AddOns/WaylaidCratesMadeEasy/WaylaidCratesMadeEasy.toc`.
4. Restart the game or type `/reload`.

For prices, install [Auctionator](https://www.curseforge.com/wow/addons/auctionator) and run a scan at the auction house.

If the addon shows as out of date, tick **Load out of date AddOns** on the character select screen. You can also update the `## Interface:` line in `WaylaidCratesMadeEasy.toc` to your client's version. Run `/dump select(4, GetBuildInfo())` in game to find it.

## Limitations

- English game client only. The addon finds the bundle list by the text "Fill the crate with any bundle from the following list:".

## Development

The tooltip parser has tests that run outside the game:

```sh
luajit tests/parse_test.lua
```
