# File: core/agents/components/navigation_system/command_idle.gd
# Version: 2.0 - RigidBody physics, drag handles deceleration automatically.
extends Node

var _movement_system: Node


func initialize(nav_system):
	_movement_system = nav_system.movement_system


func execute(_delta: float):
	# In idle state, we do nothing - drag will naturally slow the ship down
	pass
