# File: tests/core/systems/test_inventory_system.gd
# GUT Test for InventorySystem using a mocked AssetSystem
# Version: 1.1 - Corrected for GUT 7.2.0 compatibility

extends "res://addons/gut/test.gd"

# --- Test Subjects ---
var InventorySystem = load("res://core/systems/inventory_system.gd")
var Commodity = load("res://core/resource/commodity.gd")

# --- Mock Dependencies ---
var AssetSystem = load("res://core/systems/asset_system.gd")

# --- Test State ---
var inventory_system_inst
var mock_asset_system
var test_commodity_ore
var test_commodity_parts

const MOCK_CARGO_CAPACITY = 50

func before_each():
	mock_asset_system = double(AssetSystem).new()
	
	# --- THE FIX ---
	# The .with_args() method does not exist in GUT 7.2.0.
	# This simpler syntax tells the stub to always return 50 when the function is called,
	# regardless of its arguments. This is sufficient for our test.
	stub(mock_asset_system, "get_player_ship_stat").to_return(MOCK_CARGO_CAPACITY)
	
	GlobalRefs.asset_system = mock_asset_system
	inventory_system_inst = InventorySystem.new()
	add_child(inventory_system_inst)
	
	test_commodity_ore = Commodity.new()
	test_commodity_ore.item_id = "iron_ore"
	test_commodity_ore.name = "Iron Ore"
	
	test_commodity_parts = Commodity.new()
	test_commodity_parts.item_id = "machine_parts"
	test_commodity_parts.name = "Machine Parts"

func after_each():
	inventory_system_inst.free()
	mock_asset_system.free()
	GlobalRefs.asset_system = null


# --- Tests (Unchanged) ---

func test_add_item_success():
	assert_true(inventory_system_inst.add_item(test_commodity_ore, 20), "Should be able to add 20 items.")
	assert_eq(inventory_system_inst.get_total_cargo_amount(), 20, "Total cargo amount should be 20.")

func test_add_item_exceeds_capacity():
	assert_false(inventory_system_inst.add_item(test_commodity_ore, MOCK_CARGO_CAPACITY + 1), "Should fail to add 51 items.")
	assert_eq(inventory_system_inst.get_total_cargo_amount(), 0, "Cargo should still be empty after a failed add.")

func test_fill_capacity_and_fail_to_add_more():
	inventory_system_inst.add_item(test_commodity_ore, 30)
	inventory_system_inst.add_item(test_commodity_parts, 20)
	assert_eq(inventory_system_inst.get_total_cargo_amount(), 50, "Cargo should be exactly full.")
	assert_false(inventory_system_inst.add_item(test_commodity_ore, 1), "Should fail to add one more item to a full cargo hold.")

func test_remove_item_success():
	inventory_system_inst.add_item(test_commodity_ore, 30)
	assert_true(inventory_system_inst.remove_item("iron_ore", 10), "Should successfully remove 10 items.")
	assert_eq(inventory_system_inst.get_total_cargo_amount(), 20, "Total cargo should be 20 after removal.")

func test_remove_more_items_than_exist():
	inventory_system_inst.add_item(test_commodity_ore, 10)
	assert_false(inventory_system_inst.remove_item("iron_ore", 15), "Should fail to remove 15 items if only 10 exist.")
	assert_eq(inventory_system_inst.get_total_cargo_amount(), 10, "Total cargo should not have changed.")

func test_remove_item_removes_entry_when_zero():
	inventory_system_inst.add_item(test_commodity_ore, 10)
	assert_true(inventory_system_inst.remove_item("iron_ore", 10), "Should successfully remove all 10 items.")
	var cargo_dict = inventory_system_inst.get_player_cargo()
	assert_false(cargo_dict.has("iron_ore"), "The 'iron_ore' key should be removed when quantity is zero.")
