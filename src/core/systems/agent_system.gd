# AgentSystem (AgentSpawner): spawns the player and NPC agents from AgentTemplates when a zone loads.

extends Node

var populate_sectors: bool = true  # Tests switch this off to spawn only the player.

var _player_agent_body: RigidBody = null
var _next_agent_uid: int = 0  # Counter for generating unique agent UIDs
var _npc_bodies: Array = []  # Live NPCs in the current sector
var _respawn_timer: Timer = null
var _battlefield: Dictionary = {}  # get_battlefield(), reset per sector


func _ready():
	GlobalRefs.set_agent_spawner(self)

	# Listen for the zone_loaded signal to know when it's safe to spawn.
	EventBus.connect("zone_loaded", self, "_on_Zone_Loaded")

	_respawn_timer = Timer.new()
	_respawn_timer.wait_time = Constants.NPC_RESPAWN_INTERVAL
	_respawn_timer.connect("timeout", self, "_top_up_population")
	add_child(_respawn_timer)


func _on_Zone_Loaded(_zone_instance, _zone_path, agent_container_node):
	if is_instance_valid(agent_container_node):
		if not is_instance_valid(_player_agent_body):
			spawn_player()
		_npc_bodies.clear()
		_battlefield = {}
		if populate_sectors:
			_top_up_population(true)
			_respawn_timer.start()
	else:
		printerr("AgentSpawner Error: Agent container invalid. Cannot spawn agents.")


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
	var should_apply_spawn_rotation = false
	var is_jump_in = false
	var jump_in_anchor = Vector3.ZERO
	
	# Priority 1: Use saved position if it's not zero (loaded game)
	if GameState.player_position != Vector3.ZERO:
		player_spawn_pos = GameState.player_position
		player_spawn_rot = GameState.player_rotation
		should_apply_spawn_rotation = true
	# Priority 2: If docked, spawn at station
	elif GameState.player_docked_at != "":
		var dock_pos = _get_dock_position_in_zone(GameState.player_docked_at)
		if dock_pos != null:
			player_spawn_pos = dock_pos
		else:
			GameState.player_docked_at = ""  # No such station here: spawn undocked rather than stuck
	# Priority 3: Use zone entry point (new game or jump arrival)
	else:
		var anchor_pos = Vector3.ZERO
		if is_instance_valid(GlobalRefs.current_zone):
			var entry_node = GlobalRefs.current_zone.find_node("EntryPoint", true, false)
			if entry_node and entry_node is Spatial:
				anchor_pos = entry_node.global_transform.origin
		
		# Generate a random offset around the anchor based on jump_in_distance (+/- 10% variation)
		var base_dist = _get_jump_in_distance_for_sector(GameState.current_sector_id)
		var random_dir = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var random_dist = rand_range(base_dist * 0.9, base_dist * 1.1)
		player_spawn_pos = anchor_pos + (random_dir * random_dist)
		
		is_jump_in = true
		jump_in_anchor = anchor_pos
		
		if GameState.player_arrival_direction != Vector3.ZERO:
			player_spawn_rot = GameState.player_rotation
			should_apply_spawn_rotation = true
			GameState.player_arrival_direction = Vector3.ZERO
			GameState.player_arrived_from_sector = ""
		elif GameState.player_arrived_from_sector != "":
			player_spawn_rot = GameState.player_rotation
			should_apply_spawn_rotation = true
			GameState.player_arrived_from_sector = ""

	var player_overrides = {
		"agent_type": "player",
		"template_id": "player",
		"ship_template_id": GameState.player_ship_template_id
	}
	var agent_uid = _get_next_agent_uid()
	
	_player_agent_body = spawn_agent(
		Constants.PLAYER_AGENT_SCENE_PATH, player_spawn_pos, player_template, player_overrides, agent_uid
	)

	if is_instance_valid(_player_agent_body):
		# Keep the player's global orientation across saved loads and sector arrivals.
		if should_apply_spawn_rotation:
			_player_agent_body.rotation_degrees = player_spawn_rot
		
		GlobalRefs.player_agent_body = _player_agent_body
		EventBus.emit_signal("camera_set_target_requested", _player_agent_body)
		EventBus.emit_signal("player_spawned", _player_agent_body)
		
		# On jump-in trigger camera aim at target origin (coord origin or Entry point)
		if is_jump_in:
			var camera = GlobalRefs.main_camera
			if is_instance_valid(camera) and camera.has_method("set_orbit_forward_direction"):
				var look_dir = (jump_in_anchor - player_spawn_pos).normalized()
				if look_dir.length_squared() > 0.001:
					camera.set_orbit_forward_direction(look_dir)
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
				return station.get_undock_position() if station.has_method("get_undock_position") else station.global_transform.origin

	return null


func _get_jump_in_distance_for_sector(sector_id: String) -> float:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	var sector_type = "deep_space"
	var distance = -1.0
	
	if sector_template != null:
		if sector_template is Dictionary:
			if sector_template.has("jump_in_distance"):
				distance = float(sector_template["jump_in_distance"])
			if sector_template.has("sector_type"):
				sector_type = sector_template["sector_type"]
		elif sector_template is Object:
			if "jump_in_distance" in sector_template:
				distance = float(sector_template.jump_in_distance)
			if "sector_type" in sector_template:
				sector_type = sector_template.sector_type
				
	if distance > 0.0:
		return distance
		
	# Fallback based on sector type
	match sector_type.to_lower():
		"star", "star_companion":
			return 20000.0
		"planet":
			return 5000.0
		"moon":
			return 2000.0
		_:
			return 5000.0


# --- NPC Population: the battlefield (see Constants AI AND NPC POPULATION) ---

# Tops up each faction to NPC_POPULATION_PER_FACTION live ships: all at once when the sector
# loads, then one ship per faction per call, so reinforcements trickle in. Also clears old wrecks.
func _top_up_population(fill: bool = false) -> void:
	if not is_instance_valid(GlobalRefs.agent_container) or not is_instance_valid(_player_agent_body):
		return
	var live: Array = []
	for npc in _npc_bodies:
		if is_instance_valid(npc) and not npc.is_wreck:
			live.append(npc)
	_npc_bodies = live
	var battle: Dictionary = get_battlefield()
	for faction in Constants.NPC_FACTION_TEMPLATE_PATHS:
		var count := 0
		for npc in live:
			if npc.faction == faction:
				count += 1
		var missing: int = Constants.NPC_POPULATION_PER_FACTION - count
		for _i in range(missing if fill else min(missing, 1)):
			var home_point: Vector3 = battle.arrivals[faction]
			var npc = spawn_npc_from_template(
				Constants.NPC_FACTION_TEMPLATE_PATHS[faction], _scatter(home_point),
				{"faction": faction, "patrol_center": battle.center, "home_point": home_point}
			)
			if is_instance_valid(npc):
				_npc_bodies.append(npc)
	clear_old_wrecks()


# The middle of the battlefield, off the home station, and each faction's arrival point, on
# opposite sides of it. Fixed per sector load.
func get_battlefield() -> Dictionary:
	if not _battlefield.empty():
		return _battlefield
	var anchor: Vector3 = _player_agent_body.global_transform.origin if is_instance_valid(_player_agent_body) else Vector3.ZERO
	var station = _find_home_station()
	if is_instance_valid(station):
		anchor = station.global_transform.origin
	var offset_dir: Vector3 = _random_direction()
	var side: Vector3 = offset_dir.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = offset_dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var center: Vector3 = anchor + offset_dir * Constants.BATTLE_OFFSET_FROM_HOME
	var arrivals := {}
	var sign_ := 1.0
	for faction in Constants.NPC_FACTION_TEMPLATE_PATHS:
		arrivals[faction] = center + side * sign_ * Constants.BATTLE_FACTION_SPAWN_DISTANCE
		sign_ = -sign_
	_battlefield = {"center": center, "arrivals": arrivals}
	return _battlefield


func _find_home_station() -> Node:
	var fallback: Node = null
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if not (station is Spatial and is_instance_valid(GlobalRefs.current_zone) and GlobalRefs.current_zone.is_a_parent_of(station)):
			continue
		if station.get("location_id") == GameState.home_location_id:
			return station
		if fallback == null:
			fallback = station
	return fallback


func _scatter(point: Vector3) -> Vector3:
	return point + _random_direction() * randf() * Constants.BATTLE_SPAWN_SPREAD


static func _random_direction() -> Vector3:
	var direction = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1))
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD


# Past WRECK_LOOTED_CAP wrecks, removes the oldest stripped ones; past WRECK_MAX, the oldest of
# any. Wrecks someone is harpooning, and the player's own, stay.
func clear_old_wrecks() -> void:
	var wrecks: Array = []
	var held := {}
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body.get("is_wreck"):
			if not body.is_player():
				wrecks.append(body)
			continue
		var tools = body.get_node_or_null("ToolController")
		if tools != null:
			for index in range(tools.get_tool_count()):
				if is_instance_valid(tools.get_target(index)):
					held[tools.get_target(index)] = true
	wrecks.sort_custom(self, "_older_wreck_first")
	var excess: int = wrecks.size() - Constants.WRECK_LOOTED_CAP
	for wreck in wrecks.duplicate():
		if excess <= 0:
			break
		if wreck.get_salvage_units() <= 0 and not held.has(wreck):
			wrecks.erase(wreck)
			wreck.despawn()
			excess -= 1
	excess = wrecks.size() - Constants.WRECK_MAX
	for wreck in wrecks:
		if excess <= 0:
			break
		if not held.has(wreck):
			wreck.despawn()
			excess -= 1


func _older_wreck_first(a, b) -> bool:
	return a.wreck_time_ms < b.wreck_time_ms


# Spawns an NPC using a specific AgentTemplate resource path.
# This is used for encounter-driven spawns where a fixed template is desired.
func spawn_npc_from_template(agent_template_path: String, position: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> RigidBody:
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

	var agent_uid = _get_next_agent_uid()
	return spawn_agent(Constants.NPC_AGENT_SCENE_PATH, position, npc_template, npc_overrides, agent_uid)


# --- UID Generation ---
func _get_next_agent_uid() -> int:
	var uid = _next_agent_uid
	_next_agent_uid += 1
	return uid


func spawn_agent(
	agent_scene_path: String,
	position: Vector3,
	agent_template: AgentTemplate,
	overrides: Dictionary = {},
	agent_uid: int = -1
) -> RigidBody:
	var final_overrides = overrides.duplicate(true)
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
	# agent_node is the "AgentBody" RigidBody within the scene instance
	var agent_node = agent_root_instance.get_node_or_null(Constants.AGENT_BODY_NODE_NAME)

	if not (agent_node and agent_node is RigidBody):
		printerr("AgentSpawner Spawn Error: Invalid agent body node in scene: ", agent_scene_path)
		agent_root_instance.queue_free()
		return null

	var instance_name = agent_template.agent_type + "_" + str(agent_root_instance.get_instance_id())
	
	agent_root_instance.name = instance_name

	container.add_child(agent_root_instance)
	agent_node.global_transform.origin = position

	if agent_node.has_method("initialize"):
		agent_node.initialize(agent_template, final_overrides, agent_uid)

	EventBus.emit_signal(
		"agent_spawned", agent_node, {"template": agent_template, "overrides": final_overrides, "agent_uid": agent_uid}
	)

	return agent_node
