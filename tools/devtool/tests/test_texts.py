"""Words that drift: the number of designs the tool's texts and CONTENT.md name must be the number
of archetypes there are."""

import glob
import os
import re
import unittest

from devtool import data, tasks

NUMBERS = {"ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16,
           "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20, "twenty-one": 21, "twenty-two": 22,
           "twenty-three": 23, "twenty-four": 24, "twenty-five": 25}
COUNT = re.compile(r"\b(%s|\d+)\s+(?:ship\s+)?(?:designs|hulls)\b" % "|".join(sorted(NUMBERS, key=len, reverse=True)), re.I)


class TextsTest(unittest.TestCase):
    def test_design_counts_match_the_archetypes(self):
        count = len(glob.glob(os.path.join(tasks.ROOT, data.ARCHETYPES, "preset_ship_archetype_*.tres")))
        self.assertGreater(count, 0)
        texts = {"data.KINDS": " ".join(kind.about for kind in data.KINDS)}
        for name in ("CONTENT.md", "tools/devtool/app.py"):
            with open(os.path.join(tasks.ROOT, name)) as handle:
                texts[name] = handle.read()
        for name, text in texts.items():
            for match in COUNT.finditer(text):
                word = match.group(1).lower()
                self.assertEqual(NUMBERS.get(word, int(word) if word.isdigit() else -1), count,
                                 "%s says '%s'; there are %d archetypes" % (name, match.group(0), count))


if __name__ == "__main__":
    unittest.main()
