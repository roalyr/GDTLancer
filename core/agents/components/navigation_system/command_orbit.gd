# File: core/agents/components/navigation_system/command_orbit.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var cmd = _nav_sys._current_command
	var target_pos = cmd.target_node.global_transform.origin
	var orbit_dist = cmd.get("distance", 100.0)
	var clockwise = cmd.get("clockwise", false)

	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()
	if distance < 0.01:
		distance = 0.01
	var direction_to_target = vector_to_target / distance

	var tangent_dir = (direction_to_target.cross(Vector3.UP) if not clockwise else Vector3.UP.cross(direction_to_target)).normalized()
	_movement_system.apply_rotation(tangent_dir, delta)

	var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
	var target_tangential_speed = _movement_system.max_move_speed
	if orbit_dist > 0 and orbit_dist < full_speed_radius:
		target_tangential_speed *= (orbit_dist / full_speed_radius)

	target_tangential_speed = clamp(target_tangential_speed, 0.0, _movement_system.max_move_speed)

	var target_velocity = tangent_dir * target_tangential_speed
	_agent_body.current_velocity = _agent_body.current_velocity.linear_interpolate(
		target_velocity, _movement_system.acceleration * delta
	)
