# Navigation command: align with and thrust along a direction.

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
	
	var move_dir: Vector3 = _nav_sys._current_command.get("target_dir", Vector3.ZERO)
	if move_dir.length_squared() > 0.001:
		# Nose and velocity along it, flat out ("How a ship is flown"); the throttle scales the engines
		_movement_system.request_rotation_to_pid(move_dir, delta)
		_movement_system.request_velocity(move_dir.normalized() * _movement_system.top_speed())
