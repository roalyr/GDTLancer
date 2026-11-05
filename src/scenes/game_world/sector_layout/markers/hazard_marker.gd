# HazardMarker: a region that hurts ships in it. "radiation" round a star, from `core` (its
# surface) out to `radius`; hull damage a second rises from 0 at the edge to HAZARD_RADIATION_DPS at
# the surface, as the square of the depth.

tool
extends "res://src/scenes/game_world/sector_layout/markers/layout_marker.gd"

export(String, "radiation") var kind: String = "radiation"
export var core: float = 0.0  # m: the surface
export var radius: float = 0.0 setget _set_radius  # m: the edge


func _set_radius(value: float) -> void:
	radius = value
	_update_ring()


func _ring_radius() -> float:
	return radius


func _ring_color() -> Color:
	return Color(1.0, 0.4, 0.3, 0.8)


func to_spec(at: Vector3) -> Dictionary:
	return {"kind": kind, "at": at, "core": core, "radius": radius}
