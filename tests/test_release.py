"""E20 at the file seam: the release zip holds the demo module, the hak with
every built part file in it, a short readme and the census. Publishing the
zip to the GitHub Release and the Vault is the maintainer's step."""

import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
PACK = REPO / "tools" / "pack_release.sh"


@unittest.skipUnless(shutil.which("nwn_erf"), "nwn_erf comes with the dev shell")
class ReleaseTest(unittest.TestCase):
    def pack(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        override = tmp / "override"
        override.mkdir()
        for name in ("pmh0_chest001.mtr", "pmh0_chest001_m.tga", "rgb_atlas.tga", "fs_rgbpart.shd", "rgb_parts.txt"):
            (override / name).write_bytes(b"x")
        (override / "census.txt").write_text("pmh0_robe001: robes keep their stock PLT colours\n")
        mod = tmp / "rgbdemo.mod"
        mod.write_bytes(b"MOD V1.0")
        out = tmp / "dist"
        result = subprocess.run([str(PACK), str(override), str(mod), str(out)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out / "nwn-rgb-colour.zip", tmp

    def test_E20_one_zip_holds_the_module_the_hak_a_readme_and_the_census(self):
        archive, _ = self.pack()
        names = set(zipfile.ZipFile(archive).namelist())
        self.assertLessEqual({"hak/rgbcolour.hak", "modules/rgbdemo.mod", "README.txt", "census.txt"}, names)

    def test_the_hak_holds_every_built_file_but_the_census(self):
        archive, tmp = self.pack()
        zipfile.ZipFile(archive).extract("hak/rgbcolour.hak", tmp)
        listing = subprocess.run(["nwn_erf", "-f", str(tmp / "hak" / "rgbcolour.hak"), "-t"],
                                 capture_output=True, text=True, check=True).stdout.split()
        for name in ("pmh0_chest001.mtr", "pmh0_chest001_m.tga", "rgb_atlas.tga", "fs_rgbpart.shd", "rgb_parts.txt"):
            self.assertIn(name, listing)
        self.assertNotIn("census.txt", listing)


class DemoHakTest(unittest.TestCase):
    def test_E21_the_demo_module_loads_the_hak(self):
        ifo = json.loads((REPO / "demo" / "src" / "module.ifo.json").read_text())
        haks = [h["Mod_Hak"]["value"] for h in ifo["Mod_HakList"]["value"]]
        self.assertEqual(haks, ["rgbcolour"])


if __name__ == "__main__":
    unittest.main()
