"""characters.py: a character's genome (as CharacterSheet.genome makes it), the game's laws as stats,
ranking designs as the exporter does, finding a base in the life log, and pricing with a stand-in era."""

import json
import os
import tempfile
import unittest
from unittest import mock

from devtool import characters

BASE = {"behavior": {"quiet": 0.08, "caution": 0.74},
        "ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.4, "engine": 0.2, "reactor": 0.05, "capacitor": 0.05, "hold": 0.3}},
        "tools": [{"kind": "laser", "type": 2, "genes": {}}], "modules": [{"kind": "damper", "type": 1, "genes": {}}]}
SHEET = {"display_name": "Smuggler", "base_genome": BASE, "base_origin": "trader_medium_21949i2 (era 68)",
         "genes": {"quiet": 0.8}, "shares": {"engine": 0.3}, "add_parts": ["preset_damper_medium", "preset_harpoon"],
         "remove_parts": ["preset_laser_medium"]}


class GenomeTest(unittest.TestCase):
    def test_tweaks_set_genes_shares_and_parts_over_the_base(self):
        genome = characters.genome_of(SHEET)
        self.assertEqual(genome["behavior"], {"quiet": 0.8, "caution": 0.74})
        self.assertEqual(genome["ship"]["shares"]["engine"], 0.3)
        self.assertEqual(genome["tools"], [{}, {"kind": "harpoon", "type": 0, "genes": {}}], "removed: an empty slot; the harpoon a tool")
        self.assertEqual(genome["modules"][-1], {"kind": "damper", "type": 2, "genes": {}})
        self.assertEqual(BASE["behavior"]["quiet"], 0.08, "the base is left as it was")
        self.assertTrue(characters.tweaked(SHEET))
        self.assertFalse(characters.tweaked({"base_genome": BASE, "genes": {}, "shares": {}}))

    def test_part_ids_go_both_ways(self):
        for part in ({"kind": "laser", "type": 3, "genes": {}}, {"kind": "harpoon", "type": 0, "genes": {}}):
            self.assertEqual(characters.part_of(characters.part_id(part)), part)
        self.assertEqual(characters.part_of("preset_banana"), {})
        self.assertEqual(characters.part_id({"kind": "capacitor", "type": 1}), "preset_power_cell_light", "retired kinds")

    def test_a_base_is_found_by_its_design_number(self):
        self.assertEqual(characters.design_number("trader_medium_21949i2 (era 68)"), "21949i2")
        self.assertEqual(characters.design_number(""), "")


class LawTest(unittest.TestCase):
    def test_the_game_constants_read(self):
        consts = characters.game_constants()
        self.assertEqual(len(consts["LAW_HULL"]), 3)
        self.assertEqual(consts["PRESET_WEIGHT_CLASSES"][-1][1], float("inf"), "INF reads as infinity")
        self.assertIn("engage", consts["EVO_BEHAVIOR_RANGES"])

    def test_literal_drops_comments(self):
        self.assertEqual(characters.literal('{  # Gene\n\t"a": [1, 2],  # one\n}'), {"a": [1, 2]})

    def test_more_engine_is_more_speed_and_less_hold_less_cargo(self):
        consts, parts = characters.game_constants(), characters.catalogue()
        base = characters.stats(BASE, consts, parts)
        faster = characters.stats(characters.genome_of({"base_genome": BASE, "shares": {"engine": 0.3, "hold": 0.2}}), consts, parts)
        self.assertGreater(faster["accel"], base["accel"])
        self.assertLess(faster["cargo"], base["cargo"])
        self.assertGreater(base["dps_laser"], 0.0, "the catalogue's laser counts")

    def test_every_archetype_is_listed(self):
        self.assertEqual(len(characters.archetype_names()), 20)


class StandingTest(unittest.TestCase):
    def life(self, gid, fitness):
        return {"genome_id": gid, "fitness": fitness, "faction": "blue", "fam": "trader", "w": "medium", "niche": "s0|trader|near"}

    def test_designs_rank_against_their_family_with_shrinkage(self):
        lives = [self.life("good", 1.0) for _ in range(10)] + [self.life("poor", 0.0) for _ in range(10)] + [self.life("few", 5.0)] * 3
        standing, by_arch = characters.standings(lives)
        self.assertNotIn("few", standing, "under 5 lives is not ranked")
        self.assertGreater(standing["good"][0], standing["poor"][0])
        self.assertLess(standing["good"][0], 1.0, "shrunk toward the family")
        self.assertEqual(sorted(by_arch["trader_medium"]), ["good", "poor"])


class StandIn:
    """An era with one base life, no fitted models (characters.price's other inputs)."""
    consts = characters.game_constants()
    parts = characters.catalogue()

    def __init__(self, lives):
        self.lives = lives

    def last_life(self, number):
        return next((d for d in self.lives if d["genome_id"].endswith(number)), None)


class PriceTest(unittest.TestCase):
    def test_a_base_missing_from_the_log_is_said(self):
        line = characters.price("trader_medium", SHEET, StandIn([]), {}, {}, {}, {})
        self.assertIn("flew no lives in this log", line)

    def test_tweaks_that_change_the_hull_say_how(self):
        life = {"genome_id": "V21949i2", "genome": BASE, "cost": 9000.0, "fitness": 0.1, "t": 1.0}
        line = characters.price("trader_medium", SHEET, StandIn([life]), {}, {}, {}, {})
        self.assertIn("no model for traders", line)
        self.assertIn("speed +", line, "more engine")

    def test_prices_are_read_back(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "prices.json")
            with open(path, "w") as handle:
                json.dump({"prices": {"trader_medium": "tweaks: about free"}}, handle)
            with mock.patch.object(characters, "out_file", lambda name: path):
                self.assertEqual(characters.prices(), {"trader_medium": "tweaks: about free"})
            with mock.patch.object(characters, "out_file", lambda name: os.path.join(folder, "none.json")):
                self.assertEqual(characters.prices(), {})


if __name__ == "__main__":
    unittest.main()
