// Module OnClientEnter: dress each new player in plain clothing with chest 7,
// a chest whose cloth 1 layer covers about half of it, so the colour scripts
// have something to show.
#include "inc_rgb"

void main()
{
    object oPC = GetEnteringObject();
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
    SendMessageToPC(oPC, "RGB demo: type ~ then DebugMode 1, then dm_runscript rgb_red or dm_runscript rgb_clear.");
}
