# NavigationSystem: runs the active autopilot command (stop, move, approach, orbit, flee, align) for an agent.

extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }

# --- References ---
var agent_body: RigidBody = null
var movement_system: Node = null

# --- State ---
var _current_command = {}

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
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE]
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
		_apply_obstacle_avoidance(target_node)


# Sidesteps obstacles (group "obstacle") in the way of the current velocity, except the command's
# own target (e.g. the station being approached).
func _apply_obstacle_avoidance(target_node) -> void:
	var obstacles: Array = []
	for obstacle in get_tree().get_nodes_in_group("obstacle"):
		if obstacle != target_node and obstacle is Spatial and obstacle.has_method("get_obstacle_radius"):
			obstacles.append([obstacle.global_transform.origin, obstacle.get_obstacle_radius()])
	var own_radius: float = agent_body.get_apparent_radius() if agent_body.has_method("get_apparent_radius") else 10.0
	var push: Vector3 = compute_avoidance(agent_body.global_transform.origin, agent_body.linear_velocity, own_radius, obstacles)
	if push != Vector3.ZERO:
		movement_system.request_thrust_direction(push, min(1.0, push.length()) * Constants.NAV_AVOID_THRUST)


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