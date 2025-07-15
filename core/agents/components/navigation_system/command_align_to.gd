# File: core/agents/components/navigation_system/command_align_to.gd
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
		var target_dir = _nav_sys._current_command.target_dir
		_movement_system.apply_rotation(target_dir, delta)
		_movement_system.apply_deceleration(delta)
		var current_fwd = -_agent_body.global_transform.basis.z
		if current_fwd.dot(target_dir) > 0.999:
			_nav_sys.set_command_idle()
