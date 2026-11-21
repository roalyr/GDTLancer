# JumpTransitionRig: transition camera, particles, nebula and fade overlay used during sector jumps.

extends Spatial
const Interp = preload("res://src/core/utils/interp.gd")

const WorldRendering = preload("res://src/scenes/game_world/world_rendering.gd")

var _transition_camera: Camera = null
var _nebula_holder: Spatial = null
var _jump_transition_particles: Spatial = null
var _transition_overlay: ColorRect = null
var _transition_overlay_base_color: Color = Color(0, 0, 0, 1)
var _transition_overlay_alpha: float = 0.0
var _transition_particle_emitters = []
var _travel_direction: Vector3 = Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
var _captured_camera_transform: Transform = Transform.IDENTITY
var _has_captured_camera_transform: bool = false
var _route_origin_world_position: Vector3 = Vector3.ZERO
var _route_world_position: Vector3 = Vector3.ZERO
var _route_target_world_position: Vector3 = Vector3.ZERO
var _route_has_valid_positions: bool = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_transition_camera = get_node_or_null("TransitionCamera")
	Interp.keep_out(_transition_camera)  # Flown each frame
	_nebula_holder = get_node_or_null("NebulaHolder")
	_jump_transition_particles = get_node_or_null("TransitionCamera/JumpTransitionParticles")
	_transition_overlay = get_node_or_null("TransitionOverlayLayer/TransitionOverlay")
	if is_instance_valid(_transition_overlay):
		_transition_overlay_base_color = _transition_overlay.color
	visible = false
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
	_travel_direction = _normalize_travel_direction(travel_direction)
	_route_origin_world_position = _get_world_position_for_sector(source_sector_id)
	_route_world_position = _get_world_position_for_sector(source_sector_id)
	_route_target_world_position = _get_world_position_for_sector(target_sector_id)
	_route_has_valid_positions = _route_world_position != Vector3.ZERO or _route_target_world_position != Vector3.ZERO
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


func update_travel_progress(t: float) -> void:
	if _route_has_valid_positions:
		_route_world_position = lerp(_route_origin_world_position, _route_target_world_position, t)
		if is_instance_valid(_transition_camera):
			_transition_camera.global_transform.origin = _get_route_local_position()


func get_transition_overlay_alpha() -> float:
	return _transition_overlay_alpha


func reset_transition_state() -> void:
	_travel_direction = Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
	_has_captured_camera_transform = false
	_captured_camera_transform = Transform.IDENTITY
	_route_origin_world_position = Vector3.ZERO
	_route_world_position = Vector3.ZERO
	_route_target_world_position = Vector3.ZERO
	_route_has_valid_positions = false
	visible = false
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
		_transition_camera.global_transform = Transform.IDENTITY
	_apply_transition_overlay_alpha(0.0)
	set_transition_particles_active(false, true)
	_update_nebula_anchor_for_sector("")


# Shows the jump: the rig's view and camera on, its particles running.
func activate_transition_view() -> void:
	visible = true
	if is_instance_valid(_transition_camera):
		_transition_camera.current = true
	set_transition_particles_active(true, true)


func deactivate_transition_view() -> void:
	visible = false
	if is_instance_valid(_transition_camera):
		_transition_camera.current = false
	set_transition_particles_active(false, true)


func get_route_world_position() -> Vector3:
	return _route_world_position


func get_transition_camera_forward_direction() -> Vector3:
	if is_instance_valid(_transition_camera):
		return -_transition_camera.global_transform.basis.z.normalized()
	return _travel_direction


func set_transition_particles_active(is_active: bool, clear_existing: bool = false) -> void:
	if not is_instance_valid(_jump_transition_particles):
		return
	_jump_transition_particles.visible = is_active
	for emitter in _transition_particle_emitters:
		if not is_instance_valid(emitter):
			continue
		emitter.visible = is_active and WorldRendering.particles_allowed(get_tree())
		emitter.emitting = false
		if clear_existing and emitter.has_method("restart"):
			emitter.restart()
		emitter.emitting = is_active


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
