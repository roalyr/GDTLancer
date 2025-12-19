# File: core/systems/trading_system.gd
# Purpose: Provides a stateless API for trading commodities between characters and locations.
# Version: 1.0

extends Node


func _ready():
	GlobalRefs.set_trading_system(self)
	print("TradingSystem Ready.")


# --- Public API ---


# Checks if a character can buy a commodity from a location.
# Returns: {success: bool, reason: String, total_cost: int}
func can_buy(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "total_cost": 0}
	
	# Validate inputs
	if quantity <= 0:
		result.reason = "Invalid quantity"
		return result
	
	# Check location exists
	if not GameState.locations.has(location_id):
		result.reason = "Location not found"
		return result
	
	var location = GameState.locations[location_id]
	
	# Check location has this commodity
	if not location.market_inventory.has(commodity_id):
		result.reason = "Commodity not available at this location"
		return result
	
	var market_entry = location.market_inventory[commodity_id]
	
	# Check sufficient quantity at market
	if market_entry.quantity < quantity:
		result.reason = "Insufficient stock (available: %d)" % market_entry.quantity
		return result
	
	# Calculate total cost (use buy_price if available, else price)
	var unit_price = market_entry.get("buy_price", market_entry.get("price", 0))
	var total_cost = unit_price * quantity
	result.total_cost = total_cost
	
	# Check character has enough WP
	if not is_instance_valid(GlobalRefs.character_system):
		result.reason = "Character system unavailable"
		return result
	
	var current_wp = GlobalRefs.character_system.get_wp(char_uid)
	if current_wp < total_cost:
		result.reason = "Insufficient funds (need: %d WP, have: %d WP)" % [total_cost, current_wp]
		return result
	
	# Check cargo capacity
	var cargo_check = _check_cargo_capacity(char_uid, quantity)
	if not cargo_check.has_space:
		result.reason = "Insufficient cargo space (need: %d, available: %d)" % [quantity, cargo_check.available]
		return result
	
	result.success = true
	result.reason = "OK"
	return result


# Executes a buy transaction.
# Returns: {success: bool, reason: String, wp_spent: int, quantity_bought: int}
func execute_buy(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "wp_spent": 0, "quantity_bought": 0}
	
	# First check if we can buy
	var can_buy_result = can_buy(char_uid, location_id, commodity_id, quantity)
	if not can_buy_result.success:
		result.reason = can_buy_result.reason
		return result
	
	var total_cost = can_buy_result.total_cost
	var location = GameState.locations[location_id]
	
	# Execute transaction
	# 1. Deduct WP from character
	GlobalRefs.character_system.subtract_wp(char_uid, total_cost)
	
	# 2. Add commodity to character inventory
	GlobalRefs.inventory_system.add_asset(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id, 
		quantity
	)
	
	# 3. Reduce market inventory
	location.market_inventory[commodity_id].quantity -= quantity
	
	# 4. Track session stats
	GameState.session_stats.total_wp_spent += total_cost
	
	# 5. Emit signal
	EventBus.emit_signal("trade_transaction_completed", {
		"type": "buy",
		"char_uid": char_uid,
		"location_id": location_id,
		"commodity_id": commodity_id,
		"quantity": quantity,
		"total_price": total_cost
	})
	
	result.success = true
	result.reason = "OK"
	result.wp_spent = total_cost
	result.quantity_bought = quantity
	return result


# Checks if a character can sell a commodity at a location.
# Returns: {success: bool, reason: String, total_value: int}
func can_sell(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "total_value": 0}
	
	# Validate inputs
	if quantity <= 0:
		result.reason = "Invalid quantity"
		return result
	
	# Check location exists
	if not GameState.locations.has(location_id):
		result.reason = "Location not found"
		return result
	
	var location = GameState.locations[location_id]
	
	# Check location accepts this commodity (has a price for it)
	if not location.market_inventory.has(commodity_id):
		result.reason = "This location does not trade in this commodity"
		return result
	
	# Check character has the commodity
	if not is_instance_valid(GlobalRefs.inventory_system):
		result.reason = "Inventory system unavailable"
		return result
	
	var owned_quantity = GlobalRefs.inventory_system.get_asset_count(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id
	)
	
	if owned_quantity < quantity:
		result.reason = "Insufficient cargo (have: %d, trying to sell: %d)" % [owned_quantity, quantity]
		return result
	
	# Calculate value (use sell_price if available, else price)
	var market_entry = location.market_inventory[commodity_id]
	var unit_price = market_entry.get("sell_price", market_entry.get("price", 0))
	var total_value = unit_price * quantity
	result.total_value = total_value
	
	result.success = true
	result.reason = "OK"
	return result


# Executes a sell transaction.
# Returns: {success: bool, reason: String, wp_earned: int, quantity_sold: int}
func execute_sell(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "wp_earned": 0, "quantity_sold": 0}
	
	# First check if we can sell
	var can_sell_result = can_sell(char_uid, location_id, commodity_id, quantity)
	if not can_sell_result.success:
		result.reason = can_sell_result.reason
		return result
	
	var total_value = can_sell_result.total_value
	var location = GameState.locations[location_id]
	
	# Execute transaction
	# 1. Remove commodity from character inventory
	var removed = GlobalRefs.inventory_system.remove_asset(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id, 
		quantity
	)
	
	if not removed:
		result.reason = "Failed to remove commodity from inventory"
		return result
	
	# 2. Add WP to character
	GlobalRefs.character_system.add_wp(char_uid, total_value)
	
	# 3. Increase market inventory
	location.market_inventory[commodity_id].quantity += quantity
	
	# 4. Track session stats
	GameState.session_stats.total_wp_earned += total_value
	
	# 5. Emit signal
	EventBus.emit_signal("trade_transaction_completed", {
		"type": "sell",
		"char_uid": char_uid,
		"location_id": location_id,
		"commodity_id": commodity_id,
		"quantity": quantity,
		"total_price": total_value
	})
	
	result.success = true
	result.reason = "OK"
	result.wp_earned = total_value
	result.quantity_sold = quantity
	return result


# Gets the market prices at a location.
# Returns: Dictionary of commodity_id -> {price: int, quantity: int}
func get_market_prices(location_id: String) -> Dictionary:
	if not GameState.locations.has(location_id):
		return {}
	
	var location = GameState.locations[location_id]
	# Return a copy to prevent external modification
	return location.market_inventory.duplicate(true)


# Gets all commodities the player owns.
# Returns: Dictionary of commodity_id -> quantity
func get_player_cargo(char_uid: int) -> Dictionary:
	if not is_instance_valid(GlobalRefs.inventory_system):
		return {}
	
	return GlobalRefs.inventory_system.get_inventory_by_type(
		char_uid,
		GlobalRefs.inventory_system.InventoryType.COMMODITY
	)


# --- Private Helpers ---


# Checks if character's ship has cargo space for additional items.
# Returns: {has_space: bool, available: int, capacity: int, used: int}
func _check_cargo_capacity(char_uid: int, additional_quantity: int) -> Dictionary:
	var result = {"has_space": false, "available": 0, "capacity": 0, "used": 0}
	
	# Get ship's cargo capacity
	if not is_instance_valid(GlobalRefs.asset_system):
		return result
	
	var ship = GlobalRefs.asset_system.get_ship_for_character(char_uid)
	if not is_instance_valid(ship):
		return result
	
	result.capacity = ship.cargo_capacity
	
	# Calculate current cargo usage
	var cargo = get_player_cargo(char_uid)
	var total_used = 0
	for commodity_id in cargo:
		total_used += cargo[commodity_id]
	
	result.used = total_used
	result.available = result.capacity - result.used
	result.has_space = result.available >= additional_quantity
	
	return result


# Gets cargo capacity info for UI display.
# Returns: {capacity: int, used: int, available: int}
func get_cargo_info(char_uid: int) -> Dictionary:
	return _check_cargo_capacity(char_uid, 0)
