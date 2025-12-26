# File: scenes/camera/components/camera_position_controller.gd
# Version: 1.2 - Added target-tracking mode for viewing both player and target.
# Purpose: Manages camera positioning, smoothing, and bobbing effect.

extends Node
class_name CameraPositionController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null
var _look_at_target: Spatial = null  # Secondary target to track
var _rotation_controller: CameraRotationController = null
var _zoom_controller: CameraZoomController = null

# --- From Configuration ---
var position_smoothing_speed: float = 0
var rotation_smoothing_speed: float = 0
var bob_frequency: float = 0
var bob_amplitude: float = 0
# NEW: How quickly the camera's anchor point follows the ship. Lower values are smoother.
var target_smoothing_speed: float = 0

# --- Camera Mode ---
enum CameraMode { ORBIT, TARGET_TRACKING }
var _camera_mode: int = CameraMode.ORBIT

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


func set_look_at_target(look_target: Spatial):
	_look_at_target = look_target


func set_camera_mode(mode: int):
	_camera_mode = mode


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
	_smoothed_target_pos = _smoothed_target_pos.linear_interpolate(
		actual_target_pos, target_smoothing_speed * delta
	)

	var bob_offset = (
		_camera.global_transform.basis.y
		* sin(_bob_timer * bob_frequency * TAU)
		* bob_amplitude
	)

	# --- Handle Camera Mode ---
	if _camera_mode == CameraMode.TARGET_TRACKING and is_instance_valid(_look_at_target):
		_update_target_tracking_mode(delta, bob_offset)
	else:
		_update_orbit_mode(delta, bob_offset)


func _update_orbit_mode(delta: float, bob_offset: Vector3):
	"""Standard orbit camera mode - camera orbits around player."""
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


func _update_target_tracking_mode(delta: float, bob_offset: Vector3):
	"""Target tracking mode - camera positions to see both player and target."""
	var player_pos = _smoothed_target_pos
	var target_pos = _look_at_target.global_transform.origin
	
	# Direction from player to target
	var player_to_target = target_pos - player_pos
	var distance_to_target = player_to_target.length()
	
	if distance_to_target < 1.0:
		# Target too close, fall back to orbit mode
		_update_orbit_mode(delta, bob_offset)
		return
	
	var dir_to_target = player_to_target / distance_to_target
	
	# Position camera on the opposite side of the player from the target
	# So both player and target are in front of the camera
	var camera_offset_dir = -dir_to_target  # Behind player relative to target
	
	# Add some height to look down slightly
	camera_offset_dir = (camera_offset_dir + Vector3.UP * 0.3).normalized()
	
	# Calculate camera distance - further if target is far
	var base_distance = _zoom_controller.current_distance
	var extra_distance = clamp(distance_to_target * 0.15, 0.0, base_distance * 2.0)
	var total_distance = base_distance + extra_distance
	
	# Desired camera position
	var desired_position = player_pos + camera_offset_dir * total_distance + bob_offset
	
	# Interpolate camera position
	_camera.global_transform.origin = _camera.global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta * 0.5  # Slower for tracking mode
	)
	
	# Look at a point between player and target, weighted toward target
	var look_at_point = player_pos.linear_interpolate(target_pos, 0.6)
	
	var target_look_transform = _camera.global_transform.looking_at(look_at_point, Vector3.UP)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta * 0.7
	)
