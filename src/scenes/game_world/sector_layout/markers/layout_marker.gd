# LayoutMarker: a point of a sector's layout placed in its layout scene
# (scenes/levels/sectors/<sector>/<sector>_layout.tscn): a haven, beacon or hazard (HavenMarker,
# BeaconMarker, HazardMarker). Its position is the point's; in the editor it draws its reach.
# Read by SectorLayoutMarkers.to_spec; nothing of it runs in play. With `attached_to` it rides with
# a body of the sector scene (a star's radiation, a planet's ring of rocks): its position is then
# from that body, so moving the body moves it too. In the editor its ring is drawn where the game
# puts it (round the body, the offset away); the marker's own cross stays at the offset.

tool
extends Position3D

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const MarkerRing = preload("res://src/scenes/game_world/sector_layout/markers/marker_ring.gd")

export var attached_to: String = ""  # A body it rides with (its node path in the sector scene, e.g. "SceneAssets/Star Elace"): its translation is then from that body; "" none

var _ring: ImmediateGeometry = null


func _ready() -> void:
	set_process(Engine.editor_hint)  # Only the editor's ring follows a body
	if not Engine.editor_hint:
		return
	_ring = MarkerRing.new()
	add_child(_ring)
	_update_ring()


func _process(_delta: float) -> void:
	if _ring == null:
		return
	var body: Spatial = _attached_body()
	var layout = owner if owner is Spatial else null  # The layout scene's root
	if body != null and layout != null:
		_ring.global_transform.origin = body.global_transform.origin + (global_transform.origin - layout.global_transform.origin)
	elif _ring.transform.origin != Vector3.ZERO:
		_ring.transform.origin = Vector3.ZERO


# The body it is attached to, looked up from the scene it sits in (as SectorLayout does), or null:
# none, or the layout scene is open on its own.
func _attached_body() -> Spatial:
	if attached_to == "":
		return null
	var node: Node = self
	while node.get_parent() != null and not node.get_parent() is Viewport:
		node = node.get_parent()
		var found = node.get_node_or_null(attached_to)
		if found is Spatial:
			return found
	return null


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
