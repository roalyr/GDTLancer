# Navigation command: point the nose where a cannon round will meet a (possibly moving) target (its
# lead direction, ToolController.cannon_aim_direction) and hold the range: the velocity it steers
# for is the target's, plus a closing (or opening) speed toward the range it was given, at most
# NAV_AIM_MAX_CLOSING. The nose turns with a stiffer rotation PID (NAV_AIM_PID_GAIN): a cannon misses
# by a degree, where the usual autopilot eases in.

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
	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	var offset: Vector3 = target_node.global_transform.origin - _agent_body.global_transform.origin
	var distance: float = offset.length()
	if distance < 0.01:
		return
	var direction: Vector3 = offset / distance
	var tools = _agent_body.get_node_or_null("ToolController")
	var index: int = tools.find_cannon_for(target_node) if tools != null and tools.has_method("find_cannon_for") else -1
	var aim: Vector3 = tools.cannon_aim_direction(index, target_node) if index >= 0 else direction
	_movement_system.request_rotation_to_pid(aim, delta, Constants.NAV_AIM_PID_GAIN)
	var target_velocity = target_node.get("linear_velocity")
	var keep: float = clamp((distance - float(cmd.get("range", 1000.0))) / Constants.NAV_AIM_RANGE_TIME, -Constants.NAV_AIM_MAX_CLOSING, Constants.NAV_AIM_MAX_CLOSING)
	_movement_system.request_velocity_pid((target_velocity if target_velocity is Vector3 else Vector3.ZERO) + direction * keep, delta)
