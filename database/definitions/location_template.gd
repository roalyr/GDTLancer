# File: core/resource/location_template.gd
# Purpose: Defines the data structure for a location (station, outpost, etc.)
# Version: 1.0

extends Template
class_name LocationTemplate

export var location_name: String = "Unknown Station"
export var location_type: String = "station"  # station, outpost, debris_field, asteroid_field
export var position_in_zone: Vector3 = Vector3.ZERO
export var interaction_radius: float = 100.0  # How close player must be to dock

# Market inventory: commodity_template_id -> {price: int, quantity: int}
# Example: {"commodity_ore": {"price": 10, "quantity": 50}}
export var market_inventory: Dictionary = {}

# Services available at this location
export var available_services: Array = ["trade", "contracts"]

# Faction that controls this location
export var controlling_faction_id: String = ""

# Danger level affects encounter chances nearby (0 = safe, 10 = very dangerous)
export var danger_level: int = 0

# Contracts available at this location (contract_template_ids)
export var available_contract_ids: Array = []
