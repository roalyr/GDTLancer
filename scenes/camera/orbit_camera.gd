# File: scenes/camera/orbit_camera.gd
# Version: 2.2 - Removed all export variables to internalize configuration.

extends Camera

# --- INTERNAL CONFIGURATION ---
# All tuning is now done directly in this script.

# --- General ---
var distance: float = 55.0
var position_smoothing_speed: float = 25.0
var rotation_smoothing_speed: float = 18.0
var target_smoothing_speed: float = 20.0
var bob_frequency: float = 0.1
var bob_amplitude: float = 0.2

# --- Zoom & FoV ---
var zoom_speed: float = 0.5
var min_distance_multiplier: float = 3.0
var max_distance_multiplier: float = 30.0
var preferred_distance_multiplier: float = 3.0
var min_fov_deg: float = 50.0
var max_fov_deg: float = 100.0

# --- Rotation & PID ---
var pitch_min_deg: float = -83.0
var pitch_max_deg: float = 83.0
var rotation_max_speed: float = 15.0
var rotation_input_curve: float = 1.1
var pid_yaw_kp: float = 10.0
var pid_yaw_ki: float = 0.01
var pid_yaw_kd: float = 0.1
var pid_pitch_kp: float = 10.0
var pid_pitch_ki: float = 0.01
var pid_pitch_kd: float = 0.1
var pid_integral_limit: float = 10.0
var pid_output_limit_multiplier: float = 100.0

# --- Component Script Paths ---
const RotationControllerScript = preload(
	"res://scenes/camera/components/camera_rotation_controller.gd"
)
const ZoomControllerScript = preload("res://scenes/camera/components/camera_zoom_controller.gd")
const PositionControllerScript = preload(
	"res://scenes/camera/components/camera_position_controller.gd"
)

# --- Component Instances ---
var _rotation_controller: Node = null
var _zoom_controller: Node = null
var _position_controller: Node = null


# --- Initialization ---
func _ready():
	set_as_toplevel(true)
	GlobalRefs.main_camera = self

	# --- Instantiate and Initialize Components ---
	_rotation_controller = RotationControllerScript.new()
	_zoom_controller = ZoomControllerScript.new()
	_position_controller = PositionControllerScript.new()

	_rotation_controller.name = "RotationController"
	_zoom_controller.name = "ZoomController"
	_position_controller.name = "PositionController"

	add_child(_rotation_controller)
	add_child(_zoom_controller)
	add_child(_position_controller)

	# Package all internal vars into a config dictionary to pass to components
	var config = {
		"distance": distance,
		"position_smoothing_speed": position_smoothing_speed,
		"rotation_smoothing_speed": rotation_smoothing_speed,
		"target_smoothing_speed": target_smoothing_speed,
		"bob_frequency": bob_frequency,
		"bob_amplitude": bob_amplitude,
		"zoom_speed": zoom_speed,
		"min_distance_multiplier": min_distance_multiplier,
		"max_distance_multiplier": max_distance_multiplier,
		"preferred_distance_multiplier": preferred_distance_multiplier,
		"min_fov_deg": min_fov_deg,
		"max_fov_deg": max_fov_deg,
		"pitch_min": deg2rad(pitch_min_deg),
		"pitch_max": deg2rad(pitch_max_deg),
		"_rotation_max_speed": rotation_max_speed,
		"_rotation_input_curve": rotation_input_curve,
		"pid_yaw_kp": pid_yaw_kp,
		"pid_yaw_ki": pid_yaw_ki,
		"pid_yaw_kd": pid_yaw_kd,
		"pid_pitch_kp": pid_pitch_kp,
		"pid_pitch_ki": pid_pitch_ki,
		"pid_pitch_kd": pid_pitch_kd,
		"pid_integral_limit": pid_integral_limit,
		"pid_output_limit_multiplier": pid_output_limit_multiplier,
		"initial_yaw": PI,
		"initial_pitch": 0.25
	}

	_rotation_controller.initialize(self, config)
	_zoom_controller.initialize(self, config)
	_position_controller.initialize(self, _rotation_controller, _zoom_controller, config)

	# --- Connect Signals ---
	if (
		EventBus
		and not EventBus.is_connected(
			"camera_set_target_requested", self, "_on_camera_set_target_requested"
		)
	):
		EventBus.connect("camera_set_target_requested", self, "_on_camera_set_target_requested")

	# Proactive player check
	if is_instance_valid(GlobalRefs.player_agent_body):
		set_target_node(GlobalRefs.player_agent_body)


# --- Delegate Godot Functions to Components ---
func _unhandled_input(event):
	_rotation_controller.handle_input(event)
	_zoom_controller.handle_input(event)


func _physics_process(delta):
	_rotation_controller.physics_update(delta)
	_zoom_controller.physics_update()
	_position_controller.physics_update(delta)


# --- Public Methods (Delegating to Components) ---
func set_target_node(new_target: Spatial):
	if not is_instance_valid(_zoom_controller) or not is_instance_valid(_position_controller):
		return
	# When the target changes, inform the relevant components.
	_zoom_controller.set_target(new_target)
	_position_controller.set_target(new_target)
	print("OrbitCamera target set to: ", new_target.name if new_target else "null")


func set_rotation_input_active(is_active: bool):
	if is_instance_valid(_rotation_controller):
		_rotation_controller.set_rotation_input_active(is_active)


func set_is_rotating(rotating: bool):
	if is_instance_valid(_rotation_controller):
		_rotation_controller.set_is_rotating(rotating)


# --- Signal Handlers ---
func _on_camera_set_target_requested(target_node):
	set_target_node(target_node)


# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if (
			EventBus
			and EventBus.is_connected(
				"camera_set_target_requested", self, "_on_camera_set_target_requested"
			)
		):
			EventBus.disconnect(
				"camera_set_target_requested", self, "_on_camera_set_target_requested"
			)
		if GlobalRefs and GlobalRefs.main_camera == self:
			GlobalRefs.main_camera = null
