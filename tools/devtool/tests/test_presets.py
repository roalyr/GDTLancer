"""presets.py: reading character sheets, applying their tweaks, the game's laws as stats, ranking
designs as the exporter does, and writing prices back onto the sheets."""

import os
import tempfile
import unittest

from devtool import presets

DOC = """# Preset characters

Intro, with `code: 1 -> 2` that is not a sheet.

### trader_medium · Smuggler
*Jams pursuers and runs quiet.*
- **Base:** `V21949i2` (level with the pick)
- **Tweaks:** `quiet: 0.08 -> 0.80`, `share.engine: 0.20 -> 0.30`, `share.hold: 0.30 -> 0.20`, `+damper_medium`
- **Price:** old

### scavenger_heavy · Salvage tug
*Never runs.*
- **Base:** `V17072i6`
- **Tweaks:**
- **Price:** old
"""

GENOME = {"behavior": {"quiet": 0.08, "caution": 0.74},
          "ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.4, "engine": 0.2, "reactor": 0.05, "capacitor": 0.05, "hold": 0.3}},
          "tools": [{"kind": "laser", "type": 2, "genes": {}}], "modules": [{"kind": "damper", "type": 1, "genes": {}}]}


class SheetTest(unittest.TestCase):
    def test_sheets_are_read_with_name_line_base_and_tweaks(self):
        sheets = presets.parse(DOC)
        self.assertEqual([s["arch"] for s in sheets], ["trader_medium", "scavenger_heavy"])
        self.assertEqual(sheets[0]["name"], "Smuggler")
        self.assertEqual(sheets[0]["line"], "Jams pursuers and runs quiet.")
        self.assertEqual(sheets[0]["base"], "V21949i2")
        self.assertEqual(len(sheets[0]["tweaks"]), 4)
        self.assertEqual(sheets[1]["tweaks"], [], "an empty Tweaks line is no tweaks")

    def test_characters_reads_the_doc(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
            handle.write(DOC)
        try:
            self.assertEqual(presets.characters(handle.name)["scavenger_heavy"], ("Salvage tug", "Never runs."))
        finally:
            os.remove(handle.name)
        self.assertEqual(presets.characters("/no/such/doc.md"), {})

    def test_tweaks_move_genes_shares_and_parts(self):
        genome, problems = presets.apply(GENOME, presets.parse(DOC)[0]["tweaks"], {"quiet": (0.0, 0.9)})
        self.assertEqual(problems, [])
        self.assertEqual(genome["behavior"]["quiet"], 0.80)
        self.assertEqual(genome["ship"]["shares"]["engine"], 0.30)
        self.assertEqual(genome["modules"][-1], {"kind": "damper", "type": 2, "genes": {}})
        self.assertEqual(GENOME["behavior"]["quiet"], 0.08, "the base is left as it was")

    def test_an_applied_tweak_applies_again_without_complaint(self):
        once, _ = presets.apply(GENOME, ["quiet: 0.08 -> 0.80"])
        again, problems = presets.apply(once, ["quiet: 0.08 -> 0.80"])
        self.assertEqual(problems, [])
        self.assertEqual(again["behavior"]["quiet"], 0.80)

    def test_wrong_tweaks_are_named(self):
        _, problems = presets.apply(GENOME, ["caution: 0.20 -> 0.90", "quiet: 0.08 -> 1.50", "-cannon_heavy", "faster please",
                                             "share.engine: 0.20 -> 0.40"], {"quiet": (0.0, 0.9)})
        text = "; ".join(problems)
        for expected in ("caution is 0.74, not 0.20", "outside", "no cannon_heavy to remove", "can't read", "add up to 1.200"):
            self.assertIn(expected, text)

    def test_removing_a_part_empties_its_slot(self):
        genome, problems = presets.apply(GENOME, ["-laser_medium"])
        self.assertEqual(problems, [])
        self.assertEqual(genome["tools"], [{}])

    def test_prices_go_on_the_price_lines_only(self):
        text = presets.write_prices(DOC, {"trader_medium": "tweaks: about free"})
        self.assertIn("- **Price:** tweaks: about free", text)
        self.assertEqual(text.count("- **Price:** old"), 1, "the other sheet keeps its line")
        self.assertIn("`code: 1 -> 2`", text)


class LawTest(unittest.TestCase):
    def test_the_game_constants_read(self):
        consts = presets.game_constants()
        self.assertEqual(len(consts["LAW_HULL"]), 3)
        self.assertEqual(consts["PRESET_WEIGHT_CLASSES"][-1][1], float("inf"), "INF reads as infinity")
        self.assertIn("engage", consts["EVO_BEHAVIOR_RANGES"])

    def test_literal_drops_comments(self):
        self.assertEqual(presets.literal('{  # Gene\n\t"a": [1, 2],  # one\n}'), {"a": [1, 2]})

    def test_more_engine_is_more_speed_and_less_hold_less_cargo(self):
        consts, parts = presets.game_constants(), presets.catalogue()
        base = presets.stats(GENOME, consts, parts)
        tuned, _ = presets.apply(GENOME, ["share.engine: 0.20 -> 0.30", "share.hold: 0.30 -> 0.20"])
        faster = presets.stats(tuned, consts, parts)
        self.assertGreater(faster["accel"], base["accel"])
        self.assertLess(faster["cargo"], base["cargo"])
        self.assertGreater(base["dps_laser"], 0.0, "the catalogue's laser counts")

    def test_part_ids_are_the_catalogues(self):
        self.assertEqual(presets.part_id({"kind": "laser", "type": 3}), "preset_laser_heavy")
        self.assertEqual(presets.part_id({"kind": "harpoon", "type": 0}), "preset_harpoon")
        self.assertEqual(presets.part_id({"kind": "capacitor", "type": 1}), "preset_power_cell_light")


class StandingTest(unittest.TestCase):
    def life(self, gid, fitness, niche="s0|trader|near"):
        return {"genome_id": gid, "fitness": fitness, "faction": "blue", "fam": "trader", "w": "medium", "niche": niche}

    def test_designs_rank_against_their_family_with_shrinkage(self):
        lives = [self.life("good", 1.0) for _ in range(10)] + [self.life("poor", 0.0) for _ in range(10)] + [self.life("few", 5.0)] * 3
        standing, by_arch = presets.standings(lives)
        self.assertNotIn("few", standing, "under 5 lives is not ranked")
        self.assertGreater(standing["good"][0], standing["poor"][0])
        self.assertLess(standing["good"][0] + 0.0, 1.0, "shrunk toward the family")
        self.assertEqual(sorted(by_arch["trader_medium"]), ["good", "poor"])


if __name__ == "__main__":
    unittest.main()
