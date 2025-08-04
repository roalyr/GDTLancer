# File: core/resource/ship_asset.gd
# Purpose: Defines a **specific instance** of a ship owned by an agent.
# Version: 1.1

extends Resource
class_name ShipAsset

# --- Link to Blueprint ---
# This is the single source of truth for base stats.
var template: ShipAgentData

# --- Instance-Specific State ---
export var ship_name: String = "Unnamed Ship" # Player can rename their specific ship
export var current_hull_integrity: int = 100

# --- Modifications & Quirks ---
# These store deltas or additions to the base template.
export var ship_quirks: Array = []
# export var installed_upgrades: Array = [] # Future-proofing

func _ready():
	# When a new asset is created, initialize its state from the template.
	if is_instance_valid(template):
		current_hull_integrity = template.base_hull_integrity
	else:
		printerr("ShipAsset Error: Template not assigned for '", ship_name, "'!")
