# File: core/systems/agent_system.gd
# Purpose: Manages agent spawning in virtual space (ships). Assembles agents from
# character data and their inventory of assets.
# Version: 2.1 - Added character_uid linking for ship stats integration.

extends Node

var _player_agent_body: KinematicBody = null
var _next_agent_uid: int = 0  # Counter for generating unique agent UIDs


func _ready():
	GlobalRefs.set_agent_spawner(self)
	
	# Listen for the zone_loaded signal to know when it's safe to spawn.
	EventBus.connect("zone_loaded", self, "_on_Zone_Loaded")
	print("AgentSpawner Ready.")


func _on_Zone_Loaded(_zone_instance, _zone_path, agent_container_node):
	if is_instance_valid(agent_container_node):
		if not is_instance_valid(_player_agent_body):
			spawn_player()
	else:
		printerr("AgentSpawner Error: Agent container invalid. Cannot spawn agents.")


# Important: player's character and inventory of assets must exist and upon spawining an
# agent they should get linked to it.
func spawn_player():
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("AgentSpawner Error: GlobalRefs.agent_container invalid.")
		return

	var player_template = load(Constants.PLAYER_DEFAULT_TEMPLATE_PATH)
	if not player_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load Player AgentTemplate.")
		return

	var player_spawn_pos = Vector3.ZERO
	var player_spawn_rot = Vector3.ZERO
	
	# Priority 1: Use saved position if it's not zero (loaded game)
	if GameState.player_position != Vector3.ZERO:
		player_spawn_pos = GameState.player_position
		player_spawn_rot = GameState.player_rotation
	# Priority 2: If docked, spawn at station
	elif GameState.player_docked_at != "":
		var dock_pos = _get_dock_position_in_zone(GameState.player_docked_at)
		if dock_pos != null:
			player_spawn_pos = dock_pos + Vector3(0, 5, 15)
	# Priority 3: Use zone entry point (new game)
	elif is_instance_valid(GlobalRefs.current_zone):
		var entry_node = null
		if Constants.ENTRY_POINT_NAMES.size() > 0:
			entry_node = GlobalRefs.current_zone.find_node(
				Constants.ENTRY_POINT_NAMES[0], true, false
			)
		if entry_node is Spatial:
			player_spawn_pos = entry_node.global_transform.origin + Vector3(0, 5, 15)

	# Get the player character UID from GameState
	var player_char_uid = GameState.player_character_uid
	
	# Overrides include agent_type, template_id, and character_uid for ship stats lookup
	var player_overrides = {
		"agent_type": "player", 
		"template_id": "player",
		"character_uid": player_char_uid
	}
	var agent_uid = _get_next_agent_uid()
	
	_player_agent_body = spawn_agent(
		Constants.PLAYER_AGENT_SCENE_PATH, player_spawn_pos, player_template, player_overrides, agent_uid
	)

	if is_instance_valid(_player_agent_body):
		# Apply saved rotation if available
		if player_spawn_rot != Vector3.ZERO:
			_player_agent_body.rotation_degrees = player_spawn_rot
		
		GlobalRefs.player_agent_body = _player_agent_body
		EventBus.emit_signal("camera_set_target_requested", _player_agent_body)
		EventBus.emit_signal("player_spawned", _player_agent_body)
	else:
		printerr("AgentSpawner Error: Failed to spawn player agent body!")


func _get_dock_position_in_zone(location_id: String):
	# Prefer the actual station instance position in the current zone.
	if location_id == "":
		return null
	if is_instance_valid(GlobalRefs.current_zone):
		var stations = get_tree().get_nodes_in_group("dockable_station")
		for station in stations:
			if not is_instance_valid(station):
				continue
			if not (station is Spatial):
				continue
			# Ensure this station belongs to the currently loaded zone.
			if not GlobalRefs.current_zone.is_a_parent_of(station):
				continue
			if station.get("location_id") == location_id:
				return station.global_transform.origin

	# Fallback: use template data if present.
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc is Resource and loc.get("position_in_zone") is Vector3:
			return loc.position_in_zone
		if loc is Dictionary and loc.get("position_in_zone") is Vector3:
			return loc["position_in_zone"]

	return null


# Spawns an NPC agent linked to a specific character.
# character_uid: The UID of the character this NPC represents.
func spawn_npc(character_uid: int, position: Vector3 = Vector3.ZERO) -> KinematicBody:
	if not GameState.characters.has(character_uid):
		printerr("AgentSpawner Error: No character found with UID: ", character_uid)
		return null
	
	var npc_template = load(Constants.NPC_TRAFFIC_TEMPLATE_PATH)
	if not npc_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load NPC AgentTemplate.")
		return null
	
	var npc_overrides = {
		"agent_type": "npc",
		"template_id": "npc_default",
		"character_uid": character_uid
	}
	var agent_uid = _get_next_agent_uid()
	
	var npc_body = spawn_agent(
		Constants.NPC_AGENT_SCENE_PATH, position, npc_template, npc_overrides, agent_uid
	)
	
	return npc_body


# Spawns an NPC using a specific AgentTemplate resource path.
# This is used for encounter-driven spawns where a fixed template is desired.
func spawn_npc_from_template(agent_template_path: String, position: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> KinematicBody:
	if not agent_template_path or agent_template_path.empty():
		printerr("AgentSpawner Error: spawn_npc_from_template invalid template path.")
		return null

	var npc_template = load(agent_template_path)
	if not npc_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load AgentTemplate at: ", agent_template_path)
		return null

	var npc_overrides := overrides.duplicate(true)
	if not npc_overrides.has("agent_type"):
		npc_overrides["agent_type"] = "npc"
	if not npc_overrides.has("template_id"):
		npc_overrides["template_id"] = "npc"
	if not npc_overrides.has("character_uid"):
		npc_overrides["character_uid"] = -1

	var agent_uid = _get_next_agent_uid()
	return spawn_agent(Constants.NPC_AGENT_SCENE_PATH, position, npc_template, npc_overrides, agent_uid)


# --- UID Generation ---
func _get_next_agent_uid() -> int:
	var uid = _next_agent_uid
	_next_agent_uid += 1
	return uid


# TODO: spawn NPC with proper overrides.
# Important: NPC's characters and their inventories of assets must exist and upon spawining an
# agent they should get linked to it.

func spawn_agent(
	agent_scene_path: String,
	position: Vector3,
	agent_template: AgentTemplate,
	overrides: Dictionary = {},
	agent_uid: int = -1
) -> KinematicBody:
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("AgentSpawner Spawn Error: Invalid GlobalRefs.agent_container.")
		return null
	if not agent_template is AgentTemplate:
		printerr("AgentSpawner Spawn Error: Invalid AgentTemplate Resource.")
		return null

	var agent_scene = load(agent_scene_path)
	if not agent_scene:
		printerr("AgentSpawner Spawn Error: Failed to load agent scene: ", agent_scene_path)
		return null

	var agent_root_instance = agent_scene.instance()
	# agent_node is the "AgentBody" KinematicBody within the scene instance
	var agent_node = agent_root_instance.get_node_or_null(Constants.AGENT_BODY_NODE_NAME)

	if not (agent_node and agent_node is KinematicBody):
		printerr("AgentSpawner Spawn Error: Invalid agent body node in scene: ", agent_scene_path)
		agent_root_instance.queue_free()
		return null

	var instance_name = agent_template.agent_type + "_" + str(agent_root_instance.get_instance_id())
	
	agent_root_instance.name = instance_name

	container.add_child(agent_root_instance)
	agent_node.global_transform.origin = position

	if agent_node.has_method("initialize"):
		agent_node.initialize(agent_template, overrides, agent_uid)

	EventBus.emit_signal(
		"agent_spawned", agent_node, {"template": agent_template, "overrides": overrides, "agent_uid": agent_uid}
	)

	# The controller is a child of the AgentBody (agent_node), not the scene root.
	# We also need to check for both AI and Player controllers.
	var ai_controller = agent_node.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	var _player_controller = agent_node.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)

	if ai_controller and ai_controller.has_method("initialize"):
		ai_controller.initialize(overrides) # Pass agent_uid?
	# The PlayerInputHandler does not have an initialize method, so we don't need to call it,
	# but by getting a reference to it, we ensure the test framework is aware of it.

	return agent_node
