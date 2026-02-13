#
# PROJECT: GDTLancer
# MODULE: world_manager.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Node

## WorldManager: Core scene orchestrator handling game initialization, zone loading, and save/load flow.
## Coordinates TemplateIndexer, WorldGenerator, and AgentSpawner for game lifecycle.

# --- Component Scripts ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")

# --- State ---
var _spawned_agent_bodies = []

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

	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)
	
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()


func _on_game_state_loaded() -> void:
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
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

	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)
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


# --- Zone Management ---
func load_zone(zone_scene_path: String):
	if not zone_scene_path or zone_scene_path.empty():
		printerr("WM Error: Invalid zone path provided.")
		return

	# 1. Cleanup Previous Zone (if not already cleaned up)
	if is_instance_valid(GameState.current_zone_instance):
		_cleanup_current_zone()
		yield(get_tree(), "idle_frame")

	# 2. Find Parent Container Node
	var zone_holder = get_parent().get_node_or_null(Constants.CURRENT_ZONE_CONTAINER_NAME)
	if not is_instance_valid(zone_holder):
		printerr("WM Error: Could not find valid zone holder node!")
		return

	# 3. Load and Instance the Zone Scene
	var zone_scene = load(zone_scene_path)
	if not zone_scene:
		printerr("WM Error: Failed to load Zone Scene Resource: ", zone_scene_path)
		return

	GameState.current_zone_instance = zone_scene.instance()
	zone_holder.add_child(GameState.current_zone_instance)
	GlobalRefs.current_zone = GameState.current_zone_instance

	# 4. Find Agent Container and emit signal that the zone is ready
	var agent_container = GameState.current_zone_instance.find_node(
		Constants.AGENT_CONTAINER_NAME, true, false
	)
	GlobalRefs.agent_container = agent_container

	EventBus.emit_signal("zone_loaded", GameState.current_zone_instance, zone_scene_path, agent_container)


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
