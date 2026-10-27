# WorldManager: new game / load flow, sector loading and jump orchestration.

extends Node

## WorldManager: Core scene orchestrator handling game initialization, zone loading, and save/load flow.
## Coordinates TemplateIndexer, WorldGenerator, AgentSpawner and JumpOrchestrator.

# --- Component Scripts ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")
const JumpOrchestrator = preload("res://src/scenes/game_world/world_manager/jump_orchestrator.gd")

# --- State ---
var _spawned_agent_bodies = []
var _sector_loader = null
var _pending_jump_target: String = ""
var _reported_invalid_sectors: Dictionary = {}
var _jump_transition_active: bool = false
var _respawning: bool = false
var _world_serial: int = 0  # Bumped by a new game or a load: a respawn under way for the old world is dropped
var _jump_transition_tree_was_paused: bool = false
var _jump_transition_mouse_mode_before_lock: int = Input.MOUSE_MODE_VISIBLE
var _recorded_fov: float = 70.0
var _recorded_zoom_level: float = 0.5

# --- Subsystems ---
var jump_orchestrator: Reference = null

# --- Nodes ---
var _template_indexer: Node = null
var _world_generator: Node = null

# --- Initialization ---
func _init():
	jump_orchestrator = JumpOrchestrator.new()
	jump_orchestrator.initialize(self)


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
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")
	EventBus.connect("jump_available", self, "_on_jump_available")
	EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")

	randomize()
	# Do not load a zone at boot; wait for New Game / Load.


func _on_new_game_requested() -> void:
	_world_serial += 1
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	_reset_jump_transition_foundation()
	_set_main_hud_hidden(false)
	# Leaving the Main Menu; resume gameplay.
	get_tree().paused = false

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("reset_to_defaults"):
		GameStateManager.reset_to_defaults()
	else:
		printerr("WorldManager: GameStateManager.reset_to_defaults() unavailable.")
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")
	
	_setup_new_game()
	load_sector(Constants.INITIAL_SECTOR_ID)
	call_deferred("_emit_loaded_dock_signal")  # A run starts docked at its home port


func _on_game_state_loaded() -> void:
	_world_serial += 1
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	_reset_jump_transition_foundation()
	_set_main_hud_hidden(false)
	# A saved state has been applied; we now need to load a zone so AgentSpawner can
	# spawn the player from the restored GameState.
	get_tree().paused = false

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")

	var saved_sector = _resolve_known_sector_id(GameState.current_sector_id, "GameState.current_sector_id")
	GameState.current_sector_id = saved_sector
	load_sector(saved_sector)
	call_deferred("_emit_loaded_dock_signal")


# The player's ship is lost: after RESPAWN_DELAY s watching the wreck the screen fades to black,
# they wake docked at home in the start's ship (GameStateManager.lose_ship), the game saves over the
# old ship, and the screen fades back.
func _on_agent_disabled(agent_body) -> void:
	if _respawning or not is_instance_valid(agent_body) or agent_body != GlobalRefs.player_agent_body:
		return
	_respawning = true
	var serial: int = _world_serial
	yield(get_tree().create_timer(Constants.RESPAWN_DELAY), "timeout")
	if serial != _world_serial:  # A new game or a load came first
		_respawning = false
		return
	var fade_state = _fade_transition_overlay(1.0, Constants.RESPAWN_FADE_DURATION)
	if fade_state is GDScriptFunctionState:
		yield(fade_state, "completed")
	GameStateManager.lose_ship()
	_reset_camera_input_state()
	_cleanup_all_agents()
	_cleanup_current_zone()
	yield(get_tree(), "idle_frame")
	load_sector(GameState.current_sector_id)
	var dock_state = _emit_loaded_dock_signal()
	if dock_state is GDScriptFunctionState:
		yield(dock_state, "completed")
	GameStateManager.save_game(0)
	EventBus.emit_signal("announcement", "Back home in a new ship. The bank and storage are kept: %d WP" % GameState.player_bank, "info")
	_respawning = false
	_fade_transition_overlay_async(0.0, Constants.RESPAWN_FADE_DURATION)


func _emit_loaded_dock_signal() -> void:
	var retries := 0
	while retries < 30 and (not is_instance_valid(GlobalRefs.current_zone) or not is_instance_valid(GlobalRefs.player_agent_body)):
		yield(get_tree().create_timer(0.1), "timeout")
		retries += 1

	if GameState.player_docked_at == "":
		return
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == GameState.player_docked_at:
			EventBus.emit_signal("player_docked", GameState.player_docked_at)
			return
	GameState.player_docked_at = ""  # Docked at a station that is not in this sector: undocked
	
	
func _show_boot_main_menu() -> void:
	# Pause the game at boot so nothing runs until New Game.
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

	var zone_holder = get_parent().find_node(Constants.CURRENT_ZONE_CONTAINER_NAME, true, false)  # Inside the world viewport
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
	if jump_orchestrator:
		jump_orchestrator.travel_to_sector(target_sector_id)


func is_jump_transition_active() -> bool:
	if jump_orchestrator:
		return jump_orchestrator.is_jump_transition_active()
	return false


func _begin_jump_transition_foundation(source_sector_id: String, target_sector_id: String) -> void:
	if jump_orchestrator:
		jump_orchestrator._begin_jump_transition_foundation(source_sector_id, target_sector_id)


func _reset_jump_transition_foundation() -> void:
	if jump_orchestrator:
		jump_orchestrator._reset_jump_transition_foundation()


func _run_jump_transition_sequence(target_sector_id: String):
	if jump_orchestrator:
		return jump_orchestrator._run_jump_transition_sequence(target_sector_id)


func _travel_to_sector_immediate(target_sector_id: String) -> void:
	if jump_orchestrator:
		jump_orchestrator._travel_to_sector_immediate(target_sector_id)


func _prepare_sector_travel_state(target_sector_id: String, old_sector_id: String = "") -> String:
	if jump_orchestrator:
		return jump_orchestrator._prepare_sector_travel_state(target_sector_id, old_sector_id)
	return ""


func _snapshot_player_state_for_sector_travel() -> void:
	# Clear saved-position priority so sector travel always uses the arrival shell or jump point.
	GameState.player_position = Vector3.ZERO
	if is_instance_valid(GlobalRefs.player_agent_body):
		GameState.player_rotation = GlobalRefs.player_agent_body.rotation_degrees


func _pause_jump_transition_gameplay() -> void:
	_jump_transition_tree_was_paused = get_tree().paused
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_local_scene_particles_active"):
		GlobalRefs.main_camera.set_local_scene_particles_active(false, true)
	get_tree().paused = true


func _restore_jump_transition_gameplay() -> void:
	get_tree().paused = _jump_transition_tree_was_paused
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera.has_method("set_local_scene_particles_active"):
		GlobalRefs.main_camera.set_local_scene_particles_active(true, true)
	_jump_transition_tree_was_paused = false


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
	if jump_orchestrator:
		jump_orchestrator._restore_gameplay_camera_at_transition_fov()


func _restore_gameplay_camera_at_recorded_state() -> void:
	if jump_orchestrator:
		jump_orchestrator._restore_gameplay_camera_at_recorded_state()


func _fade_transition_overlay(target_alpha: float, duration: float):
	if jump_orchestrator:
		return jump_orchestrator._fade_transition_overlay(target_alpha, duration)


func _fade_transition_overlay_async(target_alpha: float, duration: float) -> void:
	if jump_orchestrator:
		jump_orchestrator._fade_transition_overlay_async(target_alpha, duration)


func _prepare_jump_transition_departure_visuals(departure_direction: Vector3):
	if jump_orchestrator:
		return jump_orchestrator._prepare_jump_transition_departure_visuals(departure_direction)


func _yield_real_time(duration_sec: float):
	if jump_orchestrator:
		return jump_orchestrator._yield_real_time(duration_sec)


func _wait_for_player_and_zone_ready(timeout_sec: float):
	if jump_orchestrator:
		return jump_orchestrator._wait_for_player_and_zone_ready(timeout_sec)


func _get_departure_direction_for_route(source_sector_id: String, target_sector_id: String) -> Vector3:
	if jump_orchestrator:
		return jump_orchestrator._get_departure_direction_for_route(source_sector_id, target_sector_id)
	return Vector3.ZERO


func _get_arrival_direction_for_route(source_sector_id: String, target_sector_id: String) -> Vector3:
	if jump_orchestrator:
		return jump_orchestrator._get_arrival_direction_for_route(source_sector_id, target_sector_id)
	return Vector3.ZERO


func _get_sector_global_position(sector_id: String) -> Vector3:
	if jump_orchestrator:
		return jump_orchestrator._get_sector_global_position(sector_id)
	return Vector3.ZERO


func _get_jump_transition_rig() -> Node:
	if jump_orchestrator:
		return jump_orchestrator._get_jump_transition_rig()
	return null


func _resolve_known_sector_id(requested_sector_id: String, context: String) -> String:
	if TemplateDatabase.has_sector(requested_sector_id):
		return requested_sector_id

	_report_invalid_sector(context, requested_sector_id)

	if TemplateDatabase.has_sector(Constants.INITIAL_SECTOR_ID):
		return Constants.INITIAL_SECTOR_ID
	if not TemplateDatabase.locations.empty():
		return str(TemplateDatabase.locations.keys()[0])

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
