# Manages camera positioning and bobbing.
# The camera sits on its rig about the ship's drawn origin. Dynamic (Settings "dynamic_camera"): a
# leash, a damped spring stepped with the physics (physics_step), trails the rig behind the ship by
# its speed (longer the faster, up to a share of the camera's distance), so it lags as the ship
# speeds up, swings ahead as it brakes and out of a turn, and springs back; frames draw it between
# its last two steps, as every body is drawn, so it is as smooth as the ship. The spring runs in
# real time (a game sped up or slowed down does not stiffen or loosen it). (Easing the camera per
# frame by the ship's velocity times the frame's length jittered: those two never quite agree with
# the drawn motion, and the error grew with speed.)
# Not dynamic: fixed to the ship's drawn origin, no leash, no bob.

extends Node
const Interp = preload("res://src/core/utils/interp.gd")
class_name CameraPositionController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null
var _look_at_target: Spatial = null  # Secondary target to track
var _rotation_controller: CameraRotationController = null
var _zoom_controller: CameraZoomController = null

# --- From Configuration ---
var bob_frequency: float = 0
var bob_amplitude: float = 0

# --- Camera Mode ---
enum CameraMode { ORBIT, TARGET_TRACKING }
var _camera_mode: int = CameraMode.ORBIT

# --- State ---
var _bob_timer: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO  # The target's drawn origin this frame
var dynamic: bool = false  # Settings "dynamic_camera" (OrbitCamera sets it)
var _leash: Vector3 = Vector3.ZERO  # The rig's offset from the ship after the last physics step
var _leash_before: Vector3 = Vector3.ZERO  # ... and after the one before
var _leash_velocity: Vector3 = Vector3.ZERO


# --- Initialization ---
func initialize(camera_node: Camera, rot_ctrl: Node, zoom_ctrl: Node, config: Dictionary):
	_camera = camera_node
	_rotation_controller = rot_ctrl
	_zoom_controller = zoom_ctrl
	bob_frequency = config.get("bob_frequency", bob_frequency)
	bob_amplitude = config.get("bob_amplitude", bob_amplitude)


# --- Public Methods ---
func set_target(new_target: Spatial):
	_target = new_target
	reset_leash()
	if is_instance_valid(_target):
		_target_pos = Interp.origin(_target)


func set_look_at_target(look_target: Spatial):
	_look_at_target = look_target


func set_camera_mode(mode: int):
	_camera_mode = mode


func reset_leash() -> void:
	_leash = Vector3.ZERO
	_leash_before = Vector3.ZERO
	_leash_velocity = Vector3.ZERO


# Once a physics step (OrbitCamera._physics_process, before the step's own camera follow when
# interpolation is off): the leash springs toward its rest for the target's velocity.
func physics_step(delta: float) -> void:
	_leash_before = _leash
	var velocity = _target.get("linear_velocity") if is_instance_valid(_target) else null
	if not dynamic or not velocity is Vector3 or delta <= 0.0:
		reset_leash()
		return
	var distance: float = float(_zoom_controller.current_distance) if is_instance_valid(_zoom_controller) else Constants.CAMERA_START_DISTANCE
	step_leash(get_leash_rest(velocity, distance), delta / max(Engine.time_scale, 0.001), distance * Constants.CAMERA_LEASH_MAX_SHARE)


# Where the leash rests at `velocity`: behind it, by CAMERA_LEASH_MAX_SHARE of the camera's
# `distance` times 1 - exp(-speed / CAMERA_LEASH_SPEED) (a third of it at that speed, near all of it
# at three times).
static func get_leash_rest(velocity: Vector3, distance: float) -> Vector3:
	var speed: float = velocity.length()
	if speed < 0.001:
		return Vector3.ZERO
	return -velocity / speed * distance * Constants.CAMERA_LEASH_MAX_SHARE * (1.0 - exp(-speed / Constants.CAMERA_LEASH_SPEED))


# The leash's spring toward `rest`: L'' = w^2 (rest - L) - 2 z w L' (semi-implicit), held within
# `limit` m.
func step_leash(rest: Vector3, delta: float, limit: float) -> void:
	var w: float = Constants.CAMERA_LEASH_FREQUENCY
	_leash_velocity += (w * w * (rest - _leash) - 2.0 * Constants.CAMERA_LEASH_DAMPING * w * _leash_velocity) * delta
	_leash += _leash_velocity * delta
	var length: float = _leash.length()
	if length > limit and length > 0.0:
		var out: Vector3 = _leash / length
		_leash = out * limit
		_leash_velocity -= out * max(out.dot(_leash_velocity), 0.0)


# The leash as drawn this frame: between its last two steps, as bodies are.
func get_drawn_leash() -> Vector3:
	if not dynamic:
		return Vector3.ZERO
	if Interp.enabled():
		return _leash_before.linear_interpolate(_leash, Engine.get_physics_interpolation_fraction())
	return _leash


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
	_target_pos = Interp.origin(_target)
	var leash: Vector3 = get_drawn_leash()
	var bob_offset = Vector3.ZERO
	if dynamic:
		bob_offset = _camera.global_transform.basis.y * sin(_bob_timer * bob_frequency * TAU) * bob_amplitude

	# --- Handle Camera Mode ---
	if _camera_mode == CameraMode.TARGET_TRACKING and is_instance_valid(_look_at_target):
		_update_target_tracking_mode(leash, bob_offset)
	else:
		_update_orbit_mode(leash, bob_offset)


# Orbit (chase) mode: the camera orbits the player. Zoomed in past the default level, it is raised
# along its own up and looks past the ship, which slides down the frame until its top edge sits
# below centre as in tracking mode. The distance is the zoom's own (no back-off), so the ship
# keeps growing as the zoom closes in. The leash moves the camera, and its aim by a share, so the
# ship drifts in the frame as it speeds up and turns.
func _update_orbit_mode(leash: Vector3, bob_offset: Vector3):
	var desired_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
		Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
	)

	var shift: float = _zoom_controller.get_chase_shift()
	var camera_distance: float = _zoom_controller.current_distance
	var lift: Vector3 = desired_basis.y * get_chase_lift(get_hull_corners(_target), desired_basis.y, _zoom_controller.get_target_radius(), camera_distance, deg2rad(_camera.fov) * 0.5) * shift
	var look_point: Vector3 = _target_pos + lift
	var position_offset = -desired_basis.z * camera_distance
	var desired_position = look_point + position_offset + bob_offset + leash

	_place(desired_position, look_point + leash * Constants.CAMERA_LEASH_AIM_SHARE, Vector3.UP)


# Target tracking: the camera sits behind the player, raised just enough that the top of the hull's
# silhouette sits below the line of sight to the target, inside the lower half of the frame. Zooming
# in brings the camera close behind the ship (distance scales with the ship's apparent radius); the
# telephoto range then narrows the FoV onto the target while backing off so the ship stays in frame.
# The leash moves only the camera: the aim stays on the target.
const TRACKING_SOLVER_STEPS = 14


func _update_target_tracking_mode(leash: Vector3, bob_offset: Vector3):
	var player_pos = _target_pos
	var target_pos = Interp.origin(_look_at_target)
	var to_target = target_pos - player_pos
	var distance_to_target = to_target.length()
	if distance_to_target < 1.0:
		_update_orbit_mode(leash, bob_offset)
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
	var desired_position = player_pos + offset_dir * camera_distance + bob_offset + leash

	_place(desired_position, target_pos, up)


# The camera to `position`, looking at `look_point`.
func _place(position: Vector3, look_point: Vector3, up: Vector3) -> void:
	if position.is_equal_approx(look_point):
		return
	_camera.global_transform = Transform(Basis(), position).looking_at(look_point, up)


# Corners of the ship's visual bounds, rotated into world orientation, relative to its origin.
static func get_hull_corners(ship: Spatial) -> Array:
	var corners: Array = []
	if not is_instance_valid(ship) or not ship.get("hull_bounds") is AABB:
		return corners
	var bounds: AABB = ship.hull_bounds
	var basis: Basis = Interp.transform(ship).basis
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
