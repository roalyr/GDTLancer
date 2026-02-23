#
# PROJECT: GDTLancer
# MODULE: test_grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_13)
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
	GameState.hostile_infestation_progress.clear()
	GameState.agents.clear()
	GameState.world_seed = ""
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
