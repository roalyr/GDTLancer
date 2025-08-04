# File: core/resource/commodity.gd
# Purpose: Defines the data structure for a tradable commodity.
# Version: 1.0

extends Resource
class_name Commodity

# --- Commodity Stats from GDD ---
export var item_id: String = "default_item"
export var name: String = "Unnamed Commodity"
export var base_value: int = 10 # Base value in WP for one unit
