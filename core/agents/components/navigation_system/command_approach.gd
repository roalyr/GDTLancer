# File: core/agents/components/navigation_system/command_approach.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node
var _pid: PIDController

func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system
	_pid = nav_system._pid_approach

func execute(delta: float):
	if not is_instance_valid(_pid): return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	var target_pos = target_node.global_transform.origin
	var target_size = _nav_sys._get_target_effective_size(target_node)
	var desired_stop_dist = max(_nav_sys.APPROACH_MIN_DISTANCE, target_size * _nav_sys.APPROACH_DISTANCE_MULTIPLIER)
	
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	if distance < (desired_stop_dist + _nav_sys.ARRIVAL_DISTANCE_THRESHOLD):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_nav_sys.set_command_idle()
		_movement_system.apply_braking(delta)
		return

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	_movement_system.apply_rotation(direction, delta)

	var deceleration_start_dist = desired_stop_dist * _nav_sys.APPROACH_DECELERATION_START_DISTANCE_FACTOR
	var target_velocity: Vector3
	
	if distance > deceleration_start_dist:
		target_velocity = direction * _movement_system.max_move_speed
		_pid.reset()
		cmd["signaled_stop"] = false
	else:
		var distance_error = distance - desired_stop_dist
		var pid_target_speed = _pid.update(distance_error, delta)
		pid_target_speed = clamp(pid_target_speed, -_movement_system.max_move_speed * 0.1, _movement_system.max_move_speed)
		target_velocity = direction * pid_target_speed

		if abs(distance_error) < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD and _agent_body.current_velocity.length_squared() < _nav_sys.ARRIVAL_SPEED_THRESHOLD_SQ:
			if not cmd.get("signaled_stop", false):
				EventBus.emit_signal("agent_reached_destination", _agent_body)
				cmd["signaled_stop"] = true
			_movement_system.apply_braking(delta)
			return
		else:
			cmd["signaled_stop"] = false
			
	_agent_body.current_velocity = _agent_body.current_velocity.linear_interpolate(
		target_velocity, _movement_system.acceleration * delta
	)
