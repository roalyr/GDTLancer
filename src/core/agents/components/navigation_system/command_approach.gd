# File: core/agents/components/navigation_system/command_approach.gd
# Version: 4.0 - RigidBody physics with PID-controlled pursuit capability.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node

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
		if delta > 0.001:
			_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	# Arrival check
	var current_speed = _movement_system.get_current_speed()
	if distance < (safe_distance + _nav_sys.ARRIVAL_DISTANCE_THRESHOLD):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_nav_sys.set_command_idle()
		_movement_system.request_thrust_brake()
		return

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	
	# Use PID for rotation control
	_movement_system.request_rotation_to_pid(direction, delta)
	
	# Check alignment
	if not _movement_system.is_aligned_to(direction):
		# Not aligned - use backward thrust if facing away, or brake
		var forward = _movement_system.get_forward()
		if forward.dot(direction) < -0.5:
			_movement_system.request_thrust_backward(0.3)
		else:
			_movement_system.request_thrust_brake()
		cmd["signaled_stop"] = false
		return
	
	# Calculate relative velocity and closing speed
	var our_velocity = _movement_system.get_velocity()
	var relative_velocity = our_velocity - _target_velocity
	var closing_speed = relative_velocity.dot(direction)
	
	# Distance remaining to safe zone
	var distance_to_safe = distance - safe_distance
	
	# Estimate stopping distance
	var mass = _agent_body.mass
	var effective_decel = (_movement_system.linear_thrust / mass) + Constants.LINEAR_DRAG * current_speed
	var brake_distance = (closing_speed * closing_speed) / (2.0 * effective_decel) if effective_decel > 0.1 else 0.0
	
	# Decision: brake or accelerate?
	var should_brake = distance_to_safe < brake_distance * 1.5 and closing_speed > 0
	
	if should_brake and distance_to_safe > 0:
		# Rotate retrograde for efficient braking
		var retrograde = -our_velocity.normalized() if our_velocity.length() > 1.0 else -direction
		_movement_system.request_rotation_to_pid(retrograde, delta)
		
		var forward = _movement_system.get_forward()
		if forward.dot(retrograde) > 0.7:
			_movement_system.request_thrust_forward()
		else:
			_movement_system.request_thrust_brake()
	else:
		_movement_system.request_thrust_forward()
		cmd["signaled_stop"] = false
