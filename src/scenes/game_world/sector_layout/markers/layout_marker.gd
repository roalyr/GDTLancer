# LayoutMarker: a point of a sector's layout placed in its layout scene
# (scenes/levels/sectors/<sector>/layout.tscn): a haven, beacon or hazard (HavenMarker,
# BeaconMarker, HazardMarker). Its position is the point's; in the editor it draws its reach.
# Read by SectorLayoutMarkers.to_spec; nothing of it runs in play.

tool
extends Position3D

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const MarkerRing = preload("res://src/scenes/game_world/sector_layout/markers/marker_ring.gd")

var _ring: ImmediateGeometry = null


func _ready() -> void:
	if not Engine.editor_hint:
		return
	_ring = MarkerRing.new()
	add_child(_ring)
	_update_ring()


# The ring's radius and colour (0: none); markers override.
func _ring_radius() -> float:
	return 0.0


func _ring_color() -> Color:
	return Color(1, 1, 1, 0.6)


func _update_ring() -> void:
	if _ring != null:
		_ring.ring_color = _ring_color()
		_ring.radius = _ring_radius()


# The point as SectorLayout reads it, `at` its position from the layout root; markers override.
func to_spec(at: Vector3) -> Dictionary:
	return {}
