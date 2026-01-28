#
# PROJECT: GDTLancer
# MODULE: test_game_state_manager.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends GutTest

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


func test_save_and_load_preserves_mutated_phase1_fields():
	# Mutate Phase 1 fields that change during gameplay and must persist.
	GameState.game_time_seconds = 42
	GameState.player_docked_at = "station_beta"
	GameState.narrative_state["reputation"] = 7
	GameState.session_stats["contracts_completed"] = 2

	# Market inventory quantity mutation
	var station_alpha = GameState.locations.get("station_alpha", null)
	assert_not_null(station_alpha, "Precondition: station_alpha location should exist.")
	if station_alpha:
		assert_true(station_alpha.market_inventory.has("commodity_ore"), "Precondition: station_alpha should sell commodity_ore.")
		if station_alpha.market_inventory.has("commodity_ore"):
			station_alpha.market_inventory["commodity_ore"]["quantity"] = 123

	# Ship quirks mutation (grab player's first ship)
	var player_uid = GameState.player_character_uid
	assert_true(GameState.inventories.has(player_uid), "Precondition: player inventory should exist.")
	var ship_uid := -1
	if GameState.inventories.has(player_uid):
		var ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(ship_inv.size() > 0, "Precondition: player should have at least one ship asset.")
		if ship_inv.size() > 0:
			ship_uid = ship_inv.keys()[0]
			ship_inv[ship_uid].ship_quirks = ["scratched_hull"]

	# Active contract mutation (simulate accepted contract with progress)
	var contract_ids = GameState.contracts.keys()
	assert_true(contract_ids.size() > 0, "Precondition: at least one contract template should exist.")
	if contract_ids.size() > 0:
		var contract_id: String = contract_ids[0]
		var active_contract = GameState.contracts[contract_id].duplicate(true)
		active_contract.accepted_at_seconds = GameState.game_time_seconds
		active_contract.progress = {"character_uid": player_uid, "test_flag": true}
		GameState.active_contracts[contract_id] = active_contract

	# Save -> clear -> load
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	# Assertions
	assert_eq(GameState.game_time_seconds, 42, "game_time_seconds should persist.")
	assert_eq(GameState.player_docked_at, "station_beta", "player_docked_at should persist.")
	assert_eq(GameState.narrative_state.get("reputation", null), 7, "narrative_state.reputation should persist.")
	assert_eq(GameState.session_stats.get("contracts_completed", null), 2, "session_stats.contracts_completed should persist.")

	assert_eq(GameState.locations["station_alpha"].market_inventory["commodity_ore"]["quantity"], 123, "Market inventory quantity should persist.")
	if ship_uid != -1:
		var loaded_ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(loaded_ship_inv.has(ship_uid), "Loaded player ship inventory should contain the mutated ship.")
		assert_eq(loaded_ship_inv[ship_uid].ship_quirks, ["scratched_hull"], "Ship quirks should persist.")

	if contract_ids.size() > 0:
		var contract_id_loaded: String = contract_ids[0]
		assert_true(GameState.active_contracts.has(contract_id_loaded), "Active contract should persist.")
		assert_eq(GameState.active_contracts[contract_id_loaded].progress.get("character_uid", -1), player_uid, "Active contract progress should persist.")
		assert_true(GameState.active_contracts[contract_id_loaded].progress.get("test_flag", false), "Active contract custom progress data should persist.")

# --- Helper Functions ---

func _clear_game_state():
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	# Reinitialize with defaults instead of just clearing
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"contact_relationships": {},
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_credits_earned": 0,
		"total_credits_spent": 0,
		"enemies_disabled": 0,
		"time_played_seconds": 0
	}
	GameState.player_character_uid = -1
	GameState.player_docked_at = ""
	GameState.game_time_seconds = 0

# Creates a serializable copy of the GameState for comparison.
func _deep_copy_game_state() -> Dictionary:
	# We now call the private methods on the GameStateManager itself to get the
	# serialized copy, since it's the authority on serialization.
	return GameStateManager._serialize_game_state()
