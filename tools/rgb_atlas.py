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
    """-> rows of (b, g, r) in stored order, the order the engine uploads."""
    data = path.read_bytes()
    kind, width, height, depth = data[2], *struct.unpack("<HH", data[12:16]), data[16] // 8
    if kind != 2 or width != WIDTH or depth not in (3, 4):
        raise ValueError(f"{path.name}: expected an uncompressed 256-wide TGA")
    start = 18 + data[0]
    rows = []
    for r in range(height):
        at = start + r * width * depth
        rows.append([tuple(data[at + c * depth:at + c * depth + 3]) for c in range(width)])
    return rows


def averaged(row):
    """Columns 256-511: the row averaged over 2, 4 ... 256 columns."""
    out = []
    for level in range(1, 9):
        span = 1 << level
        for i in range(WIDTH // span):
            chunk = row[i * span:(i + 1) * span]
            out.append(tuple(round(sum(c[k] for c in chunk) / span) for k in range(3)))
    return out + [out[-1]]


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
