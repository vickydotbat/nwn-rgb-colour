// dm_runscript rgb_clear: put every part back to its stock PLT colours.
#include "inc_rgb"

void main()
{
    // The player who ran the script.
    object oPC = RgbCaller();
    // Reset every shader value the creature holds, on every material.
    // A full reset is the safe way to clear: setting a slot to 0 would not
    // replace an earlier value (off is -1), and a reset scoped to one
    // material makes the client restore every material's defaults anyway.
    // With no values left, each part's shader draws the stock PLT colours.
    ResetMaterialShaderUniforms(oPC);
    SendMessageToPC(oPC, "Colours cleared.");
}
