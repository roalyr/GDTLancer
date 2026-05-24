#
# PROJECT: GDTLancer
# MODULE: test_grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3 + TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-05-24 19:53:28
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


func test_economy_transitions_require_sustained_pressure():
	# Sector "a" is RAW_POOR. With a loaded trader present during RECOVERY,
	# it should upgrade to RAW_ADEQUATE after threshold ticks.
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

	# Tick 1 & 2: should still be RAW_POOR (pressure accumulating)
	grid.process_tick({})
	assert_has(GameState.sector_tags["a"], "RAW_POOR",
		"RAW_POOR should persist after 1 tick (threshold=3).")

	grid.process_tick({})
	assert_has(GameState.sector_tags["a"], "RAW_POOR",
		"RAW_POOR should persist after 2 ticks.")

	# Tick 3: threshold reached, should upgrade
	grid.process_tick({})
	assert_has(GameState.sector_tags["a"], "RAW_ADEQUATE",
		"RAW_POOR should upgrade to RAW_ADEQUATE after 3 ticks of pressure.")
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

	# Tick 1 & 2: not yet infested
	grid.process_tick({})
	assert_does_not_have(GameState.sector_tags["b"], "HOSTILE_INFESTED",
		"HOSTILE_INFESTED should NOT appear after 1 tick.")

	grid.process_tick({})
	assert_does_not_have(GameState.sector_tags["b"], "HOSTILE_INFESTED",
		"HOSTILE_INFESTED should NOT appear after 2 ticks.")

	# Tick 3: infestation threshold reached
	grid.process_tick({})
	assert_has(GameState.sector_tags["b"], "HOSTILE_INFESTED",
		"HOSTILE_INFESTED should appear after 3 ticks of LAWLESS+HARSH.")


func test_colony_hub_maintenance_drains_economy():
	# A hub with zero trade activity should see economy decay
	_clear_state()
	GameState.world_seed = "maint-seed"
	GameState.world_age = "PROSPERITY"
	GameState.world_topology = {
		"hub_sector": {"connections": [], "sector_type": "hub", "station_ids": ["hub_sector"]},
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
		["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)

	for _i in range(Constants.FRONTIER_COLONY_UPGRADE_TICKS_REQUIRED - 1):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "frontier",
		"Frontier sectors should require the longer stabilization threshold before becoming outposts.")

	grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "outpost",
		"A stable frontier sector should eventually advance once the longer frontier threshold is actually met.")


func test_extreme_frontier_cannot_upgrade_until_conditions_soften():
	_seed_single_sector_state(
		"frontier_extreme_seed",
		["FRONTIER", "CONTESTED", "EXTREME", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"frontier"
	)

	for _i in range(Constants.FRONTIER_COLONY_UPGRADE_TICKS_REQUIRED + 2):
		grid.process_tick({})

	assert_eq(GameState.colony_levels["frontier_sector"], "frontier",
		"Extreme frontier sectors should not upgrade into outposts until their environment is no longer the blocked frontier state.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _seed_minimal_state() -> void:
	GameState.world_seed = "grid_test_seed"
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"a": {"connections": ["b"], "sector_type": "colony", "station_ids": ["a"]},
		"b": {"connections": ["a"], "sector_type": "colony", "station_ids": ["b"]},
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
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"frontier_sector": {"connections": [], "sector_type": "frontier", "station_ids": ["frontier_sector"]},
	}
	GameState.sector_tags = {
		"frontier_sector": Array(tags),
	}
	GameState.grid_dominion = {"frontier_sector": {"security_tag": grid._security_tag(tags)}}
	GameState.world_hazards = {"frontier_sector": {"environment": grid._environment_tag(tags)}}
	GameState.agents = {}
	grid.initialize_grid()
	GameState.colony_levels["frontier_sector"] = colony_level
	GameState.security_change_threshold["frontier_sector"] = 1
	GameState.economy_change_threshold["frontier_sector"] = {"RAW": 1, "MANUFACTURED": 1, "CURRENCY": 1}


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
	GameState.hostile_infestation_progress.clear()
	GameState.agents.clear()
	GameState.world_seed = ""
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
