# NavigationSystem: runs the active autopilot command (stop, move, approach, orbit, flee, align, watch, ram, aim) for an agent.

extends Node

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")
const OBSTACLES_META = "nav_obstacles"

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO, WATCH, RAM, AIM }

# --- References ---
var agent_body: RigidBody = null
var movement_system: Node = null

# --- State ---
var _current_command = {}
var _avoid_timer: float = randf() * Constants.NAV_AVOID_INTERVAL  # Staggers ships' avoidance checks
var _avoid_push := Vector3.ZERO  # Last avoidance push, applied every step until the next check

# --- Child Components ---
var _command_handlers = {}


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
		CommandType.RAM: load(command_path + "command_ram.gd").new(),
		CommandType.AIM: load(command_path + "command_aim.gd").new(),
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


func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}


func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}


func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target, "is_new": true}


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


func set_command_ram(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.RAM, "target_node": target, "is_new": true}


func set_command_aim(target: Spatial, keep_range: float):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.AIM, "target_node": target, "range": keep_range}


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

	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE, CommandType.WATCH, CommandType.RAM, CommandType.AIM]
	if is_target_cmd and not is_instance_valid(target_node):
		set_command_stopping()
		cmd_type = CommandType.STOPPING

	if _command_handlers.has(cmd_type):
		var handler = _command_handlers[cmd_type]
		if handler.has_method("execute"):
			handler.execute(delta)
	else:
		_command_handlers[CommandType.IDLE].execute(delta)

	if not cmd_type in [CommandType.IDLE, CommandType.MOVE_DIRECTION]:
		_apply_obstacle_avoidance(target_node, delta)


# Sidesteps obstacles (group "obstacle") in the way of the current velocity, except the command's
# own target (e.g. the station being approached). The push is worked out every
# Constants.NAV_AVOID_INTERVAL (ships staggered) and applied every step in between: it looks seconds
# ahead, so a fresher one would barely differ, and it was the costliest part of a physics step.
func _apply_obstacle_avoidance(target_node, delta: float) -> void:
	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer += Constants.NAV_AVOID_INTERVAL
		_avoid_push = _compute_obstacle_push(target_node)
	if _avoid_push != Vector3.ZERO:
		movement_system.request_thrust_direction(_avoid_push, min(1.0, _avoid_push.length()) * Constants.NAV_AVOID_THRUST)


func _compute_obstacle_push(target_node) -> Vector3:
	var obstacles: Array = []
	for obstacle in get_obstacles(get_tree()):
		if obstacle[2] != target_node:
			obstacles.append(obstacle)
	var own_radius: float = agent_body.get_apparent_radius() if agent_body.has_method("get_apparent_radius") else 10.0
	return compute_avoidance(agent_body.global_transform.origin, agent_body.linear_velocity, own_radius, obstacles)


# Every obstacle as [centre, radius, node], gathered once per physics step and shared by every
# ship that steers that step.
static func get_obstacles(tree: SceneTree) -> Array:
	var step: int = Engine.get_physics_frames()
	if tree.has_meta(OBSTACLES_META):
		var cached: Array = tree.get_meta(OBSTACLES_META)
		if cached[0] == step:
			return cached[1]
	var obstacles: Array = []
	for obstacle in tree.get_nodes_in_group("obstacle"):
		if obstacle is Spatial and obstacle.has_method("get_obstacle_radius"):
			obstacles.append([obstacle.global_transform.origin, obstacle.get_obstacle_radius(), obstacle])
	tree.set_meta(OBSTACLES_META, [step, obstacles])
	return obstacles


# Sideways push away from every obstacle ([centre, radius]) whose clearance sphere the straight
# path ahead would cross within the look-ahead; each scaled by how close and how soon. ZERO if clear.
static func compute_avoidance(position: Vector3, velocity: Vector3, own_radius: float, obstacles: Array) -> Vector3:
	var speed: float = velocity.length()
	if speed < Constants.NAV_AVOID_MIN_SPEED:
		return Vector3.ZERO
	var heading: Vector3 = velocity / speed
	var reach: float = speed * Constants.NAV_AVOID_LOOKAHEAD_TIME
	var push := Vector3.ZERO
	for obstacle in obstacles:
		var to_centre: Vector3 = obstacle[0] - position
		var clearance: float = (obstacle[1] + own_radius) * Constants.NAV_AVOID_CLEARANCE
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