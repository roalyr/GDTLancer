#
# PROJECT: GDTLancer
# MODULE: world_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §4, §6.1, §6.3, §7; TRUTH_DOCS_CanvasItem_Godot_3.6.md §Render modes; TRUTH_SIMULATION-GRAPH.md §1
# LOG_REF: 2026-05-23 15:59:10
#

extends Node

## WorldManager: Core scene orchestrator handling game initialization, zone loading, and save/load flow.
## Coordinates TemplateIndexer, WorldGenerator, and AgentSpawner for game lifecycle.

# --- Component Scripts ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")

# --- State ---
var _spawned_agent_bodies = []
var _sector_loader = null
var _pending_jump_target: String = ""
var _reported_invalid_sectors: Dictionary = {}
var _jump_transition_active: bool = false
var _jump_transition_tree_was_paused: bool = false
var _jump_transition_timer_was_running: bool = false
var _jump_transition_mouse_mode_before_lock: int = Input.MOUSE_MODE_VISIBLE

# --- Nodes ---
var _time_clock_timer: Timer = null
var _template_indexer: Node = null
var _world_generator: Node = null

# --- Initialization ---
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	GlobalRefs.set_world_manager(self)
	
	# Step 1: Index all data templates into the TemplateDatabase.
	_template_indexer = TemplateIndexer.new()
	_template_indexer.name = "TemplateIndexer"
	add_child(_template_indexer)
	_template_indexer.index_all_templates()

	# Step 2: Boot to Main Menu. World generation/zone load happens only after
	# the player chooses New Game / Load Game.
	_show_boot_main_menu()
	
	# Connect to agent signals to keep the local list clean.
	EventBus.connect("agent_spawned", self, "_on_Agent_Spawned")
	EventBus.connect("agent_despawning", self, "_on_Agent_Despawning")
	if EventBus.has_signal("game_state_loaded"):
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")
	if EventBus.has_signal("new_game_requested"):
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
	EventBus.connect("player_jump_requested", self, "_on_player_jump_requested")
	EventBus.connect("jump_available", self, "_on_jump_available")
	EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")
	

	# --- NEW: Setup the Time Clock Timer ---
	_time_clock_timer = Timer.new()
	_time_clock_timer.name = "TimeClockTimer"
	_time_clock_timer.wait_time = Constants.TIME_TICK_INTERVAL_SECONDS
	_time_clock_timer.autostart = false
	_time_clock_timer.connect("timeout", self, "_on_Time_Clock_Timer_timeout")
	add_child(_time_clock_timer)
	
	randomize()
	# Do not load a zone at boot; wait for New Game / Load.


func _on_new_game_requested() -> void:
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	_reset_jump_transition_foundation()
	_set_main_hud_hidden(false)
	# Leaving the Main Menu; resume gameplay.
	get_tree().paused = false
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.stop()  # Stop timer during cleanup

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("reset_to_defaults"):
		GameStateManager.reset_to_defaults()
	else:
		printerr("WorldManager: GameStateManager.reset_to_defaults() unavailable.")
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")
	
	_setup_new_game()

	# Initialize the four-layer simulation from a seed.
	var seed_str: String = str(OS.get_unix_time())
	if is_instance_valid(GlobalRefs.simulation_engine):
		GlobalRefs.simulation_engine.initialize_simulation(seed_str)
	else:
		push_warning("WorldManager: SimulationEngine not available, skipping sim init.")

	GameState.agents["player"]["current_sector_id"] = Constants.INITIAL_SECTOR_ID
	load_sector(Constants.INITIAL_SECTOR_ID)
	
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()


func _on_game_state_loaded() -> void:
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	_reset_jump_transition_foundation()
	_set_main_hud_hidden(false)
	# A saved state has been applied; we now need to load a zone so AgentSpawner can
	# spawn the player from the restored GameState.
	get_tree().paused = false
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.stop()  # Stop timer during cleanup

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")
	
	# Re-initialize simulation from saved seed on load.
	var saved_seed: String = GameState.world_seed
	if saved_seed != "" and is_instance_valid(GlobalRefs.simulation_engine):
		GlobalRefs.simulation_engine.initialize_simulation(saved_seed)

	var saved_sector = _resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
	GameState.current_sector_id = saved_sector
	load_sector(saved_sector)
	call_deferred("_emit_loaded_dock_signal")
	call_deferred("_emit_loaded_resource_signals")
	
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()


func _emit_loaded_resource_signals() -> void:
	if not EventBus:
		return
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return
	EventBus.emit_signal("player_credits_changed", player_char.credits)
	EventBus.emit_signal("player_fp_changed", player_char.focus_points)


func _emit_loaded_dock_signal() -> void:
	var retries := 0
	while retries < 30 and (not is_instance_valid(GlobalRefs.current_zone) or not is_instance_valid(GlobalRefs.player_agent_body)):
		yield(get_tree().create_timer(0.1), "timeout")
		retries += 1

	if GameState.player_docked_at == "":
		return
	EventBus.emit_signal("player_docked", GameState.player_docked_at)
	
	
# --- Game State Setup ---
func _initialize_game_state():
	print("WorldManager: Initializing game state...")
	# This is where the logic for choosing "New Game" vs "Load Game" will go.
	# For now, we default to creating a new game.
	_setup_new_game()


func _show_boot_main_menu() -> void:
	# Pause the game at boot so no simulation/UI actions occur until New Game.
	get_tree().paused = true
	# Ask the MainMenu UI to show itself.
	if is_instance_valid(EventBus) and EventBus.has_signal("main_menu_requested"):
		EventBus.emit_signal("main_menu_requested")


func _setup_new_game():
	if is_instance_valid(_world_generator):
		_world_generator.queue_free()
		_world_generator = null
	# Instantiate and run the world generator to populate GameState.
	_world_generator = WorldGenerator.new()
	_world_generator.name = "WorldGenerator"
	add_child(_world_generator)
	_world_generator.generate_new_world()


func _cleanup_all_agents() -> void:
	for agent in _spawned_agent_bodies:
		if is_instance_valid(agent):
			agent.queue_free()
	_spawned_agent_bodies.clear()


func _cleanup_current_zone() -> void:
	"""Clean up the current zone and all its children properly."""
	if is_instance_valid(GameState.current_zone_instance):
		EventBus.emit_signal("zone_unloading", GameState.current_zone_instance)
		GameState.current_zone_instance.queue_free()
		GameState.current_zone_instance = null
	
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GlobalRefs.agent_container = null
	# Note: main_camera is NOT part of the zone - it's in main_game_scene, so don't clear it


func _reset_camera_input_state() -> void:
	# If the previous session ended while free-flight was active or the mouse was held,
	# the PlayerController may not get a clean state exit during cleanup.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(GlobalRefs.main_camera):
		if GlobalRefs.main_camera.has_method("set_rotation_input_active"):
			GlobalRefs.main_camera.set_rotation_input_active(false)
		if GlobalRefs.main_camera.has_method("set_is_rotating"):
			GlobalRefs.main_camera.set_is_rotating(false)


# --- Sector Loading ---
func load_sector(sector_id: String):
	var resolved_sector_id: String = _resolve_known_sector_id(sector_id, "load_sector")
	if resolved_sector_id == "":
		return

	_cleanup_all_agents()
	_cleanup_current_zone()
	yield(get_tree(), "idle_frame")

	if _sector_loader == null:
		_sector_loader = load("res://src/core/systems/sector_loader.gd").new()

	var zone_root: Spatial = _sector_loader.load_sector(resolved_sector_id)
	if zone_root == null:
		printerr("WM Error: SectorLoader returned null for: ", resolved_sector_id)
		return

	var zone_holder = get_parent().get_node_or_null(Constants.CURRENT_ZONE_CONTAINER_NAME)
	if not is_instance_valid(zone_holder):
		printerr("WM Error: Could not find valid zone holder node!")
		return

	zone_holder.add_child(zone_root)
	GameState.current_zone_instance = zone_root
	GlobalRefs.current_zone = zone_root

	var agent_container = zone_root.find_node(Constants.AGENT_CONTAINER_NAME, true, false)
	GlobalRefs.agent_container = agent_container

	GameState.current_sector_id = resolved_sector_id
	EventBus.emit_signal("zone_loaded", zone_root, resolved_sector_id, agent_container)


func travel_to_sector(target_sector_id: String) -> void:
	var resolved_target_sector_id: String = _resolve_known_sector_id(target_sector_id, "travel_to_sector")
	if resolved_target_sector_id == "":
		return
	if _jump_transition_active:
		return
	if _is_jump_transition_enabled():
		_jump_transition_active = true
		call_deferred("_run_jump_transition_sequence", resolved_target_sector_id)
		return
	_travel_to_sector_immediate(resolved_target_sector_id)


func is_jump_transition_active() -> bool:
	return _jump_transition_active


func _begin_jump_transition_foundation(source_sector_id: String, target_sector_id: String) -> void:
	var jump_transition_rig = _get_jump_transition_rig()
	if not is_instance_valid(jump_transition_rig):
		_reset_jump_transition_foundation()
		return
	if not _is_jump_transition_enabled():
		_reset_jump_transition_foundation()
		return
	_jump_transition_active = true
	if is_instance_valid(GlobalRefs.main_camera):
		_call_jump_transition_rig_method(
			jump_transition_rig,
			"capture_from_camera",
			[GlobalRefs.main_camera]
		)
	var departure_direction = _get_departure_direction_for_route(source_sector_id, target_sector_id)
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"begin_departure",
		[source_sector_id, target_sector_id, departure_direction]
	)


func _reset_jump_transition_foundation() -> void:
	_jump_transition_active = false
	var jump_transition_rig = _get_jump_transition_rig()
	_call_jump_transition_rig_method(jump_transition_rig, "reset_transition_state")
	_jump_transition_mouse_mode_before_lock = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(GlobalRefs.main_camera):
		if GlobalRefs.main_camera.has_method("clear_temporary_fov_override"):
			GlobalRefs.main_camera.clear_temporary_fov_override()
		GlobalRefs.main_camera.current = true


func _run_jump_transition_sequence(target_sector_id: String) -> void:
	var resolved_target_sector_id: String = _resolve_known_sector_id(target_sector_id, "_run_jump_transition_sequence")
	if resolved_target_sector_id == "":
		_reset_jump_transition_foundation()
		return
	var old_sector = _resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
	var jump_transition_rig = _get_jump_transition_rig()
	_begin_jump_transition_foundation(old_sector, resolved_target_sector_id)
	if not _jump_transition_active:
		_travel_to_sector_immediate(resolved_target_sector_id)
		return
	var departure_direction = _get_departure_direction_for_route(old_sector, resolved_target_sector_id)
	var departure_visuals_state = _prepare_jump_transition_departure_visuals(departure_direction)
	if departure_visuals_state is GDScriptFunctionState:
		yield(departure_visuals_state, "completed")
	_pause_jump_transition_gameplay()
	_call_jump_transition_rig_method(jump_transition_rig, "begin_departure_overlay_window")
	var fov_override_state = _animate_main_camera_fov_override(
		Constants.JUMP_TRANSITION_TARGET_FOV_DEG,
		Constants.JUMP_TRANSITION_FOV_DURATION_SEC
	)
	if fov_override_state is GDScriptFunctionState:
		yield(fov_override_state, "completed")
	_prepare_sector_travel_state(resolved_target_sector_id, old_sector)
	_cleanup_all_agents()
	_cleanup_current_zone()
	yield(get_tree(), "idle_frame")
	var route_distance = _get_jump_transition_route_distance(old_sector, resolved_target_sector_id)
	var cruise_speed = _get_jump_transition_cruise_speed(route_distance)
	var route_timeout_sec = _get_jump_transition_route_timeout_sec(route_distance, cruise_speed)
	if not is_instance_valid(jump_transition_rig):
		jump_transition_rig = _get_jump_transition_rig()
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"set_transition_fov",
		[Constants.JUMP_TRANSITION_TARGET_FOV_DEG]
	)
	if _jump_transition_rig_supports_method(jump_transition_rig, "begin_cruise"):
		_call_jump_transition_rig_method(jump_transition_rig, "begin_cruise", [cruise_speed])
		_call_jump_transition_rig_method(
			jump_transition_rig,
			"set_transition_particles_active",
			[true, true]
		)
		_call_jump_transition_rig_method(jump_transition_rig, "on_departure_cruise_entered")
		var cruise_velocity_state = _wait_for_rig_velocity(
			jump_transition_rig,
			cruise_speed,
			Constants.JUMP_TRANSITION_VELOCITY_TOLERANCE,
			Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC
		)
		if cruise_velocity_state is GDScriptFunctionState:
			yield(cruise_velocity_state, "completed")
		var route_completion_state = _wait_for_rig_route_completion(jump_transition_rig, route_timeout_sec)
		if route_completion_state is GDScriptFunctionState:
			yield(route_completion_state, "completed")
		var route_complete = bool(
			_call_jump_transition_rig_method(
				jump_transition_rig,
				"is_route_complete",
				[],
				true
			)
		)
		if not route_complete and _jump_transition_rig_supports_method(jump_transition_rig, "begin_arrival"):
			_call_jump_transition_rig_method(jump_transition_rig, "begin_arrival")
			var arrival_velocity_state = _wait_for_rig_velocity(
				jump_transition_rig,
				0.0,
				Constants.JUMP_TRANSITION_VELOCITY_TOLERANCE,
				Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC
			)
			if arrival_velocity_state is GDScriptFunctionState:
				yield(arrival_velocity_state, "completed")
	load_sector(resolved_target_sector_id)
	yield(get_tree(), "idle_frame")
	var player_ready_state = _wait_for_player_and_zone_ready(Constants.JUMP_TRANSITION_LOAD_TIMEOUT_SEC)
	if player_ready_state is GDScriptFunctionState:
		yield(player_ready_state, "completed")
	_restore_gameplay_camera_at_transition_fov()
	var fov_restore_state = _animate_main_camera_fov_restore(Constants.JUMP_TRANSITION_FOV_DURATION_SEC)
	if fov_restore_state is GDScriptFunctionState:
		yield(fov_restore_state, "completed")
	_set_jump_transition_camera_locked(false)
	var hud_show_delay_state = _yield_real_time(Constants.JUMP_TRANSITION_HUD_SHOW_DELAY_SEC)
	if hud_show_delay_state is GDScriptFunctionState:
		yield(hud_show_delay_state, "completed")
	_set_main_hud_hidden(false)
	_restore_jump_transition_gameplay()
	_reset_jump_transition_foundation()
	_request_sector_travel_tick()


func _travel_to_sector_immediate(target_sector_id: String) -> void:
	_prepare_sector_travel_state(target_sector_id)
	load_sector(target_sector_id)
	_request_sector_travel_tick()


func _prepare_sector_travel_state(target_sector_id: String, old_sector_id: String = "") -> String:
	var old_sector = old_sector_id
	if old_sector == "":
		old_sector = _resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
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
		GameState.player_rotation = GlobalRefs.player_agent_body.rotation_degrees


func _pause_jump_transition_gameplay() -> void:
	_jump_transition_tree_was_paused = get_tree().paused
	_jump_transition_timer_was_running = is_instance_valid(_time_clock_timer) and not _time_clock_timer.is_stopped()
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.stop()
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_local_scene_particles_active"):
		GlobalRefs.main_camera.set_local_scene_particles_active(false, true)
	get_tree().paused = true


func _restore_jump_transition_gameplay() -> void:
	get_tree().paused = _jump_transition_tree_was_paused
	if _jump_transition_timer_was_running and is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_local_scene_particles_active"):
		GlobalRefs.main_camera.set_local_scene_particles_active(true, true)
	_jump_transition_tree_was_paused = false
	_jump_transition_timer_was_running = false


func _set_jump_transition_camera_locked(is_locked: bool) -> void:
	if is_locked:
		_jump_transition_mouse_mode_before_lock = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(_jump_transition_mouse_mode_before_lock)
	if not is_instance_valid(GlobalRefs.main_camera):
		return
	if GlobalRefs.main_camera.has_method("set_is_rotating"):
		GlobalRefs.main_camera.set_is_rotating(false)
	if GlobalRefs.main_camera.has_method("set_rotation_input_active"):
		GlobalRefs.main_camera.set_rotation_input_active(
			not is_locked and _jump_transition_mouse_mode_before_lock == Input.MOUSE_MODE_CAPTURED
		)


func _set_main_hud_hidden(is_hidden: bool) -> void:
	if is_instance_valid(GlobalRefs.main_hud):
		GlobalRefs.main_hud.visible = not is_hidden


func _restore_gameplay_camera_at_transition_fov() -> void:
	if not is_instance_valid(GlobalRefs.main_camera):
		return
	var jump_transition_rig = _get_jump_transition_rig()
	var transition_forward_direction = Vector3.ZERO
	var transition_forward_direction_value = _call_jump_transition_rig_method(
		jump_transition_rig,
		"get_transition_camera_forward_direction",
		[],
		Vector3.ZERO
	)
	if transition_forward_direction_value is Vector3:
		transition_forward_direction = transition_forward_direction_value
	_call_jump_transition_rig_method(jump_transition_rig, "deactivate_transition_view")
	_call_jump_transition_rig_method(
		jump_transition_rig,
		"set_transition_particles_active",
		[false, true]
	)
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
	if GlobalRefs.main_camera.has_method("set_temporary_fov_override"):
		GlobalRefs.main_camera.set_temporary_fov_override(Constants.JUMP_TRANSITION_TARGET_FOV_DEG)
	GlobalRefs.main_camera.current = true


func _prepare_jump_transition_departure_visuals(departure_direction: Vector3):
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_orbit_forward_direction"):
		GlobalRefs.main_camera.set_orbit_forward_direction(departure_direction)
	var camera_aim_state = _yield_real_time(Constants.JUMP_TRANSITION_CAMERA_AIM_DURATION_SEC)
	if camera_aim_state is GDScriptFunctionState:
		yield(camera_aim_state, "completed")
	var jump_transition_rig = _get_jump_transition_rig()
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
	_set_jump_transition_camera_locked(true)
	_set_main_hud_hidden(true)


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
		yield(get_tree(), "idle_frame")


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
		yield(get_tree(), "idle_frame")
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
		yield(get_tree(), "idle_frame")


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
		yield(get_tree(), "idle_frame")


func _wait_for_player_and_zone_ready(timeout_sec: float):
	var start_time_ms = OS.get_ticks_msec()
	var timeout_ms = max(int(timeout_sec * 1000.0), 1)
	while true:
		if is_instance_valid(GlobalRefs.current_zone) and is_instance_valid(GlobalRefs.player_agent_body):
			return true
		if OS.get_ticks_msec() - start_time_ms >= timeout_ms:
			return false
		yield(get_tree(), "idle_frame")


func _yield_real_time(duration_sec: float):
	if duration_sec <= 0.0:
		return
	var start_time_ms = OS.get_ticks_msec()
	var duration_ms = max(int(duration_sec * 1000.0), 1)
	while OS.get_ticks_msec() - start_time_ms < duration_ms:
		yield(get_tree(), "idle_frame")


func _get_jump_transition_route_distance(source_sector_id: String, target_sector_id: String) -> float:
	return _get_sector_global_position(source_sector_id).distance_to(_get_sector_global_position(target_sector_id))


func _get_jump_transition_cruise_speed(route_distance: float) -> float:
	if route_distance <= 0.0:
		return 0.0
	var effective_travel_window_sec = max(
		Constants.JUMP_TRANSITION_TRAVEL_DURATION_SEC - Constants.JUMP_TRANSITION_SPEED_RAMP_DURATION_SEC,
		0.1
	)
	return route_distance / effective_travel_window_sec


func _get_jump_transition_route_timeout_sec(route_distance: float, cruise_speed: float) -> float:
	if route_distance <= Constants.JUMP_TRANSITION_ROUTE_COMPLETION_TOLERANCE or cruise_speed <= 0.0:
		return Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC
	return Constants.JUMP_TRANSITION_TRAVEL_DURATION_SEC + Constants.JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC


func _request_sector_travel_tick() -> void:
	if is_instance_valid(GlobalRefs.simulation_engine):
		GlobalRefs.simulation_engine.request_tick()


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
	var scene_tree = get_tree()
	if scene_tree != null and is_instance_valid(scene_tree.current_scene):
		var scene_world_rendering = scene_tree.current_scene.get_node_or_null("WorldRendering")
		if is_instance_valid(scene_world_rendering):
			return scene_world_rendering
	if is_instance_valid(get_parent()):
		var parent_world_rendering = get_parent().get_node_or_null("WorldRendering")
		if is_instance_valid(parent_world_rendering):
			return parent_world_rendering
	return null


func _is_jump_transition_enabled() -> bool:
	var world_rendering = _get_world_rendering_node()
	if not is_instance_valid(world_rendering):
		return false
	return bool(world_rendering.get("jump_transition_enabled"))


func _get_jump_transition_rig() -> Node:
	if is_instance_valid(get_parent()):
		return get_parent().get_node_or_null(Constants.JUMP_TRANSITION_RIG_NODE_NAME)
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


func _resolve_known_sector_id(requested_sector_id: String, context: String) -> String:
	if requested_sector_id != "" and GameState.world_topology.has(requested_sector_id):
		return requested_sector_id

	_report_invalid_sector(context, requested_sector_id)

	if Constants.INITIAL_SECTOR_ID != "" and GameState.world_topology.has(Constants.INITIAL_SECTOR_ID):
		return Constants.INITIAL_SECTOR_ID
	if not GameState.world_topology.empty():
		return str(GameState.world_topology.keys()[0])

	printerr("WorldManager: No valid fallback sector available for %s." % context)
	return ""


func _report_invalid_sector(context: String, requested_sector_id: String) -> void:
	var normalized_sector_id: String = requested_sector_id if requested_sector_id != "" else "<empty>"
	var report_key = "%s:%s" % [context, normalized_sector_id]
	if _reported_invalid_sectors.has(report_key):
		return
	_reported_invalid_sectors[report_key] = true
	printerr(
		"WorldManager: Invalid sector reference for %s -> %s. Falling back to %s." % [
			context,
			normalized_sector_id,
			Constants.INITIAL_SECTOR_ID,
		]
	)


# --- Jump Signal Handlers ---
func _on_jump_available(target_sector_id, _name):
	_pending_jump_target = target_sector_id


func _on_jump_unavailable():
	_pending_jump_target = ""


func _on_player_jump_requested(target_sector_id):
	travel_to_sector(target_sector_id)


# --- Time System Driver ---
func _on_Time_Clock_Timer_timeout():
	# This function is now called every TIME_TICK_INTERVAL_SECONDS.
	# It drives the core time-based loop of the game.
	if is_instance_valid(GlobalRefs.time_system):
		# For now, each tick adds 1 second.
		GlobalRefs.time_system.advance_game_time(1)
	else:
		printerr("WorldManager: Cannot advance time, TimeSystem not registered in GlobalRefs.")


# --- Signal Handlers to maintain agent list ---
func _on_Agent_Spawned(agent_body, _init_data):
	if not _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.append(agent_body)


func _on_Agent_Despawning(agent_body):
	if _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.erase(agent_body)


func get_agent_by_uid(agent_uid: int):
	for agent_body in _spawned_agent_bodies:
		if not is_instance_valid(agent_body):
			continue
		if agent_body.get("agent_uid") != null and int(agent_body.get("agent_uid")) == agent_uid:
			return agent_body
	return null


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.world_manager == self:
			GlobalRefs.world_manager = null
		if EventBus.is_connected("agent_spawned", self, "_on_Agent_Spawned"):
			EventBus.disconnect("agent_spawned", self, "_on_Agent_Spawned")
		if EventBus.is_connected("agent_despawning", self, "_on_Agent_Despawning"):
			EventBus.disconnect("agent_despawning", self, "_on_Agent_Despawning")
		if EventBus.is_connected("player_jump_requested", self, "_on_player_jump_requested"):
			EventBus.disconnect("player_jump_requested", self, "_on_player_jump_requested")
		if EventBus.is_connected("jump_available", self, "_on_jump_available"):
			EventBus.disconnect("jump_available", self, "_on_jump_available")
		if EventBus.is_connected("jump_unavailable", self, "_on_jump_unavailable"):
			EventBus.disconnect("jump_unavailable", self, "_on_jump_unavailable")
		_reset_jump_transition_foundation()
