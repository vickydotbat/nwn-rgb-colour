// inc_rgbwin: a lean colour window, written in NWScript with NUI.
//
// The window sets the colours of the armor a player wears, for the whole
// outfit or for one part, and stores them on the item (see inc_rgb). It never
// swaps a part's model: it only colours what the armor already shows.
//
// Layout, top to bottom:
//   Part:    a list of Whole outfit and every part the armor shows
//   Colour:  1 to 6, the item's colours in toolset order
//   Mode:    RGB (any colour) or Presets (a stock palette colour)
//   a colour picker for RGB, or a grid of the stock colours for Presets
//
// NUI sends a "watch" event whenever a bound value changes, including when
// the server sets it. The stock colour picker also sends one before the
// mouse goes down, and echoes values the server set. So the window only
// takes a picker value while the player is dragging it: a mousedown on the
// picker starts a drag and a mouseup ends it.
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
const string RGB_ID_PICKER = "picker";
const string RGB_ID_GRID = "grid";
const string RGB_ID_SLOT = "slot";
// The control a player is dragging, kept on the player.
const string RGB_DRAG = "RGB_DRAG";

// Window sizes, in points. The client draws a window at exactly the size it
// is given and never shrinks it to fit. So every element gets a width, a
// height, and no margin or padding: the engine adds a default margin on top
// of a declared size, and a row sized to fit its children then can't hold
// them. A row's children are as tall as the row.
const float RGB_WIN_WIDTH = 300.0;   // the content, inside the frame
const float RGB_ROW = 28.0;          // one row of controls
const float RGB_LABEL = 60.0;        // the label column
const float RGB_PICKER = 143.0;      // the picker or the grid's height
// The preset grid: 16 x 11 cells, one per stock colour. Each cell is
// 18 x 13 points, matching the grid images the build writes.
const int RGB_GRID_COLS = 16;
const float RGB_CELL_W = 18.0;
const float RGB_CELL_H = 13.0;
const float RGB_GAP = 4.0;           // the space under each row
const float RGB_BOTTOM = 12.0;       // room under the slot, above the frame
// The frame around the content: the title bar on top, the border sides.
const float RGB_TITLE_BAR = 33.0;
const float RGB_FRAME_SIDES = 20.0;

// An element at exactly w x h, with no margin or padding.
json RgbSized(json jElem, float fWidth, float fHeight)
{
    return NuiPadding(NuiMargin(NuiHeight(NuiWidth(jElem, fWidth), fHeight), 0.0), 0.0);
}

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
    return GetLocalInt(oPC, RGB_BIND_CHANNEL) + 1;
}

// Fill the slot under the buttons: the picker, or the grid of stock colours
// for the palette the current colour uses, from rgb_palettes.2da.
void RgbWindowShowMode(object oPC, int nToken, int bPreset)
{
    json jSlot;
    if (bPreset)
    {
        string sGrid = Get2DAString("rgb_palettes", "Grid", RgbWindowChannel(oPC, nToken) - 1);
        jSlot = NuiImage(JsonString(sGrid), JsonInt(NUI_ASPECT_EXACT), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP));
        jSlot = RgbSized(NuiId(jSlot, RGB_ID_GRID), RGB_WIN_WIDTH, RGB_PICKER);
    }
    else
        jSlot = RgbSized(NuiId(NuiColorPicker(NuiBind(RGB_BIND_COLOUR)), RGB_ID_PICKER), RGB_WIN_WIDTH, RGB_PICKER);
    // Swapping one group's layout keeps the rest of the window as it is.
    NuiSetGroupLayout(oPC, nToken, RGB_ID_SLOT, jSlot);
}

// The stock colour under a click on the grid, or -1 between cells. The
// client reports the click in screen pixels from the grid's top left,
// scaled by the player's UI scale, so divide that out first.
int RgbGridColour(object oPC, json jPayload)
{
    json jPos = JsonObjectGet(jPayload, "mouse_pos");
    float fScale = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_SCALE)) / 100.0;
    if (fScale <= 0.0) fScale = 1.0;
    int nCol = FloatToInt(JsonGetFloat(JsonObjectGet(jPos, "x")) / fScale / RGB_CELL_W);
    int nRow = FloatToInt(JsonGetFloat(JsonObjectGet(jPos, "y")) / fScale / RGB_CELL_H);
    if (nCol < 0 || nCol >= RGB_GRID_COLS || nRow < 0) return -1;
    int nColour = nRow * RGB_GRID_COLS + nCol;
    return nColour < 176 ? nColour : -1;
}

// Light button nValue of a button row and unlight the rest.
void RgbSelectButton(object oPC, int nToken, string sBind, int nCount, int nValue)
{
    int i;
    for (i = 0; i < nCount; i++)
        NuiSetBind(oPC, nToken, sBind + IntToString(i), JsonBool(i == nValue));
}

// Fill the controls with the stored value of the part and channel shown.
// Setting a bind sends a watch event back, so the event script ignores
// picker values unless the player is dragging it.
void RgbWindowLoad(object oPC, int nToken)
{
    json jColours = RgbGetColours(RgbWindowArmor(oPC));
    string sValue = RgbChannelValue(jColours, RgbWindowKey(oPC, nToken), RgbWindowChannel(oPC, nToken));
    int bPreset = GetStringLeft(sValue, 1) == "p";
    int nPacked = bPreset || sValue == "" ? 0 : FloatToInt(RgbParseHex(sValue));
    RgbSelectButton(oPC, nToken, RGB_BIND_MODE, 2, bPreset);
    NuiSetBind(oPC, nToken, RGB_BIND_COLOUR, NuiColor(nPacked / 65536, (nPacked / 256) % 256, nPacked % 256));
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


// A row: a label, then one control filling the rest of the width.
json RgbFormRow(string sLabel, json jControl)
{
    json jLabel = RgbSized(NuiLabel(JsonString(sLabel), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)),
                           RGB_LABEL, RGB_ROW);
    json jRow = JsonArrayInsert(JsonArrayInsert(JsonArray(), jLabel),
                                RgbSized(jControl, RGB_WIN_WIDTH - RGB_LABEL, RGB_ROW));
    return RgbSized(NuiRow(jRow), RGB_WIN_WIDTH, RGB_ROW);
}

// A row of small select buttons, one per label. Button i is lit while the
// bind sBind holds i. Stock toggles stretch each button to the width of the
// whole control, so the window builds its own row of fixed buttons.
json RgbButtonRow(string sLabel, json jLabels, string sBind, float fButton)
{
    json jLabel = RgbSized(NuiLabel(JsonString(sLabel), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_MIDDLE)),
                           RGB_LABEL, RGB_ROW);
    json jRow = JsonArrayInsert(JsonArray(), jLabel);
    int i;
    for (i = 0; i < JsonGetLength(jLabels); i++)
    {
        json jButton = NuiButtonSelect(JsonArrayGet(jLabels, i), NuiBind(sBind + IntToString(i)));
        jRow = JsonArrayInsert(jRow, RgbSized(NuiId(jButton, sBind + IntToString(i)), fButton, RGB_ROW));
    }
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
        SendMessageToPC(oPC, "You must equip armor or clothing.");
        return;
    }

    json jChannels = JsonArray();
    int i;
    for (i = 1; i <= 6; i++)
        jChannels = JsonArrayInsert(jChannels, JsonString(IntToString(i)));
    json jModes = JsonArrayInsert(JsonArrayInsert(JsonArray(), JsonString("RGB")), JsonString("Presets"));

    // The picker and the preset grid share one slot: a group whose layout
    // RgbWindowShowMode swaps.
    json jSlot = RgbSized(NuiId(NuiGroup(RgbSized(NuiSpacer(), RGB_WIN_WIDTH, RGB_PICKER), FALSE, NUI_SCROLLBARS_NONE),
                                RGB_ID_SLOT), RGB_WIN_WIDTH, RGB_PICKER);

    json jColumn = JsonArray();
    jColumn = JsonArrayInsert(jColumn, RgbFormRow("Part", NuiCombo(RgbWindowParts(oArmor), NuiBind(RGB_BIND_PART))));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, RgbButtonRow("Colour", jChannels, RGB_BIND_CHANNEL, 32.0));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, RgbButtonRow("Mode", jModes, RGB_BIND_MODE, 80.0));
    jColumn = JsonArrayInsert(jColumn, RgbGap());
    jColumn = JsonArrayInsert(jColumn, jSlot);

    // The column holds three rows with their gaps, then the slot, then a
    // little room so the slot doesn't touch the frame.
    float fHeight = 3.0 * (RGB_ROW + RGB_GAP) + RGB_PICKER + RGB_BOTTOM;
    // The root is a group with scrollbars off: the window is sized to hold
    // it, so it never needs them.
    json jRoot = RgbSized(NuiGroup(RgbSized(NuiCol(jColumn), RGB_WIN_WIDTH, fHeight), FALSE, NUI_SCROLLBARS_NONE),
                          RGB_WIN_WIDTH, fHeight);
    json jGeometry = NuiRect(-1.0, -1.0, RGB_WIN_WIDTH + RGB_FRAME_SIDES, fHeight + RGB_TITLE_BAR);
    json jWindow = NuiWindow(jRoot, JsonString("Colours"), jGeometry,
        JSON_FALSE, JSON_FALSE, JSON_TRUE, JSON_FALSE, JSON_TRUE);

    int nToken = NuiCreate(oPC, jWindow, RGB_WINDOW, RGB_WINDOW_EVENTS);
    NuiSetBind(oPC, nToken, RGB_BIND_PART, JsonInt(RGB_WHOLE_OUTFIT));
    SetLocalInt(oPC, RGB_BIND_CHANNEL, 0);
    RgbSelectButton(oPC, nToken, RGB_BIND_CHANNEL, 6, 0);
    RgbWindowLoad(oPC, nToken);
    // Watch the controls whose changes the event script acts on.
    NuiSetBindWatch(oPC, nToken, RGB_BIND_PART, TRUE);
    NuiSetBindWatch(oPC, nToken, RGB_BIND_COLOUR, TRUE);
}
