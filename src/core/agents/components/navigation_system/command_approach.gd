# File: core/agents/components/navigation_system/command_approach.gd
# Version: 2.0 - Closing-speed-based deceleration for pursuit capability
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node

# Alignment threshold for approaching
const APPROACH_ALIGNMENT_THRESHOLD_DEG: float = 45.0
# Safety margin for brake timing (higher = earlier braking)
const BRAKE_SAFETY_MARGIN: float = 1.5

# State for tracking target motion
var _prev_target_pos: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO


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
	var target_node = cmd.target_node
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return
		
	var target_pos = target_node.global_transform.origin
	var target_size = _nav_sys._get_target_effective_size(target_node)
	var safe_distance = max(_nav_sys.APPROACH_MIN_DISTANCE, target_size * _nav_sys.APPROACH_DISTANCE_MULTIPLIER)

	# Estimate target velocity
	if cmd.get("is_new", true):
		_prev_target_pos = target_pos
		_target_velocity = Vector3.ZERO
		cmd["is_new"] = false
	else:
		_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	# Arrival check
	if distance < (safe_distance + _nav_sys.ARRIVAL_DISTANCE_THRESHOLD):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_nav_sys.set_command_idle()
		_movement_system.apply_braking(delta)
		return

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	
	# Always rotate toward target
	_movement_system.apply_rotation(direction, delta)
	
	# Check alignment
	var current_forward = -_agent_body.global_transform.basis.z.normalized()
	var alignment_angle = current_forward.angle_to(direction)
	var is_aligned = alignment_angle <= deg2rad(APPROACH_ALIGNMENT_THRESHOLD_DEG)
	
	if not is_aligned:
		# Not aligned - decelerate while turning
		_movement_system.apply_deceleration(delta)
		cmd["signaled_stop"] = false
		return
	
	# === Closing-Speed-Based Deceleration ===
	# Calculate relative velocity toward target
	var our_velocity = _agent_body.current_velocity
	var relative_velocity = our_velocity - _target_velocity
	var closing_speed = relative_velocity.dot(direction)  # Positive = approaching
	
	# Distance remaining to safe zone
	var distance_to_safe = distance - safe_distance
	
	# Time to collision (if approaching)
	var time_to_collision = INF
	if closing_speed > 0.1:  # Only if we're actually approaching
		time_to_collision = distance_to_safe / closing_speed
	
	# Time needed to brake from current speed to zero
	# Using v = v0 * (1 - decel * t)^n approximation, solve for t
	# Simplified: brake_time ≈ current_speed / (decel_rate * average_speed)
	var current_speed = our_velocity.length()
	var brake_time = 0.0
	if _movement_system.brake_strength > 0.01 and current_speed > 0.1:
		# Approximate brake time using exponential decay model
		# For linear_interpolate with weight w, time to reach 10% is roughly -ln(0.1)/w
		brake_time = 2.3 / _movement_system.brake_strength  # ln(10) ≈ 2.3
	
	# Decision: brake or accelerate?
	var should_brake = time_to_collision < (brake_time * BRAKE_SAFETY_MARGIN)
	
	if should_brake and distance_to_safe > 0:
		# Close to collision - brake
		_movement_system.apply_braking(delta)
	else:
		# Safe to pursue at full speed
		_movement_system.apply_acceleration(current_forward, delta)
		cmd["signaled_stop"] = false
