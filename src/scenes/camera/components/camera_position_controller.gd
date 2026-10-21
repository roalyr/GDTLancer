# Manages camera positioning, smoothing, and bobbing effect.

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


# Orbit (chase) mode: the camera orbits the player. Zoomed in past the default level, it blends
# toward the tracking framing: raised along its own up so it looks past the ship, which slides
# down the frame until its top edge sits below centre as in tracking mode, and in the telephoto
# range it backs off as the FoV narrows so the ship keeps its size.
func _update_orbit_mode(delta: float, bob_offset: Vector3):
	var desired_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
		Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
	)

	var shift: float = _zoom_controller.get_chase_shift()
	var camera_distance: float = _zoom_controller.get_tracking_distance() if shift > 0.0 else _zoom_controller.current_distance
	var lift: Vector3 = desired_basis.y * get_chase_lift(get_hull_corners(_target), desired_basis.y, _zoom_controller.get_target_radius(), camera_distance, deg2rad(_camera.fov) * 0.5) * shift
	var look_point: Vector3 = _smoothed_target_pos + lift
	var position_offset = -desired_basis.z * camera_distance
	var desired_position = look_point + position_offset + bob_offset

	# Interpolate Camera's actual position
	_camera.global_transform.origin = _camera.global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta
	)

	# Interpolate Look At to point towards the SMOOTHED target position
	var target_look_transform = _camera.global_transform.looking_at(
		look_point, Vector3.UP
	)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta
	)


# Target tracking: the camera sits behind the player, raised just enough that the top of the hull's
# silhouette sits below the line of sight to the target, inside the lower half of the frame. Zooming
# in brings the camera close behind the ship (distance scales with the ship's apparent radius); the
# telephoto range then narrows the FoV onto the target while backing off so the ship stays in frame.
const TRACKING_SOLVER_STEPS = 14


func _update_target_tracking_mode(delta: float, bob_offset: Vector3):
	var player_pos = _smoothed_target_pos
	var target_pos = _look_at_target.global_transform.origin
	var to_target = target_pos - player_pos
	var distance_to_target = to_target.length()
	if distance_to_target < 1.0:
		_update_orbit_mode(delta, bob_offset)
		return
	var dir_to_target = to_target / distance_to_target

	var camera_distance: float = _zoom_controller.get_tracking_distance()
	var up = Vector3.UP - dir_to_target * dir_to_target.dot(Vector3.UP)
	if up.length_squared() < 0.0001:
		up = _camera.global_transform.basis.y
	up = up.normalized()
	var half_fov: float = deg2rad(_camera.fov) * 0.5
	var corners: Array = get_hull_corners(_target)
	var elevation: float
	if corners.empty():
		elevation = get_tracking_elevation(_zoom_controller.get_target_radius(), camera_distance, half_fov * 2.0)
	else:
		elevation = solve_tracking_elevation(corners, to_target, up, camera_distance, half_fov * Constants.CAMERA_TRACKING_TOP_EDGE_SHARE)
	var offset_dir = -dir_to_target * cos(elevation) + up * sin(elevation)
	var desired_position = player_pos + offset_dir * camera_distance + bob_offset

	_camera.global_transform.origin = _camera.global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta * 0.5  # Slower for tracking mode
	)
	var target_look_transform = _camera.global_transform.looking_at(target_pos, up)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta * 0.7
	)


# Corners of the ship's visual bounds, rotated into world orientation, relative to its origin.
static func get_hull_corners(ship: Spatial) -> Array:
	var corners: Array = []
	if not is_instance_valid(ship) or not ship.get("hull_bounds") is AABB:
		return corners
	var bounds: AABB = ship.hull_bounds
	var basis: Basis = ship.global_transform.basis
	for i in range(8):
		corners.append(basis.xform(bounds.get_endpoint(i)))
	return corners


# Smallest elevation (bisection) at which every hull corner is at least `margin` radians below the
# camera's line of sight to the target. Positions are relative to the player's origin.
static func solve_tracking_elevation(corners: Array, to_target: Vector3, up: Vector3, camera_distance: float, margin: float) -> float:
	var dir: Vector3 = to_target.normalized()
	var low := 0.0
	var high := Constants.CAMERA_TRACKING_MAX_ELEVATION
	for _i in range(TRACKING_SOLVER_STEPS):
		var elevation: float = (low + high) * 0.5
		if get_hull_top_angle(corners, to_target, -dir * cos(elevation) + up * sin(elevation), camera_distance, up) > -margin:
			low = elevation
		else:
			high = elevation
	return high


# Angle of the highest hull corner above the camera's line of sight to the target (negative = below).
static func get_hull_top_angle(corners: Array, to_target: Vector3, offset_dir: Vector3, camera_distance: float, up: Vector3) -> float:
	var camera_pos: Vector3 = offset_dir * camera_distance
	var sight: Vector3 = (to_target - camera_pos).normalized()
	var sight_up: Vector3 = (up - sight * sight.dot(up)).normalized()
	var top := -PI
	for corner in corners:
		var to_corner: Vector3 = corner - camera_pos
		top = max(top, atan2(to_corner.dot(sight_up), to_corner.dot(sight)))
	return top


# How far to raise a chase camera (along `up`, looking parallel to its unraised line of sight) for
# the hull's top edge to sit Constants.CAMERA_TRACKING_TOP_EDGE_SHARE of half the FoV below centre.
static func get_chase_lift(corners: Array, up: Vector3, hull_radius: float, camera_distance: float, half_fov: float) -> float:
	var top: float = hull_radius
	if not corners.empty():
		top = -INF
		for corner in corners:
			top = max(top, corner.dot(up))
	return max(top, 0.0) + camera_distance * tan(half_fov * Constants.CAMERA_TRACKING_TOP_EDGE_SHARE)


# Fallback without model bounds: treat the hull as a sphere of the apparent radius.
static func get_tracking_elevation(hull_radius: float, camera_distance: float, fov_rad: float) -> float:
	var hull_angle: float = asin(clamp(hull_radius / max(camera_distance, 0.001), 0.0, 1.0))
	return hull_angle + fov_rad * 0.5 * Constants.CAMERA_TRACKING_TOP_EDGE_SHARE
