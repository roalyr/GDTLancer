#
# PROJECT: GDTLancer
# MODULE: test_simulation_integration.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_13)
#

extends GutTest

## Integration test: exercises the entire qualitative simulation stack end-to-end.
##
## Uses SimulationEngine (extends Node) which creates and wires all layers.
## Verifies topology, agent initialization, multi-tick stability,
## chronicle event flow, and world-age cycling with real templates.

var engine: Node = null

const TEST_SEED: String = "integration_test_seed"


func before_each():
	_clear_state()
	var Script = load("res://src/core/simulation/simulation_engine.gd")
	engine = Script.new()
	add_child(engine)
	engine.initialize_simulation(TEST_SEED)


func after_each():
	if is_instance_valid(engine):
		engine.queue_free()
	engine = null
	_clear_state()


# =============================================================================
# === INTEGRATION TESTS =======================================================
# =============================================================================

func test_full_stack_initialization():
	# World Layer
	assert_gt(GameState.world_topology.size(), 0,
		"world_topology should be populated from real templates.")
	assert_eq(GameState.world_topology.size(), GameState.world_hazards.size(),
		"Every sector must have hazard data.")

	# Grid Layer: sector_tags and colony_levels
	assert_eq(GameState.sector_tags.size(), GameState.world_topology.size(),
		"Every sector must have sector_tags.")
	assert_eq(GameState.colony_levels.size(), GameState.world_topology.size(),
		"Every sector must have a colony_level.")

	# Agent Layer
	assert_true(GameState.agents.has("player"),
		"Player agent must exist.")
	assert_gt(GameState.agents.size(), 1,
		"At least one NPC agent should exist alongside the player.")

	# Player has correct tag fields
	var player: Dictionary = GameState.agents["player"]
	assert_true(player.has("condition_tag"))
	assert_true(player.has("wealth_tag"))
	assert_true(player.has("cargo_tag"))

	# All agent sectors exist in topology
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		var sector: String = agent.get("current_sector_id", "")
		assert_true(GameState.world_topology.has(sector),
			"Agent '%s' sector '%s' must exist in world_topology." % [agent_id, sector])

	# World age
	assert_eq(GameState.world_age, "PROSPERITY",
		"Initial world age should be PROSPERITY.")


func test_multi_tick_stability():
	# Run 20 ticks and verify no crashes, agents stay in valid sectors
	for _i in range(20):
		engine.process_tick()

	assert_gt(GameState.sim_tick_count, 20,
		"sim_tick_count should have advanced.")

	# All agents still in valid sectors
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		var sector: String = agent.get("current_sector_id", "")
		assert_true(GameState.world_topology.has(sector),
			"Agent '%s' sector '%s' should still be valid after 20 ticks." % [agent_id, sector])

	# Sector tags still have exactly one security tag each
	for sector_id in GameState.sector_tags:
		var tags: Array = GameState.sector_tags[sector_id]
		var sec_count: int = 0
		for tag in ["SECURE", "CONTESTED", "LAWLESS"]:
			if tag in tags:
				sec_count += 1
		assert_eq(sec_count, 1,
			"Sector '%s' should have exactly one security tag after 20 ticks." % sector_id)


func test_chronicle_events_generated():
	# Run a few ticks and verify chronicle captures events
	for _i in range(5):
		engine.process_tick()

	assert_gt(GameState.chronicle_events.size(), 0,
		"chronicle_events should have at least one event after 5 ticks.")


func test_world_age_advances_through_cycle():
	var prosperity_duration: int = Constants.WORLD_AGE_DURATIONS["PROSPERITY"]
	for _i in range(prosperity_duration):
		engine.process_tick()

	assert_eq(GameState.world_age, "DISRUPTION",
		"World should transition to DISRUPTION after PROSPERITY duration.")


func test_sub_ticks_integration():
	var initial_tick: int = GameState.sim_tick_count
	var ticks_fired: int = engine.advance_sub_ticks(Constants.SUB_TICKS_PER_TICK * 2)
	assert_eq(ticks_fired, 2, "Two full ticks should fire from double sub-tick cost.")
	assert_eq(GameState.sim_tick_count, initial_tick + 2)


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	GameState.grid_dominion.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.agent_tags.clear()
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
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.world_tags = []
	GameState.mortal_agent_counter = 0
	GameState.mortal_agent_deaths = []
	GameState.discovered_sector_count = 0
	GameState.discovery_log = []
	GameState.sector_names.clear()
	GameState.catastrophe_log = []
	GameState.sector_disabled_until.clear()
	GameState.world_seed = ""
	GameState.world_age = ""
	GameState.world_age_timer = 0
	GameState.world_age_cycle_count = 0
	GameState.sim_tick_count = 0
	GameState.sub_tick_accumulator = 0
