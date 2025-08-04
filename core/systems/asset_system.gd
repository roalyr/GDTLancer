# File: core/systems/asset_system.gd
# Purpose: Manages an agent's major assets, primarily the player's ship.
# Version: 1.2 - Corrected property checking for Resources

extends Node

# --- State ---
var _player_ship_asset: ShipAsset = null


func _ready():
	GlobalRefs.set_asset_system(self)
	print("AssetSystem Ready.")


func initialize_player_ship(ship_asset: ShipAsset):
	if ship_asset is ShipAsset and is_instance_valid(ship_asset.template):
		_player_ship_asset = ship_asset
		print("AssetSystem: Player ship '", _player_ship_asset.ship_name, "' initialized from template '", _player_ship_asset.template.ship_class_name, "'.")
	else:
		printerr("AssetSystem Error: Invalid asset or template passed to initialize_player_ship.")


# Provides ship stats to other systems by reading from the template.
func get_player_ship_stat(stat_name: String):
	if not is_instance_valid(_player_ship_asset):
		printerr("AssetSystem Error: Player ship not initialized.")
		return null

	# --- THE FIX (Part 1) ---
	# Priority 1: Check the instance for current state using the 'in' keyword.
	if stat_name in _player_ship_asset:
		return _player_ship_asset.get(stat_name)

	# Priority 2: Check the linked template for base stats.
	var template_stat_name = "base_" + stat_name
	
	# --- THE FIX (Part 2) ---
	# Also check the template using the 'in' keyword.
	if is_instance_valid(_player_ship_asset.template) and template_stat_name in _player_ship_asset.template:
		var base_value = _player_ship_asset.template.get(template_stat_name)
		# In the future, we could apply modifiers from upgrades here.
		return base_value

	printerr("AssetSystem Warning: Could not find stat '", stat_name, "' on ship asset or its template.")
	return null
