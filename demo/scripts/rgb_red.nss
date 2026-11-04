// dm_runscript rgb_red: turn the cloth 1 layer of your chest dark red (#8b0000).
#include "inc_rgb"

void main()
{
    // The player who ran the script.
    object oPC = RgbCaller();
    // The material is named after the chest model the player wears.
    string sMaterial = RgbChestMaterial(oPC);
    RgbSetSlot(oPC, sMaterial, RGB_SLOT_CLOTH1, RgbPack(139, 0, 0));
    SendMessageToPC(oPC, "Colour 1 of " + sMaterial + " set to #8b0000.");
}
