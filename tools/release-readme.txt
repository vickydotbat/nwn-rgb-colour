RGB colour for worn parts, NWN:EE

Give the parts a character wears any RGB colour, on the stock client, with
NWScript alone.

To try the demo:
1. Copy hak/rgbcolour.hak into the hak folder of your game user folder.
2. Copy modules/rgbdemo.mod into its modules folder.
3. Start the game and load the RGB colour demo.
4. Use the easel beside you to open the colour window.

To use it in your own module, start with source/README.md and
source/docs/how-it-works.md. source/ holds the scripts to copy, the
shaders, the palette table and tools/rgb_materials.py, which makes your
own PLT parts RGB-ready:

    python3 tools/rgb_materials.py <folder of .plt files> --out <folder>

census.txt lists the stock parts the build skipped, and why.

Source, docs and the scripts to use in your own module:
https://github.com/vickydotbat/nwn-rgb-colour
