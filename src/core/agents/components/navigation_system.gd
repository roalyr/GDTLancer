# File: res://core/agents/components/navigation_system.gd
# Version: 3.0 - RigidBody physics with thrust-based 6DOF flight.

extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.3
const APPROACH_MIN_DISTANCE = 50.0
const ARRIVAL_DISTANCE_THRESHOLD = 20.0
const ARRIVAL_SPEED_THRESHOLD = 5.0
const CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR = 1.5

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


func set_command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_idle()
		return
	_current_command = {"type": CommandType.ALIGN_TO, "target_dir": direction.normalized()}


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
