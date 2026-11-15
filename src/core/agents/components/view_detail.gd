# ViewDetail: keeps a host's view band (ViewBand) for everything on it to follow. A host (a ship, a
# rock) gets one with attach(); its levels of detail (MeshLod), scars, smoulder spots, damage trails,
# hit lights and cables read `band` or listen to band_changed instead of each measuring the camera
# distance, so they all change together, at the same thresholds.
# - Checked every Constants.VIEW_CHECK_INTERVAL (spread over frames), and at once when the
#   camera's field of view changes (zooming), so zooming in on a far ship shows its detail without
#   a delay.
# - Starts at Constants.VIEW_CLOSE (everything shown) until the first check; with no camera
#   (tests, tools) it stays there.
# - One ViewDetail, the leader (the first in the tree), runs every ViewDetail's check each frame,
#   reading each viewport's camera once: a node per host each running its own _process cost a
#   millisecond a frame doing next to nothing. The others' processing stays off; when the leader
#   leaves the tree the next one leads. Called by hand (tests), _process checks that one only,
#   unless it leads.

extends Node

signal band_changed(band)

const ViewBand = preload("res://src/core/utils/view_band.gd")
const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")
const META = "view_detail"

var radius: float = 10.0  # The host's apparent radius (m), unless the host has get_apparent_radius()
var band: int = Constants.VIEW_CLOSE

var _host: Spatial = null
var _due := -1.0  # When its next check is due, on _ALL.clock (below 0: at once)
var _timer: float setget _set_timer, _get_timer  # s to its next check (the time to _due), for tests and attach
var _last_fov := -1.0
var _viewport: Viewport = null  # Where it is drawn (its camera judges it), set on entering the tree

# Every ViewDetail in the tree; the one that runs them; the clock their checks are due on (the
# frames' deltas summed); each viewport in use (id -> [viewport, field of view last seen]).
const _ALL := {"list": [], "leader": null, "clock": 0.0, "viewports": {}}


func _set_timer(value: float) -> void:
	_due = _ALL.clock + value


func _get_timer() -> float:
	return _due - _ALL.clock


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


func _enter_tree() -> void:
	_viewport = get_viewport()
	_due = -1.0  # Judged at once: the camera may have moved or zoomed while it was away
	if not self in _ALL.list:
		_ALL.list.append(self)
	var id: int = _viewport.get_instance_id()
	if not _ALL.viewports.has(id):
		_ALL.viewports[id] = [_viewport, -1.0]
	var leader = _ALL.leader
	if not (is_instance_valid(leader) and leader.is_inside_tree()):
		_ALL.leader = self
	set_process(_ALL.leader == self)


func _ready() -> void:
	set_process(_ALL.leader == self)  # Godot turns processing on at ready for a script with _process


func _exit_tree() -> void:
	_ALL.list.erase(self)
	if _ALL.leader == self:
		_ALL.leader = null
		set_process(false)
		for other in _ALL.list:
			if is_instance_valid(other) and other.is_inside_tree():
				_ALL.leader = other
				other.set_process(true)
				break


# The leader checks them all; called by hand on another (tests), it checks that one.
func _process(delta: float) -> void:
	if _ALL.leader == self:
		_check_all(delta)
		return
	var camera: Camera = get_viewport().get_camera()
	_due -= delta
	if camera == null or not is_instance_valid(_host):
		return
	if _due > _ALL.clock and camera.fov == _last_fov:
		return
	_judge(camera)


# The leader's pass ("view" section): each viewport's camera read once; a ViewDetail is judged when
# its check is due, and every one at once when a field of view changed (a zoom).
func _check_all(delta: float) -> void:
	var tree: SceneTree = get_tree()
	FrameProfiler.begin(tree, "view")
	_ALL.clock += delta
	var clock: float = _ALL.clock
	var zoomed := false
	for id in _ALL.viewports.keys():
		var seen: Array = _ALL.viewports[id]
		if not is_instance_valid(seen[0]):
			_ALL.viewports.erase(id)
			continue
		var camera: Camera = seen[0].get_camera()
		var fov: float = camera.fov if camera != null else -1.0
		if fov != seen[1]:
			seen[1] = fov
			zoomed = true
	for detail in _ALL.list.duplicate():  # A band change may take a host out of the tree
		if not is_instance_valid(detail) or (detail._due > clock and not zoomed):
			continue
		if not detail.is_inside_tree() or not is_instance_valid(detail._host):
			continue
		var camera: Camera = detail._viewport.get_camera()
		if camera != null:
			detail._judge(camera)
	FrameProfiler.end(tree, "view")


func _judge(camera: Camera) -> void:
	_due = _ALL.clock + Constants.VIEW_CHECK_INTERVAL
	_last_fov = camera.fov
	update_band(camera)


# Judges the band from `camera` now; emits band_changed if it changed.
func update_band(camera: Camera) -> void:
	var size: float = _host.get_apparent_radius() if _host.has_method("get_apparent_radius") else radius  # Rocks are scaled after they are in
	var new_band: int = ViewBand.band_for(ViewBand.screen_share(camera, _host.global_transform.origin, size), band)
	if new_band != band:
		band = new_band
		emit_signal("band_changed", band)
