# File: res://core/agents/components/navigation_system.gd
# Version: 2.0 (Refactored) - Manages and dispatches to command handler components.

extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.3
const APPROACH_MIN_DISTANCE = 50.0
const APPROACH_DECELERATION_START_DISTANCE_FACTOR = 50.0
const ARRIVAL_DISTANCE_THRESHOLD = 5.0
const ARRIVAL_SPEED_THRESHOLD_SQ = 1.0
const CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR = 1.5

# --- References ---
var agent_body: KinematicBody = null
var movement_system: Node = null

# --- State ---
var _current_command = {}

# --- Child Components ---
var _pid_orbit: PIDController = null
var _pid_approach: PIDController = null
var _pid_move_to: PIDController = null
var _command_handlers = {}
const PIDControllerScript = preload("res://core/utils/pid_controller.gd")


# --- Initialization ---
func _ready():
	if not _current_command:
		set_command_idle()


func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	movement_system = move_sys_ref
	agent_body = get_parent()

	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: Invalid parent or movement system reference!")
		set_process(false)
		return

	_initialize_pids(nav_params)
	_initialize_command_handlers()

	print("NavigationSystem Initialized.")
	set_command_idle()


func _initialize_pids(nav_params: Dictionary):
	if not PIDControllerScript:
		printerr("NavigationSystem Error: Failed to load PIDController script!")
		return
		
	_pid_orbit = PIDControllerScript.new()
	_pid_approach = PIDControllerScript.new()
	_pid_move_to = PIDControllerScript.new()

	var o_limit = movement_system.max_move_speed
	_pid_orbit.initialize(
		nav_params.get("orbit_kp", 0.5), nav_params.get("orbit_ki", 0.001), nav_params.get("orbit_kd", 1.0), 1000.0, 75.0
	)
	_pid_approach.initialize(
		nav_params.get("approach_kp", 0.5), nav_params.get("approach_ki", 0.001), nav_params.get("approach_kd", 1.0), 1000.0, o_limit
	)
	_pid_move_to.initialize(
		nav_params.get("move_to_kp", 0.5), nav_params.get("move_to_ki", 0.001), nav_params.get("move_to_kd", 1.0), 1000.0, o_limit
	)


func _initialize_command_handlers():
	var command_path = "res://core/agents/components/navigation_system/"
	_command_handlers = {
		CommandType.IDLE:           load(command_path + "command_idle.gd").new(),
		CommandType.STOPPING:       load(command_path + "command_stop.gd").new(),
		CommandType.MOVE_TO:        load(command_path + "command_move_to.gd").new(),
		CommandType.MOVE_DIRECTION: load(command_path + "command_move_direction.gd").new(),
		CommandType.APPROACH:       load(command_path + "command_approach.gd").new(),
		CommandType.ORBIT:          load(command_path + "command_orbit.gd").new(),
		CommandType.FLEE:           load(command_path + "command_flee.gd").new(),
		CommandType.ALIGN_TO:       load(command_path + "command_align_to.gd").new(),
	}

	for handler_script in _command_handlers.values():
		if handler_script.has_method("initialize"):
			handler_script.initialize(self)


# --- Public Command Setting Methods (Unchanged) ---
func set_command_idle():
	_current_command = {"type": CommandType.IDLE}

func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}
	if is_instance_valid(_pid_orbit): _pid_orbit.reset()
	if is_instance_valid(_pid_approach): _pid_approach.reset()
	if is_instance_valid(_pid_move_to): _pid_move_to.reset()

func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}
	if is_instance_valid(_pid_orbit): _pid_orbit.reset()
	if is_instance_valid(_pid_approach): _pid_approach.reset()
	if is_instance_valid(_pid_move_to): _pid_move_to.reset()

func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}

func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target}
	if is_instance_valid(_pid_orbit): _pid_orbit.reset()
	if is_instance_valid(_pid_approach): _pid_approach.reset()
	if is_instance_valid(_pid_move_to): _pid_move_to.reset()

func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.ORBIT, "target_node": target, "distance": distance, "clockwise": clockwise}
	if is_instance_valid(_pid_orbit): _pid_orbit.reset()
	if is_instance_valid(_pid_approach): _pid_approach.reset()
	if is_instance_valid(_pid_move_to): _pid_move_to.reset()

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

# --- Main Update Logic ---
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


# --- PID Correction & Helper Functions (Unchanged) ---
func apply_orbit_pid_correction(delta: float):
	if _current_command.get("type") != CommandType.ORBIT: return
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system) or not is_instance_valid(_pid_orbit): return

	var target_node = _current_command.get("target_node", null)
	if is_instance_valid(target_node):
		var desired_orbit_dist = _current_command.get("distance", 100.0)
		var vector_to_target = target_node.global_transform.origin - agent_body.global_transform.origin
		var current_distance = vector_to_target.length()
		if current_distance < 0.01: return

		var distance_error = current_distance - desired_orbit_dist
		var pid_output = _pid_orbit.update(distance_error, delta)
		
		var close_orbit_threshold = APPROACH_MIN_DISTANCE * CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
		if distance_error < 0 and desired_orbit_dist < close_orbit_threshold:
			var max_outward_push_speed = movement_system.max_move_speed * 0.05
			pid_output = max(pid_output, -max_outward_push_speed)

		var radial_direction = vector_to_target.normalized()
		var velocity_correction = radial_direction * pid_output
		agent_body.current_velocity += velocity_correction


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
