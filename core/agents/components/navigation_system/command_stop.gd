# File: core/agents/components/navigation_system/command_stop.gd
# Version: 1.1 - Added call to damp_rotation for smooth rotational stops.
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
		# --- Dampen linear motion ---
		var stopped_moving = _movement_system.apply_braking(delta)
		
		# --- NEW: Dampen angular motion ---
		_movement_system.damp_rotation(delta)
		
		# Check if linear motion has stopped before signaling completion
		if stopped_moving and not _nav_sys._current_command.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			_nav_sys._current_command["signaled_stop"] = true
