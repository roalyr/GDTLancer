#
# PROJECT: GDTLancer
# MODULE: jump_transition_rig.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.1, §6.3; TRUTH_SIMULATION-GRAPH.md §3.2, §3.3
# LOG_REF: 2026-05-16 20:25:31
#

extends Spatial

const DEFAULT_TRAVEL_DIRECTION = Vector3(0, 0, -1)
const DEFAULT_ACCELERATION = 800.0
const DEFAULT_DECELERATION = 800.0
const CRUISE_VELOCITY_RAMP_DURATION_SEC = 1.1
const ARRIVAL_VELOCITY_RAMP_DURATION_SEC = 0.85
const ROUTE_COMPLETION_TOLERANCE = 20.0

var _transition_camera: Camera = null
var _nebula_holder: Spatial = null
var _travel_direction: Vector3 = DEFAULT_TRAVEL_DIRECTION
var _current_velocity: float = 0.0
var _target_velocity: float = 0.0
var _velocity_step_rate: float = DEFAULT_ACCELERATION
var _departure_sector_id: String = ""
var _target_sector_id: String = ""
var _departure_active: bool = false
var _cruise_active: bool = false
var _arrival_active: bool = false
var _captured_camera_transform: Transform = Transform.IDENTITY
var _has_captured_camera_transform: bool = false
var _route_origin_world_position: Vector3 = Vector3.ZERO
var _route_world_position: Vector3 = Vector3.ZERO
var _route_target_world_position: Vector3 = Vector3.ZERO
var _route_has_valid_positions: bool = false
var _route_complete: bool = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_transition_camera = get_node_or_null("TransitionCamera")
	_nebula_holder = get_node_or_null("NebulaHolder")
	visible = false
	set_process(false)
	if is_instance_valid(_transition_camera):
		_transition_camera.pause_mode = Node.PAUSE_MODE_PROCESS
		_transition_camera.current = false
	_update_nebula_anchor_for_sector("")


func capture_from_camera(camera_node: Camera) -> void:
	if not is_instance_valid(_transition_camera) or not is_instance_valid(camera_node):
		return
	_captured_camera_transform = camera_node.global_transform
	_has_captured_camera_transform = true
	_transition_camera.global_transform = _captured_camera_transform
	_transition_camera.fov = camera_node.fov


func set_transition_fov(fov_deg: float) -> void:
	if is_instance_valid(_transition_camera):
		_transition_camera.fov = fov_deg


func begin_departure(source_sector_id: String, target_sector_id: String, travel_direction: Vector3) -> void:
	_departure_sector_id = source_sector_id
	_target_sector_id = target_sector_id
	_travel_direction = _normalize_travel_direction(travel_direction)
	_current_velocity = 0.0
	_target_velocity = 0.0
	_velocity_step_rate = DEFAULT_ACCELERATION
	_departure_active = true
	_cruise_active = false
	_arrival_active = false
	_route_origin_world_position = _get_world_position_for_sector(source_sector_id)
	_route_world_position = _get_world_position_for_sector(source_sector_id)
	_route_target_world_position = _get_world_position_for_sector(target_sector_id)
	_route_has_valid_positions = _route_world_position != Vector3.ZERO or _route_target_world_position != Vector3.ZERO
	_route_complete = _get_remaining_route_distance() <= ROUTE_COMPLETION_TOLERANCE
	visible = false
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
		if _has_captured_camera_transform:
			_transition_camera.global_transform = Transform(
				_captured_camera_transform.basis,
				_get_route_local_position()
			)
		else:
			_transition_camera.global_transform = Transform(Basis(), _get_route_local_position())
		_align_camera_to_travel_direction()
	_update_nebula_anchor_for_sector(source_sector_id)
	set_process(false)


func begin_cruise(target_velocity: float) -> void:
	visible = true
	_departure_active = false
	_cruise_active = true
	_arrival_active = false
	_route_complete = false
	_target_velocity = max(target_velocity, 0.0)
	_velocity_step_rate = max(
		DEFAULT_ACCELERATION,
		_target_velocity / CRUISE_VELOCITY_RAMP_DURATION_SEC
	)
	if is_instance_valid(_transition_camera):
		_transition_camera.current = true
	set_process(true)


func begin_arrival() -> void:
	_departure_active = false
	_cruise_active = false
	_arrival_active = true
	_target_velocity = 0.0
	_velocity_step_rate = max(
		DEFAULT_DECELERATION,
		_current_velocity / ARRIVAL_VELOCITY_RAMP_DURATION_SEC
	)
	set_process(true)


func reset_transition_state() -> void:
	_departure_sector_id = ""
	_target_sector_id = ""
	_travel_direction = DEFAULT_TRAVEL_DIRECTION
	_current_velocity = 0.0
	_target_velocity = 0.0
	_velocity_step_rate = DEFAULT_ACCELERATION
	_departure_active = false
	_cruise_active = false
	_arrival_active = false
	_has_captured_camera_transform = false
	_captured_camera_transform = Transform.IDENTITY
	_route_origin_world_position = Vector3.ZERO
	_route_world_position = Vector3.ZERO
	_route_target_world_position = Vector3.ZERO
	_route_has_valid_positions = false
	_route_complete = false
	visible = false
	set_process(false)
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
		_transition_camera.global_transform = Transform.IDENTITY
	_update_nebula_anchor_for_sector("")


func deactivate_transition_view() -> void:
	visible = false
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false


func _process(delta: float) -> void:
	if not is_instance_valid(_transition_camera):
		return
	if _cruise_active and _route_has_valid_positions and _get_remaining_route_distance() <= _get_braking_distance() + ROUTE_COMPLETION_TOLERANCE:
		begin_arrival()
	_current_velocity = move_toward(_current_velocity, _target_velocity, _velocity_step_rate * delta)
	var remaining_distance = _get_remaining_route_distance()
	var travel_step = _current_velocity * delta
	if travel_step > 0.0:
		if _route_has_valid_positions:
			travel_step = min(travel_step, remaining_distance)
		if _route_has_valid_positions:
			_route_world_position += _travel_direction * travel_step
			_transition_camera.global_transform.origin = _get_route_local_position()
		else:
			_transition_camera.global_transform.origin += _travel_direction * travel_step
	remaining_distance = _get_remaining_route_distance()
	if _route_has_valid_positions and remaining_distance <= ROUTE_COMPLETION_TOLERANCE and _current_velocity <= ROUTE_COMPLETION_TOLERANCE:
		_route_world_position = _route_target_world_position
		_transition_camera.global_transform.origin = _get_route_local_position()
		_current_velocity = 0.0
		_target_velocity = 0.0
		_departure_active = false
		_cruise_active = false
		_arrival_active = false
		_route_complete = true
		set_process(false)
	elif _arrival_active and _current_velocity <= ROUTE_COMPLETION_TOLERANCE:
		if _route_has_valid_positions:
			_route_world_position = _route_target_world_position
			_transition_camera.global_transform.origin = _get_route_local_position()
		_route_complete = true
		_arrival_active = false
		set_process(false)


func get_current_velocity() -> float:
	return _current_velocity


func is_route_complete() -> bool:
	return _route_complete


func get_route_world_position() -> Vector3:
	return _route_world_position


func get_transition_camera_forward_direction() -> Vector3:
	if is_instance_valid(_transition_camera):
		return -_transition_camera.global_transform.basis.z.normalized()
	return _travel_direction


func _normalize_travel_direction(travel_direction: Vector3) -> Vector3:
	if travel_direction.length_squared() < 0.001:
		return DEFAULT_TRAVEL_DIRECTION
	return travel_direction.normalized()


func _align_camera_to_travel_direction() -> void:
	if not is_instance_valid(_transition_camera):
		return
	var up_direction = Vector3.UP
	if _has_captured_camera_transform:
		up_direction = _captured_camera_transform.basis.y.normalized()
	if abs(up_direction.dot(_travel_direction)) > 0.98:
		up_direction = Vector3.UP
	_transition_camera.look_at(
		_transition_camera.global_transform.origin + _travel_direction,
		up_direction
	)


func _get_remaining_route_distance() -> float:
	if not _route_has_valid_positions:
		return 0.0
	return _route_world_position.distance_to(_route_target_world_position)


func _get_route_local_position() -> Vector3:
	if not _route_has_valid_positions:
		return Vector3.ZERO
	return _route_world_position - _route_origin_world_position


func _get_braking_distance() -> float:
	var step_rate = max(_velocity_step_rate, 1.0)
	return (_current_velocity * _current_velocity) / (2.0 * step_rate)


func _get_world_position_for_sector(sector_id: String) -> Vector3:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	if sector_template == null:
		return Vector3.ZERO
	var world_position = sector_template.get("global_position")
	return world_position if world_position is Vector3 else Vector3.ZERO


func _update_nebula_anchor_for_sector(sector_id: String) -> void:
	if not is_instance_valid(_nebula_holder):
		return
	if sector_id == "":
		_nebula_holder.transform.origin = Vector3.ZERO
		return
	var sector_template = TemplateDatabase.locations.get(sector_id)
	if sector_template == null:
		_nebula_holder.transform.origin = Vector3.ZERO
		return
	var sector_position = sector_template.get("global_position")
	if sector_position is Vector3:
		_nebula_holder.transform.origin = Constants.get_reference_origin_offset(sector_position)
	else:
		_nebula_holder.transform.origin = Vector3.ZERO