# ViewDetail: keeps a host's view band (ViewBand) for everything on it to follow. A host (a ship, a
# rock) gets one with attach(); its levels of detail (MeshLod), scars, smoulder spots, damage trails,
# hit lights and cables read `band` or listen to band_changed instead of each measuring the camera
# distance, so they all change together, at the same thresholds.
# - Checked every Constants.VIEW_CHECK_INTERVAL (spread over frames), and at once when the
#   camera's field of view changes (zooming), so zooming in on a far ship shows its detail without
#   a delay.
# - Starts at Constants.VIEW_CLOSE (everything shown) until the first check; with no camera
#   (tests, tools) it stays there.

extends Node

signal band_changed(band)

const ViewBand = preload("res://src/core/utils/view_band.gd")
const META = "view_detail"

var radius: float = 10.0  # The host's apparent radius (m), unless the host has get_apparent_radius()
var band: int = Constants.VIEW_CLOSE

var _host: Spatial = null
var _timer := 0.0
var _last_fov := -1.0


# Adds a ViewDetail to `host` for an object of `object_radius` and returns it.
static func attach(host: Spatial, object_radius: float) -> Node:
	var detail = load("res://src/core/agents/components/view_detail.gd").new()
	detail.name = "ViewDetail"
	detail.radius = max(object_radius, 0.1)
	detail._host = host
	detail._timer = randf() * Constants.VIEW_CHECK_INTERVAL  # Spread the checks over frames
	host.add_child(detail)
	host.set_meta(META, detail)
	return detail


# The ViewDetail of the host `node` is on (`node` itself or the nearest ancestor with one), or null.
static func of(node: Node) -> Node:
	while node != null:
		if node.has_meta(META):
			var detail = node.get_meta(META)
			return detail if is_instance_valid(detail) else null
		node = node.get_parent()
	return null


# The band of the host `node` is on; Constants.VIEW_CLOSE if it has none (show everything).
static func band_of_host(node: Node) -> int:
	var detail = of(node)
	return detail.band if detail != null else Constants.VIEW_CLOSE


func _process(delta: float) -> void:
	var camera = get_viewport().get_camera()
	if camera == null or not is_instance_valid(_host):
		return
	_timer -= delta
	if _timer > 0.0 and camera.fov == _last_fov:
		return
	_timer = Constants.VIEW_CHECK_INTERVAL
	_last_fov = camera.fov
	update_band(camera)


# Judges the band from `camera` now; emits band_changed if it changed.
func update_band(camera: Camera) -> void:
	var size: float = _host.get_apparent_radius() if _host.has_method("get_apparent_radius") else radius  # Rocks are scaled after they are in
	var new_band: int = ViewBand.band_for(ViewBand.screen_share(camera, _host.global_transform.origin, size), band)
	if new_band != band:
		band = new_band
		emit_signal("band_changed", band)
