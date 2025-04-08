# File: scenes/game_world/world_manager.gd
# Attach to a Node named "WorldManager" in main_game_scene.tscn
# Version 1.8 - Spawns Player, attaches camera, keeps NPC traffic

extends Node

# --- Constants ---
const NPC_AGENT_SCENE_PATH = "res://core/agents/npc_agent.tscn"
const PLAYER_AGENT_SCENE_PATH = "res://core/agents/player_agent.tscn"
const INITIAL_ZONE_SCENE_PATH = "res://modules/piloting/scenes/basic_flight_zone.tscn"
# Adjust NodePaths below based on your main_game_scene.tscn structure
const ZONE_CONTAINER_PATH = "../CurrentZoneContainer"
const CAMERA_PATH = "../OrbitCamera"
# Adjust Node Names below based on your scene contents
const AGENT_CONTAINER_NAME = "AgentContainer" # Node name inside zone scenes
const AGENT_BODY_NODE_NAME = "AgentBody"     # Node name inside agent scenes (the KinematicBody)
const AI_CONTROLLER_NODE_NAME = "AIController" # Node name inside npc_agent scene
# Define Entry Point node names within your zone scene
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"]

# --- Traffic Simulation Config ---
var max_npcs = 10
var spawn_interval = 2.0
var traffic_speed_multiplier = 0.2

# --- State ---
var current_zone_instance: Node = null
var agent_container: Node = null
var _npc_agent_scene: PackedScene = null
var _player_agent_scene: PackedScene = null
var _camera: Camera = null
var _spawned_agent_bodies = [] # Tracks ALL agent bodies (NPCs and Player)
var _player_agent_body: KinematicBody = null # Specific player reference
var _entry_point_nodes = []
var _spawn_timer: Timer = null
var _npc_counter = 0

# --- Initialization ---
func _ready():
	# Load agent scenes
	_npc_agent_scene = load(NPC_AGENT_SCENE_PATH)
	_player_agent_scene = load(PLAYER_AGENT_SCENE_PATH)
	if _npc_agent_scene == null or _player_agent_scene == null:
		printerr("WorldManager Error: Failed to load required Agent Scene(s).")
		return

	# Get camera reference
	_camera = get_node_or_null(CAMERA_PATH)
	if not _camera or not _camera.has_method("set_target_node"):
		printerr("WorldManager Error: Invalid Camera reference or camera missing set_target_node.")
		_camera = null

	# Setup Spawn Timer (for NPCs)
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	var timer_connect_error = _spawn_timer.connect("timeout", self, "_on_SpawnTimer_timeout")
	if timer_connect_error != OK:
	   printerr("WorldManager Error: Failed to connect spawn timer signal! Error code: ", timer_connect_error)
	add_child(_spawn_timer)

	randomize()

	# Load initial zone THEN spawn player and start NPC timer
	load_zone(INITIAL_ZONE_SCENE_PATH)
	if agent_container:
		call_deferred("spawn_player_and_start_traffic")
	else:
		printerr("WorldManager: Cannot proceed without valid zone/agent container.")


# --- Zone Management ---
func load_zone(zone_scene_path: String):
	# Clear previous zone data and disconnect signals
	if is_instance_valid(current_zone_instance):
		print("WorldManager: Unloading previous zone and agents...")
		_player_agent_body = null
		for agent_body in _spawned_agent_bodies:
			if is_instance_valid(agent_body) and agent_body.is_connected("agent_despawning", self, "_on_Agent_Despawned"):
				agent_body.disconnect("agent_despawning", self, "_on_Agent_Despawned")
		_spawned_agent_bodies.clear()
		_entry_point_nodes.clear()
		current_zone_instance.queue_free()
		current_zone_instance = null
		agent_container = null

	# Find the parent node to attach the zone scene to
	var zone_container_parent = get_node_or_null(ZONE_CONTAINER_PATH)
	if not zone_container_parent:
		printerr("WorldManager Error: Zone container parent node not found at path: ", ZONE_CONTAINER_PATH)
		return

	# Load and instance the new zone scene
	var zone_scene = load(zone_scene_path)
	if not zone_scene:
		printerr("WorldManager Error: Failed to load Zone Scene at: ", zone_scene_path)
		return
	current_zone_instance = zone_scene.instance()
	if not current_zone_instance:
		printerr("WorldManager Error: Failed to instance Zone Scene: ", zone_scene_path)
		return
	zone_container_parent.add_child(current_zone_instance)
	print("Loaded zone: ", zone_scene_path)

	# Find the container node within the zone where agents will be added
	agent_container = current_zone_instance.find_node(AGENT_CONTAINER_NAME, true, false)
	if not agent_container:
		printerr("WorldManager Error: Agent container node '", AGENT_CONTAINER_NAME, "' not found in zone '", current_zone_instance.name, "'")

	# Find entry point nodes within the zone
	_entry_point_nodes.clear()
	for point_name in ENTRY_POINT_NAMES:
		var entry_node = current_zone_instance.find_node(point_name, true, false)
		if entry_node is Spatial:
			_entry_point_nodes.append(entry_node)
		else:
			print("WorldManager Warning: Entry point '", point_name, "' not found or not Spatial in zone '", current_zone_instance.name, "'")

	# Check if enough entry points were found
	if _entry_point_nodes.size() < 2:
		printerr("WorldManager Error: Need at least 2 valid entry points defined in the zone for traffic!")
		if _spawn_timer: _spawn_timer.stop()


# Called deferred after zone load is complete
func spawn_player_and_start_traffic():
	if not agent_container: return

	print("Spawning player...")
	# Determine player spawn position
	var player_spawn_pos = Vector3.ZERO
	if _entry_point_nodes.size() > 0:
		player_spawn_pos = _entry_point_nodes[0].global_transform.origin + Vector3(0,5,15) # Offset slightly

	# Define player initial data
	var player_init_data = {
		"name": "PlayerShip", "faction": "Player",
		"max_move_speed": 60.0, "max_turn_speed": 2.5, # Example faster player speeds
		"acceleration": 12.0, "deceleration": 18.0
	}
	_player_agent_body = spawn_agent(_player_agent_scene, player_spawn_pos, player_init_data)

	# Store player in main list too and connect signal
	if is_instance_valid(_player_agent_body):
		_spawned_agent_bodies.append(_player_agent_body)
		if not _player_agent_body.is_connected("agent_despawning", self, "_on_Agent_Despawned"):
			var connect_error = _player_agent_body.connect("agent_despawning", self, "_on_Agent_Despawned")
			if connect_error != OK:
				printerr("WM Error: Failed connect player despawn signal! Code:", connect_error)

		# Set Camera Target to Player
		if _camera:
			print("Setting camera target to Player.")
			_camera.set_target_node(_player_agent_body)
		else:
			print("WorldManager Warning: Cannot set camera target, camera reference invalid.")
	else:
		printerr("WorldManager Error: Failed to spawn player agent body!")

	# Start NPC Spawning Timer
	if _spawn_timer and _entry_point_nodes.size() >= 2:
		print("Starting NPC spawn timer.")
		_spawn_timer.start()


# --- Agent Spawning & Management ---

# Called by timer to potentially spawn an NPC
func _on_SpawnTimer_timeout():
	# Check count excluding player (-1 if player exists)
	var current_npc_count = _spawned_agent_bodies.size()
	if is_instance_valid(_player_agent_body):
		current_npc_count -= 1

	if agent_container and current_npc_count < max_npcs and _entry_point_nodes.size() >= 2:
		spawn_traffic_npc()

# Spawns a single traffic NPC
func spawn_traffic_npc():
	# Select random spawn and destination points
	var spawn_point_node = _entry_point_nodes[randi() % _entry_point_nodes.size()]
	var destination_point_node = spawn_point_node
	var attempts = 0
	while destination_point_node == spawn_point_node and attempts < 10:
		destination_point_node = _entry_point_nodes[randi() % _entry_point_nodes.size()]
		attempts += 1
	if destination_point_node == spawn_point_node: return # Skip if points same

	var spawn_pos = spawn_point_node.global_transform.origin
	var destination_pos = destination_point_node.global_transform.origin

	# Prepare init data
	_npc_counter += 1
	var base_speed = 50.0; var base_turn_speed = 2.0 # TODO: Vary speeds?
	var init_data = {
		"name": "TrafficNPC_" + str(_npc_counter), "faction": "CivilianTraffic",
		"max_move_speed": base_speed * traffic_speed_multiplier,
		"max_turn_speed": base_turn_speed * traffic_speed_multiplier,
		"acceleration": 5.0 * traffic_speed_multiplier,
		"deceleration": 8.0 * traffic_speed_multiplier,
		"initial_target": destination_pos, "stopping_distance": 15.0
	}

	# Spawn agent and get reference to the AgentBody node
	var agent_body = spawn_agent(_npc_agent_scene, spawn_pos, init_data)

	# Store reference and connect signal if successful
	if is_instance_valid(agent_body):
		_spawned_agent_bodies.append(agent_body)
		if not agent_body.is_connected("agent_despawning", self, "_on_Agent_Despawned"):
			var connect_error = agent_body.connect("agent_despawning", self, "_on_Agent_Despawned")
			if connect_error != OK:
				printerr("WM Error: Failed to connect despawn signal for ", agent_body.name)
		# No initial camera target set here anymore


# Generic function to spawn an agent scene - Returns the AgentBody node or null
func spawn_agent(agent_scene: PackedScene, position: Vector3, init_data: Dictionary) -> KinematicBody:
	if not agent_container or not agent_scene:
		printerr("WorldManager Error: Cannot spawn agent - invalid container or scene resource.")
		return null
	var agent_root_instance = agent_scene.instance()
	if not agent_root_instance:
		printerr("WorldManager Error: Failed to instance agent scene!")
		return null

	var agent_node = agent_root_instance.get_node_or_null(AGENT_BODY_NODE_NAME)
	if not agent_node or not agent_node is KinematicBody:
		printerr("WorldManager Error: Could not find node '", AGENT_BODY_NODE_NAME, "' (KinematicBody) within the instanced agent scene!")
		agent_root_instance.queue_free()
		return null

	if init_data.has("name"):
			agent_root_instance.name = init_data.name # Name the root node (Spatial)

	agent_container.add_child(agent_root_instance)
	agent_node.global_transform.origin = position # Set position on the KinematicBody

	if agent_node.has_method("initialize"):
		agent_node.initialize(init_data)
	else:
		print("Warning: Agent node '", agent_node.name, "' does not have an initialize(data) method.")

	# Initialize AI controller if it exists
	var ai_controller = agent_node.get_node_or_null(AI_CONTROLLER_NODE_NAME)
	if ai_controller and ai_controller.has_method("initialize"):
		ai_controller.initialize(init_data)
	elif ai_controller and ai_controller.has_method("set_target") and init_data.has("initial_target"):
		ai_controller.set_target(init_data.initial_target)

	# TODO: Add similar logic for Player controller node if it needs initialization

	print("Spawned agent '", init_data.get("name", "Unnamed"), "' core node at ", position)
	return agent_node # Return the KinematicBody


# --- Signal Handlers ---

# Handles agent_despawning signal from ALL Agent nodes
func _on_Agent_Despawned(agent_instance):
	print("WorldManager received despawn signal from: ", agent_instance.name if is_instance_valid(agent_instance) else "<invalid>")
	call_deferred("_cleanup_despawned_agent", agent_instance)

# Performs cleanup after agent despawn signal
func _cleanup_despawned_agent(agent_instance):
	# Remove from main tracking list
	var found_index = -1
	for i in _spawned_agent_bodies.size():
		if _spawned_agent_bodies[i] == agent_instance:
			found_index = i
			break
	if found_index != -1:
		_spawned_agent_bodies.remove(found_index)
		print("Removed ", agent_instance.name if is_instance_valid(agent_instance) else "<freed agent>", " from tracked list.")
	else:
		print("Warning: Despawned agent not found in list during cleanup.")

	# Clear player reference if it was the player
	if _player_agent_body == agent_instance:
		print("Player agent despawned.")
		_player_agent_body = null

	# Clear camera target if it was the despawned agent
	var current_cam_target = null
	if _camera and _camera.has_method("get_current_target"):
		current_cam_target = _camera.get_current_target()

	if is_instance_valid(current_cam_target) and current_cam_target == agent_instance:
		print("Camera target despawned. Clearing target.")
		if _camera.has_method("set_target_node"):
			_camera.set_target_node(null) # Just clear, no auto-switch

# --- Cleanup ---
func _notification(what):
	# Ensure timer is stopped and freed when WorldManager is removed
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(current_zone_instance):
			# Disconnect signals before freeing zone
			for agent_body in _spawned_agent_bodies:
				if is_instance_valid(agent_body) and agent_body.is_connected("agent_despawning", self, "_on_Agent_Despawned"):
					agent_body.disconnect("agent_despawning", self, "_on_Agent_Despawned")
			current_zone_instance.queue_free()
		if is_instance_valid(_spawn_timer):
			_spawn_timer.queue_free()
