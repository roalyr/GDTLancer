# File: scenes/camera/components/camera_zoom_controller.gd
# Purpose: Manages camera zoom, distance from target, and FoV calculations.
# This is a component of the main OrbitCamera.

extends Node
class_name CameraZoomController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null

# --- Configuration ---
var distance: float = 55.0
var min_distance_multiplier: float = 3.0
var max_distance_multiplier: float = 30.0
var preferred_distance_multiplier: float = 3.0
const MIN_ABSOLUTE_DISTANCE = 1.0
const MAX_ABSOLUTE_DISTANCE = 500.0
var zoom_speed: float = 0.5
var _min_fov_deg: float = 70.0
var _max_fov_deg: float = 80.0

# --- State ---
var current_distance: float = 55.0
var _target_radius: float = 15.0
var _is_programmatically_setting_slider: bool = false


# --- Initialization ---
func initialize(camera_node: Camera, config: Dictionary):
	_camera = camera_node
	
	# Set configuration from the main camera script
	distance = config.get("distance", distance)
	min_distance_multiplier = config.get("min_distance_multiplier", min_distance_multiplier)
	max_distance_multiplier = config.get("max_distance_multiplier", max_distance_multiplier)
	preferred_distance_multiplier = config.get("preferred_distance_multiplier", preferred_distance_multiplier)
	zoom_speed = config.get("zoom_speed", zoom_speed)
	_min_fov_deg = config.get("_min_fov_deg", _min_fov_deg)
	_max_fov_deg = config.get("_max_fov_deg", _max_fov_deg)
	
	current_distance = distance
	
	# Connect to EventBus signals
	if EventBus and not EventBus.is_connected("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"):
		EventBus.connect("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed")


# --- Public Methods ---
func handle_input(event: InputEvent):
	if event is InputEventMouseButton and is_instance_valid(_target):
		var zoom_factor = 1.0 + (zoom_speed * 0.1)
		var input_handled = false
		var new_distance_candidate = current_distance

		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			new_distance_candidate = current_distance / zoom_factor
			input_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			new_distance_candidate = current_distance * zoom_factor
			input_handled = true

		if input_handled:
			_set_and_update_zoom_distance(new_distance_candidate, false)
			get_viewport().set_input_as_handled()

func physics_update():
	# Update FoV based on current distance
	if is_instance_valid(_target):
		_update_fov()

func set_target(new_target: Spatial):
	_target = new_target
	if is_instance_valid(_target):
		_target_radius = _get_target_effective_radius(_target)
		# Reset distance to preferred when target changes
		var dyn_min_dist = _get_dynamic_min_distance()
		var dyn_max_dist = _get_dynamic_max_distance()
		var preferred_dist = max(dyn_min_dist, _target_radius * preferred_distance_multiplier)
		_set_and_update_zoom_distance(clamp(preferred_dist, dyn_min_dist, dyn_max_dist), false)
	else:
		_target_radius = 10.0
	
	_update_fov()


# --- Signal Handlers ---
func _on_player_camera_zoom_changed(value):
	if _is_programmatically_setting_slider:
		return

	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	var target_distance = lerp(dyn_min_dist, dyn_max_dist, value / 100.0)

	_set_and_update_zoom_distance(target_distance, true)


# --- Private Helper Methods ---
func _set_and_update_zoom_distance(new_distance: float, from_slider_event: bool = false):
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	
	current_distance = clamp(new_distance, dyn_min_dist, dyn_max_dist)

	if not from_slider_event and is_instance_valid(GlobalRefs.main_hud):
		var zoom_slider = GlobalRefs.main_hud.get_node("ScreenControls/CenterLeftZone/SliderControlLeft")
		if is_instance_valid(zoom_slider):
			var zoom_range = dyn_max_dist - dyn_min_dist
			var normalized_value = 0.0
			if zoom_range > 0.001:
				normalized_value = 100.0 * (current_distance - dyn_min_dist) / zoom_range
			
			_is_programmatically_setting_slider = true
			zoom_slider.value = clamp(normalized_value, 0.0, 100.0)
			_is_programmatically_setting_slider = false

func _update_fov():
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	if is_equal_approx(dyn_max_dist, dyn_min_dist):
		_camera.fov = _max_fov_deg
		return
	var t = clamp((current_distance - dyn_min_dist) / (dyn_max_dist - dyn_min_dist), 0.0, 1.0)
	_camera.fov = lerp(_min_fov_deg, _max_fov_deg, t)

func _get_dynamic_min_distance() -> float:
	if not is_instance_valid(_target):
		return MIN_ABSOLUTE_DISTANCE
	return max(MIN_ABSOLUTE_DISTANCE, _target_radius * min_distance_multiplier)

func _get_dynamic_max_distance() -> float:
	if not is_instance_valid(_target):
		return MAX_ABSOLUTE_DISTANCE
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_calc = max(dyn_min_dist + 1.0, _target_radius * max_distance_multiplier)
	return min(MAX_ABSOLUTE_DISTANCE, dyn_max_calc)

func _get_target_effective_radius(target_node: Spatial) -> float:
	var default_radius = 10.0
	if not is_instance_valid(target_node):
		return default_radius
	if target_node.has_method("get_interaction_radius"):
		var radius = target_node.get_interaction_radius()
		if (radius is float or radius is int) and radius > 0.0:
			return max(float(radius), 1.0)
	var node_scale = target_node.global_transform.basis.get_scale()
	var max_scale = max(node_scale.x, max(node_scale.y, node_scale.z))
	return max(max_scale / 2.0, default_radius)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"):
			EventBus.disconnect("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed")
