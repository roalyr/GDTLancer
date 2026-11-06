"""Constants.gd as data: the real file parses, and a value changes in place with nothing else."""

import os
import unittest

from devtool import constants
from devtool.tasks import ROOT

SAMPLE = '''extends Node

const TOP = false


# =====
# FLIGHT
# =====

# Drag, damping per second.
const LINEAR_DRAG = 0.5  # 1/s
const NAME: String = "a # not a comment"  # The name
const COUNT: int = 3
const SPAN = [  # Two ends
\t1.0, 2.0,  # Inner
\t[3, 4],
]
const DOUBLE = LINEAR_DRAG * 2.0
'''


class ConstantsTest(unittest.TestCase):
    def test_sections_comments_and_kinds(self):
        entries = {entry.name: entry for entry in constants.parse(SAMPLE)}
        self.assertEqual(list(entries), ["TOP", "LINEAR_DRAG", "NAME", "COUNT", "SPAN", "DOUBLE"])
        self.assertEqual(entries["TOP"].section, "(top)")
        self.assertEqual(entries["LINEAR_DRAG"].section, "FLIGHT")
        self.assertEqual(entries["LINEAR_DRAG"].doc, ["Drag, damping per second."])
        self.assertEqual(entries["LINEAR_DRAG"].comment, "1/s")
        self.assertEqual(entries["NAME"].value, '"a # not a comment"', "A # in a string is not a comment")
        self.assertEqual(entries["NAME"].comment, "The name")
        self.assertEqual(entries["COUNT"].annotation, "int")
        self.assertTrue(entries["SPAN"].multiline())
        self.assertEqual(entries["SPAN"].family, "Array")
        self.assertEqual(entries["DOUBLE"].family, "expression")
        self.assertEqual([entries[n].family for n in ("TOP", "LINEAR_DRAG", "NAME", "COUNT")], ["bool", "float", "String", "int"])

    def test_a_value_changes_in_place(self):
        entries = {entry.name: entry for entry in constants.parse(SAMPLE)}
        changed = constants.set_value(SAMPLE, entries["LINEAR_DRAG"], "0.75")
        self.assertIn("const LINEAR_DRAG = 0.75  # 1/s\n", changed)
        self.assertEqual(changed.replace("0.75", "0.5", 1), SAMPLE, "Nothing else changed")
        spans = constants.set_value(SAMPLE, entries["SPAN"], "[1.0, 2.0]")
        self.assertIn("const SPAN = [1.0, 2.0]\nconst DOUBLE", spans)

    def test_values_keep_their_kind(self):
        entries = {entry.name: entry for entry in constants.parse(SAMPLE)}
        self.assertEqual(constants.check_value(entries["LINEAR_DRAG"], "2"), "", "A number stays a number")
        self.assertNotEqual(constants.check_value(entries["COUNT"], "2.5"), "", "Declared int")
        self.assertNotEqual(constants.check_value(entries["NAME"], "[1]"), "")
        self.assertEqual(constants.check_value(entries["DOUBLE"], "3.0"), "", "An expression may become anything")
        self.assertNotEqual(constants.check_value(entries["TOP"], ""), "")

    def test_the_real_file_parses_and_round_trips(self):
        with open(os.path.join(ROOT, constants.PATH)) as handle:
            text = handle.read()
        entries = constants.parse(text)
        declared = [line for line in text.split("\n") if line.startswith("const ")]
        self.assertEqual(len(entries), len(declared), "Every const found")
        self.assertGreater(len(constants.sections(entries)), 10)
        for entry in entries:
            self.assertEqual(constants.set_value(text, entry, entry.value), text, entry.name)
