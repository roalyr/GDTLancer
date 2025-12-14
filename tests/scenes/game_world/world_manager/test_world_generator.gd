# File: tests/scenes/game_world/world_manager/test_world_generator.gd
# GUT Test Script for the WorldGenerator component.
# Version: 2.0 - Corrected to handle system dependencies properly.

extends GutTest

const TemplateIndexer = preload("res://scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://scenes/game_world/world_manager/world_generator.gd")
const InventorySystem = preload("res://core/systems/inventory_system.gd")

var indexer_instance = null
var generator_instance = null
var inventory_system_instance = null # We need an instance for the generator to use

func before_each():
	# 1. Index templates first, as this is a dependency.
	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)
	indexer_instance.index_all_templates()

	# 2. Instantiate the InventorySystem and set it in GlobalRefs.
	# The WorldGenerator depends on this being valid.
	inventory_system_instance = InventorySystem.new()
	add_child_autofree(inventory_system_instance)
	GlobalRefs.inventory_system = inventory_system_instance

	# 3. Now, instantiate the WorldGenerator we are testing.
	generator_instance = WorldGenerator.new()
	add_child_autofree(generator_instance)

	# 4. Ensure a clean GameState for every test.
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = -1

func after_each():
	# Clean up the global reference to prevent test bleed.
	GlobalRefs.inventory_system = null

func test_generates_characters_and_inventories():
	assert_eq(GameState.characters.size(), 0, "Characters should be empty before generation.")
	assert_eq(GameState.inventories.size(), 0, "Inventories should be empty before generation.")

	generator_instance.generate_new_world()

	assert_gt(GameState.characters.size(), 0, "Characters should be populated after generation.")
	assert_eq(GameState.inventories.size(), GameState.characters.size(), "Should create one inventory per character.")

func test_assigns_player_character_uid():
	assert_eq(GameState.player_character_uid, -1, "Player UID should be -1 before generation.")

	generator_instance.generate_new_world()

	assert_ne(GameState.player_character_uid, -1, "A valid player UID should be set.")
	assert_has(GameState.characters, GameState.player_character_uid, "The player UID must be a valid key.")

func test_generated_characters_have_assets():
	generator_instance.generate_new_world()
	
	var player_uid = GameState.player_character_uid
	var player_char = GameState.characters[player_uid]

	# Check for active ship assignment
	assert_ne(player_char.active_ship_uid, -1, "Player should have an active ship UID assigned.")
	assert_has(GameState.assets_ships, player_char.active_ship_uid, "The active ship should exist in the master asset list.")

	# Check inventory contents using the system
	var ship_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.SHIP, player_char.active_ship_uid)
	assert_eq(ship_count, 1, "Player inventory should contain 1 ship.")
	
	var module_inventory = inventory_system_instance.get_inventory_by_type(player_uid, inventory_system_instance.InventoryType.MODULE)
	assert_eq(module_inventory.size(), 1, "Player inventory should contain 1 module.")
	
	# Player starts with ore and fuel for trading
	var ore_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.COMMODITY, "commodity_ore")
	assert_eq(ore_count, 15, "Player inventory should contain 15 units of ore.")
	
	var fuel_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.COMMODITY, "commodity_fuel")
	assert_eq(fuel_count, 5, "Player inventory should contain 5 units of fuel.")
