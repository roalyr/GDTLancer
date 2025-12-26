# File: core/agents/components/navigation_system/command_flee.gd
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
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	
	var target_node = _nav_sys._current_command.get("target_node", null)
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return
	
	var target_pos = target_node.global_transform.origin
	var vector_away = _agent_body.global_transform.origin - target_pos
	var direction_away = (
		vector_away.normalized()
		if vector_away.length_squared() > 0.01
		else -_agent_body.global_transform.basis.z
	)
	
	# Rotate toward flee direction using PID
	_movement_system.request_rotation_to_pid(direction_away, delta)
	
	# Thrust based on alignment
	if _movement_system.is_aligned_to(direction_away):
		_movement_system.request_thrust_forward()
	else:
		# Can use backward thrust if facing toward threat
		var forward = _movement_system.get_forward()
		if forward.dot(direction_away) < -0.5:
			# Facing threat - use backward thrust to flee immediately
			_movement_system.request_thrust_backward(0.7)
