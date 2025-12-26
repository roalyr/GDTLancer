# File: core/agents/components/navigation_system/command_move_to.gd
# Version: 4.0 - RigidBody physics with PID-controlled thrust-based flight.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var cmd = _nav_sys._current_command
	var target_pos = cmd.target_pos
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	
	# Arrival check
	var current_speed = _movement_system.get_current_speed()
	if distance < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD and current_speed < _nav_sys.ARRIVAL_SPEED_THRESHOLD:
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		# Final stop - rotate retrograde and brake
		var velocity = _movement_system.get_velocity()
		if velocity.length() > 0.5:
			_movement_system.request_rotation_to_pid(-velocity.normalized(), delta)
		_movement_system.request_thrust_brake()
		_movement_system.request_rotation_damping_pid(delta)
		return
	else:
		cmd["signaled_stop"] = false
	
	# Always try to rotate toward target using PID
	_movement_system.request_rotation_to_pid(direction, delta)
	
	# Check alignment before thrusting forward
	if not _movement_system.is_aligned_to(direction):
		# Not aligned - use backward thrust if facing away, or brake
		var forward = _movement_system.get_forward()
		if forward.dot(direction) < -0.5:
			# Facing away - can use backward thrust toward target
			_movement_system.request_thrust_backward(0.3)
		else:
			# Perpendicular - just brake while turning
			_movement_system.request_thrust_brake()
		return
	
	# Calculate if we need to start braking
	var velocity = _movement_system.get_velocity()
	var closing_speed = velocity.dot(direction)
	
	# Simple brake distance estimate: v^2 / (2 * deceleration)
	var mass = _agent_body.mass
	var effective_decel = (_movement_system.linear_thrust / mass) + Constants.LINEAR_DRAG * current_speed
	var brake_distance = (closing_speed * closing_speed) / (2.0 * effective_decel) if effective_decel > 0.1 else 0.0
	
	# Add safety margin
	var should_brake = distance < brake_distance * 1.5 and closing_speed > 0
	
	if should_brake:
		# Rotate retrograde for efficient braking
		var retrograde = -velocity.normalized() if velocity.length() > 1.0 else -direction
		_movement_system.request_rotation_to_pid(retrograde, delta)
		
		var forward = _movement_system.get_forward()
		if forward.dot(retrograde) > 0.7:
			_movement_system.request_thrust_forward()  # Retrograde burn
		else:
			_movement_system.request_thrust_brake()  # Generic brake while rotating
	else:
		_movement_system.request_thrust_forward()
