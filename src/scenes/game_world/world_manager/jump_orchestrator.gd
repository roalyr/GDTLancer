# PROJECT: GDTLancer
# MODULE: jump_orchestrator.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §4, §6.1, §6.3, §7; TRUTH_DOCS_CanvasItem_Godot_3.6.md §Render modes; TRUTH_SIMULATION-GRAPH.md §1; TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-06-12 23:42:30

extends Reference

var _world_manager: Node

func initialize(world_manager_ref: Node) -> void:
	_world_manager = world_manager_ref


func travel_to_sector(target_sector_id: String) -> void:
	var resolved_target_sector_id: String = _world_manager._resolve_known_sector_id(target_sector_id, "travel_to_sector")
	if resolved_target_sector_id == "":
		return
	if _world_manager._jump_transition_active:
		return
	if _is_jump_transition_enabled():
		_world_manager._jump_transition_active = true
		_world_manager.call_deferred("_run_jump_transition_sequence", resolved_target_sector_id)
		return
	_world_manager._travel_to_sector_immediate(resolved_target_sector_id)


func is_jump_transition_active() -> bool:
	return _world_manager._jump_transition_active


func _begin_jump_transition_foundation(source_sector_id: String, target_sector_id: String) -> void:
	var jump_transition_rig = _world_manager._get_jump_transition_rig()
	if not is_instance_valid(jump_transition_rig):
		_world_manager._reset_jump_transition_foundation()
		return
	if not _is_jump_transition_enabled():
		_world_manager._reset_jump_transition_foundation()
		return
	_world_manager._jump_transition_active = true
	if is_instance_valid(GlobalRefs.main_camera):
		_call_jump_transition_rig_method(
			jump_transition_rig,
			"capture_from_camera",
			[GlobalRefs.main_camera]
		)
	var departure_direction = _world_manager._get_departure_direction_for_route(source_sector_id, target_sector_id)
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"begin_departure",
		[source_sector_id, target_sector_id, departure_direction]
	)


func _reset_jump_transition_foundation() -> void:
	_world_manager._jump_transition_active = false
	var jump_transition_rig = _world_manager._get_jump_transition_rig()
	_call_jump_transition_rig_method(jump_transition_rig, "reset_transition_state")
	_world_manager._jump_transition_mouse_mode_before_lock = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(GlobalRefs.main_camera):
		if GlobalRefs.main_camera.has_method("clear_temporary_fov_override"):
			GlobalRefs.main_camera.clear_temporary_fov_override()
		GlobalRefs.main_camera.current = true


func _run_jump_transition_sequence(target_sector_id: String) -> void:
	var resolved_target_sector_id: String = _world_manager._resolve_known_sector_id(target_sector_id, "_run_jump_transition_sequence")
	if resolved_target_sector_id == "":
		_world_manager._reset_jump_transition_foundation()
		return
	var old_sector = _world_manager._resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
	var jump_transition_rig = _world_manager._get_jump_transition_rig()
	_world_manager._begin_jump_transition_foundation(old_sector, resolved_target_sector_id)
	if not _world_manager._jump_transition_active:
		_world_manager._travel_to_sector_immediate(resolved_target_sector_id)
		return

	var departure_direction = _world_manager._get_departure_direction_for_route(old_sector, resolved_target_sector_id)

	# Step 1: Ship orienting and accelerating, camera locked, HUD hidden, camera state recorded
	var departure_visuals_state = _world_manager._prepare_jump_transition_departure_visuals(departure_direction)
	if departure_visuals_state is GDScriptFunctionState:
		yield(departure_visuals_state, "completed")

	# Record camera state
	if is_instance_valid(GlobalRefs.main_camera):
		_world_manager._recorded_fov = GlobalRefs.main_camera.fov
		if GlobalRefs.main_camera.has_method("get_current_orbit_distance"):
			_world_manager._recorded_zoom_distance = GlobalRefs.main_camera.get_current_orbit_distance()
		else:
			_world_manager._recorded_zoom_distance = GlobalRefs.main_camera.distance

	# Resume/ensure ship acceleration
	if is_instance_valid(GlobalRefs.player_agent_body) and GlobalRefs.player_agent_body.has_method("command_align_to"):
		GlobalRefs.player_agent_body.command_align_to(departure_direction, true, 1.0, true)

	# Acceleration resumes during JUMP_ACCEL_DURATION
	var accel_state = _world_manager._yield_real_time(Constants.JUMP_ACCEL_DURATION)
	if accel_state is GDScriptFunctionState:
		yield(accel_state, "completed")

	# Step 2: Fade-in to black begins
	var fade_in_state = _world_manager._fade_transition_overlay(1.0, Constants.JUMP_FADE_DURATION)
	if fade_in_state is GDScriptFunctionState:
		yield(fade_in_state, "completed")

	# Step 3: When scene is hidden, unload old scene, enable transition camera and start movement
	_world_manager._pause_jump_transition_gameplay()

	_world_manager._prepare_sector_travel_state(resolved_target_sector_id, old_sector)
	_world_manager._cleanup_all_agents()
	_world_manager._cleanup_current_zone()
	yield(_world_manager.get_tree(), "idle_frame")

	# Enable transition camera/rig and configure
	if is_instance_valid(jump_transition_rig):
		if jump_transition_rig.has_method("capture_from_camera") and is_instance_valid(GlobalRefs.main_camera):
			jump_transition_rig.capture_from_camera(GlobalRefs.main_camera)

		# Set transition camera fov to the max orbit camera fov
		if jump_transition_rig.has_method("set_transition_fov"):
			jump_transition_rig.set_transition_fov(Constants.MAX_ORBIT_CAMERA_FOV)
		elif "_transition_camera" in jump_transition_rig and is_instance_valid(jump_transition_rig._transition_camera):
			jump_transition_rig._transition_camera.fov = Constants.MAX_ORBIT_CAMERA_FOV

		# Initialize transition rig route details
		if jump_transition_rig.has_method("begin_departure"):
			jump_transition_rig.begin_departure(old_sector, resolved_target_sector_id, departure_direction)

		# Make sure the rig is visible and active for rendering
		if "visible" in jump_transition_rig:
			jump_transition_rig.visible = true

		if "_transition_camera" in jump_transition_rig and is_instance_valid(jump_transition_rig._transition_camera):
			jump_transition_rig._transition_camera.current = true

		if jump_transition_rig.has_method("set_transition_particles_active"):
			jump_transition_rig.set_transition_particles_active(true, true)

	# Gradually lift the fade
	var fade_out_rig_state = _world_manager._fade_transition_overlay(0.0, Constants.JUMP_FADE_DURATION)
	if fade_out_rig_state is GDScriptFunctionState:
		yield(fade_out_rig_state, "completed")

	# Step 4: Movement continues for travel duration. Fade-in begins at threshold.
	var source_type = _get_sector_type(old_sector)
	var target_type = _get_sector_type(resolved_target_sector_id)
	var travel_duration = Constants.get_jump_travel_duration(source_type, target_type)

	var travel_time: float = 0.0
	var threshold_time: float = max(travel_duration - Constants.JUMP_FADE_DURATION, 0.0)
	var fade_in_started: bool = false

	while travel_time < travel_duration:
		# Use get_process_delta_time since gameplay tree is paused during transition
		var frame_delta = _world_manager.get_process_delta_time()
		travel_time += frame_delta
		var t = clamp(travel_time / travel_duration, 0.0, 1.0)
		# Smootherstep easing (Ken Perlin's formula: 6t^5 - 15t^4 + 10t^3)
		# This guarantees that both velocity and acceleration start and end at 0.
		var eased_t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

		# Interpolate rig position
		if is_instance_valid(jump_transition_rig):
			if jump_transition_rig.has_method("update_travel_progress"):
				jump_transition_rig.update_travel_progress(eased_t)
			else:
				if "_route_has_valid_positions" in jump_transition_rig and jump_transition_rig._route_has_valid_positions:
					jump_transition_rig._route_world_position = lerp(
						jump_transition_rig._route_origin_world_position,
						jump_transition_rig._route_target_world_position,
						eased_t
					)
					if "_transition_camera" in jump_transition_rig and is_instance_valid(jump_transition_rig._transition_camera):
						jump_transition_rig._transition_camera.global_transform.origin = jump_transition_rig._get_route_local_position()

		# At threshold, start the fade-in to black asynchronously
		if travel_time >= threshold_time and not fade_in_started:
			fade_in_started = true
			_world_manager._fade_transition_overlay_async(1.0, Constants.JUMP_FADE_DURATION)

		yield(_world_manager.get_tree(), "idle_frame")

	# Ensure overlay is fully opaque
	var final_fade_state = _world_manager._fade_transition_overlay(1.0, 0.1)
	if final_fade_state is GDScriptFunctionState:
		yield(final_fade_state, "completed")

	# Deactivate transition rig view
	if is_instance_valid(jump_transition_rig):
		if jump_transition_rig.has_method("deactivate_transition_view"):
			jump_transition_rig.deactivate_transition_view()
		else:
			if "visible" in jump_transition_rig:
				jump_transition_rig.visible = false
			if "_transition_camera" in jump_transition_rig and is_instance_valid(jump_transition_rig._transition_camera):
				jump_transition_rig._transition_camera.current = false
		if jump_transition_rig.has_method("set_transition_particles_active"):
			jump_transition_rig.set_transition_particles_active(false, true)

	# Load destination sector
	_world_manager.load_sector(resolved_target_sector_id)
	yield(_world_manager.get_tree(), "idle_frame")

	var player_ready_state = _world_manager._wait_for_player_and_zone_ready(Constants.JUMP_TRANSITION_LOAD_TIMEOUT_SEC)
	if player_ready_state is GDScriptFunctionState:
		yield(player_ready_state, "completed")

	# Restore camera zoom and FoV
	_world_manager._restore_gameplay_camera_at_recorded_state()

	# Unpause gameplay
	_world_manager._restore_jump_transition_gameplay()

	# Fade lifts gradually
	var final_fade_out_state = _world_manager._fade_transition_overlay(0.0, Constants.JUMP_FADE_DURATION)
	if final_fade_out_state is GDScriptFunctionState:
		yield(final_fade_out_state, "completed")

	# HUD returns in the very end
	_world_manager._set_main_hud_hidden(false)

	_world_manager._set_jump_transition_camera_locked(false)
	_world_manager._reset_jump_transition_foundation()
	_world_manager._request_sector_travel_tick()


func _get_sector_type(sector_id: String) -> String:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	if sector_template != null and "sector_type" in sector_template:
		return sector_template.sector_type
	return "star"


func _travel_to_sector_immediate(target_sector_id: String) -> void:
	_prepare_sector_travel_state(target_sector_id)
	_world_manager.load_sector(target_sector_id)
	_request_sector_travel_tick()


func _prepare_sector_travel_state(target_sector_id: String, old_sector_id: String = "") -> String:
	var old_sector = old_sector_id
	if old_sector == "":
		old_sector = _world_manager._resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
	_snapshot_player_state_for_sector_travel()
	GameState.player_docked_at = ""
	GameState.player_arrived_from_sector = old_sector
	GameState.player_arrival_direction = _get_arrival_direction_for_route(old_sector, target_sector_id)
	if GameState.agents.has("player"):
		GameState.agents["player"]["current_sector_id"] = target_sector_id
	EventBus.emit_signal("sector_changed", target_sector_id, old_sector)
	return old_sector


func _snapshot_player_state_for_sector_travel() -> void:
	# Clear saved-position priority so sector travel always uses the arrival shell or jump point.
	GameState.player_position = Vector3.ZERO
	if is_instance_valid(GlobalRefs.player_agent_body):
		_world_manager._snapshot_player_state_for_sector_travel()


func _pause_jump_transition_gameplay() -> void:
	_world_manager._pause_jump_transition_gameplay()


func _restore_jump_transition_gameplay() -> void:
	_world_manager._restore_jump_transition_gameplay()


func _set_jump_transition_camera_locked(is_locked: bool) -> void:
	_world_manager._set_jump_transition_camera_locked(is_locked)


func _set_main_hud_hidden(is_hidden: bool) -> void:
	_world_manager._set_main_hud_hidden(is_hidden)


func _restore_gameplay_camera_at_transition_fov() -> void:
	_restore_gameplay_camera_at_recorded_state()


func _restore_gameplay_camera_at_recorded_state() -> void:
	if not is_instance_valid(GlobalRefs.main_camera):
		return
	var jump_transition_rig = _world_manager._get_jump_transition_rig()
	var transition_forward_direction = Vector3.ZERO
	var transition_forward_direction_value = _call_jump_transition_rig_method(
		jump_transition_rig,
		"get_transition_camera_forward_direction",
		[],
		Vector3.ZERO
	)
	if transition_forward_direction_value is Vector3:
		transition_forward_direction = transition_forward_direction_value

	# On jump-in trigger camera aim at target origin (coord origin or Entry point)
	if is_instance_valid(GlobalRefs.player_agent_body):
		var anchor_pos = Vector3.ZERO
		if is_instance_valid(GlobalRefs.current_zone):
			var entry_node = GlobalRefs.current_zone.find_node("EntryPoint", true, false)
			if entry_node and entry_node is Spatial:
				anchor_pos = entry_node.global_transform.origin
		var player_pos = GlobalRefs.player_agent_body.global_transform.origin
		var target_origin_dir = (anchor_pos - player_pos).normalized()
		if target_origin_dir.length_squared() > 0.001:
			transition_forward_direction = target_origin_dir

	_call_jump_transition_rig_method(jump_transition_rig, "deactivate_transition_view")
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"set_transition_particles_active",
		[false, true]
	)

	# Restore recorded FoV
	if GlobalRefs.main_camera.has_method("apply_zoom_controller_fov"):
		GlobalRefs.main_camera.apply_zoom_controller_fov(_world_manager._recorded_fov)
	elif "fov" in GlobalRefs.main_camera:
		GlobalRefs.main_camera.fov = _world_manager._recorded_fov

	# Restore recorded zoom distance
	if "_zoom_controller" in GlobalRefs.main_camera and GlobalRefs.main_camera._zoom_controller != null and GlobalRefs.main_camera._zoom_controller.has_method("_set_and_update_zoom_distance"):
		GlobalRefs.main_camera._zoom_controller._set_and_update_zoom_distance(_world_manager._recorded_zoom_distance, false)
	elif "distance" in GlobalRefs.main_camera:
		GlobalRefs.main_camera.distance = _world_manager._recorded_zoom_distance

	# Clear temporary fov override if any
	if GlobalRefs.main_camera.has_method("clear_temporary_fov_override"):
		GlobalRefs.main_camera.clear_temporary_fov_override()

	if is_instance_valid(GlobalRefs.player_agent_body):
		if GlobalRefs.main_camera.has_method("restore_orbit_from_transition_view"):
			GlobalRefs.main_camera.restore_orbit_from_transition_view(
				GlobalRefs.player_agent_body,
				transition_forward_direction
			)
		elif GlobalRefs.main_camera.has_method("set_target_node"):
			GlobalRefs.main_camera.set_target_node(GlobalRefs.player_agent_body)
			if transition_forward_direction.length_squared() >= 0.001 and GlobalRefs.main_camera.has_method("set_orbit_forward_direction"):
				GlobalRefs.main_camera.set_orbit_forward_direction(transition_forward_direction)

	GlobalRefs.main_camera.current = true


func _fade_transition_overlay(target_alpha: float, duration: float):
	var rig = _world_manager._get_jump_transition_rig()
	if not is_instance_valid(rig):
		return
	var start_alpha = 0.0
	if rig.has_method("get_transition_overlay_alpha"):
		start_alpha = rig.get_transition_overlay_alpha()

	var start_time_ms = OS.get_ticks_msec()
	var duration_ms = max(int(duration * 1000.0), 1)
	while true:
		var elapsed_ms = OS.get_ticks_msec() - start_time_ms
		var t = clamp(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		var current_alpha = lerp(start_alpha, target_alpha, t)
		if rig.has_method("_apply_transition_overlay_alpha"):
			rig._apply_transition_overlay_alpha(current_alpha)
		if t >= 1.0:
			break
		yield(_world_manager.get_tree(), "idle_frame")


func _fade_transition_overlay_async(target_alpha: float, duration: float) -> void:
	_fade_transition_overlay(target_alpha, duration)


func _prepare_jump_transition_departure_visuals(departure_direction: Vector3):
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_orbit_forward_direction"):
		GlobalRefs.main_camera.set_orbit_forward_direction(departure_direction)
	var camera_aim_state = _world_manager._yield_real_time(1.0)
	if camera_aim_state is GDScriptFunctionState:
		yield(camera_aim_state, "completed")
	var jump_transition_rig = _world_manager._get_jump_transition_rig()
	if is_instance_valid(GlobalRefs.main_camera):
		_call_jump_transition_rig_method(
			jump_transition_rig,
			"capture_from_camera",
			[GlobalRefs.main_camera]
		)
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"set_transition_particles_active",
		[false, true]
	)
	_world_manager._set_jump_transition_camera_locked(true)
	_world_manager._set_main_hud_hidden(true)


func _get_jump_transition_fov_progress(linear_t: float) -> float:
	var t = clamp(linear_t, 0.0, 1.0)
	return pow(t, Constants.JUMP_TRANSITION_FOV_EASE_POWER)


func _animate_main_camera_fov_override(target_fov: float, duration_sec: float):
	if not is_instance_valid(GlobalRefs.main_camera) or not GlobalRefs.main_camera.has_method("set_temporary_fov_override"):
		return
	var start_fov = GlobalRefs.main_camera.fov
	if GlobalRefs.main_camera.has_method("get_effective_fov"):
		start_fov = GlobalRefs.main_camera.get_effective_fov()
	var start_time_ms = OS.get_ticks_msec()
	var duration_ms = max(int(duration_sec * 1000.0), 1)
	while true:
		var elapsed_ms = OS.get_ticks_msec() - start_time_ms
		var t = clamp(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		GlobalRefs.main_camera.set_temporary_fov_override(
			lerp(start_fov, target_fov, _get_jump_transition_fov_progress(t))
		)
		if t >= 1.0:
			break
		yield(_world_manager.get_tree(), "idle_frame")


func _animate_main_camera_fov_restore(duration_sec: float):
	if not is_instance_valid(GlobalRefs.main_camera) or not GlobalRefs.main_camera.has_method("set_temporary_fov_override"):
		return
	var start_fov = GlobalRefs.main_camera.fov
	if GlobalRefs.main_camera.has_method("get_effective_fov"):
		start_fov = GlobalRefs.main_camera.get_effective_fov()
	var target_fov = start_fov
	if GlobalRefs.main_camera.has_method("get_zoom_controller_fov"):
		target_fov = GlobalRefs.main_camera.get_zoom_controller_fov()
	var start_time_ms = OS.get_ticks_msec()
	var duration_ms = max(int(duration_sec * 1000.0), 1)
	while true:
		var elapsed_ms = OS.get_ticks_msec() - start_time_ms
		var t = clamp(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		GlobalRefs.main_camera.set_temporary_fov_override(
			lerp(start_fov, target_fov, _get_jump_transition_fov_progress(t))
		)
		if t >= 1.0:
			break
		yield(_world_manager.get_tree(), "idle_frame")
	if GlobalRefs.main_camera.has_method("clear_temporary_fov_override"):
		GlobalRefs.main_camera.clear_temporary_fov_override()


func _wait_for_rig_velocity(jump_transition_rig: Node, target_velocity: float, tolerance: float, timeout_sec: float):
	if not _jump_transition_rig_supports_method(jump_transition_rig, "get_current_velocity"):
		return true
	var start_time_ms = OS.get_ticks_msec()
	var timeout_ms = max(int(timeout_sec * 1000.0), 1)
	while true:
		var current_velocity = float(
			_call_jump_transition_rig_method(jump_transition_rig, "get_current_velocity", [], 0.0)
		)
		if abs(current_velocity - target_velocity) <= tolerance:
			return true
		if OS.get_ticks_msec() - start_time_ms >= timeout_ms:
			return false
		yield(_world_manager.get_tree(), "idle_frame")


func _wait_for_rig_route_completion(jump_transition_rig: Node, timeout_sec: float):
	if not _jump_transition_rig_supports_method(jump_transition_rig, "is_route_complete"):
		return true
	var start_time_ms = OS.get_ticks_msec()
	var timeout_ms = max(int(timeout_sec * 1000.0), 1)
	while true:
		if bool(_call_jump_transition_rig_method(jump_transition_rig, "is_route_complete", [], true)):
			return true
		if OS.get_ticks_msec() - start_time_ms >= timeout_ms:
			return false
		yield(_world_manager.get_tree(), "idle_frame")


func _wait_for_player_and_zone_ready(timeout_sec: float):
	var start_time_ms = OS.get_ticks_msec()
	var timeout_ms = max(int(timeout_sec * 1000.0), 1)
	while true:
		if is_instance_valid(GlobalRefs.current_zone) and is_instance_valid(GlobalRefs.player_agent_body):
			return true
		if OS.get_ticks_msec() - start_time_ms >= timeout_ms:
			return false
		yield(_world_manager.get_tree(), "idle_frame")


func _yield_real_time(duration_sec: float):
	if duration_sec <= 0.0:
		return
	var start_time_ms = OS.get_ticks_msec()
	var duration_ms = max(int(duration_sec * 1000.0), 1)
	while OS.get_ticks_msec() - start_time_ms < duration_ms:
		yield(_world_manager.get_tree(), "idle_frame")


func _get_jump_transition_route_distance(source_sector_id: String, target_sector_id: String) -> float:
	return _get_sector_global_position(source_sector_id).distance_to(_get_sector_global_position(target_sector_id))


func _get_jump_transition_cruise_speed(route_distance: float, travel_duration_sec: float = Constants.JUMP_TRANSITION_TRAVEL_DURATION_SEC) -> float:
	if route_distance <= 0.0:
		return 0.0
	var effective_travel_window_sec = max(
		travel_duration_sec - Constants.JUMP_TRANSITION_SPEED_RAMP_DURATION_SEC,
		0.1
	)
	return route_distance / effective_travel_window_sec


func _get_jump_transition_route_timeout_sec(route_distance: float, cruise_speed: float, travel_duration_sec: float = Constants.JUMP_TRANSITION_TRAVEL_DURATION_SEC, tolerance: float = Constants.JUMP_TRANSITION_ROUTE_COMPLETION_TOLERANCE) -> float:
	if route_distance <= tolerance or cruise_speed <= 0.0:
		return Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC
	return travel_duration_sec + Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC


func _request_sector_travel_tick() -> void:
	_world_manager._request_sector_travel_tick()


func _get_departure_direction_for_route(source_sector_id: String, target_sector_id: String) -> Vector3:
	var source_position: Vector3 = _get_sector_global_position(source_sector_id)
	var target_position: Vector3 = _get_sector_global_position(target_sector_id)
	if source_position == target_position:
		return Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
	return (target_position - source_position).normalized()


func _get_arrival_direction_for_route(source_sector_id: String, target_sector_id: String) -> Vector3:
	var source_position: Vector3 = _get_sector_global_position(source_sector_id)
	var target_position: Vector3 = _get_sector_global_position(target_sector_id)
	if source_position == target_position:
		return Vector3.ZERO
	return (source_position - target_position).normalized()


func _get_sector_global_position(sector_id: String) -> Vector3:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	if sector_template == null:
		return Vector3.ZERO
	var global_position = sector_template.get("global_position")
	return global_position if global_position is Vector3 else Vector3.ZERO


func _get_world_rendering_node() -> Node:
	var scene_tree = _world_manager.get_tree()
	if scene_tree != null and is_instance_valid(scene_tree.current_scene):
		var scene_world_rendering = scene_tree.current_scene.get_node_or_null("WorldRendering")
		if is_instance_valid(scene_world_rendering):
			return scene_world_rendering
	if is_instance_valid(_world_manager.get_parent()):
		var parent_world_rendering = _world_manager.get_parent().get_node_or_null("WorldRendering")
		if is_instance_valid(parent_world_rendering):
			return parent_world_rendering
	return null


func _is_jump_transition_enabled() -> bool:
	var world_rendering = _get_world_rendering_node()
	if not is_instance_valid(world_rendering):
		return false
	return bool(world_rendering.get("jump_transition_enabled"))


func _get_jump_transition_rig() -> Node:
	if is_instance_valid(_world_manager.get_parent()):
		return _world_manager.get_parent().get_node_or_null(Constants.JUMP_TRANSITION_RIG_NODE_NAME)
	return null


func _jump_transition_rig_supports_method(jump_transition_rig: Node, method_name: String) -> bool:
	return is_instance_valid(jump_transition_rig) and jump_transition_rig.has_method(method_name)


func _call_jump_transition_rig_method(
		jump_transition_rig: Node,
		method_name: String,
		args: Array = [],
		default_value = null
	):
	if not _jump_transition_rig_supports_method(jump_transition_rig, method_name):
		return default_value
	if args.empty():
		return jump_transition_rig.call(method_name)
	return jump_transition_rig.callv(method_name, args)
