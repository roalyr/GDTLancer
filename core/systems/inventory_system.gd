# File: core/systems/inventory_system.gd
# Purpose: Manages an agent's cargo hold.
# Version: 1.0

extends Node

# --- State ---
# Key: Commodity Resource (or item_id), Value: quantity
var _player_cargo: Dictionary = {}


func _ready():
	# GlobalRefs.inventory_system = self # Assuming you'll add this to GlobalRefs.gd
	print("InventorySystem Ready.")


# --- Public API ---

# Adds an item to the player's cargo if space is available.
func add_item(commodity: Commodity, quantity: int) -> bool:
	if not is_instance_valid(commodity) or quantity <= 0:
		return false

	var current_cargo = get_total_cargo_amount()
	var cargo_capacity = GlobalRefs.asset_system.get_player_ship_stat("cargo_capacity")

	if current_cargo + quantity > cargo_capacity:
		printerr("InventorySystem: Not enough cargo space.")
		return false

	if not _player_cargo.has(commodity.item_id):
		_player_cargo[commodity.item_id] = {"item": commodity, "quantity": 0}

	_player_cargo[commodity.item_id].quantity += quantity
	print("InventorySystem: Added %d x %s. New total: %d" % [quantity, commodity.name, _player_cargo[commodity.item_id].quantity])
	return true


# Removes an item from the player's cargo if available.
func remove_item(item_id: String, quantity: int) -> bool:
	if not _player_cargo.has(item_id) or quantity <= 0:
		return false

	if _player_cargo[item_id].quantity < quantity:
		printerr("InventorySystem: Not enough items to remove.")
		return false

	_player_cargo[item_id].quantity -= quantity
	print("InventorySystem: Removed %d x %s. New total: %d" % [quantity, _player_cargo[item_id].item.name, _player_cargo[item_id].quantity])

	if _player_cargo[item_id].quantity == 0:
		_player_cargo.erase(item_id)

	return true


func get_total_cargo_amount() -> int:
	var total = 0
	for item_data in _player_cargo.values():
		total += item_data.quantity
	return total


func get_player_cargo() -> Dictionary:
	return _player_cargo
