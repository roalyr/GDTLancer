# Navigation command: keep the nose on a (possibly moving) target while easing off to a drift, as a
# ship does while it makes up its mind about it (ShipControllerAI's HESITATE state). Slows with a
# share of its thrust (Constants.NAV_WATCH_BRAKE_SHARE), so it settles rather than stops dead.

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
	var target_node = _nav_sys._current_command.target_node
	var to_target: Vector3 = target_node.global_transform.origin - _agent_body.global_transform.origin
	if to_target.length_squared() > 0.01:
		_movement_system.request_rotation_to_pid(to_target.normalized(), delta)
	var velocity: Vector3 = _movement_system.get_velocity()
	var speed: float = velocity.length()
	if speed > 1.0:
		_movement_system.request_thrust_direction(-velocity / speed, Constants.NAV_WATCH_BRAKE_SHARE)
