#!/usr/bin/env python3
"""Build the palette atlas the RGB part shader reads for preset colours.

The atlas stacks the six stock palettes, 176 rows each, in slot order: skin,
hair, metal, cloth, leather, tattoo. Metal 1 and metal 2 both read the metal
palette, as stock does. Columns 0-255 are the stock row. Columns 256 on hold
the row averaged over 2, 4 ... 256 columns, which a far pixel reads so busy
rows do not fizz.

Usage:
    tools/rgb_atlas.py <folder of stock pal_*01.tga> --out <folder>
"""
import argparse
import struct
import sys
from pathlib import Path

PALETTES = ["skin", "hair", "armor", "cloth", "leath", "tattoo"]
WIDTH = 256


def read_palette(path):
    """-> rows of (b, g, r), colour 0 first.

    Colour c is the c-th line from the top of the palette as an image viewer
    shows it. A stock palette has a bottom-left origin, so it stores its
    lines bottom first, and colour c is stored line 175 - c."""
    data = path.read_bytes()
    kind, width, height, depth = data[2], *struct.unpack("<HH", data[12:16]), data[16] // 8
    if kind != 2 or width != WIDTH or depth not in (3, 4):
        raise ValueError(f"{path.name}: expected an uncompressed 256-wide TGA")
    start = 18 + data[0]
    rows = []
    for r in range(height):
        at = start + r * width * depth
        rows.append([tuple(data[at + c * depth:at + c * depth + 3]) for c in range(width)])
    # Descriptor bit 5 set means the file stores its top line first.
    return rows if data[17] & 0x20 else rows[::-1]


def averaged(row):
    """Columns 256-511: the row averaged over 2, 4 ... 256 columns."""
    out = []
    for level in range(1, 9):
        span = 1 << level
        for i in range(WIDTH // span):
            chunk = row[i * span:(i + 1) * span]
            out.append(tuple(round(sum(c[k] for c in chunk) / span) for k in range(3)))
    return out + [out[-1]]


# The preset grids the colour window shows: one cell per stock colour, 16
# across and 11 down, each filled with the colour at intensity 188, as the
# toolset's swatches look. Only the palettes an item colour uses get one.
GRID_PALETTES = ["armor", "cloth", "leath"]
GRID_COLS, GRID_ROWS = 16, 11
CELL_W, CELL_H = 18, 13
SWATCH_INTENSITY = 188
BORDER = (16, 16, 16)


def grid_tga(rows):
    width, height = GRID_COLS * CELL_W, GRID_ROWS * CELL_H
    lines = []
    for y in range(height):
        line = bytearray()
        for x in range(width):
            colour = (y // CELL_H) * GRID_COLS + x // CELL_W
            edge = x % CELL_W == CELL_W - 1 or y % CELL_H == CELL_H - 1
            line += bytes(BORDER if edge or colour >= len(rows) else rows[colour][SWATCH_INTENSITY])
        lines.append(bytes(line))
    # A bottom-left origin TGA stores its bottom line first.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 24, 0)
    return header + b"".join(reversed(lines))


def build(src, out):
    rows = []
    for name in PALETTES:
        rows += read_palette(src / f"pal_{name}01.tga")
    body = bytearray()
    for row in rows:
        for b, g, r in row + averaged(row):
            body += bytes((b, g, r))
    out.mkdir(parents=True, exist_ok=True)
    # Rows stored in atlas order, so the shader's row r is atlas row r.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 2 * WIDTH, len(rows), 24, 0)
    (out / "rgb_atlas.tga").write_bytes(header + bytes(body))
    (out / "rgb_atlas.txi").write_text("mipmap 0\nfilter 0\ndownsamplemax 0\n")
    for name in GRID_PALETTES:
        (out / f"gridv_{name}01.tga").write_bytes(grid_tga(read_palette(src / f"pal_{name}01.tga")))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("src", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        build(args.src, args.out)
    except (ValueError, FileNotFoundError) as err:
        print(err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
