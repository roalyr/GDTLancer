# Global run state: current sector, player ship, player transform and docking/jump bookkeeping.
# Pure data store; GameStateManager handles save/load.

extends Node

## Ship template the player flies (set from the game start).
var player_ship_template_id: String = ""

## Player hull carried across sector loads; negative means full (new ship).
var player_hull: float = -1.0

## Damage marks on the player's hull (HullScorch.export_marks()); kept until the hull is repaired.
var player_hull_marks: Dictionary = {}

## The run's home port (station location_id): docking there banks cargo and repairs the ship.
var home_location_id: String = ""

## Value banked at the home port this run.
var player_bank: int = 0

## Player hold: commodity id -> units.
var player_cargo: Dictionary = {}

## Currently loaded zone node.
var current_zone_instance: Node = null

## ID of the currently loaded sector (e.g. "sector_star_elace").
var current_sector_id: String = ""

## Location ID the player is docked at, or empty string if in space.
var player_docked_at: String = ""

## Player spatial position in the active zone.
var player_position: Vector3 = Vector3.ZERO

## Player spatial rotation in the active zone (degrees).
var player_rotation: Vector3 = Vector3.ZERO

## Sector the player just jumped from (for arrival spawn at return jump point).
var player_arrived_from_sector: String = ""

## Direction from sector center toward the jump arrival shell spawn point.
var player_arrival_direction: Vector3 = Vector3.ZERO


func reset_state() -> void:
	player_ship_template_id = ""
	player_hull = -1.0
	player_cargo = {}
	home_location_id = ""
	player_bank = 0
	player_hull_marks = {}
	current_zone_instance = null
	current_sector_id = ""
	player_docked_at = ""
	player_position = Vector3.ZERO
	player_rotation = Vector3.ZERO
	player_arrived_from_sector = ""
	player_arrival_direction = Vector3.ZERO
