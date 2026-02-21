#
# PROJECT: GDTLancer
# MODULE: test_affinity.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2, §3.4, §6.3 + TACTICAL_TODO.md PHASE 3 TASK_7
# LOG_REF: 2026-02-22 00:20:00
#

"""Unit tests for qualitative affinity and tag-transition CA rules.

Run:
    python3 -m unittest tests.test_affinity -v
"""

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from autoload.game_state import GameState
from autoload import constants
from core.simulation.agent_layer import AgentLayer
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
        self.state.security_upgrade_progress = {"a": 0, "b": 0}
        self.state.security_downgrade_progress = {"a": 0, "b": 0}
        self.state.security_change_threshold = {"a": 3, "b": 3}
        self.state.economy_upgrade_progress = {
            "a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        self.state.economy_downgrade_progress = {
            "a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        self.state.economy_change_threshold = {
            "a": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
            "b": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
        }
        self.state.hostile_infestation_progress = {"a": 0, "b": 0}
        self.state.agents = {
            "mil_1": {"current_sector_id": "a", "agent_role": "military", "is_disabled": False},
            "pir_1": {"current_sector_id": "b", "agent_role": "pirate", "is_disabled": False},
        }

    def test_economy_thresholds_vary_per_sector(self):
        state = GameState()
        state.world_seed = "seed-123"
        state.world_topology = {
            "s1": {"connections": ["s2"], "sector_type": "colony"},
            "s2": {"connections": ["s1"], "sector_type": "colony"},
        }
        state.sector_tags = {
            "s1": ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
            "s2": ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
        }

        self.layer.initialize_grid(state)

        s1 = state.economy_change_threshold["s1"]
        s2 = state.economy_change_threshold["s2"]
        self.assertTrue(all(2 <= value <= 5 for value in s1.values()))
        self.assertTrue(all(2 <= value <= 5 for value in s2.values()))
        self.assertNotEqual(s1, s2)

    def test_economy_transitions_require_sustained_pressure(self):
        self.state.world_age = "RECOVERY"
        self.state.agents["trader_1"] = {
            "current_sector_id": "a",
            "agent_role": "trader",
            "cargo_tag": "LOADED",
            "is_disabled": False,
        }

        self.layer.process_tick(self.state, {})
        self.assertIn("RAW_POOR", self.state.sector_tags["a"])

        self.layer.process_tick(self.state, {})
        self.assertIn("RAW_POOR", self.state.sector_tags["a"])

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

    def test_hostile_infestation_builds_gradually(self):
        self.state.world_age = "DISRUPTION"
        self.state.sector_tags["a"] = ["STATION", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
        self.state.sector_tags["b"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
        self.state.agents["mil_1"]["is_disabled"] = True

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.state.world_age = "RECOVERY"
        self.state.agents["mil_1"] = {"current_sector_id": "b", "agent_role": "military", "is_disabled": False}
        self.state.agents["pir_1"]["is_disabled"] = True
        self.state.security_change_threshold["b"] = 1
        self.state.security_upgrade_progress["b"] = 0
        self.state.security_downgrade_progress["b"] = 0

        self.layer.process_tick(self.state, {})
        self.assertIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

    def test_colony_maintenance_drains_economy(self):
        state = GameState()
        state.world_seed = "maint-seed"
        state.world_age = "PROSPERITY"
        state.world_topology = {
            "hub_sector": {"connections": [], "sector_type": "hub"},
        }
        state.sector_tags = {
            "hub_sector": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
        }
        state.grid_dominion = {"hub_sector": {}}
        state.colony_levels = {"hub_sector": "hub"}
        state.colony_upgrade_progress = {"hub_sector": 0}
        state.colony_downgrade_progress = {"hub_sector": 0}
        state.security_upgrade_progress = {"hub_sector": 0}
        state.security_downgrade_progress = {"hub_sector": 0}
        state.security_change_threshold = {"hub_sector": 3}
        state.economy_upgrade_progress = {"hub_sector": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}}
        state.economy_downgrade_progress = {"hub_sector": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}}
        state.economy_change_threshold = {"hub_sector": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}}
        state.hostile_infestation_progress = {"hub_sector": 0}
        state.agents = {}

        for _ in range(10):
            self.layer.process_tick(state, {})

        tags = state.sector_tags["hub_sector"]
        self.assertNotIn("RAW_RICH", tags)
        self.assertNotIn("MANUFACTURED_RICH", tags)
        self.assertNotIn("CURRENCY_RICH", tags)


class TestPopulationEquilibrium(unittest.TestCase):
    def test_mortal_spawn_blocked_in_poor_sector(self):
        layer = AgentLayer()
        layer._rng.seed(0)

        state = GameState()
        state.world_topology = {"s1": {"connections": [], "sector_type": "colony"}}
        state.sector_tags = {
            "s1": ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"],
        }
        state.agents = {}
        state.mortal_agent_counter = 0

        with patch.object(constants, "MORTAL_SPAWN_CHANCE", 1.0):
            layer._spawn_mortal_agents(state)

        self.assertEqual(state.mortal_agent_counter, 0)
        self.assertEqual(len(state.agents), 0)

    def test_mortal_survivor_starts_broke(self):
        layer = AgentLayer()
        layer._rng.seed(0)

        state = GameState()
        state.agents = {
            "mortal_1": {
                "is_persistent": False,
                "is_disabled": True,
                "home_location_id": "s1",
                "current_sector_id": "s2",
                "condition_tag": "DESTROYED",
                "wealth_tag": "WEALTHY",
                "cargo_tag": "LOADED",
            }
        }

        with patch.object(constants, "MORTAL_SURVIVAL_CHANCE", 1.0):
            layer._cleanup_dead_mortals(state)

        survivor = state.agents["mortal_1"]
        self.assertFalse(survivor["is_disabled"])
        self.assertEqual(survivor["condition_tag"], "DAMAGED")
        self.assertEqual(survivor["wealth_tag"], "BROKE")
        self.assertEqual(survivor["cargo_tag"], "EMPTY")


if __name__ == "__main__":
    unittest.main()
