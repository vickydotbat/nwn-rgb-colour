// dm_runscript rgb_clear: put every part back to its stock PLT colours.
#include "inc_rgb"

void main()
{
    // dm_runscript may run on the module, so fall back to the first player.
    object oPC = GetIsPC(OBJECT_SELF) ? OBJECT_SELF : GetFirstPC();
    RgbClearAll(oPC);
    SendMessageToPC(oPC, "Colours cleared.");
}
