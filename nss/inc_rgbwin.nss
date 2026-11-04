// inc_rgbwin: a lean colour window, written in NWScript with NUI.
//
// The window sets the colours of the armor a player wears, for the whole
// outfit or for one part, and stores them on the item (see inc_rgb). It never
// swaps a part's model: it only colours what the armor already shows.
//
// Layout, top to bottom:
//   Part:    a list of Whole outfit and every part the armor shows
//   Colour:  1 to 6, the item's colours in toolset order
//   Mode:    RGB (any colour) or Presets (a stock palette row)
//   a colour picker for RGB, or a row slider for Presets
//
// NUI sends a "watch" event whenever a bound value changes, including when
// the server sets it. The stock colour picker also sends one before the
// mouse goes down, and echoes values the server set. So the window only
// takes a picker or slider value while the player is dragging it: a
// mousedown on the control starts a drag and a mouseup ends it.
#include "inc_rgb"
#include "nw_inc_nui"

const string RGB_WINDOW = "rgb_window";
const string RGB_WINDOW_EVENTS = "rgb_window_event";
// The part list's value for Whole outfit. Parts use their model index.
const int RGB_WHOLE_OUTFIT = -1;

// The armor the window colours.
object RgbWindowArmor(object oPC)
{
    return GetItemInSlot(INVENTORY_SLOT_CHEST, oPC);
}

// The name a player reads for each ITEM_APPR_ARMOR_MODEL_* part.
string RgbPartLabel(int nModel)
{
    switch (nModel)
    {
        case 0: return "Right foot";      case 1: return "Left foot";
        case 2: return "Right shin";      case 3: return "Left shin";
        case 4: return "Left thigh";      case 5: return "Right thigh";
        case 6: return "Pelvis";          case 7: return "Chest";
        case 8: return "Belt";            case 9: return "Neck";
        case 10: return "Right forearm";  case 11: return "Left forearm";
        case 12: return "Right bicep";    case 13: return "Left bicep";
        case 14: return "Right shoulder"; case 15: return "Left shoulder";
        case 16: return "Right hand";     case 17: return "Left hand";
    }
    return "";
}

// The part list: Whole outfit, then every part the armor shows.
json RgbWindowParts(object oArmor)
{
    json jParts = JsonArrayInsert(JsonArray(), NuiComboEntry("Whole outfit", RGB_WHOLE_OUTFIT));
    int nModel;
    for (nModel = ITEM_APPR_ARMOR_MODEL_RFOOT; nModel <= ITEM_APPR_ARMOR_MODEL_LHAND; nModel++)
    {
        // Model 0 means the armor does not show that part.
        if (GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, nModel) == 0) continue;
        jParts = JsonArrayInsert(jParts, NuiComboEntry(RgbPartLabel(nModel), nModel));
    }
    return jParts;
}

// The colours key the window's part list points at: "all" or a part key.
string RgbWindowKey(object oPC, int nToken)
{
    int nPart = JsonGetInt(NuiGetBind(oPC, nToken, "part"));
    return nPart == RGB_WHOLE_OUTFIT ? "all" : RgbPartKey(nPart);
}

// The channel the window points at, 1-6. The toggles count from 0.
int RgbWindowChannel(object oPC, int nToken)
{
    return JsonGetInt(NuiGetBind(oPC, nToken, "chan")) + 1;
}

// Show one of the two controls, the picker or the slider.
void RgbWindowShowMode(object oPC, int nToken, int bPreset)
{
    NuiSetBind(oPC, nToken, "is_rgb", JsonBool(!bPreset));
    NuiSetBind(oPC, nToken, "is_preset", JsonBool(bPreset));
}

// Fill the controls with the stored value of the part and channel shown.
// Setting a bind sends a watch event back, so the event script ignores
// picker and slider values unless the player is dragging them.
void RgbWindowLoad(object oPC, int nToken)
{
    json jColours = RgbGetColours(RgbWindowArmor(oPC));
    string sValue = RgbChannelValue(jColours, RgbWindowKey(oPC, nToken), RgbWindowChannel(oPC, nToken));
    int bPreset = GetStringLeft(sValue, 1) == "p";
    int nRow = bPreset ? StringToInt(GetStringRight(sValue, GetStringLength(sValue) - 1)) : 0;
    int nPacked = bPreset || sValue == "" ? 0 : FloatToInt(RgbParseHex(sValue));
    NuiSetBind(oPC, nToken, "mode", JsonInt(bPreset));
    NuiSetBind(oPC, nToken, "col", NuiColor(nPacked / 65536, (nPacked / 256) % 256, nPacked % 256));
    NuiSetBind(oPC, nToken, "row", JsonInt(nRow));
    NuiSetBind(oPC, nToken, "row_label", JsonString(IntToString(nRow)));
    RgbWindowShowMode(oPC, nToken, bPreset);
}

// Store one value for the part and channel shown, then redraw the wearer.
void RgbWindowStore(object oPC, int nToken, string sValue)
{
    object oArmor = RgbWindowArmor(oPC);
    json jColours = RgbGetColours(oArmor);
    string sKey = RgbWindowKey(oPC, nToken);
    json jPart = JsonObjectGet(jColours, sKey);
    if (JsonGetType(jPart) != JSON_TYPE_OBJECT) jPart = JsonObject();
    jPart = JsonObjectSet(jPart, IntToString(RgbWindowChannel(oPC, nToken)), JsonString(sValue));
    RgbSetColours(oArmor, JsonObjectSet(jColours, sKey, jPart));
    RgbApply(oPC);
}

// Two hex digits for 0-255.
string RgbHexByte(int nValue)
{
    string sDigits = "0123456789abcdef";
    return GetSubString(sDigits, nValue / 16, 1) + GetSubString(sDigits, nValue % 16, 1);
}

// Open the colour window for oPC.
void RgbOpenWindow(object oPC)
{
    object oArmor = RgbWindowArmor(oPC);
    if (!GetIsObjectValid(oArmor))
    {
        SendMessageToPC(oPC, "Put on some armor or clothing first.");
        return;
    }

    json jPart = NuiRow(JsonArrayInsert(JsonArrayInsert(JsonArray(),
        NuiWidth(NuiLabel(JsonString("Part"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)), 70.0)),
        NuiCombo(RgbWindowParts(oArmor), NuiBind("part"))));

    json jChannels = JsonArray();
    int i;
    for (i = 1; i <= 6; i++)
        jChannels = JsonArrayInsert(jChannels, JsonString(IntToString(i)));
    json jChannel = NuiRow(JsonArrayInsert(JsonArrayInsert(JsonArray(),
        NuiWidth(NuiLabel(JsonString("Colour"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)), 70.0)),
        NuiToggles(NUI_DIRECTION_HORIZONTAL, jChannels, NuiBind("chan"))));

    json jModes = JsonArrayInsert(JsonArrayInsert(JsonArray(), JsonString("RGB")), JsonString("Presets"));
    json jMode = NuiRow(JsonArrayInsert(JsonArrayInsert(JsonArray(),
        NuiWidth(NuiLabel(JsonString("Mode"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)), 70.0)),
        NuiToggles(NUI_DIRECTION_HORIZONTAL, jModes, NuiBind("mode"))));

    json jPicker = NuiVisible(NuiHeight(NuiId(NuiColorPicker(NuiBind("col")), "picker"), 200.0), NuiBind("is_rgb"));
    json jSlider = NuiVisible(NuiRow(JsonArrayInsert(JsonArrayInsert(JsonArray(),
        NuiId(NuiSlider(NuiBind("row"), JsonInt(0), JsonInt(175), JsonInt(1)), "slider")),
        NuiWidth(NuiLabel(NuiBind("row_label"), JsonInt(NUI_HALIGN_RIGHT), JsonInt(NUI_VALIGN_MIDDLE)), 50.0))),
        NuiBind("is_preset"));

    json jRoot = NuiCol(JsonArrayInsert(JsonArrayInsert(JsonArrayInsert(JsonArrayInsert(JsonArrayInsert(JsonArray(),
        jPart), jChannel), jMode), jPicker), jSlider));
    json jWindow = NuiWindow(jRoot, JsonString("Colours"), NuiRect(-1.0, -1.0, 360.0, 400.0),
        JSON_FALSE, JSON_FALSE, JSON_TRUE, JSON_FALSE, JSON_TRUE);

    int nToken = NuiCreate(oPC, jWindow, RGB_WINDOW, RGB_WINDOW_EVENTS);
    NuiSetBind(oPC, nToken, "part", JsonInt(RGB_WHOLE_OUTFIT));
    NuiSetBind(oPC, nToken, "chan", JsonInt(0));
    RgbWindowLoad(oPC, nToken);
    // Watch the controls whose changes the event script acts on.
    NuiSetBindWatch(oPC, nToken, "part", TRUE);
    NuiSetBindWatch(oPC, nToken, "chan", TRUE);
    NuiSetBindWatch(oPC, nToken, "mode", TRUE);
    NuiSetBindWatch(oPC, nToken, "col", TRUE);
    NuiSetBindWatch(oPC, nToken, "row", TRUE);
}
