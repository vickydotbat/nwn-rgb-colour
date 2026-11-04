"""E7 at the file seam: the palette atlas holds every stock palette row, so a
channel set to a preset reads the same colours stock PLT colour does.
E8 (a free RGB colour keeps the part's shading) is a live check only."""

import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
TOOL = REPO / "tools" / "rgb_atlas.py"
sys.path.insert(0, str(REPO / "tools"))
import rgb_materials  # noqa: E402

PALETTES = ["skin", "hair", "armor", "cloth", "leath", "tattoo"]
ROWS = 176


def write_palette(path, seed):
    """A stock-shaped palette: 256 x 176, 32-bit BGRA, rows stored bottom first."""
    body = bytearray()
    for row in range(ROWS):
        for col in range(256):
            body += bytes(((seed + col) % 256, row % 256, (seed * 7 + row + col) % 256, 255))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 256, ROWS, 32, 8)
    path.write_bytes(header + bytes(body))


def stored_row(path, row):
    data = path.read_bytes()
    width = struct.unpack("<H", data[12:14])[0]
    depth = data[16] // 8
    start = 18 + row * width * depth
    return [tuple(data[start + i * depth:start + i * depth + 3]) for i in range(width)]


class AtlasTest(unittest.TestCase):
    def build(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        for i, name in enumerate(PALETTES):
            write_palette(tmp / f"pal_{name}01.tga", seed=i * 40)
        out = tmp / "out"
        result = subprocess.run([sys.executable, str(TOOL), str(tmp), "--out", str(out)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return tmp, out

    def test_E7_cloth_preset_23_reads_stock_cloth_colour_23(self):
        src, out = self.build()
        cloth_base = PALETTES.index("cloth") * ROWS
        atlas = stored_row(out / "rgb_atlas.tga", cloth_base + 23)
        self.assertEqual(atlas[:256], stored_row(src / "pal_cloth01.tga", 23))

    def test_the_atlas_holds_every_row_of_every_palette(self):
        _, out = self.build()
        data = (out / "rgb_atlas.tga").read_bytes()
        self.assertEqual(struct.unpack("<HH", data[12:16]), (512, len(PALETTES) * ROWS))

    def test_far_columns_hold_each_row_averaged(self):
        src, out = self.build()
        row = stored_row(src / "pal_hair01.tga", 5)
        atlas = stored_row(out / "rgb_atlas.tga", ROWS + 5)
        # Column 256 averages columns 0 and 1; column 510 averages the row.
        pair = tuple(round((a + b) / 2) for a, b in zip(row[0], row[1]))
        whole = tuple(round(sum(c[i] for c in row) / 256) for i in range(3))
        self.assertEqual(atlas[256], pair)
        self.assertEqual(atlas[510], whole)

    def test_the_atlas_is_never_filtered_or_shrunk(self):
        _, out = self.build()
        txi = (out / "rgb_atlas.txi").read_text().splitlines()
        for line in ("mipmap 0", "filter 0", "downsamplemax 0"):
            self.assertIn(line, txi)

    def test_every_part_material_binds_the_atlas(self):
        self.assertIn("texture8 rgb_atlas", rgb_materials.material("pmh0_chest001").splitlines())


if __name__ == "__main__":
    unittest.main()
