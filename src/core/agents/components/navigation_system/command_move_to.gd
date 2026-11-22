# Navigation command: fly to a point and stop there (MovementSystem.arrival_speed: no flip to brake).

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
	var vector_to_target: Vector3 = cmd.target_pos - _agent_body.global_transform.origin
	var distance: float = vector_to_target.length()
	var direction: Vector3 = vector_to_target / distance if distance > 0.01 else Vector3.ZERO
	var speed: float = _movement_system.get_current_speed()
	if distance < Constants.NAV_ARRIVAL_DISTANCE_THRESHOLD and speed < Constants.NAV_ARRIVAL_SPEED_THRESHOLD:
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_movement_system.request_velocity(Vector3.ZERO)  # There: hold, as a stop does
		_movement_system.request_rotation_damping_pid(delta)
		return
	cmd["signaled_stop"] = false
	# Nose on the point; the velocity toward it, as fast as it can still stop there (at most its
	# cruise speed), whichever way it faces ("How a ship is flown")
	_movement_system.request_rotation_to_pid(direction, delta)
	var closing: float = min(_nav_sys.cruise_speed, _movement_system.arrival_speed(distance, _movement_system.top_speed(), _movement_system.acceleration()))
	_movement_system.request_velocity(direction * closing)
