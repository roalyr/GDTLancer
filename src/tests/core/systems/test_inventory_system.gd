# File: tests/core/systems/test_inventory_system.gd
# GUT Test for the unified, stateless InventorySystem.
# Version: 4.0 - Adapted for sim rework (assets_modules removed from GameState).

extends GutTest

# --- Test Subjects ---
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")
const ShipTemplate = preload("res://database/definitions/asset_ship_template.gd")

# --- Test State ---
var inventory_system_instance = null
const PLAYER_UID = 0
const SHIP_UID = 100
const COMMODITY_ID = "commodity_default"


func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = PLAYER_UID

	# 2. Create mock assets in the master asset lists
	GameState.assets_ships[SHIP_UID] = ShipTemplate.new()

	# 3. Instantiate the system we are testing
	inventory_system_instance = InventorySystem.new()
	add_child_autofree(inventory_system_instance)

	# 4. Create an inventory for our test character
	inventory_system_instance.create_inventory_for_character(PLAYER_UID)


func after_each():
	# Clean up global state to ensure test isolation
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = -1
	inventory_system_instance = null


# --- Test Cases ---

func test_create_inventory_for_character():
	assert_has(GameState.inventories, PLAYER_UID, "An inventory should be created for the character UID.")
	var inventory = GameState.inventories[PLAYER_UID]
	assert_has(inventory, inventory_system_instance.InventoryType.SHIP, "Inventory should have a SHIP dictionary.")
	assert_has(inventory, inventory_system_instance.InventoryType.MODULE, "Inventory should have a MODULE dictionary.")
	assert_has(inventory, inventory_system_instance.InventoryType.COMMODITY, "Inventory should have a COMMODITY dictionary.")


func test_add_and_remove_unique_asset():
	# Test adding a unique asset (ship)
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID)
	var player_inventory = GameState.inventories[PLAYER_UID]
	assert_has(player_inventory[inventory_system_instance.InventoryType.SHIP], SHIP_UID, "Player's ship inventory should contain the ship UID.")
	assert_eq(inventory_system_instance.get_asset_count(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID), 1, "Ship count should be 1.")

	# Test removing the unique asset
	var result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID)
	assert_true(result, "Removing a unique asset should return true.")
	assert_false(player_inventory[inventory_system_instance.InventoryType.SHIP].has(SHIP_UID), "Ship should be removed from inventory.")
	assert_eq(inventory_system_instance.get_asset_count(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID), 0, "Ship count should be 0 after removal.")


func test_add_and_remove_commodity():
	# Test adding a new commodity
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 10)
	var player_inventory = GameState.inventories[PLAYER_UID]
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 10, "Commodity count should be 10.")

	# Test adding to an existing stack
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 5)
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 15, "Commodity count should be 15 after adding more.")

	# Test removing some
	var result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 3)
	assert_true(result, "Removing a partial stack should return true.")
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 12, "Commodity count should be 12 after removing some.")

	# Test removing all
	result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 12)
	assert_true(result, "Removing the rest of the stack should return true.")
	assert_false(player_inventory[inventory_system_instance.InventoryType.COMMODITY].has(COMMODITY_ID), "Commodity should be removed from inventory when count is zero.")


func test_get_inventory_by_type():
	# Add some assets to test with
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID)
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 50)

	# Get the ship inventory
	var ship_inventory = inventory_system_instance.get_inventory_by_type(PLAYER_UID, inventory_system_instance.InventoryType.SHIP)
	assert_eq(ship_inventory.size(), 1, "Should return a dictionary with one ship.")
	assert_has(ship_inventory, SHIP_UID, "The returned dictionary should contain the correct ship UID.")

	# Get the commodity inventory
	var commodity_inventory = inventory_system_instance.get_inventory_by_type(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY)
	assert_eq(commodity_inventory.size(), 1, "Should return a dictionary with one commodity type.")
	assert_eq(commodity_inventory[COMMODITY_ID], 50, "The returned dictionary should have the correct quantity.")
