# File: core/systems/inventory_system.gd
# Purpose: Provides a unified, stateless API for managing all character inventories.
# Version: 4.0 - Reworked for a unified, asset-agnostic architecture.

extends Node

# Enum to define the different types of asset inventories a character can have.
enum InventoryType { SHIP, MODULE, COMMODITY }


func _ready():
	GlobalRefs.set_inventory_system(self)
	print("InventorySystem Ready.")


# --- Public API ---

# Ensures an inventory record exists for a character in the GameState.
# This should be called by the WorldGenerator when a character is created.
func create_inventory_for_character(character_uid: int):
	if not GameState.inventories.has(character_uid):
		GameState.inventories[character_uid] = {
			InventoryType.SHIP: {},      # Key: Asset UID, Value: Asset Instance
			InventoryType.MODULE: {},    # Key: Asset UID, Value: Asset Instance
			InventoryType.COMMODITY: {}  # Key: Template ID, Value: Quantity
		}

# Adds any type of asset to a character's inventory.
func add_asset(character_uid: int, inventory_type: int, asset_id, quantity: int = 1):
	if not GameState.inventories.has(character_uid):
		printerr("InventorySystem: No inventory for character UID: ", character_uid)
		return

	var inventory = GameState.inventories[character_uid]

	if inventory_type == InventoryType.COMMODITY:
		# Commodities are stored by template ID and quantity.
		if inventory[inventory_type].has(asset_id):
			inventory[inventory_type][asset_id] += quantity
		else:
			inventory[inventory_type][asset_id] = quantity
	else:
		# Ships and Modules are unique instances stored by their UID.
		var asset_instance = _get_master_asset_instance(inventory_type, asset_id)
		if is_instance_valid(asset_instance):
			inventory[inventory_type][asset_id] = asset_instance
		else:
			printerr("InventorySystem: Invalid asset UID provided: ", asset_id)

# Removes any type of asset from a character's inventory.
func remove_asset(character_uid: int, inventory_type: int, asset_id, quantity: int = 1) -> bool:
	if not GameState.inventories.has(character_uid):
		return false

	var inventory = GameState.inventories[character_uid]

	if not inventory[inventory_type].has(asset_id):
		return false # They don't have the asset.

	if inventory_type == InventoryType.COMMODITY:
		if inventory[inventory_type][asset_id] < quantity:
			return false # Not enough to remove.
		inventory[inventory_type][asset_id] -= quantity
		if inventory[inventory_type][asset_id] <= 0:
			inventory[inventory_type].erase(asset_id)
	else:
		# For unique assets, quantity doesn't matter; we just remove the entry.
		inventory[inventory_type].erase(asset_id)

	return true

# Gets the count of a specific asset.
func get_asset_count(character_uid: int, inventory_type: int, asset_id) -> int:
	if not GameState.inventories.has(character_uid):
		return 0
	
	if inventory_type == InventoryType.COMMODITY:
		return GameState.inventories[character_uid][inventory_type].get(asset_id, 0)
	else:
		return 1 if GameState.inventories[character_uid][inventory_type].has(asset_id) else 0

# Returns a dictionary of a specific type of asset from a character's inventory.
func get_inventory_by_type(character_uid: int, inventory_type: int) -> Dictionary:
	if GameState.inventories.has(character_uid):
		return GameState.inventories[character_uid][inventory_type].duplicate(true)
	return {}


# --- Private Helper ---

# Finds the master asset instance from the correct dictionary in GameState.
func _get_master_asset_instance(inventory_type: int, asset_uid: int) -> Resource:
	if inventory_type == InventoryType.SHIP:
		return GameState.assets_ships.get(asset_uid)
	elif inventory_type == InventoryType.MODULE:
		return GameState.assets_modules.get(asset_uid)
	return null
