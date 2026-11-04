#!/usr/bin/env python3
"""Turn worn part models and their PLTs into RGB-ready parts.

A part's material is named after the bitmap its model draws, so each PLT gets
one material and one slot mask. Many race and phenotype models draw another
body's PLT. They share its material safely, because a creature wears one body
and shader values belong to the creature.

Two parts of one body that draw the same bitmap would colour together, as
when a stock right shin draws the left shin's PLT. The build gives each such
part a model copy that names itself, and a PLT of its own when it lacks one.

rgb_parts.txt maps every part whose material is not its own name to that
material, as JSON, for the scripts. census.txt lists each part it skipped.

Models may be ASCII or compiled. A compiled model is read and renamed in
place, which works for names of the same length, as left and right are.

Usage:
    tools/rgb_build.py <models folder> <plt folder> --out <folder>
"""
import argparse
import json
import re
import shutil
import struct
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rgb_materials  # noqa: E402

PART = re.compile(r"^p[mf][a-z]\d_(belt|bicep[lr]|chest|foot[lr]|fore[lr]|hand[lr]"
                  r"|leg[lr]|neck|pelvis|robe|shin[lr]|sho[lr])\d{3}$")
BITMAP = re.compile(r"^(\s*bitmap\s+)(\S+)", re.MULTILINE)

# A compiled model opens with its file and model headers. Nodes come after.
HEADER = 240
NAME = re.compile(rb"([A-Za-z0-9_]{3,})\0")
# Offsets from a node's name: its content flags, and a mesh's bitmap field.
FLAGS_AT, BITMAP_AT, FIELD = 76, 200, 64
MESH = 0x20


def binary_bitmaps(data):
    """The bitmaps a compiled model's mesh nodes name."""
    found = set()
    for m in NAME.finditer(data, HEADER):
        at = m.start()
        if at + BITMAP_AT + FIELD > len(data):
            continue
        flags = struct.unpack_from("<I", data, at + FLAGS_AT)[0]
        # Real content flags stay under 0x1000, so a larger word is not a node.
        if flags & MESH and flags < 0x1000:
            name = data[at + BITMAP_AT:at + BITMAP_AT + FIELD].split(b"\0")[0]
            if re.fullmatch(rb"[A-Za-z0-9_]+", name):
                found.add(name.decode().lower())
    return found


def read_model(mdl, plts):
    """-> (data, text or None, bitmaps that have a PLT, other bitmaps)."""
    data = mdl.read_bytes()
    try:
        text = data.decode("ascii")
        names = {b.lower() for _, b in BITMAP.findall(text)}
    except UnicodeDecodeError:
        text = None
        names = binary_bitmaps(data)
    with_plt = {n for n in names if (plts / f"{n}.plt").exists()}
    return data, text, with_plt, names - with_plt


def rename(data, text, old, new):
    if text is not None:
        return BITMAP.sub(lambda m: m.group(1) + (new if m.group(2).lower() == old else m.group(2)),
                          text).encode()
    if len(old) != len(new):
        return None
    head, tail = data[:HEADER], data[HEADER:]
    return head + tail.replace(old.encode() + b"\0", new.encode() + b"\0")


def build(models, plts, out):
    out.mkdir(parents=True, exist_ok=True)
    census, parts = [], {}
    for mdl in sorted(models.glob("*.mdl")):
        part = mdl.stem.lower()
        match = PART.match(part)
        if not match:
            continue
        if match.group(1) == "robe":
            census.append(f"{part}: robes keep their stock PLT colours")
            continue
        data, text, with_plt, without = read_model(mdl, plts)
        if len(with_plt) != 1:
            names = sorted(with_plt | without)
            census.append(f"{part}: draws {', '.join(names) or 'no bitmap'}, the build needs one PLT")
            continue
        parts[part] = (mdl, data, text, with_plt.pop())

    # Parts of one body that draw one bitmap would colour together.
    users = defaultdict(list)
    for part, (_, _, _, bitmap) in parts.items():
        users[(part[:4], bitmap)].append(part)

    lookup, materials = {}, set()
    for (_, bitmap), group in sorted(users.items()):
        keep = bitmap if bitmap in group else group[0]
        for part in group:
            mdl, data, text, _ = parts[part]
            if part == keep:
                materials.add(bitmap)
                if part != bitmap:
                    lookup[part] = bitmap
                continue
            renamed = rename(data, text, bitmap, part)
            if renamed is None:
                census.append(f"{part}: shares {bitmap} on its body, thaw it with cleanmodels to split it")
                continue
            (out / mdl.name.lower()).write_bytes(renamed)
            own = plts / f"{part}.plt"
            if not own.exists():
                # The model now names itself, so a PLT must carry that name.
                shutil.copyfile(plts / f"{bitmap}.plt", out / f"{part}.plt")
                (out / f"{part}.mtr").write_text(rgb_materials.material(part, bitmap))
                materials.add(bitmap)
                continue
            rgb_materials.write_material(own, part, out)

    for material in sorted(materials):
        rgb_materials.write_material(plts / f"{material}.plt", material, out)
    (out / "rgb_parts.txt").write_text(json.dumps(lookup, indent=0, sort_keys=True) + "\n")
    (out / "census.txt").write_text("".join(line + "\n" for line in sorted(census)))
    return census


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("models", type=Path)
    parser.add_argument("plts", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        census = build(args.models, args.plts, args.out)
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    print(f"{len(census)} parts skipped, listed in {args.out / 'census.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
