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


def colour_row(path, colour):
    """Colour c of a stock palette: the c-th line from the top as a viewer
    shows it. The palette stores its bottom line first."""
    return stored_row(path, ROWS - 1 - colour)


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
        self.assertEqual(atlas[:256], colour_row(src / "pal_cloth01.tga", 23))

    def test_the_atlas_holds_every_row_of_every_palette(self):
        _, out = self.build()
        data = (out / "rgb_atlas.tga").read_bytes()
        self.assertEqual(struct.unpack("<HH", data[12:16]), (512, len(PALETTES) * ROWS))

    def test_far_columns_hold_each_row_averaged(self):
        src, out = self.build()
        row = colour_row(src / "pal_hair01.tga", 5)
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

    def test_a_compressed_palette_is_refused_by_name(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        for i, name in enumerate(PALETTES):
            write_palette(tmp / f"pal_{name}01.tga", seed=i)
        data = bytearray((tmp / "pal_cloth01.tga").read_bytes())
        data[2] = 10
        (tmp / "pal_cloth01.tga").write_bytes(bytes(data))
        result = subprocess.run([sys.executable, str(TOOL), str(tmp), "--out", str(tmp / "o")],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pal_cloth01.tga", result.stderr)

    def test_a_palette_with_an_id_field_reads_from_after_it(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        for i, name in enumerate(PALETTES):
            write_palette(tmp / f"pal_{name}01.tga", seed=i * 40)
        plain = colour_row(tmp / "pal_skin01.tga", 0)
        data = bytearray((tmp / "pal_skin01.tga").read_bytes())
        data[0] = 4
        (tmp / "pal_skin01.tga").write_bytes(bytes(data[:18]) + b"abcd" + bytes(data[18:]))
        subprocess.run([sys.executable, str(TOOL), str(tmp), "--out", str(tmp / "o")], check=True,
                       capture_output=True)
        self.assertEqual(stored_row(tmp / "o" / "rgb_atlas.tga", 0)[:256], plain)

    def test_each_stock_grid_cell_shows_its_palette_row(self):
        src, out = self.build()
        grid = out / "gridv_cloth01.tga"
        data = grid.read_bytes()
        width, height = struct.unpack("<HH", data[12:14] + data[14:16])
        self.assertEqual((width, height), (288, 143))
        # Colour 23 is cell (column 7, row 1): 18 x 13 points each, drawn
        # top down. The file stores its bottom line first.
        colour, x, y = 23, 7 * 18 + 9, 1 * 13 + 6
        line = height - 1 - y
        pixel = tuple(data[18 + (line * width + x) * 3:18 + (line * width + x) * 3 + 3])
        self.assertEqual(pixel, colour_row(src / "pal_cloth01.tga", colour)[188])

    def test_there_is_a_grid_for_each_palette_a_channel_uses(self):
        _, out = self.build()
        for name in ("gridv_armor01", "gridv_cloth01", "gridv_leath01"):
            self.assertTrue((out / f"{name}.tga").exists(), name)

    def test_a_palette_stored_top_line_first_reads_colour_0_from_its_first_line(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        for i, name in enumerate(PALETTES):
            write_palette(tmp / f"pal_{name}01.tga", seed=i * 40)
        data = bytearray((tmp / "pal_skin01.tga").read_bytes())
        data[17] |= 0x20
        (tmp / "pal_skin01.tga").write_bytes(bytes(data))
        subprocess.run([sys.executable, str(TOOL), str(tmp), "--out", str(tmp / "o")], check=True,
                       capture_output=True)
        self.assertEqual(stored_row(tmp / "o" / "rgb_atlas.tga", 0)[:256], stored_row(tmp / "pal_skin01.tga", 0))

    def test_every_part_material_binds_the_atlas(self):
        self.assertIn("texture8 rgb_atlas", rgb_materials.material("pmh0_chest001").splitlines())


if __name__ == "__main__":
    unittest.main()
