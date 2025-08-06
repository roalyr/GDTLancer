# File: core/systems/agent_system.gd
# Purpose: Manages agent spawning in virtual space (ships). Assembles agents from
# character data and their inventory of assets.
# Version: 2.0 - Reworked to match new templates.

extends Node

var _player_agent_body: KinematicBody = null


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
	if is_instance_valid(GlobalRefs.current_zone):
		var entry_node = null
		if Constants.ENTRY_POINT_NAMES.size() > 0:
			entry_node = GlobalRefs.current_zone.find_node(
				Constants.ENTRY_POINT_NAMES[0], true, false
			)
		if entry_node is Spatial:
			player_spawn_pos = entry_node.global_transform.origin + Vector3(0, 5, 15)

	# Those are agent type flags (player or npc) and assign an UID. For player UID is 0.
	# For NPCs UID will be incremented.
	# From AgentTemplate.
	var player_overrides = {"agent_type": "player", "template_id": "player"}
	var agent_uid = 0
	
	_player_agent_body = spawn_agent(
		Constants.PLAYER_AGENT_SCENE_PATH, player_spawn_pos, player_template, player_overrides, agent_uid
	)

	if is_instance_valid(_player_agent_body):
		GlobalRefs.player_agent_body = _player_agent_body
		EventBus.emit_signal("camera_set_target_requested", _player_agent_body)
		EventBus.emit_signal("player_spawned", _player_agent_body)
	else:
		printerr("AgentSpawner Error: Failed to spawn player agent body!")

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
	var player_controller = agent_node.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)

	if ai_controller and ai_controller.has_method("initialize"):
		ai_controller.initialize(overrides) # Pass agent_uid?
	# The PlayerInputHandler does not have an initialize method, so we don't need to call it,
	# but by getting a reference to it, we ensure the test framework is aware of it.

	return agent_node
