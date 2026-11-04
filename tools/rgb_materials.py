#!/usr/bin/env python3
"""Give each PLT part a material for the RGB part shader and a slot mask.

A lit shader never sees a PLT's layers: the engine bakes the PLT into a plain
texture first. So each part gets a slot mask, a copy of its PLT a shader can
read (red = intensity, green = layer * 16), and a material named after the
part that draws it with fs_rgbpart and declares every channel off (-1).

Usage:
    tools/rgb_materials.py <folder of .plt files> --out <folder>
"""
import argparse
import struct
import sys
from pathlib import Path

# The shader has 12 slots: the 10 PLT layers and 2 accent slots.
SLOTS = 12
SLOT_STEP = 16
LAST_LAYER = 9


def read_plt(path):
    """-> (width, height, pixels): two bytes per pixel, intensity then layer."""
    data = path.read_bytes()
    if data[:8] != b"PLT V1  ":
        raise ValueError(f"{path.name}: not a PLT V1 file")
    width, height = struct.unpack("<II", data[16:24])
    pixels = data[24:]
    if len(pixels) != width * height * 2:
        raise ValueError(f"{path.name}: {width}x{height} needs {width * height * 2} pixel bytes, has {len(pixels)}")
    return width, height, pixels


def mask_tga(width, height, pixels):
    """A 24-bit TGA, rows in PLT order, which is the order the engine reads a TGA."""
    body = bytearray()
    for i in range(0, len(pixels), 2):
        intensity, layer = pixels[i], min(pixels[i + 1], LAST_LAYER)
        body += bytes((0, layer * SLOT_STEP, intensity))
    return struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 24, 0) + bytes(body)


def material(part):
    lines = [
        "customshadervs vslit",
        "customshaderfs fs_rgbpart",
        "transparency 1",
        f"texture6 {part}_m",
        "parameter float rgbDebug -1",
        "parameter float rgbAtlasMode -1",
        "parameter float rgbAtlasFlip -1",
        "parameter float rgbO -1",
        "parameter float rgbOA -1",
        "parameter float rgbSmooth 1",
    ]
    lines += [f"parameter float rgb{kind}{n} -1" for n in range(SLOTS) for kind in "CSRXGP"]
    return "\n".join(lines) + "\n"


def build(src, out):
    out.mkdir(parents=True, exist_ok=True)
    for plt in sorted(src.glob("*.plt")):
        part = plt.stem.lower()
        width, height, pixels = read_plt(plt)
        (out / f"{part}_m.tga").write_bytes(mask_tga(width, height, pixels))
        # A slot id is a category: filtering or mipmapping it mixes slots.
        (out / f"{part}_m.txi").write_text("mipmap 0\n")
        (out / f"{part}.mtr").write_text(material(part))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("src", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        build(args.src, args.out)
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
