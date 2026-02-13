#
# PROJECT: GDTLancer
# MODULE: test_ca_rules.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 1.2 (CA Catalogue)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for CARules: Pure CA transition functions.
## All functions must be stateless — no GameState mutation.

var ca_rules: Reference = null

func before_each():
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")
	ca_rules = CARulesScript.new()


# =============================================================================
# === strategic_map_step ======================================================
# =============================================================================

func test_strategic_map_influence_propagation():
	# Sector with only faction_a, neighbor has only faction_b.
	# After one step, sector should gain some faction_b influence.
	var sector_state := {
		"faction_influence": {"faction_a": 0.8},
		"security_level": 0.8,
		"pirate_activity": 0.1
	}
	var neighbor_states := [{
		"faction_influence": {"faction_b": 0.9},
		"security_level": 0.9,
		"pirate_activity": 0.0
	}]
	var config := {
		"influence_propagation_rate": 0.1,
		"pirate_activity_decay": 0.02,
		"pirate_activity_growth": 0.05
	}

	var result: Dictionary = ca_rules.strategic_map_step("test_sector", sector_state, neighbor_states, config)

	assert_true(result.has("faction_influence"), "Result must contain faction_influence.")
	assert_true(result["faction_influence"].has("faction_b"),
		"Faction B influence should propagate from neighbor.")
	assert_true(result["faction_influence"]["faction_b"] > 0.0,
		"Faction B influence should be positive after propagation.")
	# Original faction_a should still be present
	assert_true(result["faction_influence"].has("faction_a"),
		"Faction A should still be present.")


func test_strategic_map_pirate_activity_grows_in_low_security():
	var sector_state := {
		"faction_influence": {},  # No faction → 0 security
		"security_level": 0.0,
		"pirate_activity": 0.1
	}
	var config := {
		"influence_propagation_rate": 0.1,
		"pirate_activity_decay": 0.02,
		"pirate_activity_growth": 0.05
	}

	var result: Dictionary = ca_rules.strategic_map_step("test", sector_state, [], config)

	assert_true(result["pirate_activity"] > 0.1,
		"Pirate activity should grow when security is 0. Got: %f" % result["pirate_activity"])


# =============================================================================
# === supply_demand_step ======================================================
# =============================================================================

func test_supply_demand_extraction():
	var stockpiles := {
		"commodity_stockpiles": {"ore": 0.0},
		"stockpile_capacity": 1000,
		"extraction_rate": {}
	}
	var resource_potential := {
		"mineral_density": 100.0,
		"propellant_sources": 50.0
	}
	var config := {
		"extraction_rate_default": 0.01,
		"stockpile_diffusion_rate": 0.0  # Disable diffusion for this test
	}

	var result: Dictionary = ca_rules.supply_demand_step("test", stockpiles, resource_potential, [], config)

	# Extraction should have moved matter from potential to stockpiles
	var new_mineral: float = result["new_resource_potential"]["mineral_density"]
	assert_true(new_mineral < 100.0,
		"Mineral density should decrease after extraction. Got: %f" % new_mineral)

	var new_ore: float = result["new_stockpiles"]["commodity_stockpiles"].get("ore", 0.0)
	assert_true(new_ore > 0.0,
		"Ore stockpile should increase after extraction. Got: %f" % new_ore)

	# Matter should be conserved within this step
	var matter_extracted: float = result["matter_extracted"]
	assert_true(matter_extracted > 0.0, "matter_extracted should be positive.")

	# matter_extracted includes BOTH mineral and propellant extraction.
	# Verify that mineral depletion + propellant depletion == matter_extracted.
	var mineral_depleted: float = 100.0 - new_mineral
	var new_propellant: float = result["new_resource_potential"]["propellant_sources"]
	var propellant_depleted: float = 50.0 - new_propellant
	assert_almost_eq(mineral_depleted + propellant_depleted, matter_extracted, 0.001,
		"Total resource depletion should equal matter_extracted.")


func test_supply_demand_no_diffusion_in_pure_function():
	# Diffusion was moved to GridLayer (two-pass symmetric).
	# The pure supply_demand_step should NOT modify stockpiles for diffusion.
	var stockpiles := {
		"commodity_stockpiles": {"ore": 100.0},
		"stockpile_capacity": 1000,
		"extraction_rate": {}
	}
	var resource_potential := {
		"mineral_density": 0.0,
		"propellant_sources": 0.0
	}
	var neighbor := {
		"commodity_stockpiles": {"ore": 10.0},
		"stockpile_capacity": 1000,
		"extraction_rate": {}
	}
	var config := {
		"extraction_rate_default": 0.0,  # Disable extraction
		"stockpile_diffusion_rate": 0.1
	}

	var result: Dictionary = ca_rules.supply_demand_step("test", stockpiles, resource_potential, [neighbor], config)

	var new_ore: float = result["new_stockpiles"]["commodity_stockpiles"]["ore"]
	assert_eq(new_ore, 100.0,
		"Pure function should NOT apply diffusion. Ore should remain at 100. Got: %f" % new_ore)


# =============================================================================
# === market_pressure_step ====================================================
# =============================================================================

func test_market_pressure_pricing():
	var stockpiles_low := {
		"commodity_stockpiles": {"ore": 5.0},
		"stockpile_capacity": 1000
	}
	var stockpiles_high := {
		"commodity_stockpiles": {"ore": 500.0},
		"stockpile_capacity": 1000
	}
	var config := {"price_sensitivity": 0.5, "demand_base": 0.1}

	var result_low: Dictionary = ca_rules.market_pressure_step("test", stockpiles_low, 10.0, config)
	var result_high: Dictionary = ca_rules.market_pressure_step("test", stockpiles_high, 10.0, config)

	var delta_low: float = result_low["commodity_price_deltas"]["ore"]
	var delta_high: float = result_high["commodity_price_deltas"]["ore"]

	# Low supply → positive price delta (expensive)
	# High supply → negative price delta (cheap)
	assert_true(delta_low > delta_high,
		"Low supply should yield higher price delta than high supply. Low: %f, High: %f" % [delta_low, delta_high])


# =============================================================================
# === entropy_step ============================================================
# =============================================================================

func test_entropy_wreck_degradation():
	var wrecks := [{
		"wreck_uid": 1,
		"wreck_integrity": 0.5,
		"wreck_inventory": {"scrap": 10.0},
		"ship_template_id": "fighter",
		"created_at_tick": 0
	}]
	var hazards := {"radiation_level": 0.0, "thermal_background_k": 300.0, "gravity_well_penalty": 1.0}
	var config := {
		"wreck_degradation_per_tick": 0.05,
		"wreck_debris_return_fraction": 0.8,
		"entropy_radiation_multiplier": 2.0
	}

	var result: Dictionary = ca_rules.entropy_step("test", wrecks, hazards, config)

	assert_eq(result["surviving_wrecks"].size(), 1, "Wreck should survive with remaining integrity.")
	var new_integrity: float = result["surviving_wrecks"][0]["wreck_integrity"]
	assert_true(new_integrity < 0.5,
		"Wreck integrity should decrease. Got: %f" % new_integrity)


func test_entropy_matter_return():
	# Wreck with very low integrity — should be destroyed this tick
	var wrecks := [{
		"wreck_uid": 1,
		"wreck_integrity": 0.01,
		"wreck_inventory": {"scrap": 10.0},
		"ship_template_id": "fighter",
		"created_at_tick": 0
	}]
	var hazards := {"radiation_level": 0.0, "thermal_background_k": 300.0, "gravity_well_penalty": 1.0}
	var config := {
		"wreck_degradation_per_tick": 0.05,
		"wreck_debris_return_fraction": 0.8,
		"entropy_radiation_multiplier": 2.0
	}

	var result: Dictionary = ca_rules.entropy_step("test", wrecks, hazards, config)

	assert_eq(result["surviving_wrecks"].size(), 0, "Wreck should be destroyed.")
	assert_true(result["matter_returned"] > 0.0,
		"Matter should be returned when wreck is destroyed. Got: %f" % result["matter_returned"])


# =============================================================================
# === Purity assertion ========================================================
# =============================================================================

func test_all_ca_rules_are_pure():
	# Snapshot GameState before calling CA rules
	var topology_before: int = GameState.world_topology.size()
	var hazards_before: int = GameState.world_hazards.size()
	var agents_before: int = GameState.agents.size()
	var stockpiles_before: int = GameState.grid_stockpiles.size()

	# Call each CA rule with mock data
	var config := {
		"influence_propagation_rate": 0.1,
		"pirate_activity_decay": 0.02,
		"pirate_activity_growth": 0.05,
		"extraction_rate_default": 0.01,
		"stockpile_diffusion_rate": 0.05,
		"price_sensitivity": 0.5,
		"demand_base": 0.1,
		"wreck_degradation_per_tick": 0.05,
		"wreck_debris_return_fraction": 0.8,
		"entropy_radiation_multiplier": 2.0,
		"entropy_base_rate": 0.001
	}

	var mock_dominion := {"faction_influence": {"f1": 0.5}, "security_level": 0.5, "pirate_activity": 0.1}
	ca_rules.strategic_map_step("s1", mock_dominion, [mock_dominion], config)

	var mock_stk := {"commodity_stockpiles": {"ore": 50.0}, "stockpile_capacity": 1000, "extraction_rate": {}}
	var mock_res := {"mineral_density": 100.0, "propellant_sources": 50.0}
	ca_rules.supply_demand_step("s1", mock_stk, mock_res, [mock_stk], config)

	ca_rules.market_pressure_step("s1", mock_stk, 10.0, config)

	var mock_wreck := [{"wreck_uid": 1, "wreck_integrity": 0.5, "wreck_inventory": {}, "ship_template_id": "x", "created_at_tick": 0}]
	var mock_haz := {"radiation_level": 0.0, "thermal_background_k": 300.0, "gravity_well_penalty": 1.0}
	ca_rules.entropy_step("s1", mock_wreck, mock_haz, config)

	ca_rules.influence_network_step("a1", {"a2": 0.5}, [{"a2": 0.8}], config)
	ca_rules.power_load_step(100.0, 50.0)
	ca_rules.maintenance_pressure_step(mock_haz, config)

	# Verify GameState was NOT mutated
	assert_eq(GameState.world_topology.size(), topology_before, "CA rules must not mutate world_topology.")
	assert_eq(GameState.world_hazards.size(), hazards_before, "CA rules must not mutate world_hazards.")
	assert_eq(GameState.agents.size(), agents_before, "CA rules must not mutate agents.")
	assert_eq(GameState.grid_stockpiles.size(), stockpiles_before, "CA rules must not mutate grid_stockpiles.")
