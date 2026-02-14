"""
Unit tests for ca_rules.py — pure-function cellular automata transition rules.

Tests verify:
  - strategic_map_step: influence propagation, faction anchoring, security, piracy
  - supply_demand_step: extraction from resource_potential, capacity limits
  - market_pressure_step: price deltas from supply vs demand, service cost modifier
  - entropy_step: wreck degradation, matter return
  - power_load_step: power ratio clamping
  - maintenance_pressure_step: entropy rate, maintenance modifier
"""

import copy
import unittest
import ca_rules


class TestStrategicMapStep(unittest.TestCase):
    """Tests for ca_rules.strategic_map_step()."""

    def _make_sector_state(
        self,
        faction_influence=None,
        pirate_activity=0.0,
        controlling_faction_id="",
    ):
        return {
            "faction_influence": faction_influence or {},
            "pirate_activity": pirate_activity,
            "controlling_faction_id": controlling_faction_id,
        }

    def _default_config(self, **overrides):
        cfg = {
            "influence_propagation_rate": 0.1,
            "pirate_activity_decay": 0.02,
            "pirate_activity_growth": 0.05,
            "faction_anchor_strength": 0.3,
        }
        cfg.update(overrides)
        return cfg

    # --- Pure output tests ---
    def test_returns_required_keys(self):
        result = ca_rules.strategic_map_step(
            "sector_a",
            self._make_sector_state({"f1": 0.5, "f2": 0.5}),
            [],
            self._default_config(),
        )
        self.assertIn("faction_influence", result)
        self.assertIn("security_level", result)
        self.assertIn("pirate_activity", result)

    def test_no_mutation_of_input(self):
        sector = self._make_sector_state({"f1": 0.6, "f2": 0.4})
        original = copy.deepcopy(sector)
        ca_rules.strategic_map_step("s1", sector, [], self._default_config())
        self.assertEqual(sector, original)

    # --- Influence normalization ---
    def test_influence_sums_to_one(self):
        sector = self._make_sector_state({"f1": 0.3, "f2": 0.3, "f3": 0.4})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        total = sum(result["faction_influence"].values())
        self.assertAlmostEqual(total, 1.0, places=6)

    def test_influence_no_negatives(self):
        sector = self._make_sector_state({"f1": 0.01, "f2": 0.99})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        for val in result["faction_influence"].values():
            self.assertGreaterEqual(val, 0.0)

    # --- Faction anchoring ---
    def test_anchor_boosts_controlling_faction(self):
        """Controlling faction should hold higher influence than without anchor."""
        sector_anchored = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id="f1"
        )
        sector_no_anchor = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id=""
        )
        result_anchored = ca_rules.strategic_map_step(
            "s1", sector_anchored, [], self._default_config()
        )
        result_plain = ca_rules.strategic_map_step(
            "s1", sector_no_anchor, [], self._default_config()
        )
        self.assertGreater(
            result_anchored["faction_influence"]["f1"],
            result_plain["faction_influence"]["f1"],
        )

    def test_anchor_strength_zero_equals_no_anchor(self):
        """With anchor_strength=0 the result is the same as no controlling faction."""
        sector = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id="f1"
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        # Without anchor boost, both factions should remain equal
        self.assertAlmostEqual(
            result["faction_influence"]["f1"],
            result["faction_influence"]["f2"],
            places=5,
        )

    # --- Neighbor propagation ---
    def test_neighbor_influence_propagates(self):
        """Faction present only in neighbor should appear in result."""
        sector = self._make_sector_state({"f1": 1.0})
        neighbor = {"faction_influence": {"f1": 0.2, "f2": 0.8}}
        result = ca_rules.strategic_map_step(
            "s1", sector, [neighbor], self._default_config(faction_anchor_strength=0.0)
        )
        self.assertIn("f2", result["faction_influence"])
        self.assertGreater(result["faction_influence"]["f2"], 0.0)

    def test_isolated_sector_no_propagation(self):
        """With no neighbors, only anchor changes influence."""
        sector = self._make_sector_state({"f1": 0.7, "f2": 0.3})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        # Should stay the same (no propagation source, no anchor)
        self.assertAlmostEqual(
            result["faction_influence"]["f1"], 0.7, places=5
        )

    # --- Security level ---
    def test_security_matches_max_influence(self):
        sector = self._make_sector_state(
            {"f1": 0.8, "f2": 0.2}, controlling_faction_id=""
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        max_inf = max(result["faction_influence"].values())
        self.assertAlmostEqual(result["security_level"], max_inf, places=5)

    def test_security_clamped_0_to_1(self):
        sector = self._make_sector_state({"f1": 1.0})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertGreaterEqual(result["security_level"], 0.0)
        self.assertLessEqual(result["security_level"], 1.0)

    # --- Piracy ---
    def test_piracy_grows_when_security_low(self):
        sector = self._make_sector_state(
            {"f1": 0.2, "f2": 0.2}, pirate_activity=0.3
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        self.assertGreater(result["pirate_activity"], 0.3)

    def test_piracy_decays_when_security_high(self):
        sector = self._make_sector_state(
            {"f1": 0.95}, pirate_activity=0.5, controlling_faction_id="f1"
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertLess(result["pirate_activity"], 0.5)

    def test_piracy_clamped_to_0_1(self):
        sector = self._make_sector_state({"f1": 0.01}, pirate_activity=1.0)
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertLessEqual(result["pirate_activity"], 1.0)
        self.assertGreaterEqual(result["pirate_activity"], 0.0)


class TestSupplyDemandStep(unittest.TestCase):
    """Tests for ca_rules.supply_demand_step()."""

    def _make_stockpiles(self, commodities=None, capacity=1000):
        return {
            "commodity_stockpiles": commodities or {},
            "stockpile_capacity": capacity,
            "extraction_rate": {},
        }

    def _make_potential(self, mineral=100.0, propellant=50.0):
        return {
            "mineral_density": mineral,
            "propellant_sources": propellant,
        }

    def _default_config(self, **overrides):
        cfg = {"extraction_rate_default": 0.01}
        cfg.update(overrides)
        return cfg

    # --- Extraction ---
    def test_extraction_moves_matter_from_potential_to_stockpile(self):
        stockpiles = self._make_stockpiles()
        potential = self._make_potential(mineral=100.0, propellant=50.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        new_stock = result["new_stockpiles"]["commodity_stockpiles"]
        new_pot = result["new_resource_potential"]

        # Ore should appear in stockpile
        self.assertGreater(new_stock.get("commodity_ore", 0.0), 0.0)
        # Fuel should appear
        self.assertGreater(new_stock.get("commodity_fuel", 0.0), 0.0)
        # Potential should decrease
        self.assertLess(new_pot["mineral_density"], 100.0)
        self.assertLess(new_pot["propellant_sources"], 50.0)

    def test_extraction_conserves_matter(self):
        """Extracted amount equals potential decrease (Axiom 1)."""
        stockpiles = self._make_stockpiles({"commodity_ore": 10.0})
        potential = self._make_potential(mineral=100.0, propellant=50.0)

        stock_before = 10.0
        pot_before = 100.0 + 50.0

        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        new_stock = result["new_stockpiles"]["commodity_stockpiles"]
        new_pot = result["new_resource_potential"]

        stock_after = sum(new_stock.values())
        pot_after = new_pot["mineral_density"] + new_pot["propellant_sources"]

        self.assertAlmostEqual(
            stock_before + pot_before,
            stock_after + pot_after,
            places=8,
            msg="Matter must be conserved during extraction",
        )

    def test_no_extraction_when_potential_zero(self):
        stockpiles = self._make_stockpiles()
        potential = self._make_potential(mineral=0.0, propellant=0.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        self.assertEqual(result["matter_extracted"], 0.0)

    def test_extraction_respects_capacity(self):
        """Stockpile should not exceed capacity."""
        stockpiles = self._make_stockpiles(
            {"commodity_ore": 990.0}, capacity=1000
        )
        potential = self._make_potential(mineral=10000.0, propellant=0.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        total = sum(result["new_stockpiles"]["commodity_stockpiles"].values())
        self.assertLessEqual(total, 1000.0)

    def test_no_mutation_of_inputs(self):
        stockpiles = self._make_stockpiles({"commodity_ore": 50.0})
        potential = self._make_potential()
        orig_stock = copy.deepcopy(stockpiles)
        orig_pot = copy.deepcopy(potential)
        ca_rules.supply_demand_step("s1", stockpiles, potential, [], self._default_config())
        self.assertEqual(stockpiles, orig_stock)
        self.assertEqual(potential, orig_pot)


class TestMarketPressureStep(unittest.TestCase):
    """Tests for ca_rules.market_pressure_step()."""

    def _default_config(self, **overrides):
        cfg = {"price_sensitivity": 0.5, "demand_base": 0.1}
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        stockpiles = {"commodity_stockpiles": {"ore": 100}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step("s1", stockpiles, 1.0, self._default_config())
        self.assertIn("commodity_price_deltas", result)
        self.assertIn("service_cost_modifier", result)

    def test_high_supply_gives_negative_delta(self):
        """Oversupply should push price delta negative."""
        stockpiles = {"commodity_stockpiles": {"ore": 500}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 0.1, self._default_config()
        )
        self.assertLess(result["commodity_price_deltas"]["ore"], 0.0)

    def test_zero_supply_gives_positive_delta(self):
        """No supply with some demand should push price delta positive."""
        stockpiles = {"commodity_stockpiles": {"ore": 0.0}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 1.0, self._default_config()
        )
        self.assertGreater(result["commodity_price_deltas"]["ore"], 0.0)

    def test_service_modifier_clamped(self):
        stockpiles = {"commodity_stockpiles": {}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 100.0, self._default_config()
        )
        self.assertGreaterEqual(result["service_cost_modifier"], 0.5)
        self.assertLessEqual(result["service_cost_modifier"], 2.0)

    def test_empty_commodities_returns_empty_deltas(self):
        stockpiles = {"commodity_stockpiles": {}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 1.0, self._default_config()
        )
        self.assertEqual(result["commodity_price_deltas"], {})


class TestEntropyStep(unittest.TestCase):
    """Tests for ca_rules.entropy_step()."""

    def _default_config(self, **overrides):
        cfg = {
            "wreck_degradation_per_tick": 0.05,
            "wreck_debris_return_fraction": 0.8,
            "entropy_radiation_multiplier": 2.0,
        }
        cfg.update(overrides)
        return cfg

    def test_wreck_degrades_over_time(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(len(result["surviving_wrecks"]), 1)
        self.assertLess(
            result["surviving_wrecks"][0]["wreck_integrity"], 0.5
        )

    def test_wreck_destroyed_when_integrity_zero(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(len(result["surviving_wrecks"]), 0)
        self.assertGreater(result["matter_returned"], 0.0)

    def test_matter_returned_fraction(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        # Wreck matter = inventory (10) + hull mass (1) = 11. Return = 11 * 0.8 = 8.8
        self.assertAlmostEqual(result["matter_returned"], 8.8, places=2)

    def test_radiation_increases_degradation(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {}}]
        hazards_clean = {"radiation_level": 0.0}
        hazards_hot = {"radiation_level": 1.0}

        result_clean = ca_rules.entropy_step("s1", wrecks, hazards_clean, self._default_config())
        result_hot = ca_rules.entropy_step("s1", copy.deepcopy(wrecks), hazards_hot, self._default_config())

        # Higher radiation → more degradation → lower integrity
        self.assertLess(
            result_hot["surviving_wrecks"][0]["wreck_integrity"],
            result_clean["surviving_wrecks"][0]["wreck_integrity"],
        )

    def test_no_wrecks_returns_empty(self):
        result = ca_rules.entropy_step("s1", [], {}, self._default_config())
        self.assertEqual(result["surviving_wrecks"], [])
        self.assertEqual(result["matter_returned"], 0.0)

    def test_no_mutation_of_input(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {"ore": 5.0}}]
        original = copy.deepcopy(wrecks)
        ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(wrecks, original)


class TestPowerLoadStep(unittest.TestCase):
    """Tests for ca_rules.power_load_step()."""

    def test_zero_output_returns_zero_ratio(self):
        result = ca_rules.power_load_step(0.0, 50.0)
        self.assertEqual(result["power_load_ratio"], 0.0)

    def test_half_load(self):
        result = ca_rules.power_load_step(100.0, 50.0)
        self.assertAlmostEqual(result["power_load_ratio"], 0.5)

    def test_full_load(self):
        result = ca_rules.power_load_step(100.0, 100.0)
        self.assertAlmostEqual(result["power_load_ratio"], 1.0)

    def test_overload_clamped_to_2(self):
        result = ca_rules.power_load_step(100.0, 500.0)
        self.assertAlmostEqual(result["power_load_ratio"], 2.0)


class TestMaintenancePressureStep(unittest.TestCase):
    """Tests for ca_rules.maintenance_pressure_step()."""

    def _default_config(self):
        return {"entropy_base_rate": 0.001}

    def test_returns_required_keys(self):
        result = ca_rules.maintenance_pressure_step({}, self._default_config())
        self.assertIn("local_entropy_rate", result)
        self.assertIn("maintenance_cost_modifier", result)

    def test_higher_radiation_increases_entropy(self):
        low_rad = ca_rules.maintenance_pressure_step(
            {"radiation_level": 0.0}, self._default_config()
        )
        high_rad = ca_rules.maintenance_pressure_step(
            {"radiation_level": 1.0}, self._default_config()
        )
        self.assertGreater(
            high_rad["local_entropy_rate"],
            low_rad["local_entropy_rate"],
        )

    def test_modifier_clamped_1_to_3(self):
        result = ca_rules.maintenance_pressure_step(
            {"radiation_level": 100.0, "thermal_background_k": 50000.0,
             "gravity_well_penalty": 10.0},
            self._default_config(),
        )
        self.assertGreaterEqual(result["maintenance_cost_modifier"], 1.0)
        self.assertLessEqual(result["maintenance_cost_modifier"], 3.0)

    def test_benign_environment_low_modifier(self):
        result = ca_rules.maintenance_pressure_step(
            {"radiation_level": 0.0, "thermal_background_k": 300.0,
             "gravity_well_penalty": 1.0},
            self._default_config(),
        )
        self.assertAlmostEqual(result["maintenance_cost_modifier"], 1.1, places=1)


if __name__ == "__main__":
    unittest.main()
