"""Staging a demo build leaves the development folder holding exactly what
this build makes, plus anything that was never ours."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
STAGE = REPO / "tools" / "stage_demo.sh"


@unittest.skipUnless(shutil.which("nwn_erf") and shutil.which("unzip"), "the dev shell has nwn_erf and unzip")
class StageTest(unittest.TestCase):
    def stage(self, build, user, files):
        override = build / "override"
        shutil.rmtree(override, ignore_errors=True)
        override.mkdir(parents=True)
        for name in files:
            (override / name).write_bytes(b"x")
        (override / "census.txt").write_text("")
        (build / "rgbdemo.mod").write_bytes(b"MOD V1.0")
        subprocess.run([str(STAGE), str(build), str(user)], check=True, capture_output=True)

    def test_a_file_the_last_build_staged_and_this_one_does_not_make_is_removed(self):
        holder = tempfile.TemporaryDirectory()
        self.addCleanup(holder.cleanup)
        tmp = pathlib.Path(holder.name)
        build, user = tmp / "build", tmp / "user"
        (user / "development").mkdir(parents=True)
        (user / "development" / "someone_else.2da").write_text("theirs")
        self.stage(build, user, ["pmh0_chest001.mtr", "pmh0_chest001_m.txi"])
        self.stage(build, user, ["pmh0_chest001.mtr"])
        development = user / "development"
        self.assertTrue((development / "pmh0_chest001.mtr").exists())
        self.assertFalse((development / "pmh0_chest001_m.txi").exists())
        self.assertEqual((development / "someone_else.2da").read_text(), "theirs")


if __name__ == "__main__":
    unittest.main()
