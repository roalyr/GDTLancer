# File: scenes/camera/components/camera_position_controller.gd
# Version: 1.1 - Added a smoothed target position to reduce jerk on rapid velocity changes.
# Purpose: Manages camera positioning, smoothing, and bobbing effect.

extends Node
class_name CameraPositionController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null
var _rotation_controller: CameraRotationController = null
var _zoom_controller: CameraZoomController = null

# --- Configuration ---
var position_smoothing_speed: float = 18.0
var rotation_smoothing_speed: float = 18.0
var bob_frequency: float = 0.1
var bob_amplitude: float = 0.2
# NEW: How quickly the camera's anchor point follows the ship. Lower values are smoother.
var target_smoothing_speed: float = 15.0

# --- State ---
var _bob_timer: float = 0.0
# NEW: This will be the point the camera actually tries to follow.
var _smoothed_target_pos: Vector3 = Vector3.ZERO


# --- Initialization ---
func initialize(camera_node: Camera, rot_ctrl: Node, zoom_ctrl: Node, config: Dictionary):
	_camera = camera_node
	_rotation_controller = rot_ctrl
	_zoom_controller = zoom_ctrl

	# Set configuration from the main camera script
	position_smoothing_speed = config.get("position_smoothing_speed", position_smoothing_speed)
	rotation_smoothing_speed = config.get("rotation_smoothing_speed", rotation_smoothing_speed)
	bob_frequency = config.get("bob_frequency", bob_frequency)
	bob_amplitude = config.get("bob_amplitude", bob_amplitude)
	target_smoothing_speed = config.get("target_smoothing_speed", target_smoothing_speed)


# --- Public Methods ---
func set_target(new_target: Spatial):
	_target = new_target
	# When the target changes, immediately snap the smoothed position to it.
	if is_instance_valid(_target):
		_smoothed_target_pos = _target.global_transform.origin


func physics_update(delta: float):
	_bob_timer += delta

	if not is_instance_valid(_target):
		# Detached Mode
		var new_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
			Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
		)
		_camera.global_transform.basis = new_basis.orthonormalized()
		return

	# --- Attached Mode ---
	var actual_target_pos = _target.global_transform.origin

	# --- SMOOTHING LOGIC ---
	# Instead of using the actual target position directly, we lerp our
	# internal "smoothed" position towards it. This dampens any sudden jumps.
	_smoothed_target_pos = _smoothed_target_pos.linear_interpolate(
		actual_target_pos, target_smoothing_speed * delta
	)
	# --- END SMOOTHING LOGIC ---

	var bob_offset = (
		_camera.global_transform.basis.y
		* sin(_bob_timer * bob_frequency * TAU)
		* bob_amplitude
	)

	var desired_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
		Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
	)

	# Calculate desired position relative to the SMOOTHED target position
	var position_offset = -desired_basis.z * _zoom_controller.current_distance
	var desired_position = _smoothed_target_pos + position_offset + bob_offset

	# Interpolate Camera's actual position
	_camera.global_transform.origin = _camera.global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta
	)

	# Interpolate Look At to point towards the SMOOTHED target position
	var target_look_transform = _camera.global_transform.looking_at(
		_smoothed_target_pos, Vector3.UP
	)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta
	)
