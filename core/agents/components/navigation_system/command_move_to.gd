# File: core/agents/components/navigation_system/command_move_to.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node
var _pid: PIDController

func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system
	_pid = nav_system._pid_move_to

func execute(delta: float):
	if not is_instance_valid(_pid): return

	var cmd = _nav_sys._current_command
	var target_pos = cmd.target_pos
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	var pid_target_speed = _pid.update(distance, delta)
	pid_target_speed = clamp(pid_target_speed, 0, _movement_system.max_move_speed)

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	_movement_system.apply_rotation(direction, delta)

	var target_velocity = direction * pid_target_speed
	_agent_body.current_velocity = _agent_body.current_velocity.linear_interpolate(
		target_velocity, _movement_system.acceleration * delta
	)

	if distance < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD and _agent_body.current_velocity.length_squared() < _nav_sys.ARRIVAL_SPEED_THRESHOLD_SQ:
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_movement_system.apply_braking(delta)
	else:
		cmd["signaled_stop"] = false
