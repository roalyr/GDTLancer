# File: core/systems/asset_system.gd
# Purpose: Manages dictionaries of different asset types globally (unique instances).
# Version: 2.0 - Reworked to match new templates.

extends Node

var _asset_ship_template: ShipTemplate = null
var _asset_module_template: ModuleTemplate = null
var _asset_commodity_template: CommodityTemplate = null

# Global dictionaries of instances.
var _assets_ships: Dictionary = {}
var _assets_modules: Dictionary = {}
var _assets_commodieties: Dictionary = {}


func _ready():
	GlobalRefs.set_asset_system(self)
	print("AssetSystem Ready.")


# Functionality is TBD. 
# This system has to manage dictionaries of assets of different types, each
# instance of thereof should have its UID, template and data overrides (for unique ships
# or modules / commodities (if needed)).
