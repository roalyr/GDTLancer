# PROJECT: GDTLancer
# MODULE: test_grid_layer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: test_grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_SIMULATION-GRAPH.md §3; TACTICAL_TODO.md TASK_7
# LOG_REF: 2026-05-26 18:08:00
#

extends GutTest

## Unit tests for GridLayer: qualitative CA tag-transition engine.
## Ported from Python test_affinity.py::TestTagTransitionCA.

var grid: Reference = null


func before_each():
	_clear_state()
	var Script = load("res://src/core/simulation/grid_layer.gd")
	grid = Script.new()
	_seed_minimal_state()


func after_each():
	_clear_state()
	grid = null


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_initialize_grid_seeds_progress_counters():
	grid.initialize_grid()
	for sector_id in GameState.world_topology:
		assert_true(GameState.colony_levels.has(sector_id),
			"colony_levels should be seeded for '%s'." % sector_id)
		assert_true(GameState.economy_upgrade_progress.has(sector_id),
			"economy_upgrade_progress should be seeded for '%s'." % sector_id)
		assert_true(GameState.security_upgrade_progress.has(sector_id),
			"security_upgrade_progress should be seeded for '%s'." % sector_id)
		assert_true(GameState.contract_generation_pressure.has(sector_id),
			"contract_generation_pressure should be seeded for '%s'." % sector_id)
		assert_true(GameState.contract_generation_threshold.has(sector_id),
			"contract_generation_threshold should be seeded for '%s'." % sector_id)
		assert_true(GameState.contract_cargo_supply.has(sector_id),
			"contract_cargo_supply should be seeded for '%s'." % sector_id)
		assert_true(GameState.contract_payment_supply.has(sector_id),
			"contract_payment_supply should be seeded for '%s'." % sector_id)


func test_contract_accounting_refills_toward_cap_without_resetting_reservations():
	grid.initialize_grid()
	GameState.economy_change_threshold["a"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.economy_change_threshold["b"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.contract_cargo_supply["b"]["RAW"] = 0
	GameState.contract_cargo_reserved["b"]["RAW"] = 1
	GameState.contract_payment_supply["a"]["RAW"] = 0
	GameState.contract_payment_reserved["a"]["RAW"] = 1

	grid.process_tick({})

	assert_eq(int(GameState.contract_cargo_supply["b"].get("RAW", -1)), 1,
		"Contract cargo supply should recover by one unit per tick toward the tag-derived cap.")
	assert_eq(int(GameState.contract_cargo_reserved["b"].get("RAW", -1)), 1,
		"Reserved contract cargo should remain locked while the source sector recovers around it.")
	assert_eq(int(GameState.contract_payment_supply["a"].get("RAW", -1)), 1,
		"Contract payment supply should recover by one unit per tick toward the sector cap.")
	assert_eq(int(GameState.contract_payment_reserved["a"].get("RAW", -1)), 1,
		"Reserved payment bundles should remain locked until a claim is released or completed.")


func test_economy_transitions_require_sustained_pressure():
	# Sector "a" is RAW_POOR. With a loaded trader present during RECOVERY,
	# it should upgrade only after the effective recovery-adjusted threshold.
	GameState.world_age = "RECOVERY"
	GameState.agents["trader_1"] = {
		"current_sector_id": "a",
		"agent_role": "trader",
		"cargo_tag": "LOADED",
		"is_disabled": false,
	}

	grid.initialize_grid()

	# Force economy threshold to 3 for predictability
	GameState.economy_change_threshold["a"] = {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3}
	var effective_threshold: int = grid._economy_upgrade_threshold_for_level(3, GameState.colony_levels["a"])

	for _i in range(effective_threshold - 1):
		grid.process_tick({})
		assert_has(GameState.sector_tags["a"], "RAW_POOR",
			"RAW_POOR should persist until the effective recovery-adjusted threshold is met.")

	# Once the effective threshold is reached, the poor tag should clear.
	grid.process_tick({})
	assert_has(GameState.sector_tags["a"], "RAW_ADEQUATE",
		"RAW_POOR should upgrade to RAW_ADEQUATE once the effective threshold is reached.")
	assert_does_not_have(GameState.sector_tags["a"], "RAW_POOR",
		"RAW_POOR tag should be removed after upgrade.")


func test_contract_demand_tags_require_sustained_pressure():
	grid.initialize_grid()
	GameState.economy_change_threshold["a"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.contract_generation_threshold["a"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}

	grid.process_tick({})
	assert_does_not_have(GameState.sector_tags["a"], "CONTRACT_DEMAND_RAW",
		"Demand tags should not appear before their threshold is met.")
	assert_eq(GameState.contract_generation_pressure["a"]["RAW"], 1,
		"Pressure should increment while RAW_POOR pressure is sustained.")

	grid.process_tick({})
	var tags: Array = GameState.sector_tags["a"]
	assert_has(tags, "CONTRACT_DEMAND_RAW",
		"RAW demand should appear after sustained poor pressure.")
	assert_has(tags, "CONTRACT_DEMAND_MANUFACTURED",
		"MANUFACTURED demand should appear after sustained poor pressure.")
	assert_has(tags, "CONTRACT_DEMAND_CURRENCY",
		"CURRENCY demand should appear after sustained poor pressure.")
	assert_has(tags, "RELIEF_NEEDED",
		"Multiple simultaneous demand tags should surface RELIEF_NEEDED.")


func test_trade_relief_tags_active_then_clear_contract_pressure():
	grid.initialize_grid()
	GameState.economy_change_threshold["a"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.contract_generation_threshold["a"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}

	for _i in range(3):
		grid.process_tick({})

	assert_has(GameState.sector_tags["a"], "CONTRACT_DEMAND_RAW",
		"Demand should be active before relief arrives.")

	GameState.agents["relief_trader"] = {
		"current_sector_id": "a",
		"agent_role": "trader",
		"cargo_tag": "LOADED",
		"is_disabled": false,
	}

	grid.process_tick({})
	var active_relief_tags: Array = GameState.sector_tags["a"]
	assert_has(active_relief_tags, "TRADE_LANE_ACTIVE",
		"Active relief traffic should surface a trade-lane tag while demand remains active.")
	assert_has(active_relief_tags, "CONTRACT_DEMAND_RAW",
		"Demand should persist for one tick while relief pressure decays.")

	grid.process_tick({})
	var cleared_tags: Array = GameState.sector_tags["a"]
	assert_does_not_have(cleared_tags, "CONTRACT_DEMAND_RAW",
		"Demand should clear once relief reduces pressure below the threshold.")
	assert_does_not_have(cleared_tags, "RELIEF_NEEDED",
		"RELIEF_NEEDED should clear after demand pressure resolves.")
	assert_does_not_have(cleared_tags, "TRADE_LANE_ACTIVE",
		"TRADE_LANE_ACTIVE should clear once no demand tag remains.")


func test_contract_demand_tags_clear_when_pressure_drops_below_threshold_gate():
	grid.initialize_grid()
	GameState.economy_change_threshold["a"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.contract_generation_threshold["a"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}

	# Build active demand first.
	for _i in range(3):
		grid.process_tick({})

	assert_has(GameState.sector_tags["a"], "CONTRACT_DEMAND_RAW",
		"Precondition: RAW demand should be active before forcing pressure below threshold.")

	# Completion-style relief mutates pressure directly; this test verifies the
	# GridLayer gate responds strictly to pressure-threshold state on the next tick.
	GameState.contract_generation_pressure["a"]["RAW"] = 0

	grid.process_tick({})

	assert_does_not_have(GameState.sector_tags["a"], "CONTRACT_DEMAND_RAW",
		"Demand tags should clear when pressure is below threshold, preserving deterministic gate behavior for completion relief paths.")


func test_security_only_one_tag_present():
	grid.initialize_grid()
	grid.process_tick({})
	for sector_id in GameState.sector_tags:
		var tags: Array = GameState.sector_tags[sector_id]
		var security_count: int = 0
		for tag in ["SECURE", "CONTESTED", "LAWLESS"]:
			if tag in tags:
				security_count += 1
		assert_eq(security_count, 1,
			"Sector '%s' should have exactly one security tag. Tags: %s" % [sector_id, str(tags)])


func test_hostile_infestation_builds_gradually():
	GameState.world_age = "DISRUPTION"
	GameState.sector_tags["a"] = ["STATION", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
	GameState.sector_tags["b"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
	GameState.agents["mil_1"]["is_disabled"] = true

	grid.initialize_grid()
	GameState.hostile_infestation_progress["b"] = 0

	var infestation_threshold: int = int(Constants.HOSTILE_INFESTATION_TICKS_REQUIRED)
	for _i in range(infestation_threshold - 1):
		grid.process_tick({})
		assert_does_not_have(GameState.sector_tags["b"], "HOSTILE_INFESTED",
			"HOSTILE_INFESTED should not appear before the current live infestation threshold is met.")

	grid.process_tick({})
	assert_has(GameState.sector_tags["b"], "HOSTILE_INFESTED",
		"HOSTILE_INFESTED should appear once the current live infestation threshold is reached under sustained LAWLESS+HARSH pressure.")


func test_colony_hub_maintenance_drains_economy():
	# A hub with zero trade activity should see economy decay
	_clear_state()
	GameState.world_seed = "maint-seed"
	GameState.world_age = "PROSPERITY"
	GameState.world_topology = {
		"hub_sector": {"connections": [], "development_level": "hub", "station_ids": ["hub_sector"]},
	}
	GameState.sector_tags = {
		"hub_sector": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
	}
	GameState.grid_dominion = {"hub_sector": {"security_tag": "SECURE"}}
	GameState.world_hazards = {"hub_sector": {"environment": "MILD"}}
	GameState.agents = {}

	grid.initialize_grid()

	# Force low economy thresholds
	GameState.economy_change_threshold["hub_sector"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}
	GameState.colony_levels["hub_sector"] = "hub"

	for _i in range(10):
		grid.process_tick({})

	var tags: Array = GameState.sector_tags["hub_sector"]
	assert_does_not_have(tags, "RAW_RICH",
		"Hub with no trade should lose RAW_RICH over 10 ticks.")
	assert_does_not_have(tags, "MANUFACTURED_RICH",
		"Hub with no trade should lose MANUFACTURED_RICH.")
	assert_does_not_have(tags, "CURRENCY_RICH",
		"Hub with no trade should lose CURRENCY_RICH.")


func test_frontier_security_caps_at_contested_until_outpost():
	_seed_single_sector_state(
		"frontier_security_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)

	grid.process_tick({})

	assert_has(GameState.sector_tags["frontier_sector"], "CONTESTED",
		"Frontier sectors should not retain SECURE while they are still at the frontier colony level.")
	assert_does_not_have(GameState.sector_tags["frontier_sector"], "SECURE",
		"Frontier sectors should stay capped at CONTESTED until they progress into an outpost.")


func test_frontier_economy_caps_at_adequate_until_outpost():
	_seed_single_sector_state(
		"frontier_economy_seed",
		["FRONTIER", "CONTESTED", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
		"frontier"
	)

	grid.process_tick({})

	var tags: Array = GameState.sector_tags["frontier_sector"]
	assert_has(tags, "RAW_ADEQUATE",
		"Frontier sectors should not keep RAW_RICH before they stabilize into an outpost.")
	assert_has(tags, "MANUFACTURED_ADEQUATE",
		"Frontier sectors should not keep MANUFACTURED_RICH before they stabilize into an outpost.")
	assert_has(tags, "CURRENCY_ADEQUATE",
		"Frontier sectors should not keep CURRENCY_RICH before they stabilize into an outpost.")
	assert_does_not_have(tags, "RAW_RICH",
		"Frontier sectors should be capped at ADEQUATE economy while they are still frontier-level.")


func test_frontier_colony_upgrade_requires_extended_stability():
	_seed_single_sector_state(
		"frontier_upgrade_seed",
		["FRONTIER", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)
	var frontier_threshold: int = grid._colony_upgrade_threshold_for_level("frontier")

	for _i in range(frontier_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "frontier",
		"Frontier sectors should require their full current stabilization threshold before becoming outposts.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"A stable frontier sector should eventually advance once the longer frontier threshold is actually met.")


func test_extreme_frontier_cannot_upgrade_until_conditions_soften():
	_seed_single_sector_state(
		"frontier_extreme_seed",
		["FRONTIER", "CONTESTED", "EXTREME", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)

	var frontier_threshold: int = grid._colony_upgrade_threshold_for_level("frontier")
	for _i in range(frontier_threshold + 2):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "frontier",
		"Extreme frontier sectors should not upgrade into outposts even after the current live stabilization window if their environment stays in the blocked frontier state.")


func test_harsh_frontier_can_upgrade_once_stability_window_is_met():
	_seed_single_sector_state(
		"frontier_harsh_seed",
		["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)
	var frontier_threshold: int = grid._colony_upgrade_threshold_for_level("frontier")

	for _i in range(frontier_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "frontier",
		"Harsh frontier sectors should still respect the full current stabilization threshold before becoming outposts.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"Harsh frontier sectors should be allowed to mature once the stability window is met; only extreme conditions should hard-block promotion.")


func test_outpost_colony_upgrade_requires_extended_stability():
	_seed_single_sector_state(
		"outpost_upgrade_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE"],
		"outpost"
	)
	var colony_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")

	for _i in range(colony_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"Outposts should hold their intermediate identity for the full current stabilization threshold before maturing into colonies.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "colony",
		"A stable outpost should still eventually advance once the longer outpost threshold is actually met.")


func test_late_prosperity_allows_stable_outpost_to_advance_sooner():
	_seed_single_sector_state(
		"outpost_late_prosperity_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE"],
		"outpost"
	)
	var baseline_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = max(1, int(Constants.WORLD_AGE_DURATIONS["PROSPERITY"] * 0.2))
	var reduced_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	assert_lt(reduced_threshold, baseline_threshold,
		"Late prosperity should shorten the outpost stabilization window relative to the current early-prosperity threshold from the live helper path.")

	for _i in range(reduced_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"Stable outposts should still wait for the reduced late-prosperity threshold rather than upgrading immediately.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "colony",
		"Late prosperity should let a stable outpost mature sooner than the base threshold so the world can grow into colonies and hubs organically.")


func test_outpost_colony_upgrade_requires_at_least_one_rich_economy_tag():
	_seed_single_sector_state(
		"outpost_rich_gate_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"outpost"
	)
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}

	var colony_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	for _i in range(colony_threshold + 2):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"Adequate outposts should not normalize into colonies until at least part of their economy actually matures beyond the floor state.")


func test_single_rich_outpost_needs_growth_support_before_becoming_colony():
	_seed_single_sector_state(
		"outpost_growth_support_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"outpost"
	)
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}

	var colony_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	for _i in range(colony_threshold + 2):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"A one-rich outpost without active commerce or settled support should hold as an outpost instead of normalizing into a colony by default.")


func test_supported_single_rich_outpost_can_still_mature_into_colony():
	_clear_state()
	GameState.world_seed = "outpost_supported_growth_seed"
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"frontier_sector": {"connections": ["inner_colony"], "development_level": "frontier", "station_ids": ["frontier_sector"]},
		"inner_colony": {"connections": ["frontier_sector"], "development_level": "colony", "station_ids": ["inner_colony"]},
	}
	GameState.sector_tags = {
		"frontier_sector": ["FRONTIER", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"inner_colony": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
	}
	GameState.grid_dominion = {
		"frontier_sector": {"security_tag": "SECURE"},
		"inner_colony": {"security_tag": "SECURE"},
	}
	GameState.world_hazards = {
		"frontier_sector": {"environment": "MILD"},
		"inner_colony": {"environment": "MILD"},
	}
	GameState.agents = {}

	grid.initialize_grid()
	GameState.colony_levels["frontier_sector"] = "outpost"
	GameState.colony_levels["inner_colony"] = "colony"
	GameState.security_change_threshold["frontier_sector"] = 1
	GameState.security_change_threshold["inner_colony"] = 1
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.economy_change_threshold["inner_colony"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}

	var colony_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	for _i in range(colony_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"Supported outposts should still respect the full stabilization window before maturing.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "colony",
		"A one-rich outpost that is already linked into a settled colony network should still be able to mature organically.")


func test_colony_hub_upgrade_requires_rich_economy():
	_seed_single_sector_state(
		"colony_hub_gate_seed",
		["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"colony"
	)
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}

	var hub_threshold: int = grid._colony_upgrade_threshold_for_level("colony")
	for _i in range(hub_threshold + 2):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "colony",
		"Adequate colonies should not promote into hubs until they actually reach the richer economy gate for the final maturity step.")


func test_late_prosperity_colony_hub_upgrade_stays_slower_than_outpost_growth():
	_seed_single_sector_state(
		"colony_late_prosperity_seed",
		["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
		"colony"
	)
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = max(1, int(Constants.WORLD_AGE_DURATIONS["PROSPERITY"] * 0.2))

	var hub_threshold: int = grid._colony_upgrade_threshold_for_level("colony")
	var outpost_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	assert_true(hub_threshold >= outpost_threshold,
		"Late prosperity should not make colony-to-hub maturation faster than outpost-to-colony growth; the richer economy gate still keeps hubs slower in practice.")

	for _i in range(hub_threshold - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "colony",
		"Rich colonies should still wait for the longer late-prosperity hub threshold instead of upgrading immediately.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "hub",
		"Late prosperity should still allow a rich, stable colony to become a hub once the slower final threshold is actually met.")


func test_recovery_raises_colony_hub_upgrade_threshold():
	_seed_single_sector_state(
		"colony_recovery_seed",
		["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
		"colony"
	)
	var prosperity_threshold: int = grid._colony_upgrade_threshold_for_level("colony")
	GameState.world_age = "RECOVERY"

	var recovery_threshold: int = grid._colony_upgrade_threshold_for_level("colony")
	assert_gt(recovery_threshold, prosperity_threshold,
		"Recovery should require a longer colony-to-hub stabilization window than the current prosperity baseline from the live helper path.")


func test_recovery_raises_outpost_colony_upgrade_threshold():
	_seed_single_sector_state(
		"outpost_recovery_seed",
		["FRONTIER", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"outpost"
	)
	var prosperity_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	GameState.world_age = "RECOVERY"

	var recovery_threshold: int = grid._colony_upgrade_threshold_for_level("outpost")
	assert_gt(recovery_threshold, prosperity_threshold,
		"Recovery should require a longer outpost-to-colony stabilization window than the current prosperity baseline from the live helper path.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _seed_minimal_state() -> void:
	GameState.world_seed = "grid_test_seed"
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS["PROSPERITY"]
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"a": {"connections": ["b"], "development_level": "colony", "station_ids": ["a"]},
		"b": {"connections": ["a"], "development_level": "colony", "station_ids": ["b"]},
	}
	GameState.sector_tags = {
		"a": ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"],
		"b": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
	}
	GameState.grid_dominion = {"a": {"security_tag": "SECURE"}, "b": {"security_tag": "SECURE"}}
	GameState.world_hazards = {"a": {"environment": "MILD"}, "b": {"environment": "MILD"}}
	GameState.agents = {
		"mil_1": {"current_sector_id": "a", "agent_role": "military", "is_disabled": false, "cargo_tag": "EMPTY"},
		"pir_1": {"current_sector_id": "b", "agent_role": "pirate", "is_disabled": false, "cargo_tag": "EMPTY"},
	}


func _seed_single_sector_state(seed_string: String, tags: Array, colony_level: String) -> void:
	_clear_state()
	GameState.world_seed = seed_string
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS["PROSPERITY"]
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"frontier_sector": {"connections": [], "development_level": "frontier", "station_ids": ["frontier_sector"]},
	}
	GameState.sector_tags = {
		"frontier_sector": Array(tags),
	}
	GameState.grid_dominion = {"frontier_sector": {"security_tag": grid._security_tag(tags)}}
	GameState.world_hazards = {"frontier_sector": {"environment": grid._environment_tag(tags)}}
	GameState.agents = {}
	grid.initialize_grid()
	GameState.colony_levels["frontier_sector"] = colony_level
	GameState.security_change_threshold["frontier_sector"] = 99
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 99, "MANUFACTURED": 99, "CURRENCY": 99}


func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	GameState.grid_dominion.clear()
	GameState.colony_levels.clear()
	GameState.colony_upgrade_progress.clear()
	GameState.colony_downgrade_progress.clear()
	GameState.security_upgrade_progress.clear()
	GameState.security_downgrade_progress.clear()
	GameState.security_change_threshold.clear()
	GameState.economy_upgrade_progress.clear()
	GameState.economy_downgrade_progress.clear()
	GameState.economy_change_threshold.clear()
	GameState.contract_generation_pressure.clear()
	GameState.contract_generation_threshold.clear()
	GameState.contract_cargo_supply.clear()
	GameState.contract_cargo_reserved.clear()
	GameState.contract_payment_supply.clear()
	GameState.contract_payment_reserved.clear()
	GameState.hostile_infestation_progress.clear()
	GameState.agents.clear()
	GameState.world_seed = ""
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = 0
	GameState.sim_tick_count = 0
