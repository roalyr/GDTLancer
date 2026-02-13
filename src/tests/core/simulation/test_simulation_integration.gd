#
# PROJECT: GDTLancer
# MODULE: test_simulation_integration.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends GutTest

## Integration test: exercises the entire simulation stack end-to-end.
##
## This test indexes real templates, initializes all four layers, runs
## multiple ticks, and verifies Conservation Axiom 1, chronicle events,
## agent state integrity, and save/load round-trip fidelity.
## Any parse errors, missing classes, or broken dependencies will surface here.


var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var chronicle_layer: Reference = null
var ca_rules: Reference = null
var _indexer: Node = null
var _config: Dictionary = {}

const TEST_SEED: String = "integration_test_seed"
const SAVE_SLOT: int = 998


func before_all():
	# Index ALL real templates — catches missing/broken .tres and class_name issues.
	var TemplateIndexer = load("res://src/scenes/game_world/world_manager/template_indexer.gd")
	_indexer = TemplateIndexer.new()
	add_child(_indexer)
	_indexer.index_all_templates()


func after_all():
	if is_instance_valid(_indexer):
		_indexer.queue_free()
	# Clean up test save file
	var dir = Directory.new()
	var save_path = GameStateManager.SAVE_DIR + GameStateManager.SAVE_FILE_PREFIX + str(SAVE_SLOT) + ".sav"
	if dir.file_exists(save_path):
		dir.remove(save_path)


func before_each():
	_clear_game_state()

	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript = load("res://src/core/simulation/bridge_systems.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	chronicle_layer = ChronicleLayerScript.new()
	ca_rules = CARulesScript.new()
	grid_layer.ca_rules = ca_rules

	# Full four-layer initialization
	world_layer.initialize_world(TEST_SEED)
	grid_layer.initialize_grid()
	agent_layer.initialize_agents()
	world_layer.recalculate_total_matter()

	_config = _build_config()


func after_each():
	_clear_game_state()
	world_layer = null
	grid_layer = null
	agent_layer = null
	bridge_systems = null
	chronicle_layer = null
	ca_rules = null


# =============================================================================
# === INTEGRATION TESTS =======================================================
# =============================================================================

func test_full_stack_initialization():
	# All four layers should be populated with real data.
	assert_true(TemplateDatabase.locations.size() > 0,
		"TemplateDatabase should have indexed at least one location.")
	assert_true(TemplateDatabase.agents.size() > 0,
		"TemplateDatabase should have indexed at least one agent template.")
	assert_true(TemplateDatabase.characters.size() > 0,
		"TemplateDatabase should have indexed at least one character template.")

	# Layer 1: World
	assert_true(GameState.world_topology.size() > 0,
		"world_topology should be populated from real location templates.")
	assert_eq(GameState.world_topology.size(), GameState.world_hazards.size(),
		"Every sector must have hazard data.")
	assert_eq(GameState.world_topology.size(), GameState.world_resource_potential.size(),
		"Every sector must have resource potential.")
	assert_true(GameState.world_total_matter > 0.0,
		"world_total_matter should be positive. Got: %.4f" % GameState.world_total_matter)

	# Layer 2: Grid
	assert_eq(GameState.grid_stockpiles.size(), GameState.world_topology.size(),
		"Every sector must have grid_stockpiles.")
	assert_eq(GameState.grid_dominion.size(), GameState.world_topology.size(),
		"Every sector must have grid_dominion.")

	# Layer 3: Agents
	assert_true(GameState.agents.has("player"),
		"Player agent must exist.")
	assert_true(GameState.agents.size() > 1,
		"At least one NPC agent should exist alongside the player. Got: %d" % GameState.agents.size())
	assert_true(GameState.player_character_uid >= 0,
		"player_character_uid should be set.")

	# Verify all agent sectors exist in topology
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		var sector: String = agent.get("current_sector_id", "")
		assert_true(GameState.world_topology.has(sector),
			"Agent '%s' sector '%s' must exist in world_topology." % [agent_id, sector])


func test_multi_tick_matter_conservation():
	# Run 10 ticks and verify Axiom 1 (matter conservation) holds at each step.
	var initial_matter: float = GameState.world_total_matter
	var tolerance: float = _config.get("axiom1_tolerance", 0.01)

	for tick_idx in range(10):
		GameState.sim_tick_count += 1
		grid_layer.process_tick(_config)
		bridge_systems.process_tick(_config)
		agent_layer.process_tick(_config)
		chronicle_layer.process_tick()

		world_layer.recalculate_total_matter()
		var current_matter: float = GameState.world_total_matter
		var drift: float = abs(current_matter - initial_matter)

		assert_true(drift <= tolerance,
			"Axiom 1 violation at tick %d: initial=%.4f current=%.4f drift=%.4f" % [
				tick_idx + 1, initial_matter, current_matter, drift
			])


func test_chronicle_event_lifecycle():
	# Log an event, process, and verify it flows through the full chronicle pipeline.
	var sector_id: String = GameState.world_topology.keys()[0]

	var event_packet: Dictionary = {
		"actor_uid": "player",
		"action_id": "buy",
		"target_uid": "commodity_ore",
		"target_sector_id": sector_id,
		"tick_count": 1,
		"outcome": "success",
		"metadata": {"commodity_id": "commodity_ore", "quantity": 5}
	}

	chronicle_layer.log_event(event_packet)
	chronicle_layer.process_tick()

	# Event should be in the buffer
	assert_true(GameState.chronicle_event_buffer.size() > 0,
		"chronicle_event_buffer should contain the logged event.")

	var stored: Dictionary = GameState.chronicle_event_buffer[0]
	assert_eq(stored["actor_uid"], "player", "Actor UID should match.")
	assert_eq(stored["action_id"], "buy", "Action ID should match.")
	assert_true(stored.has("significance"), "Event should have significance scored.")

	# Rumor should be generated
	assert_true(GameState.chronicle_rumors.size() > 0,
		"At least one rumor should be generated from a buy event.")


func test_save_load_round_trip_with_simulation_state():
	# Run a few ticks to create non-trivial state
	for i in range(3):
		GameState.sim_tick_count += 1
		grid_layer.process_tick(_config)
		bridge_systems.process_tick(_config)
		agent_layer.process_tick(_config)
		chronicle_layer.process_tick()

	world_layer.recalculate_total_matter()

	# Snapshot key values before save
	var pre_save_tick: int = GameState.sim_tick_count
	var pre_save_matter: float = GameState.world_total_matter
	var pre_save_agent_count: int = GameState.agents.size()
	var pre_save_topology_size: int = GameState.world_topology.size()

	# Save
	var save_ok: bool = GameStateManager.save_game(SAVE_SLOT)
	assert_true(save_ok, "Save should succeed.")

	# Clear everything
	_clear_game_state()
	assert_eq(GameState.agents.size(), 0, "GameState should be empty after clear.")

	# Load
	var load_ok: bool = GameStateManager.load_game(SAVE_SLOT)
	assert_true(load_ok, "Load should succeed.")

	# Verify restored state
	assert_eq(GameState.sim_tick_count, pre_save_tick,
		"sim_tick_count should be restored.")
	assert_eq(GameState.world_topology.size(), pre_save_topology_size,
		"world_topology size should be restored.")
	assert_eq(GameState.agents.size(), pre_save_agent_count,
		"agents count should be restored.")
	assert_almost_eq(GameState.world_total_matter, pre_save_matter, 0.01,
		"world_total_matter should be restored.")


func test_npc_goals_evolve_under_simulation():
	# Find an NPC and verify goal evaluation works through the stack
	var npc_id: String = ""
	for agent_id in GameState.agents:
		if agent_id != "player":
			npc_id = agent_id
			break

	assert_true(npc_id != "", "At least one NPC must exist for this test.")

	var agent: Dictionary = GameState.agents[npc_id]
	# Force low cash to trigger 'trade' goal
	agent["cash_reserves"] = 50.0
	agent["hull_integrity"] = 1.0

	# Process agent layer
	agent_layer.process_tick(_config)

	var updated_agent: Dictionary = GameState.agents[npc_id]
	assert_eq(updated_agent["goal_archetype"], "trade",
		"NPC with low cash should adopt 'trade' goal. Got: '%s'" % updated_agent["goal_archetype"])

	# Now damage hull below repair threshold
	updated_agent["hull_integrity"] = 0.2
	agent_layer.process_tick(_config)

	var final_agent: Dictionary = GameState.agents[npc_id]
	assert_eq(final_agent["goal_archetype"], "repair",
		"NPC with low hull should adopt 'repair' goal (higher priority than trade). Got: '%s'" % final_agent["goal_archetype"])


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_game_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.world_resource_potential.clear()
	GameState.world_total_matter = 0.0
	GameState.world_seed = ""
	GameState.grid_stockpiles.clear()
	GameState.grid_dominion.clear()
	GameState.grid_market.clear()
	GameState.grid_power.clear()
	GameState.grid_maintenance.clear()
	GameState.grid_wrecks.clear()
	GameState.grid_resource_availability.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.hostile_population_integral.clear()
	GameState.player_character_uid = -1
	GameState.sim_tick_count = 0
	GameState.game_time_seconds = 0
	GameState.chronicle_event_buffer = []
	GameState.chronicle_rumors = []
	GameState.player_docked_at = ""
	GameState.locations.clear()
	GameState.factions.clear()


func _build_config() -> Dictionary:
	return {
		"influence_propagation_rate": Constants.CA_INFLUENCE_PROPAGATION_RATE,
		"pirate_activity_decay": Constants.CA_PIRATE_ACTIVITY_DECAY,
		"pirate_activity_growth": Constants.CA_PIRATE_ACTIVITY_GROWTH,
		"stockpile_diffusion_rate": Constants.CA_STOCKPILE_DIFFUSION_RATE,
		"extraction_rate_default": Constants.CA_EXTRACTION_RATE_DEFAULT,
		"price_sensitivity": Constants.CA_PRICE_SENSITIVITY,
		"demand_base": Constants.CA_DEMAND_BASE,
		"wreck_degradation_per_tick": Constants.WRECK_DEGRADATION_PER_TICK,
		"wreck_debris_return_fraction": Constants.WRECK_DEBRIS_RETURN_FRACTION,
		"entropy_radiation_multiplier": Constants.ENTROPY_RADIATION_MULTIPLIER,
		"entropy_base_rate": Constants.ENTROPY_BASE_RATE,
		"entropy_hull_multiplier": Constants.ENTROPY_HULL_MULTIPLIER,
		"heat_generation_in_space": Constants.HEAT_GENERATION_IN_SPACE,
		"heat_dissipation_base": Constants.HEAT_DISSIPATION_DOCKED,
		"heat_overheat_threshold": Constants.HEAT_OVERHEAT_THRESHOLD,
		"fleet_entropy_reduction": Constants.ENTROPY_FLEET_RATE_FRACTION,
		"propellant_drain_per_tick": Constants.PROPELLANT_DRAIN_PER_TICK,
		"energy_drain_per_tick": Constants.ENERGY_DRAIN_PER_TICK,
		"knowledge_noise_factor": Constants.AGENT_KNOWLEDGE_NOISE_FACTOR,
		"power_draw_per_agent": Constants.POWER_DRAW_PER_AGENT,
		"power_draw_per_service": Constants.POWER_DRAW_PER_SERVICE,
		"npc_cash_low_threshold": Constants.NPC_CASH_LOW_THRESHOLD,
		"npc_hull_repair_threshold": Constants.NPC_HULL_REPAIR_THRESHOLD,
		"commodity_base_price": Constants.COMMODITY_BASE_PRICE,
		"world_tick_interval_seconds": float(Constants.WORLD_TICK_INTERVAL_SECONDS),
		"respawn_timeout_seconds": Constants.RESPAWN_TIMEOUT_SECONDS,
		"hostile_growth_rate": Constants.HOSTILE_GROWTH_RATE,
		"axiom1_tolerance": Constants.AXIOM1_TOLERANCE
	}
