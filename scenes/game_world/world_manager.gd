# File: scenes/game_world/world_manager.gd
# Version 1.23 - Fixed 'has()' check, expanded all if/else, uses Tabs

extends Node

# --- NodePaths ---
const ACTIVE_MODULE_CONTAINER_PATH = "../" + Constants.CURRENT_ZONE_CONTAINER_NAME

# --- State ---
var current_zone_instance: Node = null
var _spawned_agent_bodies = []
var _player_agent_body: KinematicBody = null

# --- Initialization ---
func _ready():
	GlobalRefs.world_manager = self
	if EventBus:
		var err1 = EventBus.connect("agent_reached_destination", self, "_on_Agent_Reached_Destination")
		var err2 = EventBus.connect("agent_despawning", self, "_on_Agent_Despawning")
		var err3 = EventBus.connect("zone_loaded", self, "_on_Zone_Loaded_WorldManager")
		# Expanded check
		if err1 != OK or err2 != OK or err3 != OK:
			printerr("WM _ready Error: Failed to connect to required EventBus signals!")
	else:
		printerr("WM _ready Error: EventBus not available!")

	randomize()
	print("WM: 1/13 - _ready started.")
	print("WM _ready Debug: Checking Constant value...")
	print("- Constants.INITIAL_ZONE_SCENE_PATH = '", Constants.INITIAL_ZONE_SCENE_PATH, "'")
	print("- Type = ", typeof(Constants.INITIAL_ZONE_SCENE_PATH))

	print("WM: 2/13 - Attempting load_zone...")
	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)
	print("WM: 9/13 - Returned from initial load_zone call.")
	print("WM: 10/13 - _ready finished (Player spawn handled by signal).")


# --- Zone Management ---
func load_zone(zone_scene_path: String):
	print("WM: 3/13 - load_zone starting for path: ", zone_scene_path)

	if not zone_scene_path or zone_scene_path.empty():
		printerr("WM Error: Invalid zone path provided.")
		return

	# 1. Cleanup Previous Zone
	if is_instance_valid(current_zone_instance):
		EventBus.emit_signal("zone_unloading", current_zone_instance)
		_spawned_agent_bodies.clear()
		_player_agent_body = null
		GlobalRefs.player_agent_body = null
		GlobalRefs.current_zone = null
		GlobalRefs.agent_container = null
		current_zone_instance.queue_free()
		current_zone_instance = null

	# 2. Find Parent Container Node
	var parent_node = get_parent()
	if not is_instance_valid(parent_node):
		printerr("WM Error: Could not get valid parent node!")
		return
	var zone_holder = parent_node.get_node_or_null(Constants.CURRENT_ZONE_CONTAINER_NAME)

	if not zone_holder:
		printerr("WM Error: Node '", Constants.CURRENT_ZONE_CONTAINER_NAME, "' missing as child of parent '", parent_node.name, "'")
		return # Exit if holder not found
	print("WM: 4/13 - Found zone holder: ", zone_holder.name)

	# 3. Load and Instance the Zone Scene
	var zone_scene = load(zone_scene_path)
	if not zone_scene:
		printerr("WM Error: Failed load Zone Scene Resource: ", zone_scene_path)
		return

	current_zone_instance = zone_scene.instance()
	if not current_zone_instance:
		printerr("WM Error: Failed instance Zone Scene: ", zone_scene_path)
		return

	print("WM: 5/13 - Instanced Zone Scene: ", current_zone_instance.name)

	# 4. Add Zone to Tree & Update GlobalRefs for Zone
	zone_holder.add_child(current_zone_instance)
	GlobalRefs.current_zone = current_zone_instance

	# 5. Find Agent Container *within* the Zone & Update GlobalRef
	if not is_instance_valid(current_zone_instance):
		printerr("WM Error: current_zone_instance invalid after add_child?")
		return

	var agent_cont_ref = current_zone_instance.find_node(Constants.AGENT_CONTAINER_NAME, true, false)
	GlobalRefs.agent_container = agent_cont_ref
	print("WM: 6/13 - Found Agent Container: ", agent_cont_ref)
	if not agent_cont_ref:
		printerr("WM Warning: Agent container '", Constants.AGENT_CONTAINER_NAME, "' not found in zone.")

	# 6. Emit Loaded Signal
	print("WM: 7/13 - Emitting zone_loaded signal.")
	EventBus.emit_signal("zone_loaded", current_zone_instance, zone_scene_path, GlobalRefs.agent_container)
	print("WM: 8/13 - load_zone finished.")


# --- Agent Spawning & Management ---

# Called by handler for zone_loaded signal
func spawn_player():
	print("WM: 12/13 - spawn_player called.")
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("WM spawn_player Error: GlobalRefs.agent_container invalid.")
		return

	var player_template = load(Constants.PLAYER_DEFAULT_TEMPLATE_PATH)
	if not player_template is AgentTemplate:
		printerr("WM Error: Failed load Player AgentTemplate")
		return

	var player_spawn_pos = Vector3.ZERO
	var env_instance = GlobalRefs.current_zone
	if is_instance_valid(env_instance):
		var entry_node = null
		if Constants.ENTRY_POINT_NAMES.size() > 0:
			entry_node = env_instance.find_node(Constants.ENTRY_POINT_NAMES[0], true, false)
		# Expanded if
		if entry_node is Spatial:
			player_spawn_pos = entry_node.global_transform.origin + Vector3(0,5,15)

	var player_overrides = { "name": "PlayerShip", "faction": "Player" }
	_player_agent_body = spawn_agent(Constants.PLAYER_AGENT_SCENE_PATH, player_spawn_pos, player_template, player_overrides)

	if is_instance_valid(_player_agent_body):
		GlobalRefs.player_agent_body = _player_agent_body
		EventBus.emit_signal("camera_set_target_requested", _player_agent_body)
		EventBus.emit_signal("player_spawned", _player_agent_body)
	else:
		printerr("WorldManager Error: Failed to spawn player agent body!")
	print("WM: 13/13 - spawn_player finished.")


# Generic function CALLED BY EXTERNAL systems
func spawn_agent(agent_scene_path: String, position: Vector3, agent_template: Resource, overrides: Dictionary = {}) -> KinematicBody:
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("WM Spawn Error: Invalid GlobalRefs.agent_container.")
		return null
	if not agent_template is AgentTemplate:
		printerr("WM Spawn Error: Invalid AgentTemplate Resource.")
		return null
	if not agent_scene_path or agent_scene_path.empty():
		printerr("WM Spawn Error: Invalid scene path.")
		return null

	var agent_scene = load(agent_scene_path)
	if not agent_scene:
		printerr("WM Spawn Error: Failed load agent scene: ", agent_scene_path)
		return null
	var agent_root_instance = agent_scene.instance()
	if not agent_root_instance:
		printerr("WM Spawn Error: Failed instance agent scene!")
		return null

	var agent_node = agent_root_instance.get_node_or_null(Constants.AGENT_BODY_NODE_NAME)
	if not agent_node or not agent_node is KinematicBody:
		var error_msg = str("WM Spawn Error: Invalid node '", Constants.AGENT_BODY_NODE_NAME, "' in scene: ", agent_scene_path)
		printerr(error_msg)
		agent_root_instance.queue_free()
		return null

	var instance_name = overrides.get("name", agent_template.default_agent_name + "_" + str(agent_root_instance.get_instance_id()))
	agent_root_instance.name = instance_name

	container.add_child(agent_root_instance)
	agent_node.global_transform.origin = position

	if agent_node.has_method("initialize"):
		agent_node.initialize(agent_template, overrides)
	# Removed else print warning, initialize check is sufficient

	_spawned_agent_bodies.append(agent_node)
	# *** Fixed name check and expanded if/else ***
	var name_to_print = instance_name # Default to instance name
	if "agent_name" in agent_node: # Check if property exists
		name_to_print = agent_node.agent_name # Use script variable if available
	print("Spawned agent '", name_to_print, "' core node.")
	# *** End Fix ***
	EventBus.emit_signal("agent_spawned", agent_node, {"template": agent_template, "overrides": overrides})

	var controller = agent_node.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME) # Or PLAYER_INPUT_HANDLER_NAME
	if controller and controller.has_method("initialize"):
		controller.initialize(overrides)
	elif controller and controller.has_method("set_target") and overrides.has("initial_target"):
		controller.set_target(overrides.initial_target)

	return agent_node


# --- Signal Handlers ---
func _on_Agent_Reached_Destination(agent_body):
	if is_instance_valid(agent_body):
		if agent_body.has_method("despawn"):
			agent_body.despawn()
		else:
			agent_body.queue_free() # Fallback

func _on_Agent_Despawning(agent_body):
	call_deferred("_cleanup_despawned_agent_from_list", agent_body)

func _cleanup_despawned_agent_from_list(agent_instance):
	if _spawned_agent_bodies.has(agent_instance):
		_spawned_agent_bodies.erase(agent_instance)
	# Expanded if
	if _player_agent_body == agent_instance:
		print("Player agent reference cleared during cleanup.")
		_player_agent_body = null
		GlobalRefs.player_agent_body = null

# Handles zone_loaded signal - triggers player spawn IF needed
func _on_Zone_Loaded_WorldManager(_zone_instance, _zone_path, agent_container_node):
	print("WM: 11/13 - Reacting to zone_loaded signal.")
	if is_instance_valid(agent_container_node):
		if not is_instance_valid(_player_agent_body):
			# Using direct call now based on testing? Keep deferred if issues arise.
			spawn_player()
	else:
		printerr("WM _on_Zone_Loaded Error: Agent container invalid. Cannot spawn player.")


# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# *** ADD THIS LINE ***
		print("!!! WM: RECEIVED NOTIFICATION_PREDELETE - Call Stack: ---")
		print_stack() # Print the function call history
		print("--- End Call Stack ---")
		# *** END ADDED LINE ***

		# Disconnect from EventBus signals
		if EventBus:
			if EventBus.is_connected("agent_reached_destination", self, "_on_Agent_Reached_Destination"):
				EventBus.disconnect("agent_reached_destination", self, "_on_Agent_Reached_Destination")
			if EventBus.is_connected("agent_despawning", self, "_on_Agent_Despawning"):
				EventBus.disconnect("agent_despawning", self, "_on_Agent_Despawning")
			if EventBus.is_connected("zone_loaded", self, "_on_Zone_Loaded_WorldManager"):
				EventBus.disconnect("zone_loaded", self, "_on_Zone_Loaded_WorldManager")
		# Clear global ref
		if GlobalRefs and GlobalRefs.world_manager == self:
			GlobalRefs.world_manager = null
		# Free current zone instance if valid
		if is_instance_valid(current_zone_instance):
			current_zone_instance.queue_free()
