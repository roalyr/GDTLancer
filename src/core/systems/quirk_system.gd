#
# PROJECT: GDTLancer
# MODULE: src/core/systems/quirk_system.gd
# STATUS: [Level 3 - Verified]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2025-10-31.md Section 2.1
# LOG_REF: 2025-12-23
#

extends Node

## System for managing Ship Quirks.
## Handles adding, removing, and querying quirks for ships.

func _ready() -> void:
	GlobalRefs.quirk_system = self
	print("QuirkSystem: Registered with GlobalRefs")


## Adds a quirk to a ship.
## Returns true if the quirk was successfully added, false otherwise.
func add_quirk(ship_uid: int, quirk_id: String) -> bool:
	if not GameState.assets_ships.has(ship_uid):
		push_warning("QuirkSystem: add_quirk failed - Ship UID not found: " + str(ship_uid))
		return false
		
	var ship_data = GameState.assets_ships[ship_uid]
	# ship_quirks should be an Array
	if not ship_data.get("ship_quirks") is Array:
		push_warning("QuirkSystem: add_quirk failed - ship_quirks is not an Array for ship: " + str(ship_uid))
		return false

	var quirks: Array = ship_data.ship_quirks
	
	if quirks.has(quirk_id):
		return false # Already has it
		
	quirks.append(quirk_id)
	EventBus.emit_signal("ship_quirk_added", ship_uid, quirk_id)
	print("QuirkSystem: Added quirk ", quirk_id, " to ship ", ship_uid)
	return true


## Removes a quirk from a ship.
## Returns true if the quirk was successfully removed, false otherwise.
func remove_quirk(ship_uid: int, quirk_id: String) -> bool:
	if not GameState.assets_ships.has(ship_uid):
		return false
		
	var ship_data = GameState.assets_ships[ship_uid]
	var quirks: Array = ship_data.ship_quirks
	
	if not quirks.has(quirk_id):
		return false
		
	quirks.erase(quirk_id)
	EventBus.emit_signal("ship_quirk_removed", ship_uid, quirk_id)
	return true


## Returns a copy of the quirks array for a given ship.
func get_quirks(ship_uid: int) -> Array:
	if not GameState.assets_ships.has(ship_uid):
		return []
	
	# Return copy as per architecture for getters
	return GameState.assets_ships[ship_uid].ship_quirks.duplicate()


## Checks if a ship has a specific quirk.
func has_quirk(ship_uid: int, quirk_id: String) -> bool:
	if not GameState.assets_ships.has(ship_uid):
		return false
	return GameState.assets_ships[ship_uid].ship_quirks.has(quirk_id)
