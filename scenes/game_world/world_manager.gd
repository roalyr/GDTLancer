# File: scenes/game_world/world_manager.gd
# Version: 3.0 (Refactored) - Handles zone management only. Agent spawning is delegated.

extends Node

# --- State ---
var current_zone_instance: Node = null
var _spawned_agent_bodies = []  # This list can now be managed by a future system if needed.


# --- Initialization ---
func _ready():
	GlobalRefs.world_manager = self
	# Connect to agent signals to keep the local list clean.
	EventBus.connect("agent_spawned", self, "_on_Agent_Spawned")
	EventBus.connect("agent_despawning", self, "_on_Agent_Despawning")

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
