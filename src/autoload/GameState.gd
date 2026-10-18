# Global run state: current sector, player ship, player transform and docking/jump bookkeeping.
# Pure data store; GameStateManager handles save/load.

extends Node

## Ship template the player flies (set from the game start).
var player_ship_template_id: String = ""

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
	current_zone_instance = null
	current_sector_id = ""
	player_docked_at = ""
	player_position = Vector3.ZERO
	player_rotation = Vector3.ZERO
	player_arrived_from_sector = ""
	player_arrival_direction = Vector3.ZERO
