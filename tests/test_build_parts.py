"""E3 to E6 at the file seam: the build turns worn part models and their PLTs
into RGB-ready parts, and reports every part it skipped in a census."""

import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
BUILD = REPO / "tools" / "rgb_build.py"


def write_plt(path, width=1, height=1):
    path.write_bytes(b"PLT V1  " + bytes(8) + struct.pack("<II", width, height) + bytes(2 * width * height))


def write_model(path, bitmap):
    """A minimal ASCII part model: one trimesh node naming its bitmap."""
    name = path.stem
    path.write_text(
        f"newmodel {name}\nsetsupermodel {name} NULL\nbeginmodelgeom {name}\n"
        f"node trimesh {name}g\n  parent {name}\n  bitmap {bitmap}\nendnode\n"
        f"endmodelgeom {name}\ndonemodel {name}\n")


class BuildTest(unittest.TestCase):
    def run_build(self, models, plts):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        mdl, plt, out = tmp / "mdl", tmp / "plt", tmp / "out"
        mdl.mkdir()
        plt.mkdir()
        for name, bitmap in models.items():
            write_model(mdl / f"{name}.mdl", bitmap)
        for name in plts:
            write_plt(plt / f"{name}.plt")
        result = subprocess.run([sys.executable, str(BUILD), str(mdl), str(plt), "--out", str(out)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out

    def test_E3_every_part_with_a_plt_gets_a_material_and_mask(self):
        out = self.run_build({"pmh0_chest001": "pmh0_chest001", "pfe0_bicepl002": "pfe0_bicepl002"},
                             ["pmh0_chest001", "pfe0_bicepl002"])
        for part in ("pmh0_chest001", "pfe0_bicepl002"):
            self.assertTrue((out / f"{part}.mtr").exists(), part)
            self.assertTrue((out / f"{part}_m.tga").exists(), part)

    def test_E3_a_part_with_no_plt_is_skipped_and_named_in_the_census(self):
        out = self.run_build({"pmh0_neck003": "pmh0_neck003"}, [])
        self.assertFalse((out / "pmh0_neck003.mtr").exists())
        self.assertIn("pmh0_neck003", (out / "census.txt").read_text())

    def test_E4_a_right_limb_drawing_the_left_bitmap_gets_its_own_model(self):
        out = self.run_build({"pmh0_shinl001": "pmh0_shinl001", "pmh0_shinr001": "pmh0_shinl001"},
                             ["pmh0_shinl001"])
        self.assertIn("bitmap pmh0_shinr001", (out / "pmh0_shinr001.mdl").read_text())
        self.assertTrue((out / "pmh0_shinr001.mtr").exists())
        self.assertTrue((out / "pmh0_shinr001_m.tga").exists())
        self.assertTrue((out / "pmh0_shinl001.mtr").exists())

    def test_E5_a_robe_gets_no_material_and_the_census_says_why(self):
        out = self.run_build({"pmh0_robe001": "pmh0_robe001"}, ["pmh0_robe001"])
        self.assertFalse((out / "pmh0_robe001.mtr").exists())
        census = (out / "census.txt").read_text()
        self.assertIn("pmh0_robe001", census)
        self.assertIn("robes keep their stock PLT colours", census)

    def test_E6_just_convert_writes_beside_the_builders_own_parts(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        folder = pathlib.Path(holder.name)
        write_plt(folder / "my_chest.plt")
        result = subprocess.run(["just", "convert", str(folder)], cwd=REPO, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((folder / "my_chest.mtr").exists())
        self.assertTrue((folder / "my_chest_m.tga").exists())


if __name__ == "__main__":
    unittest.main()
