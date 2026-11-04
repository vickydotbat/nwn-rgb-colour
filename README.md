# nwn-rgb-colour

Give the parts a character wears any RGB colour in Neverwinter Nights: Enhanced Edition. It runs on the stock client with NWScript alone: no client extender, no NWNX, no C#.

This is a builder's proof of concept. It is still being built, and the docs come with the first release.

## Working on it

You need Nix with flakes turned on.

```sh
nix develop
just test
just compile
```

`just compile` finds your game install by itself. Set `NWN_ROOT` to the game folder if it can't.

## Licence

The code is MIT, see `LICENSE`. The generated game files in a release (masks, materials, models, the hak) are built from the game's stock assets and are not covered by that licence.
