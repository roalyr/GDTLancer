# File: scenes/game_world/world_manager.gd
# Version: 3.1 - Added a timer to drive the global TimeSystem.

extends Node

# --- State ---
var current_zone_instance: Node = null
var _spawned_agent_bodies = []

# --- Nodes ---
var _time_clock_timer: Timer = null


# --- Initialization ---
func _ready():
	GlobalRefs.set_world_manager(self)
	
	# Connect to agent signals to keep the local list clean.
	EventBus.connect("agent_spawned", self, "_on_Agent_Spawned")
	EventBus.connect("agent_despawning", self, "_on_Agent_Despawning")

	# --- NEW: Setup the Time Clock Timer ---
	_time_clock_timer = Timer.new()
	_time_clock_timer.name = "TimeClockTimer"
	_time_clock_timer.wait_time = Constants.TIME_TICK_INTERVAL_SECONDS
	_time_clock_timer.autostart = true
	_time_clock_timer.connect("timeout", self, "_on_Time_Clock_Timer_timeout")
	add_child(_time_clock_timer)
	# --- END NEW ---
	
	randomize()
	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)


# --- Zone Management ---
func load_zone(zone_scene_path: String):
	if not zone_scene_path or zone_scene_path.empty():
		printerr("WM Error: Invalid zone path provided.")
		return

	# 1. Cleanup Previous Zone
	if is_instance_valid(current_zone_instance):
		EventBus.emit_signal("zone_unloading", current_zone_instance)
		# Clear references that will be repopulated on new zone load
		_spawned_agent_bodies.clear()
		GlobalRefs.player_agent_body = null
		GlobalRefs.current_zone = null
		GlobalRefs.agent_container = null
		current_zone_instance.queue_free()
		current_zone_instance = null

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

	current_zone_instance = zone_scene.instance()
	zone_holder.add_child(current_zone_instance)
	GlobalRefs.current_zone = current_zone_instance

	# 4. Find Agent Container and emit signal that the zone is ready
	var agent_container = current_zone_instance.find_node(
		Constants.AGENT_CONTAINER_NAME, true, false
	)
	GlobalRefs.agent_container = agent_container

	EventBus.emit_signal("zone_loaded", current_zone_instance, zone_scene_path, agent_container)


# --- Time System Driver ---
func _on_Time_Clock_Timer_timeout():
	# This function is now called every TIME_TICK_INTERVAL_SECONDS.
	# It drives the core time-based loop of the game.
	if is_instance_valid(GlobalRefs.time_system):
		# For now, each tick adds 1 TU. This can be modified later (e.g., based on game speed).
		GlobalRefs.time_system.add_time_units(1)
		#print(GlobalRefs.time_system._current_tu)
	else:
		printerr("WorldManager: Cannot advance time, TimeSystem not registered in GlobalRefs.")


# --- Signal Handlers to maintain agent list ---
func _on_Agent_Spawned(agent_body, _init_data):
	if not _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.append(agent_body)


func _on_Agent_Despawning(agent_body):
	if _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.erase(agent_body)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.world_manager == self:
			GlobalRefs.world_manager = null
		if EventBus.is_connected("agent_spawned", self, "_on_Agent_Spawned"):
			EventBus.disconnect("agent_spawned", self, "_on_Agent_Spawned")
		if EventBus.is_connected("agent_despawning", self, "_on_Agent_Despawning"):
			EventBus.disconnect("agent_despawning", self, "_on_Agent_Despawning")
