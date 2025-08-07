# File: core/systems/asset_system.gd
# Purpose: Provides a logical API for accessing asset data stored in GameState.
# This system is STATELESS. All data is read from the GameState autoload.
# Version: 3.0 - Refactored to be stateless.

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
