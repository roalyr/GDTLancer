"""The sector map from above."""

import unittest

from devtool import worldmap


class WorldMapTest(unittest.TestCase):
    def test_bodies_and_markers_are_drawn_to_scale(self):
        items = [{"name": "Star", "kind": "star", "x": 0.0, "z": 0.0, "node": ""},
                 {"name": "Port", "kind": "haven_marker", "x": 10000.0, "z": 0.0, "node": "Havens/Port"},
                 {"name": "Field", "kind": "beacon_marker", "x": -10000.0, "z": 5000.0, "node": "Beacons/Field"}]
        lines = worldmap.render(items, width=21, height=11).split("\n")
        self.assertEqual(len(lines), 11 + 3, "Border, rows, border, legend")
        grid = [line[1:-1] for line in lines[1:-2]]
        self.assertEqual(grid[0].index("*"), 10, "The star in the middle column, at the top (z 0 of 0..5000)")
        self.assertEqual(grid[0].index("H"), 20, "The haven at the right edge")
        self.assertEqual(grid[-1].index("B"), 0, "The beacon at the bottom left")
        picked = worldmap.render(items, "Havens/Port", width=21, height=11)
        self.assertIn("[reverse bold]H[/]", picked)

    def test_nothing_to_draw(self):
        self.assertEqual(worldmap.render([]), "(nothing to draw)")
