#
# PROJECT: GDTLancer
# MODULE: hud_target_projector.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Workflow And Scope Boundary
# LOG_REF: 2026-06-13 06:40:05
#

extends Reference

var _hud: Control

func _init(hud: Control) -> void:
	_hud = hud

func get_projected_target_distance_fade_alpha(screen_pos: Vector2, viewport_rect: Rect2) -> float:
	if not _hud._is_projected_target_center_fade_enabled():
		return 1.0
	var viewport_center = viewport_rect.position + (viewport_rect.size / 2.0)
	var max_distance = max((viewport_rect.size / 2.0).length(), 1.0)
	var normalized_distance = clamp(screen_pos.distance_to(viewport_center) / max_distance, 0.0, 1.0)
	return compute_projected_target_distance_fade_alpha(normalized_distance)

func compute_projected_target_distance_fade_alpha(normalized_distance: float) -> float:
	var safe_normalized_distance = clamp(normalized_distance, 0.0, 1.0)
	return lerp(1.0, _hud.PROJECTED_TARGET_EDGE_ALPHA, pow(safe_normalized_distance, _hud.PROJECTED_TARGET_EDGE_POW))

func apply_projected_target_distance_fade(button: Control, fade_alpha: float) -> void:
	if is_instance_valid(button) and button.has_method("set_distance_fade_alpha"):
		button.call("set_distance_fade_alpha", fade_alpha)

func get_projected_target_overlay_kind(target_ref) -> String:
	if is_route_target(target_ref):
		var dest_id = target_ref.get("target_sector_id")
		var sector_type = "star"
		if dest_id != null and dest_id != "":
			if GameState.world_topology.has(dest_id) and GameState.world_topology[dest_id].has("sector_type"):
				sector_type = GameState.world_topology[dest_id].sector_type
			elif TemplateDatabase.locations.has(dest_id):
				var loc = TemplateDatabase.locations[dest_id]
				if loc != null and loc.get("sector_type") != null:
					sector_type = loc.sector_type
		if sector_type == "star":
			return _hud.OVERLAY_KIND_JUMP
		else:
			return _hud.OVERLAY_KIND_STELLAR
	if not (target_ref is Node and is_instance_valid(target_ref)):
		return ""
	if target_ref.is_in_group("jump_point"):
		return _hud.OVERLAY_KIND_JUMP
	if is_stellar_target(target_ref):
		return _hud.OVERLAY_KIND_STELLAR
	return _hud.OVERLAY_KIND_STRUCTURES

func is_projected_target_overlay_enabled(overlay_kind: String) -> bool:
	match overlay_kind:
		_hud.OVERLAY_KIND_STRUCTURES:
			return _hud._overlay_structures_enabled
		_hud.OVERLAY_KIND_STELLAR:
			return _hud._overlay_stellar_enabled
		_hud.OVERLAY_KIND_JUMP:
			return _hud._overlay_jump_enabled
		_:
			return true

func is_stellar_target(target_node: Node) -> bool:
	if not (target_node is StaticBody):
		return false
	if target_node.is_in_group("dockable_station") or target_node.is_in_group("jump_point"):
		return false
	var lower_name = str(target_node.name).to_lower()
	for token in ["star", "planet", "moon", "sun"]:
		if lower_name.find(token) != -1:
			return true
	return false

func is_route_target(target_ref) -> bool:
	return target_ref != null and target_ref.get("target_kind") == "jump_route"

func is_target_valid(target_ref) -> bool:
	if target_ref == null:
		return false
	if is_route_target(target_ref):
		return true
	return is_instance_valid(target_ref)

func get_projection_origin() -> Vector3:
	if is_instance_valid(GlobalRefs.player_agent_body):
		return GlobalRefs.player_agent_body.global_transform.origin
	if is_instance_valid(_hud._main_camera):
		return _hud._main_camera.global_transform.origin
	return Vector3.ZERO

func get_target_world_position(target_ref) -> Vector3:
	if is_route_target(target_ref):
		return target_ref.get_projection_world_position(
			get_projection_origin(),
			Constants.SECTOR_JUMP_ARRIVAL_RADIUS
		)
	if target_ref is Spatial and is_instance_valid(target_ref):
		return target_ref.global_transform.origin
	return Vector3.ZERO

func clear_route_target_overlay() -> void:
	for selection_key in _hud._route_target_buttons:
		var button = _hud._route_target_buttons[selection_key]
		if is_instance_valid(button):
			_hud._untrack_inflight_drag_control(button)
			button.queue_free()
	_hud._route_target_buttons.clear()
	_hud._route_target_overlay_sector_id = ""
	_hud._route_target_overlay_signature = ""
	_hud._refresh_process_state()

func clear_world_target_overlay() -> void:
	for instance_id in _hud._world_target_buttons:
		var button = _hud._world_target_buttons[instance_id]
		if is_instance_valid(button):
			_hud._untrack_inflight_drag_control(button)
			button.queue_free()
	_hud._world_target_buttons.clear()
	_hud._refresh_process_state()

func rebuild_projected_target_overlays() -> void:
	rebuild_route_target_overlay()
	rebuild_world_target_overlay()

func rebuild_route_target_overlay() -> void:
	clear_route_target_overlay()
	if not is_instance_valid(_hud.projected_target_overlay):
		return
	var current_sector_id: String = GameState.current_sector_id
	if current_sector_id == "":
		return
	_hud._route_target_overlay_sector_id = current_sector_id
	_hud._route_target_overlay_signature = get_route_target_overlay_signature(current_sector_id)
	var route_targets: Array = _hud._route_target_provider.build_targets_for_sector(current_sector_id)
	for route_target in route_targets:
		var button = _hud._instance_projected_target_bracket()
		if button == null:
			continue
		button.name = "Route_%s" % route_target.target_sector_id
		button.configure_target(route_target)
		button.connect("pressed", _hud, "_on_route_target_button_pressed", [route_target])
		_hud.projected_target_overlay.add_child(button)
		_hud._track_inflight_drag_control(button)
		_hud._route_target_buttons[route_target.selection_key] = button
	update_route_target_selection_state()
	_hud._refresh_process_state()

func sync_route_target_overlay_with_topology() -> void:
	var current_sector_id: String = GameState.current_sector_id
	var route_signature: String = get_route_target_overlay_signature(current_sector_id)
	if current_sector_id != _hud._route_target_overlay_sector_id or route_signature != _hud._route_target_overlay_signature:
		rebuild_route_target_overlay()

func get_route_target_overlay_signature(sector_id: String) -> String:
	if sector_id == "":
		return ""
	var connections: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
	var normalized_connections: Array = []
	for target_sector_id in connections:
		normalized_connections.append(str(target_sector_id))
	normalized_connections.sort()
	return "%s|%s" % [sector_id, str(normalized_connections)]

func rebuild_world_target_overlay() -> void:
	clear_world_target_overlay()
	if not is_instance_valid(_hud.projected_target_overlay):
		return
	var world_targets: Array = collect_world_projected_targets()
	for target_node in world_targets:
		var button = _hud._instance_projected_target_bracket()
		if button == null:
			continue
		button.name = "World_%s" % target_node.get_instance_id()
		button.configure_target(target_node, _hud._resolve_target_display_name(target_node))
		button.connect("pressed", _hud, "_on_world_target_button_pressed", [target_node])
		_hud.projected_target_overlay.add_child(button)
		_hud._track_inflight_drag_control(button)
		_hud._world_target_buttons[target_node.get_instance_id()] = button
	update_world_target_selection_state()
	_hud._refresh_process_state()

func update_route_target_overlay() -> void:
	if not is_instance_valid(_hud._main_camera):
		return
	var camera_fwd = -_hud._main_camera.global_transform.basis.z.normalized()
	var viewport_rect = _hud.get_viewport_rect()
	for selection_key in _hud._route_target_buttons:
		var button = _hud._route_target_buttons[selection_key]
		if not is_instance_valid(button):
			continue
		var route_target = button.target_ref
		if not is_route_target(route_target):
			button.visible = false
			apply_projected_target_distance_fade(button, 1.0)
			continue
		var overlay_kind = get_projected_target_overlay_kind(route_target)
		if not is_projected_target_overlay_enabled(overlay_kind):
			button.visible = false
			apply_projected_target_distance_fade(button, 1.0)
			continue
		var target_world_position: Vector3 = get_target_world_position(route_target)
		var target_dir = (target_world_position - _hud._main_camera.global_transform.origin).normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0
		var screen_pos = _hud._main_camera.unproject_position(target_world_position)
		var is_on_screen = viewport_rect.has_point(screen_pos)
		button.visible = is_in_front and is_on_screen
		if button.visible:
			button.rect_position = screen_pos - (button.rect_size / 2.0)
			apply_projected_target_distance_fade(button, get_projected_target_distance_fade_alpha(screen_pos, viewport_rect))
		else:
			apply_projected_target_distance_fade(button, 1.0)

func collect_world_projected_targets() -> Array:
	var targets: Array = []
	if not is_instance_valid(GlobalRefs.current_zone):
		return targets
	append_world_projected_targets(GlobalRefs.current_zone, targets)
	return targets

func append_world_projected_targets(node: Node, targets: Array) -> void:
	if is_world_projectable_target(node):
		targets.append(node)
	for child in node.get_children():
		append_world_projected_targets(child, targets)

func is_world_projectable_target(node: Node) -> bool:
	if not (node is Spatial):
		return false
	if node == GlobalRefs.player_agent_body:
		return false
	if node.is_in_group("jump_point"):
		return false
	if node is RigidBody:
		if node.has_method("is_player") and node.is_player():
			return false
		return true
	if node is StaticBody:
		return true
	return false

func update_world_target_overlay() -> void:
	if not is_instance_valid(_hud._main_camera):
		return
	var camera_fwd = -_hud._main_camera.global_transform.basis.z.normalized()
	var viewport_rect = _hud.get_viewport_rect()
	for instance_id in _hud._world_target_buttons:
		var button = _hud._world_target_buttons[instance_id]
		if not is_instance_valid(button):
			continue
		var target_node = button.target_ref
		if not (target_node is Spatial and is_instance_valid(target_node)):
			button.visible = false
			apply_projected_target_distance_fade(button, 1.0)
			continue
		var overlay_kind = get_projected_target_overlay_kind(target_node)
		if not is_projected_target_overlay_enabled(overlay_kind):
			button.visible = false
			apply_projected_target_distance_fade(button, 1.0)
			continue
		var target_world_position: Vector3 = get_target_world_position(target_node)
		var target_dir = (target_world_position - _hud._main_camera.global_transform.origin).normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0
		var screen_pos = _hud._main_camera.unproject_position(target_world_position)
		var is_on_screen = viewport_rect.has_point(screen_pos)
		button.visible = is_in_front and is_on_screen
		if button.visible:
			button.rect_position = screen_pos - (button.rect_size / 2.0)
			apply_projected_target_distance_fade(button, get_projected_target_distance_fade_alpha(screen_pos, viewport_rect))
		else:
			apply_projected_target_distance_fade(button, 1.0)

func get_route_target_selection_key() -> String:
	if is_route_target(_hud._current_target):
		return _hud._current_target.selection_key
	return ""

func update_route_target_selection_state() -> void:
	var selected_key = get_route_target_selection_key()
	for selection_key in _hud._route_target_buttons:
		var button = _hud._route_target_buttons[selection_key]
		if is_instance_valid(button):
			button.set_selected_state(selection_key == selected_key)
			if button.has_method("set_context_hint"):
				button.call("set_context_hint", get_projected_target_context_hint(button.target_ref))

func get_world_target_instance_id() -> int:
	if _hud._current_target is Spatial and is_instance_valid(_hud._current_target) and not is_route_target(_hud._current_target):
		return _hud._current_target.get_instance_id()
	return -1

func get_projected_target_context_hint(target_ref) -> String:
	if is_route_target(target_ref):
		return ""
	if target_ref is Node and is_instance_valid(target_ref) and target_ref.is_in_group("dockable_station"):
		return "Dock Target"
	if target_ref == _hud._current_target and is_target_valid(target_ref):
		return "Target Locked"
	return ""

func update_world_target_selection_state() -> void:
	var selected_instance_id = get_world_target_instance_id()
	for instance_id in _hud._world_target_buttons:
		var button = _hud._world_target_buttons[instance_id]
		if is_instance_valid(button):
			button.set_selected_state(instance_id == selected_instance_id)
			if button.has_method("set_context_hint"):
				button.call("set_context_hint", get_projected_target_context_hint(button.target_ref))
