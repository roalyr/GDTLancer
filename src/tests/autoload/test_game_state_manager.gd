#
# PROJECT: GDTLancer
# MODULE: test_game_state_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-04 02:36:00
#

extends GutTest

## Unit tests for GameStateManager: save/load operations and state serialization.
## Updated for four-layer simulation architecture.

# --- Component Preloads ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

# --- Test State ---
const TEST_SLOT = 999
var _initial_game_state_copy = {}


func before_all():
	# Index templates once for all tests in this file.
	var indexer = TemplateIndexer.new()
	add_child_autofree(indexer)
	indexer.index_all_templates()

func before_each():
	# Set up a complete, known game state before each test.
	_clear_game_state()
	
	# The generator needs an inventory system to exist in GlobalRefs.
	var inv_sys = InventorySystem.new()
	add_child_autofree(inv_sys)
	GlobalRefs.inventory_system = inv_sys
	
	var generator = WorldGenerator.new()
	add_child_autofree(generator)
	generator.generate_new_world()
	
	# Take a deep copy of the freshly generated state for comparison later.
	_initial_game_state_copy = _deep_copy_game_state()

func after_each():
	_clear_game_state()
	GlobalRefs.inventory_system = null # Clean up the global ref
	var save_path = GameStateManager.SAVE_DIR + GameStateManager.SAVE_FILE_PREFIX + str(TEST_SLOT) + ".sav"
	var dir = Directory.new()
	if dir.file_exists(save_path):
		dir.remove(save_path)

# --- Test Cases ---

func test_save_and_load_restores_identical_state():
	# 1. Save the game
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")

	# 2. Clear the live GameState to simulate a restart
	_clear_game_state()
	assert_eq(GameState.characters.size(), 0, "Pre-load check: GameState should be empty.")

	# 3. Load the game
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")
	
	# 4. Compare the loaded state to the original state
	var loaded_state_copy = _deep_copy_game_state()

	# Use GUT's deep compare for detailed comparison
	var result = compare_deep(_initial_game_state_copy, loaded_state_copy)
	assert_true(result.are_equal(), "Loaded GameState should be identical to the pre-save state.\n" + result.summary)


func test_save_and_load_preserves_mutated_fields():
	# Mutate fields that change during gameplay and must persist.
	GameState.game_time_seconds = 42
	GameState.current_sector_id = "sector_star_cob"
	GameState.player_docked_at = "sector_star_cob"
	GameState.sim_tick_count = 7

	# Market inventory quantity mutation (legacy locations)
	var starter_sector = GameState.locations.get("sector_star_elace", null)
	assert_not_null(starter_sector, "Precondition: sector_star_elace location should exist.")
	if starter_sector:
		assert_true(starter_sector.market_inventory.has("commodity_ore"), "Precondition: sector_star_elace should sell commodity_ore.")
		if starter_sector.market_inventory.has("commodity_ore"):
			starter_sector.market_inventory["commodity_ore"]["quantity"] = 123

	# Ship quirks mutation (grab player's first ship)
	var player_uid = int(GameState.player_character_uid)
	assert_true(GameState.inventories.has(player_uid), "Precondition: player inventory should exist.")
	var ship_uid := -1
	if GameState.inventories.has(player_uid):
		var ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(ship_inv.size() > 0, "Precondition: player should have at least one ship asset.")
		if ship_inv.size() > 0:
			ship_uid = ship_inv.keys()[0]
			ship_inv[ship_uid].ship_quirks = ["scratched_hull"]

	# Save -> clear -> load
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	# Assertions — fields that still exist in GameState
	assert_eq(GameState.game_time_seconds, 42, "game_time_seconds should persist.")
	assert_eq(GameState.current_sector_id, "sector_star_cob", "current_sector_id should persist.")
	assert_eq(GameState.player_docked_at, "sector_star_cob", "player_docked_at should persist.")
	assert_eq(GameState.sim_tick_count, 7, "sim_tick_count should persist.")

	assert_eq(GameState.locations["sector_star_elace"].market_inventory["commodity_ore"]["quantity"], 123, "Market inventory quantity should persist.")
	if ship_uid != -1:
		var loaded_ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(loaded_ship_inv.has(ship_uid), "Loaded player ship inventory should contain the mutated ship.")
		assert_eq(loaded_ship_inv[ship_uid].ship_quirks, ["scratched_hull"], "Ship quirks should persist.")


func test_save_and_load_preserves_plain_dict_location_market_inventory():
	GameState.locations["synthetic_discovered_1"] = {
		"location_name": "Test Station",
		"market_inventory": {
			"commodity_ore": {
				"buy_price": 8,
				"sell_price": 6,
				"quantity": 77
			}
		}
	}
	
	GameState.locations["synthetic_discovered_1"]["market_inventory"]["commodity_ore"]["quantity"] = 42

	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully with plain-dict location.")
	_clear_game_state()
	
	assert_false(GameState.locations.has("synthetic_discovered_1"), "Locations should be empty after clear state.")
	
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully with plain-dict location.")
	
	assert_true(GameState.locations.has("synthetic_discovered_1"), "synthetic_discovered_1 location should be loaded.")
	var loaded_loc = GameState.locations["synthetic_discovered_1"]
	assert_true(loaded_loc.has("market_inventory"), "Loaded location should have market_inventory.")
	assert_eq(int(loaded_loc["market_inventory"]["commodity_ore"]["quantity"]), 42, "Mutated quantity must persist through round-trip.")


func test_save_and_load_preserves_scene_state_restore_fields():
	GameState.current_sector_id = "sector_star_cob"
	GameState.player_docked_at = ""
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3(15, 120, -5)
	GameState.player_arrived_from_sector = "sector_star_elace"
	GameState.player_arrival_direction = Vector3(0, 0, -1)

	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	assert_eq(GameState.current_sector_id, "sector_star_cob", "current_sector_id should survive save/load for load-game sector bootstrap.")
	assert_eq(GameState.player_rotation, Vector3(15, 120, -5), "player_rotation should survive save/load for arrival restore.")
	assert_eq(GameState.player_arrived_from_sector, "sector_star_elace", "player_arrived_from_sector should survive save/load until spawn consumes it.")
	assert_eq(GameState.player_arrival_direction, Vector3(0, 0, -1), "player_arrival_direction should survive save/load until spawn consumes it.")


func test_save_and_load_preserves_runtime_contract_occurrence_state():
	var occurrence_id: String = "runtime_contract:sector_star_cob:RAW"
	GameState.contract_generation_pressure = {"sector_star_cob": {"RAW": 2}}
	GameState.contract_generation_threshold = {"sector_star_cob": {"RAW": 3}}
	GameState.contract_cargo_supply = {"sector_star_elace": {"RAW": 1}}
	GameState.contract_cargo_reserved = {"sector_star_elace": {"RAW": 1}}
	GameState.contract_payment_supply = {"sector_star_cob": {"RAW": 2}}
	GameState.contract_payment_reserved = {"sector_star_cob": {"RAW": 1}}
	GameState.player_claimed_occurrence_id = occurrence_id
	GameState.player_cargo_tag = "EMPTY"
	GameState.runtime_contract_occurrences = {
		occurrence_id: {
			"occurrence_id": occurrence_id,
			"generator_id": "qualitative_demand",
			"contract_type": "delivery",
			"commodity_category": "RAW",
			"demand_tag": "CONTRACT_DEMAND_RAW",
			"source_sector_id": "sector_star_elace",
			"target_sector_id": "sector_star_cob",
			"source_accounting_sector_id": "sector_star_elace",
			"payment_accounting_sector_id": "sector_star_cob",
			"origin_location_id": "sector_star_elace",
			"destination_location_id": "sector_star_cob",
			"status": "claimed",
			"claimant_agent_id": "player",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"source_reserved": true,
			"payment_reserved": true,
			"cargo_picked_up": false,
			"created_at_tick": 7,
			"claimed_at_tick": 7,
			"completed_at_tick": -1,
			"last_refreshed_tick": 7,
			"title": "Raw Relief Route to sector_star_cob",
			"description": "Raw demand in sector_star_cob can be relieved from sector_star_elace.",
		}
	}
	GameState.runtime_contract_occurrences_by_target_sector = {"sector_star_cob": [occurrence_id]}
	GameState.runtime_contract_occurrences_by_source_sector = {"sector_star_elace": [occurrence_id]}

	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	_assert_deep_equal(GameState.contract_generation_pressure, {"sector_star_cob": {"RAW": 2}},
		"contract_generation_pressure should survive save/load.")
	_assert_deep_equal(GameState.contract_generation_threshold, {"sector_star_cob": {"RAW": 3}},
		"contract_generation_threshold should survive save/load.")
	_assert_deep_equal(GameState.contract_cargo_supply, {"sector_star_elace": {"RAW": 1}},
		"contract_cargo_supply should survive save/load.")
	_assert_deep_equal(GameState.contract_cargo_reserved, {"sector_star_elace": {"RAW": 1}},
		"contract_cargo_reserved should survive save/load.")
	_assert_deep_equal(GameState.contract_payment_supply, {"sector_star_cob": {"RAW": 2}},
		"contract_payment_supply should survive save/load.")
	_assert_deep_equal(GameState.contract_payment_reserved, {"sector_star_cob": {"RAW": 1}},
		"contract_payment_reserved should survive save/load.")
	assert_eq(GameState.player_claimed_occurrence_id, occurrence_id,
		"player_claimed_occurrence_id should survive save/load.")
	assert_eq(GameState.player_cargo_tag, "EMPTY",
		"player_cargo_tag should survive save/load.")
	assert_eq(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("origin_location_id", ""), "sector_star_elace",
		"runtime_contract_occurrences should survive save/load.")
	assert_eq(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("source_accounting_sector_id", ""), "sector_star_elace",
		"source_accounting_sector_id should survive save/load.")
	assert_eq(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("payment_accounting_sector_id", ""), "sector_star_cob",
		"payment_accounting_sector_id should survive save/load.")
	assert_eq(bool(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("source_reserved", false)), true,
		"Runtime occurrence reservation state should survive save/load.")
	assert_eq(bool(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("payment_reserved", false)), true,
		"Runtime occurrence payment reservation state should survive save/load.")
	assert_eq(bool(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("cargo_picked_up", true)), false,
		"Runtime occurrence cargo pickup state should survive save/load.")
	assert_eq(int(GameState.runtime_contract_occurrences.get(occurrence_id, {}).get("completed_at_tick", -2)), -1,
		"Runtime occurrence incomplete completion-state sentinel should survive save/load.")
	_assert_deep_equal(GameState.runtime_contract_occurrences_by_target_sector, {"sector_star_cob": [occurrence_id]},
		"runtime contract target index should survive save/load.")
	_assert_deep_equal(GameState.runtime_contract_occurrences_by_source_sector, {"sector_star_elace": [occurrence_id]},
		"runtime contract source index should survive save/load.")


func test_serialize_backfills_current_sector_id_from_docked_sector_when_scene_field_is_empty():
	GameState.current_sector_id = ""
	GameState.player_docked_at = "sector_star_elace"

	var save_data = GameStateManager._serialize_game_state()

	assert_eq(save_data.get("current_sector_id", ""), "sector_star_elace", "Serialization should backfill current_sector_id from the docked sector for scene-state bootstrap consistency.")


func test_deserialize_backfills_current_sector_id_from_player_agent_for_legacy_save_data():
	var save_data = _deep_copy_game_state()
	save_data.erase("current_sector_id")
	save_data["player_docked_at"] = ""
	save_data["agents"] = {
		"player": {
			"current_sector_id": "sector_star_cob"
		}
	}

	GameStateManager._deserialize_and_apply_game_state(save_data)

	assert_eq(GameState.current_sector_id, "sector_star_cob", "Deserialization should recover current_sector_id from the player agent for legacy saves that predate the scene-state field.")
	assert_eq(GameState.agents.get("player", {}).get("current_sector_id", ""), "sector_star_cob", "Recovered player agent sector state should stay aligned with GameState.current_sector_id.")


func test_reset_to_defaults_clears_full_runtime_and_scene_state() -> void:
	var stray_zone := Node.new()
	add_child_autofree(stray_zone)

	GameState.game_time_seconds = 91
	GameState.current_zone_instance = stray_zone
	GameState.player_position = Vector3(5, 6, 7)
	GameState.player_rotation = Vector3(10, 20, 30)
	GameState.colony_level_history = [
		{"sector_id": "sector_star_elace", "levels": ["outpost", "colony"]}
	]
	GameState.catastrophe_log = [{"tick": 3, "sector_id": "sector_star_elace"}]
	GameState.sector_disabled_until = {"sector_star_elace": 99}
	GameState.mortal_agent_counter = 4
	GameState.mortal_agent_deaths = [{"tick": 2, "agent_id": "mortal_4"}]
	GameState.discovered_sector_count = 2
	GameState.discovery_log = [{"sector_id": "discovered_1"}]
	GameState.sector_names = {"sector_star_elace": "Elace"}
	GameState.sub_tick_accumulator = 6
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = 17
	GameState.world_age_cycle_count = 3
	GameState.locations["test_location"] = {"display_name": "Stray"}
	GameState.factions["test_faction"] = {"name": "Stray Faction"}
	GameState.assets_commodities["test_commodity"] = {"display_name": "Ore"}
	GameState.persistent_agents["test_agent"] = {"role": "trader"}
	GameState.inventories[1] = {"cargo": {}}
	GameState.assets_ships[1] = {"template_id": "ship_test"}

	GameStateManager.reset_to_defaults()

	assert_eq(GameState.game_time_seconds, 0, "reset_to_defaults should clear game_time_seconds for a true new game.")
	assert_eq(GameState.current_zone_instance, null, "reset_to_defaults should drop the previous live zone instance.")
	assert_eq(GameState.player_position, Vector3.ZERO, "reset_to_defaults should clear saved player position.")
	assert_eq(GameState.player_rotation, Vector3.ZERO, "reset_to_defaults should clear saved player rotation.")
	assert_eq(GameState.colony_level_history.size(), 0, "reset_to_defaults should clear colony level history.")
	assert_eq(GameState.catastrophe_log.size(), 0, "reset_to_defaults should clear catastrophe history.")
	assert_eq(GameState.sector_disabled_until.size(), 0, "reset_to_defaults should clear disabled-sector timers.")
	assert_eq(GameState.mortal_agent_counter, 0, "reset_to_defaults should clear mortal counters.")
	assert_eq(GameState.mortal_agent_deaths.size(), 0, "reset_to_defaults should clear mortal death history.")
	assert_eq(GameState.discovered_sector_count, 0, "reset_to_defaults should clear discovered sector count.")
	assert_eq(GameState.discovery_log.size(), 0, "reset_to_defaults should clear discovery history.")
	assert_eq(GameState.sector_names.size(), 0, "reset_to_defaults should clear sector display names.")
	assert_eq(GameState.sub_tick_accumulator, 0, "reset_to_defaults should clear sub-tick accumulator state.")
	assert_eq(GameState.world_age, "", "reset_to_defaults should clear world-age phase state.")
	assert_eq(GameState.world_age_timer, 0, "reset_to_defaults should clear world-age timer state.")
	assert_eq(GameState.world_age_cycle_count, 0, "reset_to_defaults should clear completed world-age cycle count.")
	assert_eq(GameState.locations.size(), 0, "reset_to_defaults should clear cached locations.")
	assert_eq(GameState.factions.size(), 0, "reset_to_defaults should clear cached factions.")
	assert_eq(GameState.assets_commodities.size(), 0, "reset_to_defaults should clear cached commodities.")
	assert_eq(GameState.persistent_agents.size(), 0, "reset_to_defaults should clear legacy persistent-agent mirrors.")
	assert_eq(GameState.inventories.size(), 0, "reset_to_defaults should clear inventories.")
	assert_eq(GameState.assets_ships.size(), 0, "reset_to_defaults should clear ship assets.")

# --- Helper Functions ---

func _clear_game_state():
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.factions.clear()
	GameState.agents.clear()
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.world_tags = []
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
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.hostile_infestation_progress.clear()
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.current_sector_id = ""
	GameState.player_character_uid = ""
	GameState.player_docked_at = ""
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO
	GameState.player_arrived_from_sector = ""
	GameState.player_arrival_direction = Vector3.ZERO
	GameState.game_time_seconds = 0
	GameState.sim_tick_count = 0
	GameState.world_seed = ""

# Creates a serializable copy of the GameState for comparison.
func _deep_copy_game_state() -> Dictionary:
	# We now call the private methods on the GameStateManager itself to get the
	# serialized copy, since it's the authority on serialization.
	return GameStateManager._serialize_game_state()


func _assert_deep_equal(actual, expected, message: String) -> void:
	var result = compare_deep(expected, actual)
	assert_true(result.are_equal(), "%s\n%s" % [message, result.summary])
