# nwn-rgb-colour

Give the parts a character wears any RGB colour in Neverwinter Nights: Enhanced Edition. It runs on the stock client with NWScript alone: no client extender, no NWNX, no C#.

This is a builder's proof of concept. Take the principle, the scripts and the build tools, and put RGB colour in your own module.

## Try the demo

1. Download the zip from the latest GitHub Release.
2. Put `rgbcolour.hak` in your game user folder's `hak` folder, and `rgbdemo.mod` in its `modules` folder.
3. Start the game and load the RGB colour demo.
4. Use the easel beside you to open the colour window.

## How it works

Read [docs/how-it-works.md](docs/how-it-works.md). It explains why a lit shader can't see a PLT's layers, what a slot mask holds, and why a creature stops at 1024 shader values.

## Use it in your module

1. Add the release's hak to your module.
2. Copy `nss/inc_rgb.nss` and, for the window, `nss/inc_rgbwin.nss` into your module.
3. Call `RgbApply` on a player from your module's OnClientEnter, OnPlayerEquipItem and OnPlayerUnEquipItem scripts. The demo's `rgb_enter`, `rgb_equip` and `rgb_unequip` show how.
4. Store colours on an armor item with `RgbSetColours`, or let players use the window with `RgbOpenWindow`.

Your own PLT parts need a material and a slot mask too. Run `just convert <folder>` on a folder of `.plt` files, and pack what it writes into your hak beside the parts. Each material takes the name of its PLT, so a model must name that PLT as its `bitmap`.

## Build it from source

You need Nix with flakes turned on, and a copy of the game.

```sh
nix develop
just test
just compile
just build <game folder>
```

`just build` writes every worn stock part's material and mask, the palette atlas, `rgb_parts.txt` and `census.txt` to `build/parts`. `just compile` finds your game install by itself. Set `NWN_ROOT` to the game folder if it can't.

Compiled models that would need renaming to a different length are skipped and listed in the census. `cleanmodels`, a free NWN:EE community tool, thaws them to ASCII.

## Licence

The code is MIT, see `LICENSE`. The generated game files in a release (masks, materials, models, the hak) are built from the game's stock assets and are not covered by that licence.
