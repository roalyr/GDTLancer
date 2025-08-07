# File: tests/autoload/test_game_state_manager.gd
# GUT Test for the streamlined GameStateManager.
# Version: 2.1 - Corrected for private serialization methods.

extends GutTest

# --- Component Preloads ---
const TemplateIndexer = preload("res://scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://scenes/game_world/world_manager/world_generator.gd")
const InventorySystem = preload("res://core/systems/inventory_system.gd")

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

# --- Helper Functions ---

func _clear_game_state():
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.inventories.clear()
	GameState.player_character_uid = -1
	GameState.current_tu = 0

# Creates a serializable copy of the GameState for comparison.
func _deep_copy_game_state() -> Dictionary:
	# We now call the private methods on the GameStateManager itself to get the
	# serialized copy, since it's the authority on serialization.
	return GameStateManager._serialize_game_state()
