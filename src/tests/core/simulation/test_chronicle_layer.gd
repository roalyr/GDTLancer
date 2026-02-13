#
# PROJECT: GDTLancer
# MODULE: test_chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 5 (Chronicle Layer)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for ChronicleLayer: event logging, rumor generation, distribution.

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var chronicle_layer: Reference = null
var ca_rules: Reference = null

func before_each():
	_clear_game_state()

	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	chronicle_layer = ChronicleLayerScript.new()
	ca_rules = CARulesScript.new()
	grid_layer.ca_rules = ca_rules

	# Full init chain to get agents in sectors
	world_layer.initialize_world("chronicle_test_seed")
	grid_layer.initialize_grid()
	agent_layer.initialize_agents()
	world_layer.recalculate_total_matter()

func after_each():
	_clear_game_state()
	world_layer = null
	grid_layer = null
	agent_layer = null
	chronicle_layer = null
	ca_rules = null


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
	GameState.chronicle_event_buffer = []
	GameState.chronicle_rumors = []


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_event_logged():
	# Stage an event via log_event, then process
	var event_packet: Dictionary = {
		"actor_uid": "player",
		"action_id": "buy",
		"target_uid": "commodity_ore",
		"target_sector_id": _get_first_sector_id(),
		"tick_count": 1,
		"outcome": "success",
		"metadata": {"commodity_id": "commodity_ore", "quantity": 5}
	}

	chronicle_layer.log_event(event_packet)
	chronicle_layer.process_tick()

	assert_true(GameState.chronicle_event_buffer.size() > 0,
		"chronicle_event_buffer should contain at least one event after process_tick.")

	var stored: Dictionary = GameState.chronicle_event_buffer[0]
	assert_eq(stored["actor_uid"], "player",
		"Stored event actor_uid should match.")
	assert_eq(stored["action_id"], "buy",
		"Stored event action_id should match.")
	assert_true(stored.has("significance"),
		"Event should have a significance score after processing.")
	assert_eq(stored["significance"], 0.5,
		"Phase 1 stub significance should be 0.5.")
	assert_true(stored.has("causality_chain"),
		"Event should have causality_chain tagged.")
	assert_true(stored["is_root_cause"],
		"Phase 1 stub: all events are root causes.")


func test_rumor_generated():
	var sector_id: String = _get_first_sector_id()
	var event_packet: Dictionary = {
		"actor_uid": "player",
		"action_id": "buy",
		"target_uid": "commodity_ore",
		"target_sector_id": sector_id,
		"tick_count": 1,
		"outcome": "success",
		"metadata": {"commodity_id": "commodity_ore", "quantity": 3}
	}

	chronicle_layer.log_event(event_packet)
	chronicle_layer.process_tick()

	assert_true(GameState.chronicle_rumors.size() > 0,
		"At least one rumor should be generated from the event.")

	var rumor: String = GameState.chronicle_rumors[0]
	assert_true(rumor is String and rumor.length() > 0,
		"Rumor should be a non-empty string. Got: '%s'" % rumor)


func test_event_distributed():
	# Place an NPC agent in the same sector as the event
	var sector_id: String = _get_first_sector_id()
	var npc_id: String = _get_first_npc_id()
	if npc_id == "":
		pending("No NPCs found.")
		return

	# Move the NPC to the event sector
	GameState.agents[npc_id]["current_sector_id"] = sector_id
	# Ensure event_memory is clean
	GameState.agents[npc_id]["event_memory"] = []

	var event_packet: Dictionary = {
		"actor_uid": "player",
		"action_id": "sell",
		"target_uid": "commodity_ore",
		"target_sector_id": sector_id,
		"tick_count": 1,
		"outcome": "success",
		"metadata": {"commodity_id": "commodity_ore", "quantity": 10}
	}

	chronicle_layer.log_event(event_packet)
	chronicle_layer.process_tick()

	var agent: Dictionary = GameState.agents[npc_id]
	var memory: Array = agent.get("event_memory", [])
	assert_true(memory.size() > 0,
		"NPC in event sector should receive the event in event_memory.")

	var received_event: Dictionary = memory[0]
	assert_eq(received_event["action_id"], "sell",
		"Distributed event action_id should match.")


func test_no_events_no_processing():
	# Process with empty staging buffer — should be a no-op
	chronicle_layer.process_tick()
	assert_eq(GameState.chronicle_event_buffer.size(), 0,
		"No events should be added when staging buffer is empty.")
	assert_eq(GameState.chronicle_rumors.size(), 0,
		"No rumors should be generated when no events are staged.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _get_first_sector_id() -> String:
	for sector_id in GameState.world_topology:
		return sector_id
	return ""

func _get_first_npc_id() -> String:
	for agent_id in GameState.agents:
		if agent_id != "player":
			return agent_id
	return ""
