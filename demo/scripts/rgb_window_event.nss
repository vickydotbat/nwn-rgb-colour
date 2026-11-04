// The colour window's event script. NUI runs it for every event the window
// sends: a watched bind that changed, a mouse press, the window closing.
#include "inc_rgbwin"

void main()
{
    object oPC = NuiGetEventPlayer();
    int nToken = NuiGetEventWindow();
    string sType = NuiGetEventType();
    string sElement = NuiGetEventElement();

    // A click on the preset grid stores that stock colour, "p" and its row.
    if (sType == "mousedown" && sElement == RGB_ID_GRID)
    {
        int nColour = RgbGridColour(oPC, NuiGetEventPayload());
        if (nColour >= 0) RgbWindowStore(oPC, nToken, "p" + IntToString(nColour));
        return;
    }
    // A drag starts on mousedown and ends on mouseup. Only a value that
    // changes during a drag comes from the player.
    if (sType == "mousedown" && sElement == RGB_ID_PICKER)
    {
        SetLocalString(oPC, RGB_DRAG, sElement);
        return;
    }
    if (sType == "mouseup")
    {
        DeleteLocalString(oPC, RGB_DRAG);
        return;
    }
    // A colour or mode button: its id is the bind name and its index.
    if (sType == "click")
    {
        string sBase = RgbButtonRowOf(sElement);
        int nIndex = RgbButtonIndexOf(sElement);
        if (sBase == RGB_BIND_CHANNEL)
        {
            SetLocalInt(oPC, RGB_CHANNEL_LOCAL, nIndex);
            RgbSelectButton(oPC, nToken, RGB_BIND_CHANNEL, RGB_CHANNELS, nIndex);
            RgbWindowLoad(oPC, nToken);
        }
        else if (sBase == RGB_BIND_MODE)
        {
            RgbSelectButton(oPC, nToken, RGB_BIND_MODE, RGB_MODES, nIndex);
            RgbWindowShowMode(oPC, nToken, nIndex == 1);
        }
        return;
    }
    if (sType != "watch") return;

    string sDrag = GetLocalString(oPC, RGB_DRAG);
    if (sElement == RGB_BIND_PART)
    {
        // A new part or channel: show what it holds.
        RgbWindowLoad(oPC, nToken);
    }
    else if (sElement == RGB_BIND_COLOUR && sDrag == RGB_ID_PICKER)
    {
        // The picker holds r, g and b as 0-255 values. Store it as "#rrggbb".
        json jColour = NuiGetBind(oPC, nToken, RGB_BIND_COLOUR);
        string sHex = "#" + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "r")))
                          + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "g")))
                          + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "b")));
        RgbWindowStore(oPC, nToken, sHex);
    }
}
