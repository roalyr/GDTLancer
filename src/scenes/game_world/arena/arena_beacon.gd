# ArenaBeacon: the middle of an arena (see Arena). Seen from anywhere in the system, so the player
# can pick an arena and fly to it; NPCs of the arena patrol round it.

extends StaticBody

export var zone_id: String = ""


func _ready():
	add_to_group("arena_beacon")


func get_signature() -> float:
	return INF


func get_apparent_radius() -> float:
	return 20.0
