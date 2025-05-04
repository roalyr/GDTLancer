# File: res://core/agents/components/navigation_system.gd
# Version: 1.4.3 - Reworked size calculation to prioritize combined Model AABB radius.
extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.3  # Factor of target size for stopping distance
const APPROACH_MIN_DISTANCE = 50.0  # Minimum stopping distance regardless of size
const APPROACH_DECELERATION_START_DISTANCE_FACTOR = 50.0  # Start PID deceleration when distance <= this * desired_stop_dist

# Thresholds for considering PID-controlled arrival complete (tune these)
const ARRIVAL_DISTANCE_THRESHOLD = 5.0
const ARRIVAL_SPEED_THRESHOLD_SQ = 1.0  # Squared speed (1 m/s)^2
# Threshold for considering an orbit "close" to suppress strong outward push
const CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR = 1.5  # Multiplier for APPROACH_MIN_DISTANCE

# --- References (Set by AgentBody) ---
var agent_body: KinematicBody = null
var movement_system: Node = null  # Reference to the MovementSystem sibling node

# --- State ---
var _current_command = {}  # Holds the active command dictionary

# --- PID Controller Instances --- # DECLARED HERE, INSTANTIATED IN initialize_navigation
var _orbit_pid: PIDController = null  # For maintaining orbit distance
var _approach_pid: PIDController = null  # For controlling approach speed based on distance
var _move_to_pid: PIDController = null  # For controlling move speed based on distance

# --- Initialization ---


func _ready():
	# Initial state is typically set via AgentBody calling a command method
	# Ensure a default state if nothing else is called *after* initialization
	if not _current_command:
		set_command_idle()


# Called by AgentBody's initialize method
func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	# Store references provided by AgentBody
	movement_system = move_sys_ref
	agent_body = get_parent()  # Assume NavigationSystem is a direct child of AgentBody

	# Safety check references BEFORE using them
	if not is_instance_valid(agent_body):
		printerr("NavigationSystem Error: Parent AgentBody is not valid!")
		return
	if not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: MovementSystem reference is not valid!")
		return

	# --- Instantiate PID Controllers HERE ---
	var PIDControllerScript = load("res://core/utils/pid_controller.gd")
	if PIDControllerScript:
		_orbit_pid = PIDControllerScript.new()
		_approach_pid = PIDControllerScript.new()
		_move_to_pid = PIDControllerScript.new()
		print("NavigationSystem: PID Controllers instantiated.")
	else:
		printerr(
			"NavigationSystem Error: Failed to load PIDController script! Cannot initialize PIDs."
		)

	# --- Initialize PID controllers ---
	# Orbit PID
	if is_instance_valid(_orbit_pid):
		var pid_kp = nav_params.get("orbit_kp", 0.5)
		var pid_ki = nav_params.get("orbit_ki", 0.001)
		var pid_kd = nav_params.get("orbit_kd", 1.0)
		var pid_i_limit = nav_params.get("orbit_pid_integral_limit", 1000.0)
		var pid_o_limit = nav_params.get("orbit_pid_output_limit", 75.0)
		_orbit_pid.initialize(pid_kp, pid_ki, pid_kd, pid_i_limit, pid_o_limit)
		print("  Orbit PID Initialized (Kp=%.2f, Ki=%.2f, Kd=%.2f)" % [pid_kp, pid_ki, pid_kd])
	else:
		printerr(
			"NavigationSystem Error: _orbit_pid instance is not valid during initialization (Instantiation likely failed)."
		)

	# Approach PID (**NEEDS TUNING**)
	if is_instance_valid(_approach_pid):
		var ap_kp = nav_params.get("approach_kp", 0.5)
		var ap_ki = nav_params.get("approach_ki", 0.001)
		var ap_kd = nav_params.get("approach_kd", 1.0)
		var ap_o_limit = movement_system.max_move_speed
		_approach_pid.initialize(ap_kp, ap_ki, ap_kd, 1000.0, ap_o_limit)
		print(
			(
				"  Approach PID Initialized (**TUNE ME**: Kp=%.3f, Ki=%.3f, Kd=%.3f)"
				% [ap_kp, ap_ki, ap_kd]
			)
		)
	else:
		printerr(
			"NavigationSystem Error: _approach_pid instance not valid during init (Instantiation likely failed)."
		)

	# Move To PID (**NEEDS TUNING**)
	if is_instance_valid(_move_to_pid):
		var mt_kp = nav_params.get("move_to_kp", 0.5)
		var mt_ki = nav_params.get("move_to_ki", 0.001)
		var mt_kd = nav_params.get("move_to_kd", 1.0)
		var mt_o_limit = movement_system.max_move_speed
		_move_to_pid.initialize(mt_kp, mt_ki, mt_kd, 1000.0, mt_o_limit)
		print(
			(
				"  MoveTo PID Initialized (**TUNE ME**: Kp=%.3f, Ki=%.3f, Kd=%.3f)"
				% [mt_kp, mt_ki, mt_kd]
			)
		)
	else:
		printerr(
			"NavigationSystem Error: _move_to_pid instance not valid during init (Instantiation likely failed)."
		)

	print("NavigationSystem Initialized.")
	if not _current_command:
		set_command_idle()


# --- Public Command Setting Methods (Called by AgentBody) ---


func set_command_idle():
	var last_look = (
		-agent_body.global_transform.basis.z
		if is_instance_valid(agent_body)
		else Vector3.BACK
	)
	if _current_command:
		if "target_dir" in _current_command:
			last_look = _current_command.target_dir
		elif "target_node" in _current_command:
			var cmd_target = _current_command.get("target_node")
			if is_instance_valid(cmd_target) and is_instance_valid(agent_body):
				last_look = (cmd_target.global_transform.origin - agent_body.global_transform.origin).normalized()

	_current_command = {"type": CommandType.IDLE, "target_dir": last_look}


func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for MOVE_DIRECTION.")
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for APPROACH.")
		set_command_stopping()
		return

	if is_instance_valid(agent_body):
		var target_pos = target.global_transform.origin
		var target_size = _get_target_effective_size(target)  # This now returns radius
		# desired_stop_dist is distance from center, so use radius directly
		var desired_stop_dist = max(
			APPROACH_MIN_DISTANCE, target_size * APPROACH_DISTANCE_MULTIPLIER
		)
		var current_distance = agent_body.global_transform.origin.distance_to(target_pos)

		if current_distance < (desired_stop_dist + ARRIVAL_DISTANCE_THRESHOLD):
			print("Agent ", agent_body.name, " already within approach range. Switching to IDLE.")
			EventBus.emit_signal("agent_reached_destination", agent_body)
			set_command_idle()
			return

	_current_command = {"type": CommandType.APPROACH, "target_node": target}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


# Accepts the calculated/captured distance from the caller (e.g., agent.gd)
func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	if (
		_current_command.get("type") == CommandType.ORBIT
		and _current_command.get("target_node") == target
		and is_equal_approx(_current_command.get("distance"), distance)
		and _current_command.get("clockwise") == clockwise
	):
		return

	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for ORBIT.")
		set_command_stopping()
		return

	#print(distance)

	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": distance,  # Uses the distance passed in
		"clockwise": clockwise
	}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


func set_command_flee(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for FLEE.")
		set_command_stopping()
		return
	_current_command = {"type": CommandType.FLEE, "target_node": target}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


func set_command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for ALIGN_TO.")
		set_command_idle()
		return
	_current_command = {"type": CommandType.ALIGN_TO, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()
	if is_instance_valid(_approach_pid):
		_approach_pid.reset()
	if is_instance_valid(_move_to_pid):
		_move_to_pid.reset()


# --- Main Update Logic (Called by AgentBody._physics_process before move_and_slide) ---
func update_navigation(delta: float):
	# Check basic validity early
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	# --- Target Validity Check ---
	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd and not is_instance_valid(target_node):
		printerr(
			(
				"NavigationSystem: Target node for command %s became invalid."
				% CommandType.keys()[cmd_type]
			)
		)
		set_command_stopping()
		cmd_type = CommandType.STOPPING

	# --- Command Execution Logic ---
	match cmd_type:
		CommandType.IDLE:
			movement_system.apply_deceleration(delta)

		CommandType.STOPPING:
			var stopped = movement_system.apply_braking(delta)
			if stopped and not _current_command.get("signaled_stop", false):
				EventBus.emit_signal("agent_reached_destination", agent_body)
				_current_command["signaled_stop"] = true

		CommandType.MOVE_TO:
			if not is_instance_valid(_move_to_pid):
				printerr("NavigationSystem Error: MOVE_TO requires a valid _move_to_pid instance.")
				set_command_stopping()
				return

			var target_pos = _current_command.target_pos
			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			var distance_error = distance
			var pid_target_speed = _move_to_pid.update(distance_error, delta)
			pid_target_speed = clamp(pid_target_speed, 0, movement_system.max_move_speed)

			var direction = Vector3.ZERO
			if distance > 0.01:
				direction = vector_to_target.normalized()

			movement_system.apply_rotation(direction, delta)

			var target_velocity = direction * pid_target_speed
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)

			if (
				distance < ARRIVAL_DISTANCE_THRESHOLD
				and agent_body.current_velocity.length_squared() < ARRIVAL_SPEED_THRESHOLD_SQ
			):
				if not _current_command.get("signaled_stop", false):
					print("Agent ", agent_body.name, " reached move_to destination.")
					EventBus.emit_signal("agent_reached_destination", agent_body)
					_current_command["signaled_stop"] = true
				movement_system.apply_braking(delta)
			else:
				_current_command["signaled_stop"] = false

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				movement_system.apply_rotation(move_dir, delta)
				movement_system.apply_acceleration(move_dir, delta)
			else:
				movement_system.apply_deceleration(delta)

		CommandType.APPROACH:
			if not is_instance_valid(_approach_pid):
				printerr(
					"NavigationSystem Error: APPROACH requires a valid _approach_pid instance."
				)
				set_command_stopping()
				return

			var target_pos = target_node.global_transform.origin
			var target_size = _get_target_effective_size(target_node)  # Returns radius now
			# desired_stop_dist is distance from center
			var desired_stop_dist = max(
				APPROACH_MIN_DISTANCE, target_size * APPROACH_DISTANCE_MULTIPLIER
			)
			var deceleration_start_distance = (
				desired_stop_dist
				* APPROACH_DECELERATION_START_DISTANCE_FACTOR
			)
			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()

			# Early Exit Check
			if distance < (desired_stop_dist + ARRIVAL_DISTANCE_THRESHOLD):
				if not _current_command.get("signaled_stop", false):
					print(
						"Agent ", agent_body.name, " is within approach range. Switching to IDLE."
					)
					EventBus.emit_signal("agent_reached_destination", agent_body)
					_current_command["signaled_stop"] = true
				set_command_idle()
				movement_system.apply_braking(delta)
				return

			var direction = Vector3.ZERO
			if distance > 0.01:
				direction = vector_to_target.normalized()

			movement_system.apply_rotation(direction, delta)

			var target_velocity: Vector3
			if distance > deceleration_start_distance:
				# Far from target
				target_velocity = direction * movement_system.max_move_speed
				if is_instance_valid(_approach_pid):
					_approach_pid.reset()
				agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
					target_velocity, movement_system.acceleration * delta
				)
				_current_command["signaled_stop"] = false
			else:
				# Close to target (PID zone)
				var distance_error = distance - desired_stop_dist
				var pid_target_speed = 0.0
				if is_instance_valid(_approach_pid):
					pid_target_speed = _approach_pid.update(distance_error, delta)

				pid_target_speed = clamp(
					pid_target_speed,
					-movement_system.max_move_speed * 0.1,
					movement_system.max_move_speed
				)

				target_velocity = direction * pid_target_speed
				agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
					target_velocity, movement_system.acceleration * delta
				)

				# Completion Check (only in PID zone)
				var final_distance_error = distance - desired_stop_dist
				if (
					abs(final_distance_error) < ARRIVAL_DISTANCE_THRESHOLD
					and agent_body.current_velocity.length_squared() < ARRIVAL_SPEED_THRESHOLD_SQ
				):
					if not _current_command.get("signaled_stop", false):
						print("Agent ", agent_body.name, " reached approach destination.")
						EventBus.emit_signal("agent_reached_destination", agent_body)
						_current_command["signaled_stop"] = true
					movement_system.apply_braking(delta)
				else:
					_current_command["signaled_stop"] = false

		CommandType.ORBIT:
			if not is_instance_valid(_orbit_pid):
				printerr("NavigationSystem Error: ORBIT requires a valid _orbit_pid instance.")
				set_command_stopping()
				return

			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.get("distance", 100.0)  # The desired/captured distance
			var clockwise = _current_command.get("clockwise", false)

			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()  # Current distance
			if distance < 0.01:
				distance = 0.01
			var direction_to_target = vector_to_target / distance

			# Determine tangent direction
			var target_up = Vector3.UP
			var tangent_dir: Vector3
			var cross_fallback_axis = agent_body.global_transform.basis.x
			var cross_product = (
				direction_to_target.cross(target_up)
				if not clockwise
				else target_up.cross(direction_to_target)
			)
			if cross_product.length_squared() < 0.01:
				cross_product = (
					direction_to_target.cross(cross_fallback_axis)
					if not clockwise
					else cross_fallback_axis.cross(direction_to_target)
				)
			tangent_dir = cross_product.normalized()

			# Apply rotation towards the tangent direction
			movement_system.apply_rotation(tangent_dir, delta)

			# Calculate Target Tangential Speed based on desired orbit_dist
			var target_tangential_speed = 0.0
			var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
			if orbit_dist <= 0:
				target_tangential_speed = 0.0
			elif orbit_dist < full_speed_radius:
				target_tangential_speed = (
					movement_system.max_move_speed
					* (orbit_dist / full_speed_radius)
				)
			else:
				target_tangential_speed = movement_system.max_move_speed

			target_tangential_speed = clamp(
				target_tangential_speed, 0.0, movement_system.max_move_speed
			)

			# Interpolate velocity towards tangential target velocity
			var target_velocity = tangent_dir * target_tangential_speed
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)
			# PID correction for distance is applied separately

		CommandType.FLEE:
			var target_pos = target_node.global_transform.origin
			var vector_away = agent_body.global_transform.origin - target_pos
			var direction_away = Vector3.ZERO
			if vector_away.length_squared() > 0.01:
				direction_away = vector_away.normalized()
			else:
				direction_away = (
					-agent_body.global_transform.basis.z
					if agent_body.global_transform.basis.z.length_squared() > 0.01
					else Vector3.FORWARD
				)
			movement_system.apply_rotation(direction_away, delta)
			movement_system.apply_acceleration(direction_away, delta)

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			movement_system.apply_rotation(target_dir, delta)
			movement_system.apply_deceleration(delta)
			var current_fwd = -agent_body.global_transform.basis.z
			if current_fwd.dot(target_dir) > 0.999:
				set_command_idle()


# --- PID Correction Logic (Called by AgentBody._physics_process AFTER move_and_slide) ---
func apply_orbit_pid_correction(delta: float):
	# Only apply ORBIT PID correction here
	if _current_command.get("type") != CommandType.ORBIT:
		return
	# Check validity again
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return
	# Ensure the PID controller specifically needed is valid
	if not is_instance_valid(_orbit_pid):
		return

	var target_node = _current_command.get("target_node", null)
	if is_instance_valid(target_node):
		var desired_orbit_dist = _current_command.get("distance", 100.0)
		var target_pos = target_node.global_transform.origin
		var current_pos = agent_body.global_transform.origin
		var vector_to_target = target_pos - current_pos
		var current_distance = vector_to_target.length()

		if current_distance < 0.01:
			return  # Avoid division by zero

		# Error is how far we are from the desired orbit distance
		var distance_error = current_distance - desired_orbit_dist

		#print(desired_orbit_dist, " ", current_distance)

		var pid_output = _orbit_pid.update(distance_error, delta)

		# Dampen outward push for intentionally close orbits
		var close_orbit_threshold = APPROACH_MIN_DISTANCE * CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
		if distance_error < 0 and desired_orbit_dist < close_orbit_threshold:
			var max_outward_push_speed = movement_system.max_move_speed * 0.05
			pid_output = max(pid_output, -max_outward_push_speed)

		# Calculate the radial direction (points from agent towards target)
		var radial_direction = vector_to_target.normalized()

		# Apply correction velocity based on PID output
		var velocity_correction = radial_direction * pid_output

		# Apply the correction directly to the velocity
		agent_body.current_velocity += velocity_correction


# --- Helper Functions ---
# Calculates the effective radius of the target for interaction distances.
func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0  # Represents radius
	var default_radius = 10.0  # Fallback radius if nothing else works
	var found_source = "Default"  # Track where the size came from for debugging

	if not is_instance_valid(target_node):
		return default_radius

	# --- Priority 1: Explicit Interaction Radius Method ---
	if target_node.has_method("get_interaction_radius"):
		var explicit_radius = target_node.get_interaction_radius()
		if (explicit_radius is float or explicit_radius is int) and explicit_radius > 0:
			calculated_size = float(explicit_radius)  # Ensure it's a float
			found_source = "Method(get_interaction_radius)"
			# print("DEBUG Size Source: ", found_source, " | Value: ", calculated_size)
			return max(calculated_size, 1.0)  # Return early if found

	# --- Priority 2: Combined AABB of Visual Children under "Model" ---
	var model_node = target_node.get_node_or_null("Model")
	if is_instance_valid(model_node) and model_node is Spatial:
		var combined_aabb: AABB = AABB()  # Start with an empty AABB
		var first_visual_found = false

		# Iterate through all children of the "Model" node
		for child in model_node.get_children():
			if child is VisualInstance:  # Check if the child is renderable
				# Get the AABB in WORLD space
				var child_global_aabb = child.get_transformed_aabb()

				if not first_visual_found:
					# Initialize the combined AABB with the first visual child's AABB
					combined_aabb = child_global_aabb
					first_visual_found = true
				else:
					# Merge the current child's AABB with the combined AABB
					combined_aabb = combined_aabb.merge(child_global_aabb)

		# If we found at least one visual child and calculated a combined AABB
		if first_visual_found:
			# Calculate size based on the longest axis of the combined AABB
			var longest_axis_size = combined_aabb.get_longest_axis_size()
			# Divide by 2 to get the effective radius from the center
			calculated_size = longest_axis_size / 2.0
			if calculated_size > 0.01:
				found_source = "Combined Model AABB Radius"
				# print("DEBUG Size Source: ", found_source, " | Value: ", calculated_size)
				return max(calculated_size, 1.0)  # Return early if valid size found

	# --- Priority 3: Fallback to Target Node's Own Scale (if no method or valid Model AABB) ---
	var node_scale = target_node.global_transform.basis.get_scale()
	# Use the largest scale component as a rough radius estimate
	calculated_size = max(node_scale.x, max(node_scale.y, node_scale.z)) / 2.0  # Divide by 2 for radius
	if calculated_size <= 0.01:  # Check for zero or negative scale
		calculated_size = 1.0  # Use minimum radius if scale is invalid
	found_source = "Target Node Scale Radius"
	# print("DEBUG Size Source: ", found_source, " | Value: ", calculated_size)
	# Don't return early here, let final fallback check happen

	# --- Final Fallback: Default Radius ---
	if calculated_size < 1.0:  # If scale was tiny or zero
		calculated_size = default_radius
		found_source = "Default Fallback Radius"
		# print("DEBUG Size Source: ", found_source, " | Value: ", calculated_size)

	# Ensure radius is at least 1.0 before returning
	return max(calculated_size, 1.0)
