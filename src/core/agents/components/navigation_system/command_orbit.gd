# File: core/agents/components/navigation_system/command_orbit.gd
# Version: 1.4 - Added dynamic speed calculation for the spiral-out phase.
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node

const SPIRAL_OUTWARD_FACTOR = 0.3
const ORBITAL_VELOCITY_LERP_WEIGHT = 2.5

var _current_orbital_velocity: Vector3 = Vector3.ZERO


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	var target_pos = target_node.global_transform.origin
	var clockwise = cmd.get("clockwise", false)

	if cmd.get("is_new", false):
		_current_orbital_velocity = _agent_body.current_velocity
		cmd["is_new"] = false

	# --- Vector Calculations ---
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()
	if distance < 0.01:
		distance = 0.01
	var direction_to_target = vector_to_target / distance
	var tangent_dir = (direction_to_target.cross(Vector3.UP) if not clockwise else Vector3.UP.cross(direction_to_target)).normalized()

	# --- Determine Movement Direction & Ideal Speed ---
	var safe_dist = (
		_nav_sys._get_target_effective_size(target_node)
		* _nav_sys.CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
	)
	var ideal_move_dir: Vector3
	var speed_calc_dist: float  # The distance to use for speed calculation

	if distance < safe_dist:
		# TOO CLOSE: Spiral out and use CURRENT distance for speed calculation.
		var radial_dir_outward = -direction_to_target
		ideal_move_dir = (tangent_dir + radial_dir_outward * SPIRAL_OUTWARD_FACTOR).normalized()
		speed_calc_dist = distance  # Use current, closer distance for a slower speed.
	else:
		# SAFE DISTANCE: Normal orbit and use DESIRED distance for speed calculation.
		ideal_move_dir = tangent_dir
		speed_calc_dist = cmd.get("distance", 100.0)  # Use final, desired distance.

	# Calculate the ideal speed based on the appropriate distance (current or desired).
	var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
	var ideal_speed = _movement_system.max_move_speed
	if speed_calc_dist > 0 and speed_calc_dist < full_speed_radius:
		ideal_speed *= (speed_calc_dist / full_speed_radius)
	ideal_speed = clamp(ideal_speed, 0.0, _movement_system.max_move_speed)

	var ideal_orbital_velocity = ideal_move_dir * ideal_speed

	# --- Smoothly Transition & Apply ---
	_current_orbital_velocity = _current_orbital_velocity.linear_interpolate(
		ideal_orbital_velocity, ORBITAL_VELOCITY_LERP_WEIGHT * delta
	)

	_movement_system.apply_rotation(tangent_dir, delta)
	_agent_body.current_velocity = _current_orbital_velocity
