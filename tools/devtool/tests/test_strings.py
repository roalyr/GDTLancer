"""The Strings tab's file logic (strings.py) on the real file and on a scratch copy."""

import json
import os
import tempfile
import unittest

from devtool import strings


class StringsFileTest(unittest.TestCase):
    def test_the_real_file_has_every_language_and_no_problems(self):
        table = strings.load()
        self.assertGreater(len(table), 100)
        self.assertEqual(strings.problems(table, strings.used_keys()), [], "Every key filled and matching, every used key there")

    def test_problems_name_the_empty_and_the_mismatched(self):
        table = {"a.ok": {"en": "%d WP", "uk": "%d WP"}, "a.empty": {"en": "Text", "uk": ""},
                 "a.mismatch": {"en": "%s of %d", "uk": "%s"}, "a.percent": {"en": "%d%%", "uk": "%d %%"}}
        found = strings.problems(table, {"a.ok": "x.gd", "a.gone": "y.gd"})
        self.assertIn(("a.empty", "no uk"), found)
        self.assertIn(("a.mismatch", "placeholders differ in uk"), found)
        self.assertIn(("a.gone", "missing: used in y.gd"), found)
        self.assertNotIn("a.ok", [key for key, _ in found])
        self.assertNotIn("a.percent", [key for key, _ in found], "A literal %% is no placeholder")

    def test_saved_sorted_and_read_back(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "strings.json")
            strings.save({"b.x": {"en": "B", "uk": "Б"}, "a.x": {"en": "A", "uk": "А"}}, path)
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
            self.assertLess(text.index("a.x"), text.index("b.x"))
            self.assertIn("Б", text, "Written as letters, not escapes")
            self.assertEqual(json.loads(text)["b.x"]["uk"], "Б")
            self.assertEqual(strings.load(path)["a.x"]["en"], "A")

    def test_keys(self):
        self.assertTrue(strings.valid_key("hud.button.dock"))
        for bad in ["dock", "Hud.dock", "hud..dock", "hud.dock.", "hud dock.x"]:
            self.assertFalse(strings.valid_key(bad), bad)


if __name__ == "__main__":
    unittest.main()
