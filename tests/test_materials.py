"""E1 and E2 at the file seam: the material and slot mask a PLT part needs
before a script can colour one of its layers, or clear it."""

import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
TOOL = REPO / "tools" / "rgb_materials.py"

CLOTH1 = 4


def write_plt(path, pixels, width, height):
    """A PLT V1 file: (intensity, layer) per pixel."""
    body = bytes(b for px in pixels for b in px)
    path.write_bytes(b"PLT V1  " + bytes(8) + struct.pack("<II", width, height) + body)


def read_tga(path):
    data = path.read_bytes()
    width, height = struct.unpack("<HH", data[12:16])
    return width, height, data[18:]


class MaterialTest(unittest.TestCase):
    def build(self, pixels, width, height, name="pmh0_chest007"):
        tmp = pathlib.Path(tempfile.mkdtemp())
        src, out = tmp / "in", tmp / "out"
        src.mkdir()
        write_plt(src / f"{name}.plt", pixels, width, height)
        result = subprocess.run([sys.executable, str(TOOL), str(src), "--out", str(out)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out

    def test_the_mask_keeps_each_texel_layer_and_intensity(self):
        out = self.build([(200, CLOTH1), (90, 0)], 2, 1)
        width, height, body = read_tga(out / "pmh0_chest007_m.tga")
        self.assertEqual((width, height), (2, 1))
        # BGR: red is the intensity, green the layer * 16.
        self.assertEqual(body[0:3], bytes((0, CLOTH1 * 16, 200)))
        self.assertEqual(body[3:6], bytes((0, 0, 90)))

    def test_the_mask_is_never_mipmapped(self):
        out = self.build([(1, 0)], 1, 1)
        self.assertIn("mipmap 0", (out / "pmh0_chest007_m.txi").read_text())

    def test_the_material_draws_with_the_rgb_shader_and_binds_the_mask(self):
        mtr = (self.build([(1, 0)], 1, 1) / "pmh0_chest007.mtr").read_text().splitlines()
        self.assertIn("customshaderfs fs_rgbpart", mtr)
        self.assertIn("texture6 pmh0_chest007_m", mtr)

    def test_every_channel_starts_off(self):
        mtr = (self.build([(1, 0)], 1, 1) / "pmh0_chest007.mtr").read_text().splitlines()
        for slot in range(12):
            self.assertIn(f"parameter float rgbC{slot} -1", mtr)

    def test_a_file_that_is_not_a_plt_is_refused(self):
        tmp = pathlib.Path(tempfile.mkdtemp())
        (tmp / "bad.plt").write_bytes(b"NOPE" + bytes(30))
        result = subprocess.run([sys.executable, str(TOOL), str(tmp), "--out", str(tmp / "o")],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bad.plt", result.stderr)


if __name__ == "__main__":
    unittest.main()
