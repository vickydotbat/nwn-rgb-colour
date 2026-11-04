# How RGB colour works on the stock client

Stock armor colour comes from PLT files. A PLT stores two bytes per pixel: an intensity and a layer, such as cloth 1 or metal 2. The engine bakes each PLT into a plain texture, picking each pixel's colour from a stock palette by its layer and intensity. Lighting runs on the baked texture. By then the layer byte is gone, so a lit shader can't tell cloth from leather.

This package gives the shader the layers back, then lets a script pick any colour per layer.

## The slot mask

Each part gets a slot mask: a copy of its PLT as a TGA the shader can read. Red holds the intensity and green holds the layer times 16. The part's material binds the mask on `texture6`. For each pixel, the shader reads the mask, finds the layer, and draws the colour a script set for that layer at the pixel's own intensity. A layer with no colour set draws the stock baked texture.

A layer number is a category, not a shade. Filtering would blend two layers into a third that doesn't exist, so the shader reads the layer from the full-size mask, texel by texel. The intensity is a shade, so the shader reads it filtered, through the mask's mipmaps: from a distance, that keeps coloured armor from glittering. Each mask ships as a full-size, uncompressed TGA with no `.txi`, so the client builds those mipmaps.

## The material

A material is a `.mtr` file named after the bitmap a model draws. It tells the engine to draw that bitmap with `fs_rgbpart`, binds the mask and the palette atlas, and declares every shader value the scripts may set. The engine only accepts a value the material declares. Each declared value starts at -1, which means off. A value of 0 does not replace one set earlier, so a script turns a layer off with -1.

Many race and phenotype models draw the human model's PLT. They share its material. Shader values belong to one creature, and a creature wears one body, so a dwarf's chest and a human's chest never mix. `rgb_parts.txt` lists each part whose material is not its own name, and `RgbPartMaterial` in `nss/inc_rgb.nss` reads it.

Two parts of one body may draw the same PLT. Stock right shins draw the left shin's PLT, for example. One material would then colour both. `just build` gives each such part a model copy that names itself, so it gets a material of its own.

## Setting a colour

`SetMaterialShaderUniformVec4(oCreature, sMaterial, sParam, ...)` sets one value on one creature. `rgbC<n>` is the colour of layer n, packed into one float as `r * 65536 + g * 256 + b`. `rgbP<n>` picks a stock palette row instead, from the atlas.

The palette atlas stacks the six stock palettes, 176 rows each, in one TGA bound on `texture8`. A preset reads its row at each pixel's intensity, the same way the engine reads a PLT, so preset 23 looks like stock colour 23.

## The 1024 limit

A creature holds at most 1024 shader values. The engine drops value 1025 with no error, and the colour never shows. Setting a value never removes one, and the creature saves its list with the character.

So `RgbApply` calls `ResetMaterialShaderUniforms` once with no material, which wipes every value, then writes only what the armor needs. A full outfit is at most 17 parts with 6 colours each: 102 values. Reset everything, not one material. A reset scoped to one material makes the client restore every material's defaults when it replays the list.

## Colours that follow the item

An armor item keeps its colours in one local string, `RGB_COLOURS`, as JSON you can read in the toolset:

```json
{"all": {"1": "#2e8b57", "2": "p23"}, "forel": {"1": "#00ff00"}}
```

`all` is the whole outfit, and a part key such as `forel` (left forearm) overrides it for that part. `1` to `6` are the item's colours in toolset order: cloth 1, cloth 2, leather 1, leather 2, metal 1, metal 2. A value is `#rrggbb`, or `p` and a palette row.

The demo calls `RgbApply` when a player enters, equips or unequips armor. Call it from the same events in your own module, and from an area's OnEnter if your module has several areas.

## Testing a change

Shaders and the atlas load when the client starts. After you change either, quit the game fully before you look again. A shader that fails to compile on your graphics driver is named in `logs/nwengineLog.txt` in the game user folder.

## What it does not colour

- Robes keep their stock PLT colours. A robe is an attachment and never takes the wearer's values.
- Helmets keep theirs too. See [helmets.md](helmets.md).
- `census.txt` from `just build` lists every other part it skipped, and why.
