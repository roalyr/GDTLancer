#
# PROJECT: GDTLancer
# MODULE: test_simulation_tick.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_13)
#

extends GutTest

## Unit tests for SimulationEngine: world-age cycling and sub-tick system.
## NOTE: SimulationEngine extends Node and must be added to the tree.

var engine: Node = null


func before_each():
	_clear_state()
	var Script = load("res://src/core/simulation/simulation_engine.gd")
	engine = Script.new()
	add_child(engine)


func after_each():
	if is_instance_valid(engine):
		engine.queue_free()
	engine = null
	_clear_state()


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_initialize_simulation_sets_world_age():
	engine.initialize_simulation("tick_test_seed")
	assert_eq(GameState.world_age, "PROSPERITY",
		"World should start in PROSPERITY age.")
	assert_eq(GameState.world_age_timer, Constants.WORLD_AGE_DURATIONS["PROSPERITY"],
		"Timer should be set to PROSPERITY duration.")

func test_process_tick_increments_counter():
	engine.initialize_simulation("tick_test_seed")
	var before: int = GameState.sim_tick_count
	engine.process_tick()
	assert_eq(GameState.sim_tick_count, before + 1,
		"process_tick should increment sim_tick_count by 1.")

func test_world_age_transitions_after_duration():
	engine.initialize_simulation("tick_test_seed")
	# Run ticks until PROSPERITY ends
	var prosperity_duration: int = Constants.WORLD_AGE_DURATIONS["PROSPERITY"]
	for _i in range(prosperity_duration):
		engine.process_tick()
	assert_eq(GameState.world_age, "DISRUPTION",
		"World should transition to DISRUPTION after PROSPERITY duration.")

func test_world_age_full_cycle():
	engine.initialize_simulation("tick_test_seed")
	var total_cycle: int = 0
	for age in Constants.WORLD_AGE_CYCLE:
		total_cycle += Constants.WORLD_AGE_DURATIONS[age]

	for _i in range(total_cycle):
		engine.process_tick()
	assert_eq(GameState.world_age, "PROSPERITY",
		"World should return to PROSPERITY after one full cycle.")
	assert_eq(GameState.world_age_cycle_count, 1,
		"Cycle count should be 1 after one full cycle.")

func test_sub_ticks_fire_full_tick():
	engine.initialize_simulation("tick_test_seed")
	var before: int = GameState.sim_tick_count

	var ticks_fired: int = engine.advance_sub_ticks(Constants.SUB_TICKS_PER_TICK)
	assert_eq(ticks_fired, 1, "One full tick should fire.")
	assert_eq(GameState.sim_tick_count, before + 1)

func test_sub_ticks_accumulate():
	engine.initialize_simulation("tick_test_seed")
	var before: int = GameState.sim_tick_count

	# Add half a tick worth of sub-ticks — should NOT fire
	var half: int = int(Constants.SUB_TICKS_PER_TICK / 2)
	var ticks_fired: int = engine.advance_sub_ticks(half)
	assert_eq(ticks_fired, 0, "Half threshold should not fire a full tick.")
	assert_eq(GameState.sim_tick_count, before, "Tick count unchanged.")

	# Add remaining half — should fire
	var remaining: int = Constants.SUB_TICKS_PER_TICK - half
	ticks_fired = engine.advance_sub_ticks(remaining)
	assert_eq(ticks_fired, 1, "Completing the threshold should fire one tick.")

func test_is_initialized():
	assert_false(engine.is_initialized(), "Should not be initialized before init call.")
	engine.initialize_simulation("tick_test_seed")
	assert_true(engine.is_initialized(), "Should be initialized after init call.")

func test_get_config_has_required_keys():
	engine.initialize_simulation("tick_test_seed")
	var config: Dictionary = engine.get_config()
	assert_true(config.has("colony_upgrade_ticks_required"), "Config must have colony_upgrade_ticks_required.")
	assert_true(config.has("respawn_cooldown_ticks"), "Config must have respawn_cooldown_ticks.")
	assert_true(config.has("mortal_global_cap"), "Config must have mortal_global_cap.")


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
