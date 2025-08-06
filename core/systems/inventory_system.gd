# File: core/systems/inventory_system.gd
# Purpose: Manages a global dictionary of inventories by type of asset.
# Version: 2.0 - Reworked to match new templates.

extends Node

var _inventories_ships: Dictionary = {}
var _inventories_modules: Dictionary = {}
var _inventories_commodieties: Dictionary = {}


func _ready():
	GlobalRefs.set_asset_system(self)
	print("AssetSystem Ready.")


# Functionality is TBD. 
# This system has to manage dictionaries of inventories of assets of different types, each
# instance of thereof should have its inventory UID, and should be linked to a character (not agent).
