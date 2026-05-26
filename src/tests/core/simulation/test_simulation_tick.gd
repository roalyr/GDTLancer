#
# PROJECT: GDTLancer
# MODULE: test_simulation_tick.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_3
## LOG_REF: 2026-05-26 19:02:00
#

extends GutTest

## Unit tests for SimulationEngine: world-age cycling and sub-tick system.
## NOTE: SimulationEngine extends Node and must be added to the tree.

var engine: Node = null


class TickOrderSpy extends Reference:
	var order: Array = []
	var label: String = ""
	var delegate: Reference = null

	func _init(p_order: Array, p_label: String, p_delegate: Reference = null) -> void:
		order = p_order
		label = p_label
		delegate = p_delegate

	func process_tick(config: Dictionary) -> void:
		order.append(label)
		if delegate != null and delegate.has_method("process_tick"):
			delegate.process_tick(config)


class AgentOrderSpy extends Reference:
	var order: Array = []
	var seen_occurrence_count: int = -1

	func _init(p_order: Array) -> void:
		order = p_order

	func process_tick(_config: Dictionary) -> void:
		seen_occurrence_count = GameState.runtime_contract_occurrences.size()
		order.append("agent")


func before_each():
	_clear_state()
	_seed_template_database()
	var Script = load("res://src/core/simulation/simulation_engine.gd")
	engine = Script.new()
	add_child_autofree(engine)


func after_each():
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
	assert_true(config.has("contract_occurrence_global_cap"), "Config must have contract_occurrence_global_cap.")


func test_initialize_simulation_bootstraps_starter_contracts_before_first_tick():
	engine.initialize_simulation("tick_test_seed")

	assert_gt(GameState.runtime_contract_occurrences.size(), 0,
		"Initialization should preseed runtime contracts from authored starting poor sectors before the first live tick.")
	assert_gt(Array(GameState.runtime_contract_occurrences_by_source_sector.get(Constants.INITIAL_SECTOR_ID, [])).size(), 0,
		"Initialization should expose source-side player-facing contracts at the starter sector before the first docking tick.")


func test_contract_generation_runs_between_bridge_and_agent_layer():
	engine.initialize_simulation("tick_test_seed")
	GameState.world_age_timer = 5
	_seed_contract_tick_state()

	var order: Array = []
	engine.grid_layer = TickOrderSpy.new(order, "grid")
	engine.bridge_systems = TickOrderSpy.new(order, "bridge")
	engine.contract_generation_system = TickOrderSpy.new(order, "contract", engine.contract_generation_system)
	var agent_spy = AgentOrderSpy.new(order)
	engine.agent_layer = agent_spy
	engine.chronicle_layer = TickOrderSpy.new(order, "chronicle")
	engine.set_config("contract_occurrence_global_cap", 1)
	engine.set_config("contract_occurrence_per_sector_cap", 1)
	engine.set_config("contract_source_search_max_hops", 1)

	engine.process_tick()

	assert_eq(order, ["grid", "bridge", "contract", "agent", "chronicle"],
		"SimulationEngine should run contract generation after BridgeSystems and before AgentLayer.")
	assert_eq(agent_spy.seen_occurrence_count, 1,
		"AgentLayer should observe runtime contract occurrences generated earlier in the same tick.")
	assert_true(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"Contract generation should run during the tick and produce the expected occurrence.")


func test_run_composite_research_report_advances_once_to_largest_requested_window():
	engine.initialize_simulation("tick_test_seed")
	var report: String = engine.run_composite_research_report([5, 10], {})

	assert_true(report.find("COMPOSITE RESEARCH CHRONICLE") != -1,
		"SimulationEngine should expose the new composite research report surface.")
	assert_true(report.find("COMPOSITE WINDOW: 5 ticks") != -1,
		"Composite reports should include the first requested milestone.")
	assert_true(report.find("COMPOSITE WINDOW: 10 ticks") != -1,
		"Composite reports should include the largest requested milestone.")
	assert_eq(GameState.sim_tick_count, 10,
		"Composite reporting should advance the live simulation only to the largest requested cumulative window.")


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
	GameState.contract_generation_pressure.clear()
	GameState.contract_generation_threshold.clear()
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
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
	TemplateDatabase.actions.clear()
	TemplateDatabase.agents.clear()
	TemplateDatabase.characters.clear()
	TemplateDatabase.assets_ships.clear()
	TemplateDatabase.assets_modules.clear()
	TemplateDatabase.assets_commodities.clear()
	TemplateDatabase.locations.clear()
	TemplateDatabase.contracts.clear()
	TemplateDatabase.utility_tools.clear()
	TemplateDatabase.factions.clear()
	TemplateDatabase.contacts.clear()


func _seed_contract_tick_state() -> void:
	GameState.world_topology = {
		"a": {"connections": ["b"], "sector_type": "colony", "station_ids": ["a"]},
		"b": {"connections": ["a"], "sector_type": "colony", "station_ids": ["b"]},
	}
	GameState.sector_names = {"a": "Alpha", "b": "Beta"}
	GameState.sector_tags = {
		"a": [
			"STATION", "CONTESTED", "MILD",
			"RAW_POOR", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE",
			"CONTRACT_DEMAND_RAW", "RELIEF_NEEDED"
		],
		"b": [
			"STATION", "SECURE", "MILD",
			"RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"
		],
	}
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()


func _seed_template_database() -> void:
	var TemplateIndexer = load("res://src/scenes/game_world/world_manager/template_indexer.gd")
	var indexer = TemplateIndexer.new()
	indexer.index_all_templates()
	indexer.free()
