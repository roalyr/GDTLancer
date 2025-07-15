# File: core/agents/components/navigation_system/command_idle.gd
extends Node

var _movement_system: Node

func initialize(nav_system):
	_movement_system = nav_system.movement_system

func execute(delta: float):
	if is_instance_valid(_movement_system):
		_movement_system.apply_deceleration(delta)
