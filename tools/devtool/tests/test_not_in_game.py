"""Every editable field the game never reads carries a "not in the game yet" notice (data.NOT_IN_GAME),
and none the game reads does. A field counts as read when game code (src/, not its tests) names it
outside its own export line: another script, or its own file's to_spec(). A SHOWN_WHEN rule (which
fields the dev tool shows) is no read."""

import glob
import os
import re
import unittest

from devtool import data
from devtool.tasks import ROOT

TEMPLATE_SCRIPTS = ("database/definitions/*.gd", "src/scenes/game_world/sector_layout/markers/*.gd")
EXPORT = re.compile(r"^export[^\n]*?var\s+(\w+)", re.M)
SHOWN_WHEN = re.compile(r"^const SHOWN_WHEN = \{(?:[^\n]*\}$|.*?^\}$)", re.M | re.S)


def game_sources():
    out = {}
    for path in glob.glob(os.path.join(ROOT, "src", "**", "*.gd"), recursive=True) + glob.glob(os.path.join(ROOT, "database", "definitions", "*.gd")):
        if os.sep + "tests" + os.sep not in path:
            with open(path) as handle:
                out[path] = SHOWN_WHEN.sub("", handle.read())
    return out


def unread_fields():
    sources = game_sources()
    out = set()
    for pattern in TEMPLATE_SCRIPTS:
        for script in glob.glob(os.path.join(ROOT, pattern)):
            own = sources.get(script) or SHOWN_WHEN.sub("", open(script).read())
            for name in EXPORT.findall(own):
                word = re.compile(r"\b%s\b" % re.escape(name))
                in_own = [line for line in own.split("\n") if word.search(line) and not line.lstrip().startswith(("export", "#"))]
                elsewhere = any(word.search(text) for path, text in sources.items() if path != script)
                if not in_own and not elsewhere:
                    out.add((os.path.basename(script), name))
    return out


class NotInGameTest(unittest.TestCase):
    def test_every_unread_field_has_a_notice_and_no_read_one_does(self):
        unread = unread_fields()
        marked = set(data.NOT_IN_GAME)
        self.assertEqual(sorted(unread - marked), [], "Unread by the game: add a notice to data.NOT_IN_GAME")
        self.assertEqual(sorted(marked - unread), [], "The game reads these now: take their notice out of data.NOT_IN_GAME")

    def test_notices_are_found_by_path_or_name(self):
        self.assertTrue(data.not_in_game("res://database/definitions/location_template.gd", "danger_level"))
        self.assertEqual(data.not_in_game("res://database/definitions/location_template.gd", "connections"), "")


if __name__ == "__main__":
    unittest.main()
