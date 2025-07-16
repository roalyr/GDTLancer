# File: core/agents/components/navigation_system/command_flee.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system) and is_instance_valid(_agent_body):
		var target_pos = _nav_sys._current_command.target_node.global_transform.origin
		var vector_away = _agent_body.global_transform.origin - target_pos
		var direction_away = (
			vector_away.normalized()
			if vector_away.length_squared() > 0.01
			else -_agent_body.global_transform.basis.z
		)
		_movement_system.apply_rotation(direction_away, delta)
		_movement_system.apply_acceleration(direction_away, delta)
