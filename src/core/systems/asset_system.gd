# File: core/systems/asset_system.gd
# Purpose: Provides a logical API for accessing asset data stored in GameState.
# This system is STATELESS. All data is read from the GameState autoload.
# Version: 3.1 - Added get_ship_for_character() helper.

extends Node

func _ready():
	GlobalRefs.set_asset_system(self)
	print("AssetSystem Ready.")


# --- Public API ---


func get_ship(ship_uid: int) -> ShipTemplate:
	return GameState.assets_ships.get(ship_uid)


# Convenience function to get the player's currently active ship.
func get_player_ship() -> ShipTemplate:
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return null

	if player_char.active_ship_uid != -1:
		return get_ship(player_char.active_ship_uid)

	return null


# Gets the active ship for any character by their UID.
func get_ship_for_character(character_uid: int) -> ShipTemplate:
	if not GameState.characters.has(character_uid):
		return null
	
	var character = GameState.characters[character_uid]
	if not is_instance_valid(character):
		return null
	
	if character.active_ship_uid != -1:
		return get_ship(character.active_ship_uid)
	
	return null


# Gets all ships owned by a character (from their inventory).
func get_ships_for_character(character_uid: int) -> Array:
	var ships = []
	if not is_instance_valid(GlobalRefs.inventory_system):
		return ships
	
	var ship_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		character_uid, 
		GlobalRefs.inventory_system.InventoryType.SHIP
	)
	
	for ship_uid in ship_inventory.keys():
		var ship = get_ship(ship_uid)
		if is_instance_valid(ship):
			ships.append(ship)
	
	return ships
