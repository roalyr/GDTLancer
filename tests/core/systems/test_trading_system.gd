# File: tests/core/systems/test_trading_system.gd
# Purpose: Tests for TradingSystem buy/sell API and validation logic.
# Version: 1.0

extends GutTest

var trading_system: Node
var inventory_system: Node
var character_system: Node
var asset_system: Node

const TEST_CHARACTER_UID = 999
const TEST_LOCATION_ID = "test_station"


func before_each():
	# Create TradingSystem under test.
	trading_system = load("res://core/systems/trading_system.gd").new()
	add_child(trading_system)
	
	# Create InventorySystem.
	inventory_system = Node.new()
	inventory_system.set_script(load("res://core/systems/inventory_system.gd"))
	add_child(inventory_system)
	GlobalRefs.inventory_system = inventory_system
	GlobalRefs.trading_system = trading_system
	
	# Create CharacterSystem (needed for WP operations).
	character_system = Node.new()
	character_system.set_script(load("res://core/systems/character_system.gd"))
	add_child(character_system)
	GlobalRefs.character_system = character_system
	
	# Create AssetSystem (needed for cargo capacity checks).
	asset_system = Node.new()
	asset_system.set_script(load("res://core/systems/asset_system.gd"))
	add_child(asset_system)
	GlobalRefs.asset_system = asset_system
	
	# Set up test character with wealth_points and cargo capacity.
	var character = CharacterTemplate.new()
	character.character_name = "Test Trader"
	character.wealth_points = 1000
	GameState.characters[TEST_CHARACTER_UID] = character
	GameState.player_character_uid = TEST_CHARACTER_UID
	
	# Create inventory for test character.
	inventory_system.create_inventory_for_character(TEST_CHARACTER_UID)
	
	# Set up test ship with cargo capacity.
	var ship = ShipTemplate.new()
	ship.cargo_capacity = 100
	var ship_uid = 1
	GameState.assets_ships[ship_uid] = ship
	character.active_ship_uid = ship_uid
	
	# Set up test location with market inventory.
	var location = LocationTemplate.new()
	location.template_id = TEST_LOCATION_ID
	location.location_name = "Test Station"
	location.market_inventory = {
		"commodity_ore": {"quantity": 50, "buy_price": 10, "sell_price": 8},
		"commodity_fuel": {"quantity": 20, "buy_price": 25, "sell_price": 20}
	}
	GameState.locations[TEST_LOCATION_ID] = location


func after_each():
	# Clean up.
	GlobalRefs.inventory_system = null
	GlobalRefs.trading_system = null
	GlobalRefs.character_system = null
	GlobalRefs.asset_system = null
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.locations.clear()
	GameState.inventories.clear()
	GameState.player_character_uid = -1
	# Reset session_stats with defaults (TradingSystem expects these keys)
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	
	if is_instance_valid(trading_system):
		trading_system.queue_free()
	if is_instance_valid(inventory_system):
		inventory_system.queue_free()
	if is_instance_valid(character_system):
		character_system.queue_free()
	if is_instance_valid(asset_system):
		asset_system.queue_free()


# --- Buy Tests ---

func test_can_buy_within_budget():
	# Player has 1000 credits, ore costs 10 each.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_true(result.success, "Should be able to buy 5 ore for 50 credits")


func test_can_buy_insufficient_funds():
	# Try to buy 40 ore at 10 each = 400 WP. Set character to only have 100 WP.
	GameState.characters[TEST_CHARACTER_UID].wealth_points = 100
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 40)
	assert_false(result.success, "Should not be able to afford 40 ore with only 100 WP")
	assert_true("Insufficient funds" in result.reason, "Reason should mention insufficient funds")


func test_can_buy_exceeds_stock():
	# Station only has 50 ore, try to buy 100.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 100)
	assert_false(result.success, "Should not be able to buy more than station stock")
	assert_true("Insufficient stock" in result.reason, "Reason should mention insufficient stock")


func test_can_buy_exceeds_cargo():
	# Ship has 100 cargo space, each commodity is 1 unit.
	# Try to buy 150 ore.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 150)
	# This should fail due to stock (only 50 available) first.
	assert_false(result.success, "Should fail validation")


func test_execute_buy_success():
	var initial_wp = GameState.characters[TEST_CHARACTER_UID].wealth_points
	var result = trading_system.execute_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	
	assert_true(result.success, "Buy should succeed")
	
	# Check WP deducted.
	var expected_wp = initial_wp - (5 * 10) # 5 ore at 10 each.
	assert_eq(GameState.characters[TEST_CHARACTER_UID].wealth_points, expected_wp, "WP should be deducted")
	
	# Check commodity added to inventory.
	var cargo = inventory_system.get_inventory_by_type(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY)
	assert_has(cargo, "commodity_ore", "Ore should be in cargo")
	assert_eq(cargo["commodity_ore"], 5, "Should have 5 ore in cargo")
	
	# Check station stock reduced.
	var location = GameState.locations[TEST_LOCATION_ID]
	assert_eq(location.market_inventory["commodity_ore"].quantity, 45, "Station should have 45 ore left")


func test_execute_buy_fails_validation():
	# Try to buy with insufficient WP: 40 ore at 10 each = 400 WP, but set to only 100.
	GameState.characters[TEST_CHARACTER_UID].wealth_points = 100
	var result = trading_system.execute_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 40)
	assert_false(result.success, "Buy should fail validation")
	assert_true("Insufficient funds" in result.reason, "Reason should mention insufficient funds")


# --- Sell Tests ---

func test_can_sell_owned_commodity():
	# Give player some ore to sell.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_true(result.success, "Should be able to sell owned ore")


func test_can_sell_non_owned_commodity():
	# Player has no ore.
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_false(result.success, "Should not be able to sell commodity not owned")
	assert_true("Insufficient cargo" in result.reason, "Reason should mention insufficient cargo")


func test_can_sell_more_than_owned():
	# Give player 3 ore, try to sell 10.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 3)
	
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 10)
	assert_false(result.success, "Should not be able to sell more than owned")
	assert_true("Insufficient cargo" in result.reason, "Reason should mention insufficient cargo")


func test_execute_sell_success():
	# Give player ore.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	var initial_wp = GameState.characters[TEST_CHARACTER_UID].wealth_points
	
	var result = trading_system.execute_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	
	assert_true(result.success, "Sell should succeed")
	
	# Check WP added (sell price is 8 for ore).
	var expected_wp = initial_wp + (5 * 8)
	assert_eq(GameState.characters[TEST_CHARACTER_UID].wealth_points, expected_wp, "WP should be added")
	
	# Check commodity removed from inventory.
	var cargo = inventory_system.get_inventory_by_type(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY)
	assert_eq(cargo.get("commodity_ore", 0), 5, "Should have 5 ore left")
	
	# Check station stock increased.
	var location = GameState.locations[TEST_LOCATION_ID]
	assert_eq(location.market_inventory["commodity_ore"].quantity, 55, "Station should have 55 ore now")


func test_execute_sell_fails_validation():
	# Try to sell without owning.
	var result = trading_system.execute_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_false(result.success, "Sell should fail validation")


# --- Market Info Tests ---

func test_get_market_prices():
	var prices = trading_system.get_market_prices(TEST_LOCATION_ID)
	
	assert_has(prices, "commodity_ore", "Should have ore prices")
	assert_eq(prices["commodity_ore"].buy_price, 10, "Ore buy price should be 10")
	assert_eq(prices["commodity_ore"].sell_price, 8, "Ore sell price should be 8")


func test_get_market_prices_invalid_location():
	var prices = trading_system.get_market_prices("nonexistent_station")
	assert_eq(prices.size(), 0, "Should return empty dict for invalid location")


func test_get_cargo_info():
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	
	var info = trading_system.get_cargo_info(TEST_CHARACTER_UID)
	
	# get_cargo_info returns {has_space, available, capacity, used}
	assert_true(info.has("capacity"), "Should have capacity key")
	assert_true(info.has("used"), "Should have used key")
	assert_true(info.has("available"), "Should have available key")
	assert_eq(info.used, 10, "Should have 10 units used")
