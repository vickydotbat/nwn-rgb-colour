// Module OnClientEnter: dress each new player in plain clothing with chest 7,
// a chest whose cloth 1 layer covers about half of it, so the colour scripts
// have something to show.
#include "inc_rgb"

// Put a usable easel beside the entry point, once. Using it opens the colour
// window, so a player never needs the console.
void RgbPlaceEasel()
{
    if (GetIsObjectValid(GetObjectByTag("RGB_EASEL"))) return;
    location lHere = GetStartingLocation();
    vector vAt = GetPositionFromLocation(lHere) + Vector(2.0, 0.0, 0.0);
    location lEasel = Location(GetAreaFromLocation(lHere), vAt, 270.0);
    // The stock painting easel is neither static nor a container, so a
    // script can make it usable and give it an OnUsed script.
    object oEasel = CreateObject(OBJECT_TYPE_PLACEABLE, "plc_pntingeasel", lEasel, FALSE, "RGB_EASEL");
    SetUseableFlag(oEasel, TRUE);
    SetName(oEasel, "Colour easel");
    SetEventScript(oEasel, EVENT_SCRIPT_PLACEABLE_ON_USED, "rgb_window_open");
}

void main()
{
    object oPC = GetEnteringObject();
    RgbPlaceEasel();
    // A returning player keeps their armor. Show its colours again: the
    // engine sends a creature's values to clients, and RgbApply rebuilds
    // them from the item, so they match what the item says.
    if (GetIsObjectValid(GetItemInSlot(INVENTORY_SLOT_CHEST, oPC)))
    {
        RgbApply(oPC);
        return;
    }
    // Make the clothing from the stock blueprint, then copy it with chest model 7.
    // CopyItemAndModify returns a new item, so the original is destroyed.
    object oBase = CreateItemOnObject("nw_cloth001", oPC);
    object oCloth = CopyItemAndModify(oBase, ITEM_APPR_TYPE_ARMOR_MODEL, ITEM_APPR_ARMOR_MODEL_TORSO, 7, TRUE);
    DestroyObject(oBase);
    // Start the demo armor blue all over, with a green left forearm, so a
    // new player sees colours that follow the item (E9).
    json jColours = JsonParse("{\"all\": {\"1\": \"#1e5bd6\"}, \"forel\": {\"1\": \"#2ecc40\"}}");
    RgbSetColours(oCloth, jColours);
    AssignCommand(oPC, ActionEquipItem(oCloth, INVENTORY_SLOT_CHEST));
    SendMessageToPC(oPC, "Use the easel to open the colour window.");
}
