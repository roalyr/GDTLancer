"""The bridge against the real Godot (skipped when GODOT is not there, or DEVTOOL_NO_GODOT is set)."""

import os
import shutil
import unittest

from devtool import tasks
from devtool.bridge import Bridge, BridgeError, res_path


@unittest.skipIf(os.environ.get("DEVTOOL_NO_GODOT") or not shutil.which(tasks.GODOT), "no Godot")
class LiveBridgeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = Bridge()

    @classmethod
    def tearDownClass(cls):
        cls.bridge.close()

    def test_reads_a_faction_with_its_schema(self):
        read = self.bridge.call("read", path="res://database/factions/verdant.tres")
        self.assertEqual(read["class"], "FactionTemplate")
        self.assertEqual(read["values"]["template_id"], "verdant")
        names = [field["name"] for field in self.bridge.call("schema", path=read["path"])["fields"]]
        self.assertIn("roster", names)

    def test_floats_arrive_whole(self):
        read = self.bridge.call("read", path="res://database/registry/tools/tool_ablative_laser_long_range.tres")
        self.assertEqual(read["values"]["tracking"], 0.0707107)

    def test_errors_come_back_as_errors(self):
        with self.assertRaises(BridgeError):
            self.bridge.call("no_such_command")
        with self.assertRaises(BridgeError):
            self.bridge.call("read", path="res://nothing.tres")

    def test_the_content_holds(self):
        self.assertEqual(self.bridge.call("validate", section="factions"), [])
        sections = self.bridge.call("validate", sections=True)
        self.assertEqual(sections[-1], "models", "The slow one last")
        self.assertTrue({"factions", "locations", "sectors", "starts"} <= set(sections), sections)

    def test_godot_checks_constants_before_they_are_saved(self):
        from devtool import constants
        with open(os.path.join(tasks.ROOT, constants.PATH)) as handle:
            text = handle.read()
        entry = next(e for e in constants.parse(text) if e.name == "LINEAR_DRAG")
        self.assertTrue(self.bridge.call("check_script", source=constants.set_value(text, entry, "0.75"))["ok"])
        self.assertFalse(self.bridge.call("check_script", source=constants.set_value(text, entry, "0.75 +"))["ok"])

    def test_paths(self):
        self.assertEqual(res_path("database/factions/verdant.tres"), "res://database/factions/verdant.tres")


if __name__ == "__main__":
    unittest.main()
