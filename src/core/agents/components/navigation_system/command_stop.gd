# File: core/agents/components/navigation_system/command_stop.gd
# Version: 3.0 - RigidBody physics with orientation-aware braking.
# Ships can use forward or backward thrusters depending on alignment.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node

# State for tracking stop progress
enum StopPhase { ASSESS, ROTATE_RETROGRADE, BRAKING, FINAL_DAMPING }
var _phase: int = StopPhase.ASSESS


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var velocity = _movement_system.get_velocity()
	var speed = velocity.length()
	var angular_speed = _agent_body.angular_velocity.length()
	
	# Always apply rotation kill (counter-torque to zero angular velocity)
	_movement_system.request_rotation_damping_pid(delta)
	
	# Check if fully stopped (both linear and angular)
	if speed < 1.0 and angular_speed < 0.1:
		if not _nav_sys._current_command.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			_nav_sys._current_command["signaled_stop"] = true
		_phase = StopPhase.ASSESS
		return
	
	# Reset signal flag if we start moving again
	if speed > 2.0:
		_nav_sys._current_command["signaled_stop"] = false
	
	# If only angular velocity remains, just keep damping rotation
	if speed < 1.0:
		_phase = StopPhase.FINAL_DAMPING
		return
	
	var velocity_dir = velocity.normalized() if speed > 0.1 else Vector3.ZERO
	var forward = _movement_system.get_forward()
	var backward = -forward
	
	# Check alignment with velocity
	var forward_dot = forward.dot(velocity_dir)   # Positive = facing direction of travel
	var backward_dot = backward.dot(velocity_dir) # Positive = facing away from travel
	
	# Determine best braking strategy
	if speed < 5.0:
		# Low speed - just apply braking thrust, don't worry about rotation
		_phase = StopPhase.FINAL_DAMPING
		_movement_system.request_thrust_brake()
		return
	
	# At higher speeds, we want to rotate for efficient braking
	# Retrograde burn: face backward to travel, use forward thrust
	# Prograde burn: face forward to travel, use backward thrust
	
	# Prefer retrograde (forward thrust is usually stronger)
	var retrograde_dir = -velocity_dir  # Direction ship should face for retrograde burn
	
	if backward_dot > 0.95:
		# Already facing retrograde - full forward thrust
		_phase = StopPhase.BRAKING
		_movement_system.request_thrust_forward()
		_movement_system.request_rotation_to_pid(retrograde_dir, delta)  # Maintain alignment
	elif backward_dot > 0.5:
		# Partially aligned retrograde - rotate while partial braking
		_phase = StopPhase.ROTATE_RETROGRADE
		_movement_system.request_rotation_to_pid(retrograde_dir, delta)
		_movement_system.request_thrust_forward(0.5)  # Partial thrust while rotating
	elif forward_dot > 0.95:
		# Facing prograde - can use backward thrust immediately
		_phase = StopPhase.BRAKING
		_movement_system.request_thrust_backward()
		# Also start rotating to retrograde for stronger braking
		_movement_system.request_rotation_to_pid(retrograde_dir, delta)
	elif forward_dot > 0.5:
		# Partially prograde - use backward thrust while rotating
		_phase = StopPhase.ROTATE_RETROGRADE
		_movement_system.request_thrust_backward(0.5)
		_movement_system.request_rotation_to_pid(retrograde_dir, delta)
	else:
		# Perpendicular - rotate to retrograde, minimal thrust
		_phase = StopPhase.ROTATE_RETROGRADE
		_movement_system.request_rotation_to_pid(retrograde_dir, delta)
		# Apply small brake to prevent acceleration
		_movement_system.request_thrust_brake()
