# File: core/agents/components/navigation_system/command_move_direction.gd
# Version: 3.0 - RigidBody physics with PID-controlled flight.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system):
		return
	
	var move_dir = _nav_sys._current_command.get("target_dir", Vector3.ZERO)
	if move_dir.length_squared() > 0.001:
		# Rotate toward movement direction using PID
		_movement_system.request_rotation_to_pid(move_dir, delta)
		
		# Thrust based on alignment
		if _movement_system.is_aligned_to(move_dir):
			_movement_system.request_thrust_forward()
		else:
			# Can use backward thrust if facing opposite
			var forward = _movement_system.get_forward()
			if forward.dot(move_dir) < -0.7:
				_movement_system.request_thrust_backward(0.5)
			# Otherwise drag handles deceleration
