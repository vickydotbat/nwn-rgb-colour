---
name: rgb-colour
description: RGB colour on worn parts through the RGB part shader. Use when writing or changing inc_rgbpart.shd, a part .mtr or slot mask, the palette atlas, the colour scripts or the colour window; when a picked colour shows nothing, shimmers, fizzes or draws the wrong row; or when running an in-game colour check.
---

# RGB colour

This skill holds the engine rules a change must keep, and the steps for a broken colour. The shader header in `shaders/inc_rgbpart.shd` lists every uniform and debug view.

## Engine rules

- **A PLT is baked before lighting.** The engine turns `(intensity, layer)` into a plain texture, and the lit shader reads that as `texUnit0`. The layer byte is gone by then, so a part reads its slot mask on `texture6`.
- **A value reaches a part only if its `.mtr` declares it.** `SetMaterialShaderUniformVec4(object, material, param, ...)` overrides a declared `parameter` on one object. The material name is the model's bitmap, lower case.
- **Declare each uniform with the float count the shader declares.** A 4-float declaration for a `float` uniform fails silently, and the shader falls back to its defaults. A colour packs into one float as `r * 65536 + g * 256 + b`.
- **Off is -1, never 0.** A 0 does not replace an earlier override.
- **Prefix every custom parameter `rgb`.** A name a stock uniform uses turns the part pink.
- **An object holds at most 1024 shader values.** The engine refuses value 1025 with no error, so the colour never shows. Setting a value never removes one, and the list is saved with the character.
- **Reset everything once, then write only what you want.** A full reapply calls `ResetMaterialShaderUniforms` with no material and no parameter. A reset scoped to one material or uniform makes the client restore every material's defaults when it replays the list. Keep one writer of colour values, because a full reset also clears values another feature set.
- **A worn helmet, a robe attachment and a VFX instance never take a creature's values.** Helmets are out of scope: NWScript alone cannot keep a worn helmet's colour. The docs explain the server-side fix. A robe keeps stock PLT colours. A VFX keeps PLT colour.
- **A shader or atlas change needs a full client restart to show.**
- **Read the client log after every in-game check.** `logs/nwengineLog.txt` in the game's user folder names a shader that failed to compile (`CompileShader: Shader <name> failed to compile`). An offline glslang check misses words a driver reserves: Mesa rejects `packed`.

## Mask and atlas rules

- **A slot id is a category: read it at the nearest texel, at level 0, never filtered.** A mask ships as a full-size uncompressed TGA with no `.txi`, so the client builds its mipmaps. BC1, BC3 and half size break slot ids. BC5 keeps them but shifts intensities.
- **A coloured slot reads the mask's intensity filtered, through its mipmaps.** A mask `.txi` with `mipmap 0` takes them away, and coloured armor glitters at a distance.
- **Blend the finished colour of the four nearest texels** (`rgbSmooth 1`, the default). One texel per pixel fizzes at slot borders. Blending only the intensity makes it worse.
- **A slot with no value returns the engine's filtered bake** (`texture2D(texUnit0, ...)`), never a `texelFetch`. A level-0 read skips mipmaps and turns plain armor grainy at a distance.
- **Each mask texel reads its own intensity up close. A far pixel reads the row averaged over the intensities under it.** The atlas holds those averages in the 256 columns past each row. Without them, glitter and rainbow rows fizz.
- **The engine uploads a TGA's rows in stored order.** Store atlas row 0 first, so the shader's texel row r is atlas row r, and every material sets `rgbAtlasFlip -1`.
- **The atlas `.txi` holds `mipmap 0`, `filter 0`, `downsamplemax 0`.** Otherwise rows blend and shrink.
- **Stock metal 1 and metal 2 both bake from `pal_armor01`.** `pal_armor02` is unused.
- **Call `SetupSpecularity` again after replacing the diffuse.** A bound specular or roughness map overrides what the palette says about metal.

## Window rules

- **Take a picker colour only during a drag.** The stock NUI colour picker fires a watch event before the mouse goes down, and echoes a value the server set.
- **A pick updates binds, never rebuilds the scrolling body.** A rebuilt body resets the scroll under the cursor.
- **A part's own channel value beats the Whole outfit value.**
- **A look is not a layer.** Stock parts paint leather-looking straps on cloth layers. Check a part's PLT layers before calling a slot wrong.

## When a picked colour shows nothing

Work down the chain and stop at the first link that fails.

1. **Count the object's values.** At 1024 the engine refuses every new one.
2. **Check the part's own channel value** against the Whole outfit value.
3. **Compare the `development` folder's copies** of the shaders and atlas with the branch's build.
4. **Read the part's `.mtr` the client loads.** It binds `texture6` (the mask) and `texture8 rgb_atlas`.
5. **Set one value by hand** from a test script on the character: one `rgbP<n>` or `rgbC<n>` on one named material. A value that draws by hand while the window does not puts the fault in the scripts.

## In-game checks

- Test files go in the game's `development` folder, which outranks every hak.
- A check needs a clean character: no debug value left by a test script, then a relog.
