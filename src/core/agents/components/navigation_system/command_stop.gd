# Navigation command: stop in place ("How a ship is flown", MovementSystem): hold still, the thrust
# straight against the motion, the spin let go of over SPIN_DAMP_TIME. The nose stays where it was.

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
	var speed: float = _movement_system.get_current_speed()
	_movement_system.request_velocity(Vector3.ZERO)
	_movement_system.request_rotation_damping_pid(delta)
	if speed < 1.0 and _agent_body.angular_velocity.length() < 0.1:
		if not _nav_sys._current_command.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			_nav_sys._current_command["signaled_stop"] = true
	elif speed > 2.0:
		_nav_sys._current_command["signaled_stop"] = false
