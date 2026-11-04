// inc_rgb: the calls a script needs to colour one worn part.
// Each part's material (a .mtr named after the part) declares one shader
// parameter per slot, and a script sets them on the creature wearing it.

// Slots are the PLT layers, in the engine's own order.
const int RGB_SLOT_SKIN     = 0;
const int RGB_SLOT_HAIR     = 1;
const int RGB_SLOT_METAL1   = 2;
const int RGB_SLOT_METAL2   = 3;
const int RGB_SLOT_CLOTH1   = 4;
const int RGB_SLOT_CLOTH2   = 5;
const int RGB_SLOT_LEATHER1 = 6;
const int RGB_SLOT_LEATHER2 = 7;
const int RGB_SLOT_TATTOO1  = 8;
const int RGB_SLOT_TATTOO2  = 9;

// Pack a colour into the one float the shader reads: r * 65536 + g * 256 + b.
// The shader takes one float per parameter, because a four-part value does
// not reach it whole.
float RgbPack(int nRed, int nGreen, int nBlue)
{
    return IntToFloat(nRed * 65536 + nGreen * 256 + nBlue);
}

// The material name of oCreature's chest model.
// A part model is named p<gender><race><phenotype>_chest<number>, for example
// pmh0_chest007 for a human male of normal build. The race letter comes from
// the RACE column of appearance.2da, so any playable race works.
string RgbChestMaterial(object oCreature)
{
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    int nModel = GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, ITEM_APPR_ARMOR_MODEL_TORSO);
    string sGender = GetGender(oCreature) == GENDER_FEMALE ? "f" : "m";
    string sRace = GetStringLowerCase(Get2DAString("appearance", "RACE", GetAppearanceType(oCreature)));
    string sNumber = GetStringRight("00" + IntToString(nModel), 3);
    return "p" + sGender + sRace + IntToString(GetPhenoType(oCreature)) + "_chest" + sNumber;
}

// Set one slot of one part to a colour.
// The engine only accepts a parameter the material already declares, and
// every slot is declared off (-1) until a script sets it.
void RgbSetSlot(object oCreature, string sMaterial, int nSlot, float fColour)
{
    SetMaterialShaderUniformVec4(oCreature, sMaterial, "rgbC" + IntToString(nSlot), fColour);
}

// The player a dm_runscript call means: it may run on the module, not the player.
object RgbCaller()
{
    return GetIsPC(OBJECT_SELF) ? OBJECT_SELF : GetFirstPC();
}
