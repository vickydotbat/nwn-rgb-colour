// dm_runscript rgb_preset: give the cloth 1 layer of your chest stock
// cloth colour 23, the same swatch the toolset's colour 23 shows.
#include "inc_rgb"

void main()
{
    // The player who ran the script.
    object oPC = RgbCaller();
    // The material is the one the player's chest model draws with.
    string sMaterial = RgbChestMaterial(oPC);
    // A preset is a row of the palette atlas. The shader reads the row at
    // each texel's own intensity, the way the engine reads a PLT, so the
    // part looks the same as stock cloth colour 23.
    RgbSetPreset(oPC, sMaterial, RGB_SLOT_CLOTH1, 23);
    SendMessageToPC(oPC, "Colour 1 of " + sMaterial + " set to cloth preset 23.");
}
