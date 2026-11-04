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

// Bind names and control ids the window and its event script share. NUI
// ignores a bind name it doesn't know, so a typo fails without an error.
const string RGB_BIND_PART = "part";
const string RGB_BIND_CHANNEL = "chan";
const string RGB_BIND_MODE = "mode";
const string RGB_BIND_COLOUR = "col";
const string RGB_BIND_ROW = "row";
const string RGB_BIND_ROW_LABEL = "row_label";
const string RGB_BIND_IS_RGB = "is_rgb";
const string RGB_BIND_IS_PRESET = "is_preset";
const string RGB_ID_PICKER = "picker";
const string RGB_ID_SLIDER = "slider";
// The control a player is dragging, kept on the player.
const string RGB_DRAG = "RGB_DRAG";

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
    int nPart = JsonGetInt(NuiGetBind(oPC, nToken, RGB_BIND_PART));
    return nPart == RGB_WHOLE_OUTFIT ? "all" : RgbPartKey(nPart);
}

// The channel the window points at, 1-6. The toggles count from 0.
int RgbWindowChannel(object oPC, int nToken)
{
    return JsonGetInt(NuiGetBind(oPC, nToken, RGB_BIND_CHANNEL)) + 1;
}

// Show one of the two controls, the picker or the slider.
void RgbWindowShowMode(object oPC, int nToken, int bPreset)
{
    NuiSetBind(oPC, nToken, RGB_BIND_IS_RGB, JsonBool(!bPreset));
    NuiSetBind(oPC, nToken, RGB_BIND_IS_PRESET, JsonBool(bPreset));
}

// Fill the controls with the stored value of the part and channel shown.
// Setting a bind sends a watch event back, so the event script ignores
// picker and slider values unless the player is dragging them.
void RgbWindowLoad(object oPC, int nToken)
{
    json jColours = RgbGetColours(RgbWindowArmor(oPC));
    string sValue = RgbChannelValue(jColours, RgbWindowKey(oPC, nToken), RgbWindowChannel(oPC, nToken));
    int bPreset = GetStringLeft(sValue, 1) == "p";
    int nRow = bPreset ? RgbPresetRow(sValue) : 0;
    int nPacked = bPreset || sValue == "" ? 0 : FloatToInt(RgbParseHex(sValue));
    NuiSetBind(oPC, nToken, RGB_BIND_MODE, JsonInt(bPreset));
    NuiSetBind(oPC, nToken, RGB_BIND_COLOUR, NuiColor(nPacked / 65536, (nPacked / 256) % 256, nPacked % 256));
    NuiSetBind(oPC, nToken, RGB_BIND_ROW, JsonInt(nRow));
    NuiSetBind(oPC, nToken, RGB_BIND_ROW_LABEL, JsonString(IntToString(nRow)));
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


// Window sizes, in points. The client draws a window at exactly the size it
// is given and never shrinks it to fit. So every element gets a width, a
// height, and no margin or padding: the engine adds a default margin on top
// of a declared size, and a row sized to fit its children then can't hold
// them. A row's children are as tall as the row.
const float RGB_WIN_WIDTH = 300.0;   // the content, inside the frame
const float RGB_ROW = 28.0;          // one row of controls
const float RGB_LABEL = 60.0;        // the label column
const float RGB_PICKER = 140.0;      // the colour picker's height
const float RGB_GAP = 4.0;           // the space under each row
// The frame around the content: the title bar on top, the border sides.
const float RGB_TITLE_BAR = 33.0;
const float RGB_FRAME_SIDES = 20.0;

// An element at exactly w x h, with no margin or padding.
json RgbSized(json jElem, float fWidth, float fHeight)
{
    return NuiPadding(NuiMargin(NuiHeight(NuiWidth(jElem, fWidth), fHeight), 0.0), 0.0);
}

// A row: a label, then one control filling the rest of the width.
json RgbFormRow(string sLabel, json jControl)
{
    json jLabel = RgbSized(NuiLabel(JsonString(sLabel), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)),
                           RGB_LABEL, RGB_ROW);
    json jRow = JsonArrayInsert(JsonArrayInsert(JsonArray(), jLabel),
                                RgbSized(jControl, RGB_WIN_WIDTH - RGB_LABEL, RGB_ROW));
    return RgbSized(NuiRow(jRow), RGB_WIN_WIDTH, RGB_ROW);
}

// A gap of RGB_GAP between two rows.
json RgbGap()
{
    return RgbSized(NuiSpacer(), RGB_WIN_WIDTH, RGB_GAP);
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

    json jChannels = JsonArray();
    int i;
    for (i = 1; i <= 6; i++)
        jChannels = JsonArrayInsert(jChannels, JsonString(IntToString(i)));
    json jModes = JsonArrayInsert(JsonArrayInsert(JsonArray(), JsonString("RGB")), JsonString("Presets"));

    // The picker and the slider row share one slot: only one shows at a time.
    json jPicker = NuiVisible(RgbSized(NuiId(NuiColorPicker(NuiBind(RGB_BIND_COLOUR)), RGB_ID_PICKER),
                                       RGB_WIN_WIDTH, RGB_PICKER), NuiBind(RGB_BIND_IS_RGB));
    json jSliderRow = JsonArrayInsert(JsonArrayInsert(JsonArray(),
        RgbSized(NuiId(NuiSlider(NuiBind(RGB_BIND_ROW), JsonInt(0), JsonInt(175), JsonInt(1)), RGB_ID_SLIDER),
                 RGB_WIN_WIDTH - RGB_LABEL, RGB_ROW)),
        RgbSized(NuiLabel(NuiBind(RGB_BIND_ROW_LABEL), JsonInt(NUI_HALIGN_RIGHT), JsonInt(NUI_VALIGN_MIDDLE)),
                 RGB_LABEL, RGB_ROW));
    json jSlider = NuiVisible(RgbSized(NuiRow(jSliderRow), RGB_WIN_WIDTH, RGB_ROW), NuiBind(RGB_BIND_IS_PRESET));

    json jColumn = JsonArray();
    jColumn = JsonArrayInsert(jColumn, RgbFormRow("Part", NuiCombo(RgbWindowParts(oArmor), NuiBind(RGB_BIND_PART))));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, RgbFormRow("Colour", NuiToggles(NUI_DIRECTION_HORIZONTAL, jChannels, NuiBind(RGB_BIND_CHANNEL))));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, RgbFormRow("Mode", NuiToggles(NUI_DIRECTION_HORIZONTAL, jModes, NuiBind(RGB_BIND_MODE))));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, jPicker);
    jColumn = JsonArrayInsert(jColumn, jSlider);

    // The column holds three rows with their gaps, then the picker or the
    // slider. Hidden or not, both keep their place, so count both.
    float fHeight = 3.0 * (RGB_ROW + RGB_GAP) + RGB_PICKER + RGB_ROW;
    json jRoot = RgbSized(NuiCol(jColumn), RGB_WIN_WIDTH, fHeight);
    json jGeometry = NuiRect(-1.0, -1.0, RGB_WIN_WIDTH + RGB_FRAME_SIDES, fHeight + RGB_TITLE_BAR);
    json jWindow = NuiWindow(jRoot, JsonString("Colours"), jGeometry,
        JSON_FALSE, JSON_FALSE, JSON_TRUE, JSON_FALSE, JSON_TRUE);

    int nToken = NuiCreate(oPC, jWindow, RGB_WINDOW, RGB_WINDOW_EVENTS);
    NuiSetBind(oPC, nToken, RGB_BIND_PART, JsonInt(RGB_WHOLE_OUTFIT));
    NuiSetBind(oPC, nToken, RGB_BIND_CHANNEL, JsonInt(0));
    RgbWindowLoad(oPC, nToken);
    // Watch the controls whose changes the event script acts on.
    NuiSetBindWatch(oPC, nToken, RGB_BIND_PART, TRUE);
    NuiSetBindWatch(oPC, nToken, RGB_BIND_CHANNEL, TRUE);
    NuiSetBindWatch(oPC, nToken, RGB_BIND_MODE, TRUE);
    NuiSetBindWatch(oPC, nToken, RGB_BIND_COLOUR, TRUE);
    NuiSetBindWatch(oPC, nToken, RGB_BIND_ROW, TRUE);
}
