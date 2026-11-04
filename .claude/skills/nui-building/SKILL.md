---
name: nui-building
description: NUI windows written in NWScript with nw_inc_nui. Use when building, resizing or debugging the colour window (nss/inc_rgbwin.nss) or any NUI window, when a window comes out too big, scrolls, shows dead space, or fails with "The constraint can not be satisfied.", and when a bind's watch event fires on its own.
---

# Building NUI windows

The client lays out a NUI window with a constraint solver. Size the layout so the solver has exactly one answer, and the window comes out as small as its content.

## Size every element

- **Give every element a width and a height, and set its margin and padding to 0.** In `inc_rgbwin.nss`, `RgbSized` does all four. The engine adds a default margin on top of a declared size, so a 28-tall label in a row fixed at 28 asks for more than 28. The solver then refuses the whole window: "The constraint can not be satisfied."
- **A child's cross-axis size equals its parent's.** In a row, each child is as tall as the row. In a column, each child is as wide as the column.
- **Children may sum to less than their parent along the layout direction, never more.** Size a parent to what it must hold.
- **A row or a column never scrolls.** Content past its size fails to build. Repeated rows go in a scrolling `NuiGroup`, and a child of a scrolling group must leave room for the scrollbar.
- **Stock `NuiToggles` draws each button as wide as the whole control.** Six toggles in a 240-point row overflow it. Build a row of fixed-size `NuiButtonSelect` buttons instead.
- **A hidden element keeps its place.** `NuiVisible` hides an element but not its space, so count both sides of a swap in the height.
- **A zero-size `NuiSpacer` still moves the elements after it.** Skip a gap of 0.

## Size the window to its content

- **The client draws a window at exactly the geometry it is given.** It never shrinks one to fit. Every extra point is dead space at the bottom or right, and a window smaller than its root grows scrollbars.
- **Window width is the root's width plus 20 for the side frame. Window height is the root's height plus 33 for the title bar.** A window declared only as wide as its root stretches the root by 20, and the content grows a horizontal scrollbar.
- **Leave 16 to 32 points of slack at most.** Derive the height from the rows in code, never by eye.
- `NuiRect(-1.0, -1.0, w, h)` centres the window. -1 works for x and y only, never for the size.

## Binds talk back

- **A value the server sets fires its own watch event**, as if the player moved the control. Ignore watch events while you set several binds in a row.
- **The stock colour picker fires a watch event before the mouse goes down, and echoes values the server set.** Take a picker or slider value only during a drag: a `mousedown` on the control starts one and a `mouseup` ends it.
- **`NuiColorPicker` is a square plus a hue bar**: saturation across, brightness down, hue beside it.
- **NUI ignores a bind name it doesn't know**, with no error. Keep bind names in constants shared by the window and its event script.

## See it

A window change needs a look in game: run `just demo <game folder> <game user folder>`, load the demo and use the easel. A window that fails to build shows an error window instead of nothing.
