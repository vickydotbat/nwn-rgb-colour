// Placeable OnUsed: open the colour window for the player who used it.
#include "inc_rgbwin"

void main()
{
    RgbOpenWindow(GetLastUsedBy());
}
