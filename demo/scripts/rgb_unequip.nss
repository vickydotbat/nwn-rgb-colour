// Module OnPlayerUnEquipItem: take the armor's colours off the player.
#include "inc_rgb"

void main()
{
    object oPC = GetPCItemLastUnequippedBy();
    object oItem = GetPCItemLastUnequipped();
    if (GetBaseItemType(oItem) != BASE_ITEM_ARMOR) return;
    // The armor is still in the slot while this event runs, so wait a
    // moment. RgbApply then finds no armor and only wipes the values, which
    // a creature would otherwise keep, saved with the character.
    DelayCommand(0.1, RgbApply(oPC));
}
