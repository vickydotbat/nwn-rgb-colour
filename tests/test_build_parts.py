"""E3 to E6 at the file seam: the build turns worn part models and their PLTs
into RGB-ready parts, and reports every part it skipped in a census."""

import json
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


def binary_model(name, bitmap, flags=0x21):
    """A compiled model: headers, then one node whose content flags sit 76
    bytes past its name and whose bitmap field sits 200 past it."""
    node = bytearray(f"{name}g".encode().ljust(264, b"\0"))
    node[76:80] = struct.pack("<I", flags)
    node[200:200 + len(bitmap) + 1] = bitmap.encode() + b"\0"
    return bytes(12) + name.encode().ljust(300, b"\xff") + bytes(node)


class BuildTest(unittest.TestCase):
    def run_in(self, setup):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        setup(tmp)
        out = tmp / "out"
        subprocess.run([sys.executable, str(BUILD), str(tmp), str(tmp), "--out", str(out)], check=True,
                       capture_output=True)
        return out

    def test_a_bitmap_field_outside_a_mesh_node_is_not_read(self):
        def setup(tmp):
            (tmp / "pmh0_chest001.mdl").write_bytes(binary_model("pmh0_chest001", "pmh0_chest001", flags=0x1))
            write_plt(tmp / "pmh0_chest001.plt")
        out = self.run_in(setup)
        self.assertFalse((out / "pmh0_chest001.mtr").exists())
        self.assertIn("pmh0_chest001", (out / "census.txt").read_text())

    def test_the_part_named_like_the_bitmap_keeps_it(self):
        out = self.run_build({"pmh0_shinl005": "pmh0_shinr005", "pmh0_shinr005": "pmh0_shinr005"},
                             ["pmh0_shinr005"])
        self.assertIn("bitmap pmh0_shinl005", (out / "pmh0_shinl005.mdl").read_text())
        self.assertFalse((out / "pmh0_shinr005.mdl").exists())

    def test_a_compiled_part_whose_name_cannot_fit_is_named_in_the_census(self):
        def setup(tmp):
            for side in "lr":
                (tmp / f"pmh0_shin{side}001.mdl").write_bytes(binary_model(f"pmh0_shin{side}001", "shinplt"))
            write_plt(tmp / "shinplt.plt")
        out = self.run_in(setup)
        self.assertFalse((out / "pmh0_shinr001.mdl").exists())
        self.assertIn("pmh0_shinr001: shares shinplt", (out / "census.txt").read_text())

    def test_a_null_bitmap_beside_a_real_one_is_ignored(self):
        def setup(tmp):
            (tmp / "pmh0_chest001.mdl").write_text(
                "newmodel pmh0_chest001\nnode trimesh a\n  bitmap NULL\nendnode\n"
                "node trimesh b\n  bitmap pmh0_chest001\nendnode\ndonemodel pmh0_chest001\n")
            write_plt(tmp / "pmh0_chest001.plt")
        out = self.run_in(setup)
        self.assertTrue((out / "pmh0_chest001.mtr").exists())

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
        self.assertTrue((out / "pmh0_shinl001.mtr").exists())

    def test_E5_a_robe_gets_no_material_and_the_census_says_why(self):
        out = self.run_build({"pmh0_robe001": "pmh0_robe001"}, ["pmh0_robe001"])
        self.assertFalse((out / "pmh0_robe001.mtr").exists())
        census = (out / "census.txt").read_text()
        self.assertIn("pmh0_robe001", census)
        self.assertIn("robes keep their stock PLT colours", census)

    def test_a_model_that_is_not_a_worn_part_is_left_out(self):
        out = self.run_build({"c_goblin": "c_goblin"}, ["c_goblin"])
        self.assertFalse((out / "c_goblin.mtr").exists())
        self.assertNotIn("c_goblin", (out / "census.txt").read_text())

    def test_a_part_naming_no_bitmap_is_named_in_the_census(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        (tmp / "pmh0_belt001.mdl").write_text("newmodel pmh0_belt001\ndonemodel pmh0_belt001\n")
        out = tmp / "out"
        subprocess.run([sys.executable, str(BUILD), str(tmp), str(tmp), "--out", str(out)], check=True,
                       capture_output=True)
        self.assertIn("pmh0_belt001", (out / "census.txt").read_text())

    def test_the_mask_is_never_mipmapped(self):
        out = self.run_build({"pmh0_chest001": "pmh0_chest001"}, ["pmh0_chest001"])
        self.assertIn("mipmap 0", (out / "pmh0_chest001_m.txi").read_text())

    def test_a_binary_right_limb_drawing_the_left_bitmap_names_itself(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        # A compiled model: headers, then a mesh node whose content flags
        # sit 76 bytes past its name and whose bitmap field sits 200 past it.
        node = bytearray(b"pmh0_shinr001g\0".ljust(264, b"\0"))
        node[76:80] = struct.pack("<I", 0x21)
        node[200:214] = b"pmh0_shinl001\0"
        model = bytes(12) + b"pmh0_shinr001\0".ljust(300, b"\xff") + bytes(node)
        (tmp / "pmh0_shinr001.mdl").write_bytes(model)
        write_model(tmp / "pmh0_shinl001.mdl", "pmh0_shinl001")
        write_plt(tmp / "pmh0_shinl001.plt")
        out = tmp / "out"
        subprocess.run([sys.executable, str(BUILD), str(tmp), str(tmp), "--out", str(out)], check=True,
                       capture_output=True)
        built = (out / "pmh0_shinr001.mdl").read_bytes()
        self.assertEqual(len(built), len(model))
        self.assertNotIn(b"pmh0_shinl001", built)
        self.assertTrue((out / "pmh0_shinr001.mtr").exists())

    def test_a_part_drawing_another_bodys_plt_shares_its_material(self):
        out = self.run_build({"pmh0_chest001": "pmh0_chest001", "pmd0_chest001": "pmh0_chest001"},
                             ["pmh0_chest001"])
        self.assertFalse((out / "pmd0_chest001.mdl").exists())
        self.assertFalse((out / "pmd0_chest001.mtr").exists())
        lookup = json.loads((out / "rgb_parts.txt").read_text())
        self.assertEqual(lookup["pmd0_chest001"], "pmh0_chest001")

    def test_a_split_part_with_no_plt_of_its_own_gets_a_copy(self):
        out = self.run_build({"pmh0_shinl002": "pmh0_shinl002", "pmh0_shinr002": "pmh0_shinl002"},
                             ["pmh0_shinl002"])
        self.assertTrue((out / "pmh0_shinr002.plt").exists())
        # The copy draws the same PLT, so it reads the same mask.
        self.assertIn("texture6 pmh0_shinl002_m", (out / "pmh0_shinr002.mtr").read_text())
        self.assertFalse((out / "pmh0_shinr002_m.tga").exists())

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
