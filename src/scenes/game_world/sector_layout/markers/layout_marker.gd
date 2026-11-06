# LayoutMarker: a point of a sector's layout placed in its layout scene
# (scenes/levels/sectors/<sector>/layout.tscn): a haven, beacon or hazard (HavenMarker,
# BeaconMarker, HazardMarker). Its position is the point's; in the editor it draws its reach.
# Read by SectorLayoutMarkers.to_spec; nothing of it runs in play. With `attached_to` it rides with
# a body of the sector scene (a star's radiation, a planet's ring of rocks): its position is then
# from that body, so moving the body moves it too.

tool
extends Position3D

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const MarkerRing = preload("res://src/scenes/game_world/sector_layout/markers/marker_ring.gd")

export var attached_to: String = ""  # A body it rides with (its node path in the sector scene, e.g. "SceneAssets/Star Elace"): its translation is then from that body; "" none

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


# The point as SectorLayout reads it, `at` its position from the layout root (an offset from its
# body's, when attached); markers override and pass their spec through attach().
func to_spec(at: Vector3) -> Dictionary:
	return attach({})


func attach(spec: Dictionary) -> Dictionary:
	if attached_to != "":
		spec["attached_to"] = attached_to
	return spec
