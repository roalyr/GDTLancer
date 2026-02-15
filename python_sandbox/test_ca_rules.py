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

    def test_surviving_wreck_hull_dust_conserved(self):
        """Hull erosion on a surviving wreck must appear as dust (Axiom 1)."""
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {"ore": 3.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        surviving = result["surviving_wrecks"]
        self.assertEqual(len(surviving), 1)
        new_integrity = surviving[0]["wreck_integrity"]
        hull_lost = 0.5 - new_integrity
        # Dust must equal the hull mass lost (inventory untouched on surviving wrecks).
        self.assertAlmostEqual(result["matter_to_dust"], hull_lost, places=6)
        # Salvaged is 0 — wreck didn't die.
        self.assertEqual(result["matter_salvaged"], 0.0)
        # Total matter = surviving hull + inventory + dust = original 3.5
        total = new_integrity + 3.0 + result["matter_to_dust"]
        self.assertAlmostEqual(total, 3.5, places=6)

    def test_wreck_destroyed_when_integrity_zero(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(len(result["surviving_wrecks"]), 0)
        total = result["matter_salvaged"] + result["matter_to_dust"]
        self.assertGreater(total, 0.0)

    def test_matter_returned_fraction(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        # Hull 0.01 degrades fully → 0.01 dust.
        # Inventory 10.0: salvaged = 10.0 * 0.8 = 8.0, dust = 10.0 * 0.2 = 2.0.
        # Total dust = 0.01 + 2.0 = 2.01.
        self.assertAlmostEqual(result["matter_salvaged"], 8.0, places=2)
        self.assertAlmostEqual(result["matter_to_dust"], 2.01, places=2)
        # Axiom 1: salvaged + dust = original wreck matter (10.01)
        total = result["matter_salvaged"] + result["matter_to_dust"]
        self.assertAlmostEqual(total, 10.01, places=2)

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
        self.assertEqual(result["matter_salvaged"], 0.0)
        self.assertEqual(result["matter_to_dust"], 0.0)

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


class TestProspectingStep(unittest.TestCase):
    """Tests for ca_rules.prospecting_step()."""

    def _make_hidden(self, mineral=1000.0, propellant=500.0):
        return {"mineral_density": mineral, "propellant_sources": propellant}

    def _make_potential(self, mineral=50.0, propellant=30.0):
        return {"mineral_density": mineral, "propellant_sources": propellant}

    def _make_market(self, deltas=None):
        return {"commodity_price_deltas": deltas or {}}

    def _make_dominion(self, security=0.8):
        return {"security_level": security}

    def _make_hazards(self, radiation=0.05):
        return {"radiation_level": radiation}

    def _default_config(self, **overrides):
        cfg = {
            "prospecting_base_rate": 0.002,
            "prospecting_scarcity_boost": 2.0,
            "prospecting_security_factor": 1.0,
            "prospecting_hazard_penalty": 0.5,
            "prospecting_randomness": 0.3,
            "resource_layer_fractions": {"surface": 0.15, "deep": 0.35, "mantle": 0.50},
            "resource_layer_rate_multipliers": {"surface": 3.0, "deep": 1.0, "mantle": 0.3},
            "resource_layer_depletion_threshold": 0.01,
        }
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertIn("new_hidden", result)
        self.assertIn("new_potential", result)
        self.assertIn("matter_discovered", result)

    def test_matter_conservation(self):
        """Hidden → discovered transfer must conserve matter."""
        hidden = self._make_hidden(1000.0, 500.0)
        potential = self._make_potential(50.0, 30.0)
        before = 1000.0 + 500.0 + 50.0 + 30.0

        result = ca_rules.prospecting_step(
            "s1", hidden, potential,
            self._make_market({"ore": 0.1}), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        nh = result["new_hidden"]
        np_ = result["new_potential"]
        after = (nh["mineral_density"] + nh["propellant_sources"]
                 + np_["mineral_density"] + np_["propellant_sources"])
        self.assertAlmostEqual(before, after, places=8,
                               msg="Prospecting must conserve matter")

    def test_no_mutation_of_inputs(self):
        hidden = self._make_hidden()
        potential = self._make_potential()
        orig_h = copy.deepcopy(hidden)
        orig_p = copy.deepcopy(potential)
        ca_rules.prospecting_step(
            "s1", hidden, potential,
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertEqual(hidden, orig_h)
        self.assertEqual(potential, orig_p)

    def test_discovery_increases_potential(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(1000.0, 500.0), self._make_potential(50.0, 30.0),
            self._make_market({"ore": 0.1}), self._make_dominion(0.8),
            self._make_hazards(0.05), self._default_config(), 0.5,
        )
        self.assertGreater(result["new_potential"]["mineral_density"], 50.0)
        self.assertGreater(result["new_potential"]["propellant_sources"], 30.0)

    def test_discovery_decreases_hidden(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(1000.0, 500.0), self._make_potential(50.0, 30.0),
            self._make_market({"ore": 0.1}), self._make_dominion(0.8),
            self._make_hazards(0.05), self._default_config(), 0.5,
        )
        self.assertLess(result["new_hidden"]["mineral_density"], 1000.0)
        self.assertLess(result["new_hidden"]["propellant_sources"], 500.0)

    def test_no_hidden_no_discovery(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(0.0, 0.0), self._make_potential(50.0, 30.0),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertEqual(result["matter_discovered"], 0.0)

    def test_scarcity_boosts_discovery(self):
        """Higher scarcity (positive price deltas) should increase discovery rate."""
        market_low = self._make_market({})
        market_high = self._make_market({"ore": 0.5, "fuel": 0.3})

        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            market_low, self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            market_high, self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_high["matter_discovered"],
            result_low["matter_discovered"],
        )

    def test_high_security_boosts_discovery(self):
        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(0.1),
            self._make_hazards(), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(1.0),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_high["matter_discovered"],
            result_low["matter_discovered"],
        )

    def test_high_radiation_reduces_discovery(self):
        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(0.0), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(1.0), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_low["matter_discovered"],
            result_high["matter_discovered"],
        )

    def test_randomness_variance(self):
        """Different rng values should produce different amounts."""
        r1 = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.0,
        )
        r2 = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 1.0,
        )
        self.assertNotAlmostEqual(
            r1["matter_discovered"], r2["matter_discovered"], places=6,
        )


class TestHazardDriftStep(unittest.TestCase):
    """Tests for ca_rules.hazard_drift_step()."""

    def _base_hazards(self, rad=0.05, thermal=280.0, gravity=1.2):
        return {
            "radiation_level": rad,
            "thermal_background_k": thermal,
            "gravity_well_penalty": gravity,
        }

    def _default_config(self, **overrides):
        cfg = {
            "hazard_drift_period": 200,
            "hazard_radiation_amplitude": 0.04,
            "hazard_thermal_amplitude": 15.0,
        }
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        result = ca_rules.hazard_drift_step(
            "s1", self._base_hazards(), 0, 0, self._default_config(),
        )
        self.assertIn("radiation_level", result)
        self.assertIn("thermal_background_k", result)
        self.assertIn("gravity_well_penalty", result)

    def test_gravity_unchanged(self):
        """Gravity should never be affected by space weather."""
        base = self._base_hazards(gravity=1.5)
        result = ca_rules.hazard_drift_step(
            "s1", base, 100, 0, self._default_config(),
        )
        self.assertEqual(result["gravity_well_penalty"], 1.5)

    def test_no_mutation_of_input(self):
        base = self._base_hazards()
        original = copy.deepcopy(base)
        ca_rules.hazard_drift_step("s1", base, 50, 0, self._default_config())
        self.assertEqual(base, original)

    def test_radiation_drifts_from_base(self):
        """At non-zero tick, radiation should differ from base (unless at sin=0)."""
        base = self._base_hazards(rad=0.1)
        # tick 50 with period 200 → θ = π/2 → sin = 1.0, so drift = amplitude
        result = ca_rules.hazard_drift_step(
            "s1", base, 50, 0, self._default_config(),
        )
        self.assertNotAlmostEqual(result["radiation_level"], 0.1, places=3)

    def test_thermal_drifts_from_base(self):
        base = self._base_hazards(thermal=300.0)
        result = ca_rules.hazard_drift_step(
            "s1", base, 50, 0, self._default_config(),
        )
        self.assertNotAlmostEqual(result["thermal_background_k"], 300.0, places=0)

    def test_radiation_clamped_non_negative(self):
        """Even with large amplitude, radiation should never go negative."""
        base = self._base_hazards(rad=0.01)
        cfg = self._default_config(hazard_radiation_amplitude=1.0)
        # Test many ticks
        for tick in range(300):
            result = ca_rules.hazard_drift_step("s1", base, tick, 0, cfg)
            self.assertGreaterEqual(result["radiation_level"], 0.0)

    def test_thermal_clamped_above_minimum(self):
        """Thermal should never drop below 50K."""
        base = self._base_hazards(thermal=60.0)
        cfg = self._default_config(hazard_thermal_amplitude=100.0)
        for tick in range(300):
            result = ca_rules.hazard_drift_step("s1", base, tick, 0, cfg)
            self.assertGreaterEqual(result["thermal_background_k"], 50.0)

    def test_different_sectors_different_phase(self):
        """Different sector indices should produce different hazard values at same tick."""
        base = self._base_hazards()
        # Use tick 50 where sin values diverge clearly across phase offsets
        r0 = ca_rules.hazard_drift_step("s1", base, 50, 0, self._default_config())
        r1 = ca_rules.hazard_drift_step("s2", base, 50, 1, self._default_config())
        # At least one value should differ
        self.assertNotAlmostEqual(
            r0["radiation_level"], r1["radiation_level"], places=4
        )

    def test_periodic_returns_to_base(self):
        """After one full period, values should return close to base."""
        base = self._base_hazards(rad=0.1, thermal=300.0)
        period = 200
        result = ca_rules.hazard_drift_step(
            "s1", base, period, 0, self._default_config(hazard_drift_period=period),
        )
        # sin(2π) = 0 → drift = 0
        self.assertAlmostEqual(result["radiation_level"], 0.1, places=6)
        self.assertAlmostEqual(result["thermal_background_k"], 300.0, places=4)

    def test_zero_amplitude_no_drift(self):
        base = self._base_hazards(rad=0.1, thermal=300.0)
        cfg = self._default_config(hazard_radiation_amplitude=0.0, hazard_thermal_amplitude=0.0)
        result = ca_rules.hazard_drift_step("s1", base, 99, 2, cfg)
        self.assertAlmostEqual(result["radiation_level"], 0.1, places=8)
        self.assertAlmostEqual(result["thermal_background_k"], 300.0, places=8)


if __name__ == "__main__":
    unittest.main()
