# PROJECT: GDTLancer
# MODULE: command_idle.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: core/agents/components/navigation_system/command_idle.gd
# Version: 2.0 - RigidBody physics, drag handles deceleration automatically.
extends Node

var _movement_system: Node


func initialize(nav_system):
	_movement_system = nav_system.movement_system


func execute(_delta: float):
	# In idle state, we do nothing - drag will naturally slow the ship down
	pass