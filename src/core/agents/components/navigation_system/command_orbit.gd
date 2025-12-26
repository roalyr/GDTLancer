# File: core/agents/components/navigation_system/command_orbit.gd
# Version: 2.0 - Uses alignment-before-acceleration for consistent physics.
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node

const SPIRAL_OUTWARD_FACTOR = 0.3
# Alignment threshold for orbiting
const ORBIT_ALIGNMENT_THRESHOLD_DEG: float = 60.0


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

	# --- Vector Calculations ---
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()
	if distance < 0.01:
		distance = 0.01
	var direction_to_target = vector_to_target / distance
	var tangent_dir = (
		direction_to_target.cross(Vector3.UP) if not clockwise 
		else Vector3.UP.cross(direction_to_target)
	).normalized()

	# --- Determine Movement Direction ---
	var safe_dist = (
		_nav_sys._get_target_effective_size(target_node)
		* _nav_sys.CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
	)
	var ideal_move_dir: Vector3

	if distance < safe_dist:
		# TOO CLOSE: Spiral out
		var radial_dir_outward = -direction_to_target
		ideal_move_dir = (tangent_dir + radial_dir_outward * SPIRAL_OUTWARD_FACTOR).normalized()
	else:
		# SAFE DISTANCE: Normal orbit tangent
		ideal_move_dir = tangent_dir

	# --- Always rotate toward ideal movement direction ---
	_movement_system.apply_rotation(ideal_move_dir, delta)
	
	# --- Check alignment before accelerating ---
	var current_forward = -_agent_body.global_transform.basis.z.normalized()
	var alignment_angle = current_forward.angle_to(ideal_move_dir)
	
	if alignment_angle <= deg2rad(ORBIT_ALIGNMENT_THRESHOLD_DEG):
		# Aligned - accelerate in forward direction
		_movement_system.apply_acceleration(current_forward, delta)
	else:
		# Not aligned - decelerate while turning
		_movement_system.apply_deceleration(delta)
	
	# Apply orbit PID correction for distance maintenance
	_nav_sys.apply_orbit_pid_correction(delta)
