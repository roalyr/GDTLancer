#
# PROJECT: GDTLancer
# MODULE: test_game_state_manager.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 8 (Simulation Architecture)
# LOG_REF: 2026-02-13
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
	GameState.player_docked_at = "station_beta"
	GameState.sim_tick_count = 7

	# Market inventory quantity mutation (legacy locations)
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

	# Save -> clear -> load
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	# Assertions — fields that still exist in GameState
	assert_eq(GameState.game_time_seconds, 42, "game_time_seconds should persist.")
	assert_eq(GameState.player_docked_at, "station_beta", "player_docked_at should persist.")
	assert_eq(GameState.sim_tick_count, 7, "sim_tick_count should persist.")

	assert_eq(GameState.locations["station_alpha"].market_inventory["commodity_ore"]["quantity"], 123, "Market inventory quantity should persist.")
	if ship_uid != -1:
		var loaded_ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(loaded_ship_inv.has(ship_uid), "Loaded player ship inventory should contain the mutated ship.")
		assert_eq(loaded_ship_inv[ship_uid].ship_quirks, ["scratched_hull"], "Ship quirks should persist.")

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
	GameState.hostile_infestation_progress.clear()
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.player_character_uid = ""
	GameState.player_docked_at = ""
	GameState.game_time_seconds = 0
	GameState.sim_tick_count = 0
	GameState.world_seed = ""

# Creates a serializable copy of the GameState for comparison.
func _deep_copy_game_state() -> Dictionary:
	# We now call the private methods on the GameStateManager itself to get the
	# serialized copy, since it's the authority on serialization.
	return GameStateManager._serialize_game_state()
