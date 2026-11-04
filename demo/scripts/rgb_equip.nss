// Module OnPlayerEquipItem: show the colours of the armor a player puts on.
#include "inc_rgb"

void main()
{
    object oPC = GetPCItemLastEquippedBy();
    object oItem = GetPCItemLastEquipped();
    // Only chest armor carries part colours.
    if (GetBaseItemType(oItem) != BASE_ITEM_ARMOR) return;
    // The colours live on the item, so whoever wears it shows them.
    RgbApply(oPC);
}
