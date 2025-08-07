# File: tests/core/systems/test_inventory_system.gd
# GUT Test for the stateless InventorySystem.
# Version: 2.0 - Rewritten for GameState architecture and new asset types.

extends GutTest

# --- Test Subjects ---
const InventorySystem = preload("res://core/systems/inventory_system.gd")
const CharacterTemplate = preload("res://core/resource/character_template.gd")
const ModuleTemplate = preload("res://core/resource/asset_module_template.gd")

# --- Test State ---
var inventory_system_instance = null
const PLAYER_UID = 0
const MODULE_UID = 200
const COMMODITY_ID = "commodity_default"

func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = -1

	# 2. Create and register a mock player character with some starting inventory
	var player_char = CharacterTemplate.new()
	player_char.inventory_commodities = { (COMMODITY_ID): 20 } # Start with 20 default commodities
	GameState.characters[PLAYER_UID] = player_char
	GameState.player_character_uid = PLAYER_UID

	# 3. Create and register a mock module asset that can be added/removed
	var module_asset = ModuleTemplate.new()
	module_asset.module_name = "Test Module"
	GameState.assets_modules[MODULE_UID] = module_asset

	# 4. Instantiate the system we are testing
	inventory_system_instance = InventorySystem.new()
	add_child_autofree(inventory_system_instance)

func after_each():
	GameState.characters.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = -1
	inventory_system_instance = null

# --- Commodity Test Cases ---

func test_add_commodity_to_existing_stack():
	inventory_system_instance.add_commodity(PLAYER_UID, COMMODITY_ID, 10)
	var final_count = GameState.characters[PLAYER_UID].inventory_commodities[COMMODITY_ID]
	assert_eq(final_count, 30, "Should add 10 to the existing stack of 20.")

func test_add_new_commodity():
	var new_commodity_id = "new_parts"
	inventory_system_instance.add_commodity(PLAYER_UID, new_commodity_id, 5)
	assert_has(GameState.characters[PLAYER_UID].inventory_commodities, new_commodity_id, "New commodity should be added to inventory.")
	assert_eq(GameState.characters[PLAYER_UID].inventory_commodities[new_commodity_id], 5, "New commodity should have a quantity of 5.")

func test_remove_commodity_successfully():
	var result = inventory_system_instance.remove_commodity(PLAYER_UID, COMMODITY_ID, 5)
	assert_true(result, "Should return true when removing a valid amount.")
	assert_eq(GameState.characters[PLAYER_UID].inventory_commodities[COMMODITY_ID], 15, "Quantity should be 15 after removing 5.")

func test_remove_commodity_fully_deletes_entry():
	var result = inventory_system_instance.remove_commodity(PLAYER_UID, COMMODITY_ID, 20)
	assert_true(result, "Should return true when removing the full stack.")
	assert_false(GameState.characters[PLAYER_UID].inventory_commodities.has(COMMODITY_ID), "Commodity entry should be removed when quantity is zero.")

func test_remove_more_commodities_than_exist_fails():
	var result = inventory_system_instance.remove_commodity(PLAYER_UID, COMMODITY_ID, 25)
	assert_false(result, "Should return false when trying to remove more than available.")
	assert_eq(GameState.characters[PLAYER_UID].inventory_commodities[COMMODITY_ID], 20, "Quantity should not change on a failed removal.")

func test_get_commodity_count():
	var count = inventory_system_instance.get_commodity_count(PLAYER_UID, COMMODITY_ID)
	assert_eq(count, 20, "Should return the correct count for an existing commodity.")
	var non_existent_count = inventory_system_instance.get_commodity_count(PLAYER_UID, "non_existent")
	assert_eq(non_existent_count, 0, "Should return 0 for a non-existent commodity.")

# --- Module Test Cases ---

func test_add_and_get_module():
	inventory_system_instance.add_module(PLAYER_UID, MODULE_UID)
	var modules = inventory_system_instance.get_character_modules(PLAYER_UID)
	assert_has(modules, MODULE_UID, "Character's module inventory should contain the new module UID.")
	assert_eq(modules[MODULE_UID], GameState.assets_modules[MODULE_UID], "The correct module instance should be in the inventory.")

func test_remove_module():
	# Add it first to ensure it's there
	inventory_system_instance.add_module(PLAYER_UID, MODULE_UID)
	assert_has(GameState.characters[PLAYER_UID].inventory_modules, MODULE_UID, "Pre-check: Module should be in inventory.")

	# Now remove it
	inventory_system_instance.remove_module(PLAYER_UID, MODULE_UID)
	assert_false(GameState.characters[PLAYER_UID].inventory_modules.has(MODULE_UID), "Module should be removed from inventory.")
