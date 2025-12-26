# File: core/agents/components/navigation_system/command_move_to.gd
# Version: 2.0 - Closing-speed-based deceleration
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node

# Alignment threshold for move_to
const MOVE_TO_ALIGNMENT_THRESHOLD_DEG: float = 45.0
# Safety margin for brake timing
const BRAKE_SAFETY_MARGIN: float = 1.5


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	if delta <= 0.0001:
		return

	var cmd = _nav_sys._current_command
	var target_pos = cmd.target_pos
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	
	# Always rotate toward target
	_movement_system.apply_rotation(direction, delta)
	
	# Check alignment before accelerating
	var current_forward = -_agent_body.global_transform.basis.z.normalized()
	var alignment_angle = current_forward.angle_to(direction) if direction.length_squared() > 0.001 else 0.0
	var is_aligned = alignment_angle <= deg2rad(MOVE_TO_ALIGNMENT_THRESHOLD_DEG)
	
	# Arrival check
	if (
		distance < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD
		and _agent_body.current_velocity.length_squared() < _nav_sys.ARRIVAL_SPEED_THRESHOLD_SQ
	):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_movement_system.apply_braking(delta)
		return
	else:
		cmd["signaled_stop"] = false
	
	if not is_aligned:
		# Not aligned - decelerate while turning
		_movement_system.apply_deceleration(delta)
		return
	
	# === Closing-Speed-Based Deceleration (for static target) ===
	var our_velocity = _agent_body.current_velocity
	var closing_speed = our_velocity.dot(direction)  # Speed toward target
	
	# Time to arrival
	var time_to_arrival = INF
	if closing_speed > 0.1:
		time_to_arrival = distance / closing_speed
	
	# Brake time estimate
	var current_speed = our_velocity.length()
	var brake_time = 0.0
	if _movement_system.brake_strength > 0.01 and current_speed > 0.1:
		brake_time = 2.3 / _movement_system.brake_strength
	
	# Decision
	var should_brake = time_to_arrival < (brake_time * BRAKE_SAFETY_MARGIN)
	
	if should_brake and distance > _nav_sys.ARRIVAL_DISTANCE_THRESHOLD:
		_movement_system.apply_braking(delta)
	else:
		_movement_system.apply_acceleration(current_forward, delta)
