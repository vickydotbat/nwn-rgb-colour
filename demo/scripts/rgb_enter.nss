// Module OnClientEnter: dress each new player in plain clothing with chest 7,
// a chest whose cloth 1 layer covers about half of it, so the colour scripts
// have something to show.
void main()
{
    object oPC = GetEnteringObject();
    // Make the clothing from the stock blueprint, then copy it with chest model 7.
    // CopyItemAndModify returns a new item, so the original is destroyed.
    object oBase = CreateItemOnObject("nw_cloth001", oPC);
    object oCloth = CopyItemAndModify(oBase, ITEM_APPR_TYPE_ARMOR_MODEL, ITEM_APPR_ARMOR_MODEL_TORSO, 7, TRUE);
    DestroyObject(oBase);
    AssignCommand(oPC, ActionEquipItem(oCloth, INVENTORY_SLOT_CHEST));
    SendMessageToPC(oPC, "RGB demo: type ~ then DebugMode 1, then dm_runscript rgb_red or dm_runscript rgb_clear.");
}
