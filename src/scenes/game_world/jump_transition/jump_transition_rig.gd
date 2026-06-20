# PROJECT: GDTLancer
# MODULE: jump_transition_rig.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: jump_transition_rig.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §4, §6.1, §6.3, §7; TRUTH_DOCS_CanvasItem_Godot_3.6.md §Render modes; TRUTH_SIMULATION-GRAPH.md §1; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-08 02:20:00
#

extends Spatial

enum OverlayEnvelopeState { INACTIVE, RISING, HOLDING, DECAYING }

var _transition_camera: Camera = null
var _nebula_holder: Spatial = null
var _jump_transition_particles: Spatial = null
var _transition_overlay: ColorRect = null
var _transition_overlay_base_color: Color = Color(0, 0, 0, 1)
var _transition_overlay_alpha: float = 0.0
var _transition_overlay_immediate_override: bool = false
var _transition_overlay_state: int = OverlayEnvelopeState.INACTIVE
var _transition_overlay_elapsed_sec: float = 0.0
var _transition_overlay_duration_sec: float = 0.0
var _transition_overlay_rise_curve_power: float = 0.7
var _transition_overlay_auto_decay_duration_sec: float = 0.0
var _transition_overlay_hold_decay_duration_sec: float = 0.0
var _transition_overlay_decay_start_alpha: float = 0.0
var _transition_particle_emitters = []
var _travel_direction: Vector3 = Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
var _current_velocity: float = 0.0
var _target_velocity: float = 0.0
var _velocity_step_rate: float = 0.0
var _cruise_active: bool = false
var _arrival_active: bool = false
var _captured_camera_transform: Transform = Transform.IDENTITY
var _has_captured_camera_transform: bool = false
var _route_origin_world_position: Vector3 = Vector3.ZERO
var _route_world_position: Vector3 = Vector3.ZERO
var _route_target_world_position: Vector3 = Vector3.ZERO
var _route_has_valid_positions: bool = false
var _route_complete: bool = false
var _source_sector_id: String = ""
var _target_sector_id: String = ""


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_transition_camera = get_node_or_null("TransitionCamera")
	_nebula_holder = get_node_or_null("NebulaHolder")
	_jump_transition_particles = get_node_or_null("TransitionCamera/JumpTransitionParticles")
	_transition_overlay = get_node_or_null("TransitionOverlayLayer/TransitionOverlay")
	if is_instance_valid(_transition_overlay):
		_transition_overlay_base_color = _transition_overlay.color
	visible = false
	set_process(false)
	if is_instance_valid(_transition_camera):
		_transition_camera.pause_mode = Node.PAUSE_MODE_PROCESS
		_transition_camera.current = false
	_cache_transition_particle_emitters()
	_apply_transition_overlay_alpha(0.0)
	set_transition_particles_active(false, true)
	_update_nebula_anchor_for_sector("")


func capture_from_camera(camera_node: Camera) -> void:
	if not is_instance_valid(_transition_camera) or not is_instance_valid(camera_node):
		return
	_captured_camera_transform = camera_node.global_transform
	_has_captured_camera_transform = true
	_transition_camera.global_transform = _captured_camera_transform
	_transition_camera.fov = Constants.MAX_ORBIT_CAMERA_FOV


func set_transition_fov(fov_deg: float) -> void:
	if is_instance_valid(_transition_camera):
		_transition_camera.fov = fov_deg


func begin_departure(source_sector_id: String, target_sector_id: String, travel_direction: Vector3) -> void:
	_source_sector_id = source_sector_id
	_target_sector_id = target_sector_id
	_travel_direction = _normalize_travel_direction(travel_direction)
	_current_velocity = 0.0
	_target_velocity = 0.0
	_cruise_active = false
	_arrival_active = false
	_route_origin_world_position = _get_world_position_for_sector(source_sector_id)
	_route_world_position = _get_world_position_for_sector(source_sector_id)
	_route_target_world_position = _get_world_position_for_sector(target_sector_id)
	_route_has_valid_positions = _route_world_position != Vector3.ZERO or _route_target_world_position != Vector3.ZERO
	_route_complete = false
	visible = false
	set_transition_particles_active(false, true)
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
	_cruise_active = true
	_arrival_active = false
	_route_complete = false
	_target_velocity = max(target_velocity, 0.0)
	_current_velocity = _target_velocity
	if is_instance_valid(_transition_camera):
		_transition_camera.current = true
	set_process(true)


func begin_arrival() -> void:
	_cruise_active = false
	_arrival_active = true
	_target_velocity = 0.0
	_current_velocity = 0.0
	_route_complete = true
	set_process(false)


func update_travel_progress(t: float) -> void:
	if _route_has_valid_positions:
		var old_pos = _route_world_position
		_route_world_position = lerp(_route_origin_world_position, _route_target_world_position, t)
		
		# Estimate current velocity based on position change and delta time
		var delta = get_process_delta_time()
		if delta > 0.0001:
			_current_velocity = old_pos.distance_to(_route_world_position) / delta
		else:
			_current_velocity = 0.0

		if is_instance_valid(_transition_camera):
			_transition_camera.global_transform.origin = _get_route_local_position()


func begin_departure_overlay_window() -> void:
	pass


func on_departure_cruise_entered() -> void:
	pass


func begin_arrival_overlay_window() -> void:
	pass


func on_arrival_fov_stabilized() -> void:
	pass


func get_transition_overlay_alpha() -> float:
	return _transition_overlay_alpha


func reset_transition_state() -> void:
	_source_sector_id = ""
	_target_sector_id = ""
	_travel_direction = Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
	_current_velocity = 0.0
	_target_velocity = 0.0
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
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
		_transition_camera.global_transform = Transform.IDENTITY
	_apply_transition_overlay_alpha(0.0)
	set_transition_particles_active(false, true)
	_update_nebula_anchor_for_sector("")
	set_process(false)


func get_transition_fov() -> float:
	if is_instance_valid(_transition_camera):
		return _transition_camera.fov
	return Constants.MAX_ORBIT_CAMERA_FOV


func deactivate_transition_view() -> void:
	visible = false
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
	set_transition_particles_active(false, true)
	set_process(false)


func _process(delta: float) -> void:
	if _cruise_active:
		var remaining = _get_remaining_route_distance()
		var step = _target_velocity * delta
		if remaining > 0.0:
			step = min(step, remaining)
			_route_world_position += _travel_direction * step
			if is_instance_valid(_transition_camera):
				_transition_camera.global_transform.origin = _get_route_local_position()
			if _get_remaining_route_distance() <= 0.1:
				_route_complete = true
				_cruise_active = false
				set_process(false)
		else:
			_route_complete = true
			_cruise_active = false
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


func _set_transition_overlay_active(is_active: bool) -> void:
	_apply_transition_overlay_alpha(1.0 if is_active else 0.0)


func set_transition_particles_active(is_active: bool, clear_existing: bool = false) -> void:
	if not is_instance_valid(_jump_transition_particles):
		return
	_jump_transition_particles.visible = is_active
	for emitter in _transition_particle_emitters:
		if not is_instance_valid(emitter):
			continue
		emitter.visible = is_active
		emitter.emitting = false
		if clear_existing and emitter.has_method("restart"):
			emitter.restart()
		emitter.emitting = is_active


func _set_jump_transition_particles_active(is_active: bool, clear_existing: bool = false) -> void:
	set_transition_particles_active(is_active, clear_existing)


func _apply_transition_overlay_alpha(alpha: float) -> void:
	_transition_overlay_alpha = clamp(alpha, 0.0, 1.0)
	if not is_instance_valid(_transition_overlay):
		return
	_transition_overlay.visible = _transition_overlay_alpha > 0.001
	_transition_overlay.color = Color(
		_transition_overlay_base_color.r,
		_transition_overlay_base_color.g,
		_transition_overlay_base_color.b,
		_transition_overlay_alpha
	)
	if _transition_overlay.visible:
		_transition_overlay.raise()


func _cache_transition_particle_emitters() -> void:
	_transition_particle_emitters.clear()
	if not is_instance_valid(_jump_transition_particles):
		return
	for emitter in _jump_transition_particles.get_children():
		if emitter is CPUParticles:
			emitter.pause_mode = Node.PAUSE_MODE_PROCESS
			emitter.visible = false
			emitter.emitting = false
			_transition_particle_emitters.append(emitter)


func _normalize_travel_direction(travel_direction: Vector3) -> Vector3:
	if travel_direction.length_squared() < 0.001:
		return Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
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
