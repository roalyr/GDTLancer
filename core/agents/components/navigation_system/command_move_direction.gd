# File: core/agents/components/navigation_system/command_move_direction.gd
extends Node

var _nav_sys: Node
var _movement_system: Node

func initialize(nav_system):
	_nav_sys = nav_system
	_movement_system = nav_system.movement_system

func execute(delta: float):
	if is_instance_valid(_movement_system):
		var move_dir = _nav_sys._current_command.get("target_dir", Vector3.ZERO)
		if move_dir.length_squared() > 0.001:
			_movement_system.apply_rotation(move_dir, delta)
			_movement_system.apply_acceleration(move_dir, delta)
		else:
			_movement_system.apply_deceleration(delta)
