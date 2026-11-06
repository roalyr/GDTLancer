# BeaconMarker: a point of a sector's map the AI goes by. `kind`: "patrol" (a faction's, `owner`:
# its patrol ships go round them, its safe zone), "field" (a rock field to mine: `rocks` of them
# within `radius`, `ring`: only the outer share past it, round a planet) or "landmark" (a point
# routes go through; every planet and moon gets one by itself; `player_visible` shows it on the HUD)
# or "entry" (where ships jumping in arrive and new games start, `radius` out from it; one a sector).

tool
extends "res://src/scenes/game_world/sector_layout/markers/layout_marker.gd"

export(String, "patrol", "field", "landmark", "entry") var kind: String = "landmark" setget _set_kind
export var beacon_name: String = ""
export var owner_faction: String = ""  # A patrol beacon's faction
export var radius: float = 0.0 setget _set_radius  # m; 0: the traffic radius (Constants BEACON_TRAFFIC_RADIUS)
export var rocks: int = 0  # A field's rocks
export var ring: float = 0.0  # A field round a planet: rocks only past this share of its radius
export var player_visible: bool = false  # A landmark shown on the HUD (fields always are)


func _set_kind(value: String) -> void:
	kind = value
	_update_ring()


func _set_radius(value: float) -> void:
	radius = value
	_update_ring()


func _ring_radius() -> float:
	return radius if radius > 0.0 else Defaults.BEACON_TRAFFIC_RADIUS


func _ring_color() -> Color:
	match kind:
		"patrol":
			return Color(0.5, 1.0, 0.5, 0.7)
		"field":
			return Color(1.0, 0.8, 0.4, 0.7)
		"entry":
			return Color(0.6, 0.8, 1.0, 0.7)
	return Color(0.8, 0.8, 0.8, 0.5)


func to_spec(at: Vector3) -> Dictionary:
	var spec := {"kind": kind, "name": beacon_name, "at": at}
	if owner_faction != "":
		spec["owner"] = owner_faction
	if radius > 0.0:
		spec["radius"] = radius
	if kind == "field":
		spec["rocks"] = rocks
		if ring > 0.0:
			spec["ring"] = ring
	if player_visible:
		spec["player_visible"] = true
	return attach(spec)
