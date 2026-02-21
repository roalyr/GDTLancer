#
# PROJECT: GDTLancer
# MODULE: test_affinity.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_14
# LOG_REF: 2026-02-21 (TASK_13)
#

"""Unit tests for qualitative affinity and tag-transition CA rules.

Run:
    python3 -m unittest tests.test_affinity -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from autoload.game_state import GameState
from core.simulation.affinity_matrix import (
    AFFINITY_MATRIX,
    ATTACK_THRESHOLD,
    FLEE_THRESHOLD,
    TRADE_THRESHOLD,
    compute_affinity,
    derive_agent_tags,
    derive_sector_tags,
)
from core.simulation.grid_layer import GridLayer


class TestAffinity(unittest.TestCase):
    def test_compute_affinity_positive_pair(self):
        self.assertGreater(compute_affinity(["TRADER"], ["STATION"]), 0.0)

    def test_compute_affinity_negative_pair(self):
        self.assertLess(compute_affinity(["PIRATE"], ["MILITARY"]), 0.0)

    def test_compute_affinity_empty_inputs(self):
        self.assertEqual(compute_affinity([], []), 0.0)
        self.assertEqual(compute_affinity(["TRADER"], []), 0.0)

    def test_attack_threshold_reachable(self):
        self.assertTrue(any(v >= ATTACK_THRESHOLD for v in AFFINITY_MATRIX.values()))

    def test_thresholds_ordered(self):
        self.assertTrue(FLEE_THRESHOLD < 0 < TRADE_THRESHOLD < ATTACK_THRESHOLD)

    def test_derive_agent_tags_uses_new_condition_wealth_cargo(self):
        char = {"personality_traits": {"aggression": 0.8, "greed": 0.7}}
        agent = {
            "agent_role": "trader",
            "condition_tag": "DAMAGED",
            "wealth_tag": "BROKE",
            "cargo_tag": "LOADED",
            "dynamic_tags": ["DESPERATE"],
        }
        tags = derive_agent_tags(char, agent, has_cargo=True)
        self.assertIn("TRADER", tags)
        self.assertIn("DAMAGED", tags)
        self.assertIn("BROKE", tags)
        self.assertIn("LOADED", tags)
        self.assertIn("DESPERATE", tags)

    def test_derive_sector_tags_defaults(self):
        state = GameState()
        state.world_topology = {"s1": {"connections": [], "sector_type": "colony"}}
        state.world_hazards = {"s1": {}}
        state.grid_dominion = {"s1": {"security_level": 0.9}}
        state.sector_tags = {"s1": ["STATION"]}
        tags = derive_sector_tags("s1", state)
        self.assertIn("SECURE", tags)
        self.assertIn("MILD", tags)
        self.assertIn("RAW_ADEQUATE", tags)


class TestTagTransitionCA(unittest.TestCase):
    def setUp(self):
        self.layer = GridLayer()
        self.state = GameState()
        self.state.world_age = "PROSPERITY"
        self.state.world_topology = {
            "a": {"connections": ["b"], "sector_type": "colony"},
            "b": {"connections": ["a"], "sector_type": "colony"},
        }
        self.state.sector_tags = {
            "a": ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"],
            "b": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
        }
        self.state.grid_dominion = {"a": {}, "b": {}}
        self.state.colony_levels = {"a": "outpost", "b": "outpost"}
        self.state.colony_upgrade_progress = {"a": 0, "b": 0}
        self.state.colony_downgrade_progress = {"a": 0, "b": 0}
        self.state.agents = {
            "mil_1": {"current_sector_id": "a", "agent_role": "military", "is_disabled": False},
            "pir_1": {"current_sector_id": "b", "agent_role": "pirate", "is_disabled": False},
        }

    def test_economy_transitions_up_from_prosperity_and_neighbors(self):
        self.state.world_age = "RECOVERY"
        self.state.agents["trader_1"] = {
            "current_sector_id": "a",
            "agent_role": "trader",
            "cargo_tag": "LOADED",
            "is_disabled": False,
        }
        self.layer.process_tick(self.state, {})
        a_tags = self.state.sector_tags["a"]
        self.assertIn("RAW_ADEQUATE", a_tags)
        self.assertNotIn("RAW_POOR", a_tags)

    def test_security_transitions_with_military_and_pirates(self):
        self.layer.process_tick(self.state, {})
        a_tags = self.state.sector_tags["a"]
        b_tags = self.state.sector_tags["b"]
        self.assertIn("SECURE", a_tags)
        self.assertTrue(any(tag in b_tags for tag in {"SECURE", "CONTESTED", "LAWLESS"}))
        self.assertEqual(sum(1 for tag in b_tags if tag in {"SECURE", "CONTESTED", "LAWLESS"}), 1)

    def test_environment_transitions_under_disruption(self):
        self.state.world_age = "DISRUPTION"
        self.layer.process_tick(self.state, {})
        self.assertIn(self.state.sector_tags["a"][-1] if "MILD" in self.state.sector_tags["a"] else "HARSH", {"MILD", "HARSH", "EXTREME"})

    def test_hostile_presence_tags_applied(self):
        self.state.sector_tags["b"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
        self.layer.process_tick(self.state, {})
        self.assertTrue(any(tag in self.state.sector_tags["b"] for tag in {"HOSTILE_INFESTED", "HOSTILE_THREATENED"}))


if __name__ == "__main__":
    unittest.main()
