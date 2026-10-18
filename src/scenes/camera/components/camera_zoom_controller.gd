# Manages camera zoom: one zoom level (0 = fully in, 1 = fully out) drives both distance and FoV.
# All distances scale with the target's apparent radius (ShipTemplate.apparent_radius).
# The inner part of the range (telephoto) holds the camera at its closest safe distance, which
# keeps the hull outside the near plane, and narrows the FoV instead.
# This is a component of the main OrbitCamera.

extends Node
class_name CameraZoomController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null

# --- From Configuration ---
var min_distance_multiplier: float = 0.0
var max_distance_multiplier: float = 0.0
var preferred_distance_multiplier: float = 0.0
var zoom_speed: float = 0.0
var _min_fov_deg: float = 0.0
var _max_fov_deg: float = 0.0
var _telephoto_min_fov_deg: float = 0.0
var _telephoto_fraction: float = 0.0

# --- Constants ---
const MIN_ABSOLUTE_DISTANCE = 1.0
const MAX_ABSOLUTE_DISTANCE = 500.0
const NEAR_PLANE_MARGIN = 1.5  # Closest camera distance is radius + near * this.
const DEFAULT_RADIUS = 10.0

# --- State ---
var current_distance: float = 0.0
var current_fov_deg: float = 70.0
var _zoom_level: float = 0.5
var _target_radius: float = DEFAULT_RADIUS
var _is_programmatically_setting_slider: bool = false


# --- Initialization ---
func initialize(camera_node: Camera, config: Dictionary):
	_camera = camera_node
	min_distance_multiplier = config.get("min_distance_multiplier", min_distance_multiplier)
	max_distance_multiplier = config.get("max_distance_multiplier", max_distance_multiplier)
	preferred_distance_multiplier = config.get("preferred_distance_multiplier", preferred_distance_multiplier)
	zoom_speed = config.get("zoom_speed", zoom_speed)
	_min_fov_deg = config.get("min_fov_deg", _min_fov_deg)
	_max_fov_deg = config.get("max_fov_deg", _max_fov_deg)
	_telephoto_min_fov_deg = config.get("telephoto_min_fov_deg", _min_fov_deg)
	_telephoto_fraction = config.get("telephoto_zoom_fraction", 0.0)
	current_distance = config.get("distance", current_distance)

	if EventBus and not EventBus.is_connected("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"):
		EventBus.connect("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed")


# --- Public Methods ---
func handle_input(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed and is_instance_valid(_target)):
		return
	var step: float = zoom_speed * 0.1
	if event.button_index == BUTTON_WHEEL_UP:
		set_zoom_level(_zoom_level - step)
		get_viewport().set_input_as_handled()
	elif event.button_index == BUTTON_WHEEL_DOWN:
		set_zoom_level(_zoom_level + step)
		get_viewport().set_input_as_handled()


func physics_update():
	if is_instance_valid(_target):
		_apply_zoom()


func set_target(new_target: Spatial):
	_target = new_target
	_target_radius = get_target_radius_of(_target)
	if is_instance_valid(_target):
		set_zoom_level(_level_for_distance(_target_radius * preferred_distance_multiplier))
	else:
		_apply_zoom()


func get_zoom_level() -> float:
	return _zoom_level


func get_target_radius() -> float:
	return _target_radius


# How far into the telephoto range the zoom is: 0 outside it, 1 at the narrowest FoV.
func get_telephoto_amount() -> float:
	if _telephoto_fraction <= 0.0:
		return 0.0
	return clamp(1.0 - _zoom_level / _telephoto_fraction, 0.0, 1.0)


# Distance for target tracking. In the telephoto range the camera backs off as the FoV narrows
# (a dolly zoom), so the ship keeps its on-screen size while the far target is magnified.
func get_tracking_distance() -> float:
	if _zoom_level >= _telephoto_fraction:
		return current_distance
	return current_distance * tan(deg2rad(_min_fov_deg) * 0.5) / tan(deg2rad(current_fov_deg) * 0.5)


func set_zoom_level(level: float, from_slider_event: bool = false) -> void:
	_zoom_level = clamp(level, 0.0, 1.0)
	_apply_zoom()
	if not from_slider_event:
		_sync_slider()


func get_min_distance() -> float:
	var near_plane: float = _camera.near if _camera != null else 0.0
	var by_radius: float = _target_radius * min_distance_multiplier
	return max(MIN_ABSOLUTE_DISTANCE, max(by_radius, _target_radius + near_plane * NEAR_PLANE_MARGIN))


func get_max_distance() -> float:
	return min(MAX_ABSOLUTE_DISTANCE, max(get_min_distance() + 1.0, _target_radius * max_distance_multiplier))


static func get_target_radius_of(target_node: Spatial) -> float:
	if not is_instance_valid(target_node):
		return DEFAULT_RADIUS
	if target_node.has_method("get_apparent_radius"):
		return max(float(target_node.get_apparent_radius()), 1.0)
	if target_node.has_method("get_interaction_radius"):
		return max(float(target_node.get_interaction_radius()), 1.0)
	return DEFAULT_RADIUS


# --- Signal Handlers ---
func _on_player_camera_zoom_changed(value):
	if _is_programmatically_setting_slider:
		return
	set_zoom_level(value / 100.0, true)


# --- Private Helpers ---

# Zoom level -> distance and FoV. Telephoto part: fixed closest distance, FoV narrows.
# Rest: distance grows geometrically (even feel per wheel step) while FoV widens.
func _apply_zoom() -> void:
	var min_distance: float = get_min_distance()
	var max_distance: float = get_max_distance()
	if _zoom_level < _telephoto_fraction:
		var t: float = _zoom_level / _telephoto_fraction
		current_distance = min_distance
		current_fov_deg = _geometric_lerp(_telephoto_min_fov_deg, _min_fov_deg, t)
	else:
		var u: float = (_zoom_level - _telephoto_fraction) / max(1.0 - _telephoto_fraction, 0.0001)
		current_distance = _geometric_lerp(min_distance, max_distance, u)
		current_fov_deg = lerp(_min_fov_deg, _max_fov_deg, u)
	_apply_camera_fov(current_fov_deg)


func _level_for_distance(distance: float) -> float:
	var min_distance: float = get_min_distance()
	var max_distance: float = get_max_distance()
	if distance <= min_distance:
		return _telephoto_fraction
	var u: float = log(distance / min_distance) / log(max_distance / min_distance)
	return _telephoto_fraction + clamp(u, 0.0, 1.0) * (1.0 - _telephoto_fraction)


static func _geometric_lerp(from: float, to: float, t: float) -> float:
	return from * pow(to / from, t)


func _sync_slider() -> void:
	if not is_instance_valid(GlobalRefs.main_hud):
		return
	var zoom_slider = GlobalRefs.main_hud.get_node_or_null("ScreenControls/CenterLeftZone/SliderControlLeft")
	if is_instance_valid(zoom_slider):
		_is_programmatically_setting_slider = true
		zoom_slider.value = _zoom_level * 100.0
		_is_programmatically_setting_slider = false


func _apply_camera_fov(computed_fov: float) -> void:
	if _camera != null and _camera.has_method("apply_zoom_controller_fov"):
		_camera.call("apply_zoom_controller_fov", computed_fov)
	elif _camera != null:
		_camera.fov = computed_fov


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"):
			EventBus.disconnect("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed")
