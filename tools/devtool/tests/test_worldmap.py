"""The sector map from above: square cells, a grid in round km, rings, colours."""

import re
import unittest

from devtool import worldmap

PLAIN = re.compile(r"\[/?[^\]\\]*\]")


def plain(text):
    return PLAIN.sub("", text).replace("\\[", "[")


class WorldMapTest(unittest.TestCase):
    ITEMS = [{"name": "Star", "kind": "star", "x": 0.0, "z": 0.0, "node": ""},
             {"name": "Port", "kind": "haven_marker", "x": 10000.0, "z": 0.0, "node": "Havens/Port", "faction": "verdant", "radius": 0.0},
             {"name": "Field", "kind": "beacon_marker", "x": -10000.0, "z": 4000.0, "node": "Beacons/Field", "faction": "", "radius": 3000.0}]

    def grid(self, text):
        lines = plain(text).split("\n")
        return [line[worldmap.LABEL_WIDTH:worldmap.LABEL_WIDTH + 2 * 20] for line in lines[2:2 + 10]]

    def test_cells_are_two_characters_and_equal_metres_both_ways(self):
        text = worldmap.render(self.ITEMS, columns=20, rows=10)
        rows = self.grid(text)
        star = next((r, line.index("*")) for r, line in enumerate(rows) if "*" in line)
        port = next((r, line.index("H")) for r, line in enumerate(rows) if "H" in line)
        field = next((r, line.index("B")) for r, line in enumerate(rows) if "B" in line)
        self.assertEqual(star[0], port[0], "Same z, same row")
        self.assertEqual(star[1] % 2, 0, "Symbols start on a cell's first character")
        cells_across = (port[1] - star[1]) // 2
        cells_down = field[0] - star[0]
        self.assertEqual((cells_across, cells_down), (5, 2), "10 km across and 4 km down at 2 km a cell")
        self.assertIn("one cell 2 km", text)

    def test_a_grid_in_round_km_with_labels(self):
        text = plain(worldmap.render(self.ITEMS, columns=20, rows=10))
        self.assertIn("grid 10 km", text)
        self.assertIn("┼", text)
        header = text.split("\n")[0]
        for label in ("-10", "0", "10"):
            self.assertIn(label, header.split())

    def test_shared_cells_count_and_the_picked_one_shows(self):
        items = self.ITEMS + [{"name": "Near", "kind": "beacon_marker", "x": 10400.0, "z": 400.0, "node": "Beacons/Near", "faction": ""}]
        text = worldmap.render(items, columns=20, rows=10)
        self.assertIn("H2", plain(text), "The haven over the beacon, with the count")
        picked = worldmap.render(items, "Beacons/Near", columns=20, rows=10)
        self.assertIn("B2", plain(picked), "The picked one on top")
        self.assertIn("reverse", picked)

    def test_owner_colours_and_rings(self):
        text = worldmap.render(self.ITEMS + [{"name": "play area", "kind": "play_area", "x": 0.0, "z": 0.0, "radius": 8000.0, "node": ""}],
                               "Beacons/Field", columns=20, rows=10, colors={"verdant": "rgb(60,120,60)"})
        self.assertIn("[bold rgb(60,120,60)]H", text)
        self.assertGreater(plain(text).count("·"), 20, "The play area and the picked beacon's radius")

    def test_zoom_centres_on_the_picked_one(self):
        text = plain(worldmap.render(self.ITEMS, "Havens/Port", columns=20, rows=None, zoom=4))
        self.assertIn("zoom x4", text)
        self.assertIn("off the map", text, "The far beacon is out of view")
        rows = self.grid(text)
        port = next((r, line.index("H")) for r, line in enumerate(rows) if "H" in line)
        self.assertLessEqual(abs(port[1] // 2 - 10), 1, "In the middle")

    def test_rows_fit_the_sector(self):
        wide = [dict(item, z=0.0) for item in self.ITEMS]
        self.assertLess(len(plain(worldmap.render(wide, columns=20, rows=None)).split("\n")), 15, "A flat sector, few rows")

    def test_nothing_to_draw(self):
        self.assertEqual(worldmap.render([]), "(nothing to draw)")


if __name__ == "__main__":
    unittest.main()
