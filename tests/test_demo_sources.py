"""The demo module is written from scratch: it carries only fields it sets
itself, and nothing from a stock module (an intro movie, IDs, areas)."""

import json
import pathlib
import unittest

SRC = pathlib.Path(__file__).resolve().parent.parent / "demo" / "src"


def load(name):
    return json.loads((SRC / name).read_text())


class DemoSourcesTest(unittest.TestCase):
    def test_the_module_plays_no_intro_movie(self):
        ifo = load("module.ifo.json")
        self.assertNotIn("Mod_StartMovie", ifo)

    def test_the_module_holds_only_the_fields_it_sets(self):
        ifo = load("module.ifo.json")
        fields = {k for k in ifo if not k.startswith("__")}
        self.assertEqual(fields, {
            "Mod_Area_list", "Mod_Entry_Area", "Mod_Entry_X", "Mod_Entry_Y", "Mod_Entry_Z",
            "Mod_Entry_Dir_X", "Mod_Entry_Dir_Y", "Mod_Name", "Mod_Description", "Mod_Tag",
            "Mod_HakList", "Mod_MinGameVer", "Mod_OnClientEntr", "Mod_OnPlrEqItm", "Mod_OnPlrUnEqItm",
            "Mod_XPScale",
        })

    def test_every_area_the_module_names_is_its_own(self):
        ifo = load("module.ifo.json")
        areas = [a["Area_Name"]["value"] for a in ifo["Mod_Area_list"]["value"]]
        self.assertEqual(areas, ["rgbdemo"])
        for area in areas:
            self.assertTrue((SRC / f"{area}.are.json").exists())

    def test_the_area_keeps_no_stock_scripts_or_comments(self):
        are = load("rgbdemo.are.json")
        for key in ("OnEnter", "OnExit", "OnHeartbeat", "OnUserDefined", "Comments", "ID", "Creator_ID"):
            self.assertNotIn(key, are)


    def test_E9_to_E11_colours_reapply_on_entry_and_follow_the_item(self):
        ifo = load("module.ifo.json")
        scripts = SRC.parent / "scripts"
        for field, script in (("Mod_OnClientEntr", "rgb_enter"), ("Mod_OnPlrEqItm", "rgb_equip"),
                              ("Mod_OnPlrUnEqItm", "rgb_unequip")):
            self.assertEqual(ifo[field]["value"], script)
            self.assertIn("RgbApply", (scripts / f"{script}.nss").read_text())


if __name__ == "__main__":
    unittest.main()
