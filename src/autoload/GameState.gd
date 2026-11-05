# Global run state: current sector, player ship, player transform and docking/jump bookkeeping.
# Pure data store; GameStateManager handles save/load.

extends Node

## Ship template the player flies (set from the game start).
var player_ship_template_id: String = ""

## Player hull carried across sector loads; negative means full (new ship).
var player_hull: float = -1.0

## Scars on the player's hull (HullScars.export_scars()); kept until the hull is repaired.
var player_hull_scars: Array = []


## The run's home port (station location_id): docking there banks cargo and repairs the ship.
var home_location_id: String = ""

## Value banked at the home port this run.
var player_bank: int = 0

## The player's ship fit (ShipFit: parts per slot); empty means the hull's default fit.
var player_fit: Dictionary = {}

## Parts kept at the home port, not fitted: part id -> count.
var player_storage: Dictionary = {}

## The player's standing with each faction (Standing): faction id -> -1..1; missing means its start.
var player_standing: Dictionary = {}

## Bounties posted on the player (Bounty): faction id -> WP; they lapse when the ship is lost.
var player_bounties: Dictionary = {}

## Persistent travelling NPCs (Traffic): their records, and when lost ones are replaced (world time).
var travelers: Array = []
var traffic_replacements: Array = []
var traffic_next_id: int = 0

## Game time (scaled with the time scale, unlike play_time), the clock the travellers keep.
var world_time: float = 0.0

## Each station's price markup (Market): location id -> 0..PRICE_MARKUP_MAX, rolled on first use.
var station_markups: Dictionary = {}
var station_markup_until: Dictionary = {}  # Location id -> world time its markup is rolled again

## Lances left in the player's lance quiver; negative means full.
var player_lance_nails: int = -1
var player_tool_ammo: Array = []  # [[tool id, rounds left] per tool slot] (ToolController)

## Player hold: commodity id -> units.
var player_cargo: Dictionary = {}

## Currently loaded zone node.
var current_zone_instance: Node = null

## ID of the currently loaded sector (e.g. "sector_elace").
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

# Wall-clock seconds played in this game (saved; shown when offering to load it).
var play_time: float = 0.0


func reset_state() -> void:
	play_time = 0.0
	player_ship_template_id = ""
	player_hull = -1.0
	player_lance_nails = -1
	player_tool_ammo = []
	player_cargo = {}
	home_location_id = ""
	player_bank = 0
	player_fit = {}
	player_storage = {}
	player_standing = {}
	player_bounties = {}
	travelers = []
	traffic_replacements = []
	traffic_next_id = 0
	world_time = 0.0
	station_markups = {}
	station_markup_until = {}
	player_hull_scars = []
	current_zone_instance = null
	current_sector_id = ""
	player_docked_at = ""
	player_position = Vector3.ZERO
	player_rotation = Vector3.ZERO
	player_arrived_from_sector = ""
	player_arrival_direction = Vector3.ZERO
