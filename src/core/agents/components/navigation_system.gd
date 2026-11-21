# NavigationSystem: runs the active autopilot command (stop, move, approach, orbit, flee, align, watch, charge, aim) for an agent.

extends Node

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")
const StepCache = preload("res://src/core/utils/step_cache.gd")
const OBSTACLES_META = "nav_obstacles"

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO, WATCH, CHARGE }

# --- References ---
var agent_body: RigidBody = null
var movement_system: Node = null

# --- State ---
var _current_command = {}
var _avoid_timer: float = randf() * Constants.NAV_AVOID_INTERVAL  # Staggers ships' avoidance checks
var _avoid_push := Vector3.ZERO  # Last avoidance push, applied every step until the next check
var _avoid_contacts: Array = []  # Directions to the planets it is up against (contacts), as of the last push

# --- Child Components ---
var _command_handlers = {}
var _tools: Node = null  # The ship's ToolController, looked up once (it may come after this)

const TARGET_COMMANDS = {CommandType.APPROACH: true, CommandType.ORBIT: true, CommandType.FLEE: true, CommandType.WATCH: true, CommandType.CHARGE: true}


# --- Initialization ---
func _ready():
	if not _current_command:
		set_command_idle()


func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	movement_system = move_sys_ref
	agent_body = get_parent()

	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: Invalid parent or movement system reference!")
		return

	_initialize_command_handlers()

	if Constants.VERBOSE_RUNTIME_LOGS:
		print("NavigationSystem Initialized.")
	set_command_idle()


func _initialize_command_handlers():
	var command_path = "res://src/core/agents/components/navigation_system/"
	_command_handlers = {
		CommandType.IDLE: load(command_path + "command_idle.gd").new(),
		CommandType.STOPPING: load(command_path + "command_stop.gd").new(),
		CommandType.MOVE_TO: load(command_path + "command_move_to.gd").new(),
		CommandType.MOVE_DIRECTION: load(command_path + "command_move_direction.gd").new(),
		CommandType.APPROACH: load(command_path + "command_approach.gd").new(),
		CommandType.ORBIT: load(command_path + "command_orbit.gd").new(),
		CommandType.FLEE: load(command_path + "command_flee.gd").new(),
		CommandType.ALIGN_TO: load(command_path + "command_align_to.gd").new(),
		CommandType.WATCH: load(command_path + "command_watch.gd").new(),
		CommandType.CHARGE: load(command_path + "command_charge.gd").new(),
	}

	for handler_script in _command_handlers.values():
		add_child(handler_script)
		if handler_script.has_method("initialize"):
			handler_script.initialize(self)


# --- Public Command Setting Methods ---
func set_command_idle():
	_current_command = {"type": CommandType.IDLE}


func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}


var cruise_speed: float = INF  # m/s a MOVE_TO thrusts up to (the AI's cruising; INF: flat out)


func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}


func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}


# `at_weapons`: while weapons are on the target, hold at their range (ToolController.fighting_range)
# rather than close in (the player's APPROACH; NPCs choose their own range).
func set_command_approach(target: Spatial, at_weapons: bool = false):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target, "is_new": true, "at_weapons": at_weapons}


func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": distance,
		"clockwise": clockwise,
		"is_new": true
	}


func set_command_flee(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.FLEE, "target_node": target}


func set_command_watch(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.WATCH, "target_node": target}


func set_command_charge(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.CHARGE, "target_node": target, "is_new": true}


func set_command_align_to(
	direction: Vector3,
	apply_forward_thrust: bool = false,
	forward_thrust_scale: float = 1.0,
	persist_until_cleared: bool = false
):
	if direction.length_squared() < 0.001:
		set_command_idle()
		return
	_current_command = {
		"type": CommandType.ALIGN_TO,
		"target_dir": direction.normalized(),
		"apply_forward_thrust": apply_forward_thrust,
		"forward_thrust_scale": clamp(forward_thrust_scale, 0.0, 1.0),
		"persist_until_cleared": persist_until_cleared
	}


# The ship or body the current command is about (null for none).
func get_command_target():
	var target = _current_command.get("target_node")
	return target if is_instance_valid(target) else null


func get_current_command_type() -> int:
	return int(_current_command.get("type", CommandType.IDLE))


# --- Main Update Logic (Called from AgentBody._integrate_forces) ---
func update_navigation(delta: float):
	FrameProfiler.begin(get_tree(), "nav")
	_update_navigation(delta)
	FrameProfiler.end(get_tree(), "nav")


func _update_navigation(delta: float):
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	if TARGET_COMMANDS.has(cmd_type) and not is_instance_valid(target_node):
		set_command_stopping()
		cmd_type = CommandType.STOPPING

	# An active cannon holds the nose on its lead; the course below steers a heading of its own. Not
	# while charging: a lance is thrown along the nose (LanceController), so the charge keeps it.
	if not is_instance_valid(_tools):
		_tools = agent_body.get_node_or_null("ToolController")
	var cannon_ok: bool = cmd_type != CommandType.CHARGE and _tools != null and _tools.has_method("cannon_facing")
	movement_system.facing = _tools.cannon_facing() if cannon_ok else Vector3.ZERO

	var handler = _command_handlers.get(cmd_type)
	if handler == null:
		handler = _command_handlers[CommandType.IDLE]
	handler.execute(delta)

	if cmd_type != CommandType.IDLE and cmd_type != CommandType.MOVE_DIRECTION:
		_apply_obstacle_avoidance(target_node, delta, cmd_type == CommandType.CHARGE and is_straight_charge(target_node))
	movement_system.apply_facing(delta)


# A charge at a rock or at debris (a wreck, an ore chunk) is flown straight at it: no strafe, no
# break-off (command_charge) and no sidestepping the rocks round it; only a live ship is charged the
# long way.
static func is_straight_charge(target) -> bool:
	return is_instance_valid(target) and target.get("is_wreck") != false


# Sidesteps obstacles (group "obstacle") in the way of the current velocity, except the command's
# own target (e.g. the station being approached); `straight` (a charge at a rock or debris): only
# keeps from pressing into a planet, no sidestep. The push is worked out every
# Constants.NAV_AVOID_INTERVAL (ships staggered) and applied every step in between: it looks seconds
# ahead, so a fresher one would barely differ, and it was the costliest part of a physics step.
func _apply_obstacle_avoidance(target_node, delta: float, straight: bool = false) -> void:
	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer += Constants.NAV_AVOID_INTERVAL
		var index: Dictionary = get_obstacle_index(get_tree())
		var own_radius: float = agent_body.get_apparent_radius() if agent_body.has_method("get_apparent_radius") else 10.0
		var requested = movement_system.get_requested_force() if movement_system.has_method("get_requested_force") else null
		var intent: Vector3 = requested if requested is Vector3 else Vector3.ZERO
		var position: Vector3 = agent_body.global_transform.origin
		_avoid_push = _avoidance(position, agent_body.linear_velocity, own_radius, index.tree, intent, target_node)
		_avoid_contacts = contacts(position, own_radius, index.celestials)
	if not _avoid_contacts.empty() and movement_system.has_method("cancel_thrust_toward"):
		for inward in _avoid_contacts:
			movement_system.cancel_thrust_toward(inward)  # Against a planet: no pressing on into it
	if _avoid_push != Vector3.ZERO and not straight:
		movement_system.request_thrust_direction(_avoid_push, min(1.0, _avoid_push.length()) * Constants.NAV_AVOID_THRUST)


# Every obstacle as [centre, radius, node]. Obstacles never move (rocks, stations, planets and moons
# are static bodies), so in the game world the list stands until one enters or leaves (each calls
# forget_obstacles); elsewhere (unit tests, which place and move them between steps) it is gathered
# once per physics step. Shared by every ship that steers.
static func get_obstacles(tree: SceneTree) -> Array:
	return get_obstacle_index(tree).obstacles


# Drops the gathered obstacles: an obstacle entering or leaving the tree calls it, and tests that
# make or move one faster than steps go by.
static func forget_obstacles(tree: SceneTree) -> void:
	if tree != null and tree.has_meta(OBSTACLES_META):
		tree.remove_meta(OBSTACLES_META)


# The obstacles three ways: "obstacles" (every one, [centre, radius, node]), "celestials" (the
# planets and moons among them, for contacts()) and "tree", the same obstacles binned
# NAV_OBSTACLE_LEVELS times (cubes of NAV_OBSTACLE_CELL, then each level's bins in cubes
# NAV_OBSTACLE_REGION times as big) into nested clusters (cluster()): a path that passes a
# cluster's sphere by more than its clearance passes all within, so most are never looked at.
static func get_obstacle_index(tree: SceneTree) -> Dictionary:
	var step: int = -1 if StepCache.in_world() else Engine.get_physics_frames()
	if tree.has_meta(OBSTACLES_META):
		var cached: Array = tree.get_meta(OBSTACLES_META)
		if cached[0] == step:
			return cached[1]
	var obstacles: Array = []
	var celestials: Array = []
	for obstacle in tree.get_nodes_in_group("obstacle"):
		if obstacle is Spatial and obstacle.has_method("get_obstacle_radius"):
			var entry: Array = [obstacle.global_transform.origin, obstacle.get_obstacle_radius(), obstacle]
			obstacles.append(entry)
			if obstacle.is_in_group("celestial"):
				celestials.append(entry)
	var index := {"obstacles": obstacles, "celestials": celestials, "tree": nest(obstacles, Constants.NAV_OBSTACLE_CELL, Constants.NAV_OBSTACLE_REGION, Constants.NAV_OBSTACLE_LEVELS)}
	tree.set_meta(OBSTACLES_META, [step, index])
	return index


# `obstacles` clustered `levels` times, in cubes of `cell` m growing `growth` times a level.
static func nest(obstacles: Array, cell: float, growth: float, levels: int) -> Array:
	var items: Array = obstacles
	for _level in range(levels):
		items = cluster(items, cell)
		cell *= growth
	return items


# `items` (obstacles [centre, radius, node] and clusters) binned in cubes of `cell` m. A bin of
# several becomes a cluster [centre, reach (from its centre to the furthest centre of an obstacle
# within), largest obstacle radius within, members]; a bin of one stays as it is.
static func cluster(items: Array, cell: float) -> Array:
	var bins := {}
	for item in items:
		var key: Vector3 = (item[0] / cell).floor()
		if not bins.has(key):
			bins[key] = []
		bins[key].append(item)
	var clusters: Array = []
	for members in bins.values():
		if members.size() == 1:
			clusters.append(members[0])
			continue
		var centre := Vector3.ZERO
		for member in members:
			centre += member[0]
		centre /= members.size()
		var reach := 0.0
		var largest := 0.0
		for member in members:
			var nested: bool = member.size() > 3
			reach = max(reach, centre.distance_to(member[0]) + (member[1] if nested else 0.0))
			largest = max(largest, member[2] if nested else member[1])
		clusters.append([centre, reach, largest, members])
	return clusters


# Sideways push away from every obstacle ([centre, radius]) whose clearance sphere the straight
# path ahead would cross within the look-ahead; each scaled by how close and how soon. ZERO if clear.
# The path ahead is the way it moves and, when its command pushes another way (`intent`: the thrust
# asked for), that way too: the stronger push wins, so a ship sliding slowly along a planet it is
# thrusting into turns off it rather than pressing on. Slower than NAV_AVOID_MIN_SPEED, only `intent`.
static func compute_avoidance(position: Vector3, velocity: Vector3, own_radius: float, obstacles: Array, intent: Vector3 = Vector3.ZERO) -> Vector3:
	return _avoidance(position, velocity, own_radius, obstacles, intent, null)


# compute_avoidance over obstacles and clusters of them (get_obstacle_index's "tree"), leaving out
# the obstacle `exclude` (the command's own target, e.g. the station being approached).
static func _avoidance(position: Vector3, velocity: Vector3, own_radius: float, items: Array, intent: Vector3, exclude) -> Vector3:
	var push := Vector3.ZERO
	var speed: float = velocity.length()
	if speed >= Constants.NAV_AVOID_MIN_SPEED:
		push = _push_along(position, velocity / speed, speed * Constants.NAV_AVOID_LOOKAHEAD_TIME, own_radius, items, exclude)
	if intent.length_squared() > 0.001 and (speed < Constants.NAV_AVOID_MIN_SPEED or intent.normalized().dot(velocity / speed) < Constants.NAV_AVOID_INTENT_DOT):
		var pushing: Vector3 = _push_along(position, intent.normalized(), max(speed, Constants.NAV_AVOID_MIN_SPEED) * Constants.NAV_AVOID_LOOKAHEAD_TIME, own_radius, items, exclude)
		if pushing.length_squared() > push.length_squared():
			push = pushing
	return push


# The push off `items` (obstacles and clusters) of a path from `position` along `heading`, `reach` m
# ahead (the look-ahead at its speed).
static func _push_along(position: Vector3, heading: Vector3, reach: float, own_radius: float, items: Array, exclude) -> Vector3:
	var push := Vector3.ZERO
	for item in items:
		if item.size() > 3:  # A cluster
			# An obstacle counts only within its clearance of the path's first reach + clearance
			# metres, and every one within is within the cluster's reach of its centre: a centre
			# further than both from that stretch rules them all out.
			var widest: float = (item[2] + own_radius) * Constants.NAV_AVOID_CLEARANCE
			var to_cluster: Vector3 = item[0] - position
			var nearest: float = clamp(to_cluster.dot(heading), 0.0, reach + widest)
			var keep: float = item[1] + widest
			if (to_cluster - heading * nearest).length_squared() < keep * keep:
				push += _push_along(position, heading, reach, own_radius, item[3], exclude)
			continue
		if exclude != null and item[2] == exclude:
			continue
		var to_centre: Vector3 = item[0] - position
		var clearance: float = (item[1] + own_radius) * Constants.NAV_AVOID_CLEARANCE
		var along: float = to_centre.dot(heading)
		if along < 0.0 or along > reach + clearance:
			continue
		var offset: Vector3 = to_centre - heading * along  # From the path to the centre, sideways
		var miss: float = offset.length()
		if miss >= clearance:
			continue
		var away: Vector3 = -offset / miss if miss > 0.01 else _any_perpendicular(heading)
		var urgency: float = (1.0 - miss / clearance) * (1.0 - clamp(along / (reach + clearance), 0.0, 1.0))
		push += away * urgency
	return push


# Directions (unit) to the planets and moons a ship at `position` is up against (within
# NAV_CONTACT_MARGIN of touching). Rocks and stations are left out: ships work right by those.
static func contacts(position: Vector3, own_radius: float, obstacles: Array) -> Array:
	var found: Array = []
	for obstacle in obstacles:
		if not (is_instance_valid(obstacle[2]) and obstacle[2].is_in_group("celestial")):
			continue
		var to_centre: Vector3 = obstacle[0] - position
		if to_centre.length() < obstacle[1] + own_radius + Constants.NAV_CONTACT_MARGIN and to_centre.length_squared() > 0.01:
			found.append(to_centre.normalized())
	return found


static func _any_perpendicular(direction: Vector3) -> Vector3:
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	return side.normalized()


# --- Helper Functions ---
func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0
	var default_radius = 10.0

	if not is_instance_valid(target_node):
		return default_radius

	if target_node.has_method("get_interaction_radius"):
		var explicit_radius = target_node.get_interaction_radius()
		if (explicit_radius is float or explicit_radius is int) and explicit_radius > 0:
			return max(float(explicit_radius), 1.0)

	var model_node = target_node.get_node_or_null("Model")
	if is_instance_valid(model_node) and model_node is Spatial:
		var combined_aabb: AABB = AABB()
		var first_visual_found = false
		for child in model_node.get_children():
			if child is VisualInstance:
				var child_global_aabb = child.get_transformed_aabb()
				if not first_visual_found:
					combined_aabb = child_global_aabb
					first_visual_found = true
				else:
					combined_aabb = combined_aabb.merge(child_global_aabb)

		if first_visual_found:
			var longest_axis_size = combined_aabb.get_longest_axis_size()
			calculated_size = longest_axis_size / 2.0
			if calculated_size > 0.01:
				return max(calculated_size, 1.0)

	var node_scale = target_node.global_transform.basis.get_scale()
	calculated_size = max(node_scale.x, max(node_scale.y, node_scale.z)) / 2.0
	if calculated_size <= 0.01:
		return default_radius

	return max(calculated_size, 1.0)