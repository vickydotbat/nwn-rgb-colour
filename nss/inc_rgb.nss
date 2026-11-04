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

// The material a part model draws with. Most parts draw their own name, but
// many race and phenotype parts draw another body's PLT, and the build lists
// those in rgb_parts.txt. A creature wears one body, so sharing is safe.
string RgbPartMaterial(string sPart)
{
    json jParts = GetLocalJson(GetModule(), "RGB_PARTS");
    if (JsonGetType(jParts) == JSON_TYPE_NULL)
    {
        // Read the list once and keep it on the module.
        jParts = JsonParse(ResManGetFileContents("rgb_parts", RESTYPE_TXT));
        SetLocalJson(GetModule(), "RGB_PARTS", jParts);
    }
    json jMaterial = JsonObjectGet(jParts, sPart);
    return JsonGetType(jMaterial) == JSON_TYPE_STRING ? JsonGetString(jMaterial) : sPart;
}


// Set one slot of one part to a colour.
// The engine only accepts a parameter the material already declares, and
// every slot is declared off (-1) until a script sets it.
void RgbSetSlot(object oCreature, string sMaterial, int nSlot, float fColour)
{
    SetMaterialShaderUniformVec4(oCreature, sMaterial, "rgbC" + IntToString(nSlot), fColour);
}

// The first atlas row of each slot's stock palette. The atlas stacks the
// six stock palettes, 176 rows each: skin, hair, metal, cloth, leather,
// tattoo. Metal 1 and metal 2 share the metal palette, as stock does.
int RgbPaletteBase(int nSlot)
{
    int nPalette;
    if (nSlot <= RGB_SLOT_METAL2) nPalette = nSlot == RGB_SLOT_METAL2 ? 2 : nSlot;
    else nPalette = 3 + (nSlot - RGB_SLOT_CLOTH1) / 2;
    return nPalette * 176;
}

// Set one slot of one part to stock palette row nRow (0-175), the colour
// the toolset's swatch nRow gives. The shader reads it from the atlas.
void RgbSetPreset(object oCreature, string sMaterial, int nSlot, int nRow)
{
    SetMaterialShaderUniformVec4(oCreature, sMaterial, "rgbP" + IntToString(nSlot),
                                 IntToFloat(RgbPaletteBase(nSlot) + nRow));
}

// ---------------------------------------------------------------------------
// Colours that follow the item
//
// An item keeps its colours in one local string, RGB_COLOURS, holding JSON a
// builder can read in the toolset's Variables list:
//
//   {"all": {"1": "#2e8b57", "2": "p23"}, "forel": {"1": "#00ff00"}}
//
// "all" is the whole outfit, and a part key ("chest", "forel", "shinr" ...)
// overrides it for that part. "1" to "6" are the item's colours in toolset
// order: cloth 1, cloth 2, leather 1, leather 2, metal 1, metal 2. A value is
// "#rrggbb" for any colour, or "p" and a row for a stock palette preset.
// ---------------------------------------------------------------------------

const string RGB_COLOURS = "RGB_COLOURS";

// The part key of each ITEM_APPR_ARMOR_MODEL_* index (0-17), in that order.
// Model names call a thigh "leg". The robe (18) keeps stock colours.
string RgbPartKey(int nModel)
{
    switch (nModel)
    {
        case 0: return "footr";  case 1: return "footl";
        case 2: return "shinr";  case 3: return "shinl";
        case 4: return "legl";   case 5: return "legr";
        case 6: return "pelvis"; case 7: return "chest";
        case 8: return "belt";   case 9: return "neck";
        case 10: return "forer"; case 11: return "forel";
        case 12: return "bicepr"; case 13: return "bicepl";
        case 14: return "shor";  case 15: return "shol";
        case 16: return "handr"; case 17: return "handl";
    }
    return "robe";
}

// The PLT slot of a toolset colour, 1-6.
int RgbChannelSlot(int nChannel)
{
    switch (nChannel)
    {
        case 1: return RGB_SLOT_CLOTH1;
        case 2: return RGB_SLOT_CLOTH2;
        case 3: return RGB_SLOT_LEATHER1;
        case 4: return RGB_SLOT_LEATHER2;
        case 5: return RGB_SLOT_METAL1;
    }
    return RGB_SLOT_METAL2;
}

// The item's colours, or an empty object.
json RgbGetColours(object oItem)
{
    json jColours = JsonParse(GetLocalString(oItem, RGB_COLOURS));
    return JsonGetType(jColours) == JSON_TYPE_OBJECT ? jColours : JsonObject();
}

// Store the item's colours. Call RgbApply on the wearer to show them.
void RgbSetColours(object oItem, json jColours)
{
    SetLocalString(oItem, RGB_COLOURS, JsonDump(jColours));
}

// One part's value for one channel: the part's own beats the whole outfit's.
string RgbChannelValue(json jColours, string sKey, int nChannel)
{
    string sChannel = IntToString(nChannel);
    json jValue = JsonObjectGet(JsonObjectGet(jColours, sKey), sChannel);
    if (JsonGetType(jValue) != JSON_TYPE_STRING)
        jValue = JsonObjectGet(JsonObjectGet(jColours, "all"), sChannel);
    return JsonGetType(jValue) == JSON_TYPE_STRING ? JsonGetString(jValue) : "";
}

// Turn "#rrggbb" into the packed float the shader reads. Packing r, g and b
// as r * 65536 + g * 256 + b is the same number the hex digits spell.
float RgbParseHex(string sHex)
{
    string sDigits = "0123456789abcdef";
    string sLower = GetStringLowerCase(GetStringRight(sHex, 6));
    int nValue = 0;
    int i;
    for (i = 0; i < 6; i++)
        nValue = nValue * 16 + FindSubString(sDigits, GetSubString(sLower, i, 1));
    return IntToFloat(nValue);
}

// Two hex digits for 0-255, the inverse of one byte of RgbParseHex.
string RgbHexByte(int nValue)
{
    string sDigits = "0123456789abcdef";
    return GetSubString(sDigits, nValue / 16, 1) + GetSubString(sDigits, nValue % 16, 1);
}

// The palette row of a preset value "p<row>".
int RgbPresetRow(string sValue)
{
    return StringToInt(GetStringRight(sValue, GetStringLength(sValue) - 1));
}

// The model name of one part oCreature wears, as the engine builds it.
string RgbPartModel(object oCreature, object oArmor, int nModel)
{
    int nNumber = GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, nModel);
    string sGender = GetGender(oCreature) == GENDER_FEMALE ? "f" : "m";
    string sRace = GetStringLowerCase(Get2DAString("appearance", "RACE", GetAppearanceType(oCreature)));
    return "p" + sGender + sRace + IntToString(GetPhenoType(oCreature)) + "_"
         + RgbPartKey(nModel) + GetStringRight("00" + IntToString(nNumber), 3);
}

// Show the colours of oCreature's armor on oCreature.
// Every value is wiped first, once: a value set never goes away on its own,
// and a reset scoped to one material makes the client restore every
// material's defaults when it replays the list. Then each part that has a
// colour gets it. At most 18 parts x 6 channels = 108 values, well under
// the engine's 1024 per object.
void RgbApply(object oCreature)
{
    ResetMaterialShaderUniforms(oCreature);
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    if (!GetIsObjectValid(oArmor)) return;
    json jColours = RgbGetColours(oArmor);
    int nModel;
    for (nModel = ITEM_APPR_ARMOR_MODEL_RFOOT; nModel <= ITEM_APPR_ARMOR_MODEL_LHAND; nModel++)
    {
        // Model 0 means the part is not shown.
        if (GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, nModel) == 0) continue;
        string sKey = RgbPartKey(nModel);
        string sMaterial = RgbPartMaterial(RgbPartModel(oCreature, oArmor, nModel));
        int nChannel;
        for (nChannel = 1; nChannel <= 6; nChannel++)
        {
            string sValue = RgbChannelValue(jColours, sKey, nChannel);
            int nSlot = RgbChannelSlot(nChannel);
            if (GetStringLeft(sValue, 1) == "#")
                RgbSetSlot(oCreature, sMaterial, nSlot, RgbParseHex(sValue));
            else if (GetStringLeft(sValue, 1) == "p")
                RgbSetPreset(oCreature, sMaterial, nSlot, RgbPresetRow(sValue));
        }
    }
}

// The material of oCreature's chest model, for scripts that colour one part.
string RgbChestMaterial(object oCreature)
{
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    return RgbPartMaterial(RgbPartModel(oCreature, oArmor, ITEM_APPR_ARMOR_MODEL_TORSO));
}

// The player a dm_runscript call means: it may run on the module, not the player.
object RgbCaller()
{
    return GetIsPC(OBJECT_SELF) ? OBJECT_SELF : GetFirstPC();
}
