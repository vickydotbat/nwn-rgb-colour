// The colour window's event script. NUI runs it for every event the window
// sends: a watched bind that changed, a mouse press, the window closing.
#include "inc_rgbwin"

void main()
{
    object oPC = NuiGetEventPlayer();
    int nToken = NuiGetEventWindow();
    string sType = NuiGetEventType();
    string sElement = NuiGetEventElement();

    // A drag starts on mousedown and ends on mouseup. Only a value that
    // changes during a drag comes from the player.
    if (sType == "mousedown" && (sElement == "picker" || sElement == "slider"))
    {
        SetLocalString(oPC, "RGB_DRAG", sElement);
        return;
    }
    if (sType == "mouseup")
    {
        DeleteLocalString(oPC, "RGB_DRAG");
        return;
    }
    if (sType != "watch") return;

    string sDrag = GetLocalString(oPC, "RGB_DRAG");
    if (sElement == "part" || sElement == "chan")
    {
        // A new part or channel: show what it holds.
        RgbWindowLoad(oPC, nToken);
    }
    else if (sElement == "mode")
    {
        RgbWindowShowMode(oPC, nToken, JsonGetInt(NuiGetBind(oPC, nToken, "mode")) == 1);
    }
    else if (sElement == "col" && sDrag == "picker")
    {
        // The picker holds r, g and b as 0-255 values. Store it as "#rrggbb".
        json jColour = NuiGetBind(oPC, nToken, "col");
        string sHex = "#" + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "r")))
                          + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "g")))
                          + RgbHexByte(JsonGetInt(JsonObjectGet(jColour, "b")));
        RgbWindowStore(oPC, nToken, sHex);
    }
    else if (sElement == "row" && sDrag == "slider")
    {
        int nRow = JsonGetInt(NuiGetBind(oPC, nToken, "row"));
        NuiSetBind(oPC, nToken, "row_label", JsonString(IntToString(nRow)));
        // A preset is stored as "p" and its row.
        RgbWindowStore(oPC, nToken, "p" + IntToString(nRow));
    }
}
