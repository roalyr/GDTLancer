# File: res://core/agents/components/navigation_system.gd
# Version: 1.1 - Refactored PID logic into separate PIDController class.
extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.5
const APPROACH_MIN_DISTANCE = 500.0

# --- References (Set by AgentBody) ---
var agent_body: KinematicBody = null
var movement_system: Node = null  # Reference to the MovementSystem sibling node

# --- State ---
var _current_command = {}  # Holds the active command dictionary

# --- PID Controller Instance --- # MODIFIED SECTION
var _orbit_pid: PIDController = null  # Instance of our PID controller class

# --- Initialization ---


func _ready():
	# Initial state is typically set via AgentBody calling a command method
	# Ensure a default state if nothing else is called
	if not _current_command:
		set_command_idle()

	# Preload the PIDController script (optional but good practice)
	var PIDControllerScript = load("res://core/utils/pid_controller.gd")
	if PIDControllerScript:
		_orbit_pid = PIDControllerScript.new()
	else:
		printerr("NavigationSystem Error: Failed to load PIDController script!")


# Called by AgentBody's initialize method
func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	# Store references provided by AgentBody
	movement_system = move_sys_ref
	agent_body = get_parent()

	# Initialize PID controller # MODIFIED SECTION
	if is_instance_valid(_orbit_pid):
		# Get gains/limits from nav_params or use defaults
		var pid_kp = nav_params.get("orbit_kp", 3.0)
		var pid_ki = nav_params.get("orbit_ki", 0.1)
		var pid_kd = nav_params.get("orbit_kd", 0.5)
		# Use defaults from old constants if not in nav_params
		var pid_i_limit = nav_params.get("orbit_pid_integral_limit", 1000.0)
		var pid_o_limit = nav_params.get("orbit_pid_output_limit", 50.0)
		_orbit_pid.initialize(pid_kp, pid_ki, pid_kd, pid_i_limit, pid_o_limit)
		print(
			(
				"NavigationSystem: PID Controller Initialized (Kp=%.2f, Ki=%.2f, Kd=%.2f)"
				% [pid_kp, pid_ki, pid_kd]
			)
		)
	else:
		printerr("NavigationSystem Error: _orbit_pid instance is not valid during initialization!")

	if not is_instance_valid(agent_body):
		printerr("NavigationSystem Error: Parent AgentBody is not valid!")
	if not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: MovementSystem reference is not valid!")

	print("NavigationSystem Initialized.")


# --- Public Command Setting Methods (Called by AgentBody) ---
# Calls to _reset_orbit_pid() are replaced with _orbit_pid.reset()


func set_command_idle():
	# Preserve last look direction if available
	var last_look = (
		-agent_body.global_transform.basis.z
		if is_instance_valid(agent_body)
		else Vector3.BACK
	)
	if _current_command:
		if "target_dir" in _current_command:
			last_look = _current_command.target_dir
		elif "target_node" in _current_command:
			var cmd_target = _current_command.target_node
			if is_instance_valid(cmd_target) and is_instance_valid(agent_body):
				last_look = (cmd_target.global_transform.origin - agent_body.global_transform.origin).normalized()

	_current_command = {"type": CommandType.IDLE, "target_dir": last_look}
	# No need to reset PID on idle


func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()  # Reset PID if stopping


func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for MOVE_DIRECTION.")
		set_command_stopping()  # Stop if direction is invalid
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for APPROACH.")
		set_command_stopping()  # Stop if target is invalid
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	# Prevent re-issuing the exact same orbit command details
	if (
		_current_command.get("type") == CommandType.ORBIT
		and _current_command.get("target_node") == target
		and is_equal_approx(_current_command.get("distance"), distance)
		and _current_command.get("clockwise") == clockwise
	):
		return  # Already orbiting this target with same params

	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for ORBIT.")
		set_command_stopping()  # Stop if target is invalid
		return

	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": distance,
		"clockwise": clockwise
	}
	# Reset PID state for the new/updated orbit command
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


func set_command_flee(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for FLEE.")
		set_command_stopping()  # Stop if target is invalid
		return
	_current_command = {"type": CommandType.FLEE, "target_node": target}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


func set_command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for ALIGN_TO.")
		set_command_idle()  # Go idle if direction is invalid
		return
	_current_command = {"type": CommandType.ALIGN_TO, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid):
		_orbit_pid.reset()


# --- Main Update Logic (Called by AgentBody._physics_process before move_and_slide) ---
func update_navigation(delta: float):
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		# Skip if references aren't valid (initialization might be pending/failed)
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	# --- Target Validity Check ---
	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd and not is_instance_valid(target_node):
		# If target becomes invalid mid-command, stop
		set_command_stopping()
		cmd_type = CommandType.STOPPING  # Update local type for this frame's match

	# --- Command Execution Logic ---
	match cmd_type:
		CommandType.IDLE:
			movement_system.apply_deceleration(delta)

		CommandType.STOPPING:
			var stopped = movement_system.apply_braking(delta)
			if stopped:
				# Check if we were already stopping to prevent repeated signals
				if _current_command.get("signaled_stop", false) == false:
					EventBus.emit_signal("agent_reached_destination", agent_body)
					_current_command["signaled_stop"] = true  # Mark as signaled
				# Stay stopping until new command
				pass

		CommandType.MOVE_TO:
			var target_pos = _current_command.target_pos
			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance_sq = vector_to_target.length_squared()
			var stopping_dist_sq = pow(10.0, 2)  # Simple fixed stopping distance

			if distance_sq < stopping_dist_sq:
				set_command_stopping()  # Initiate stop
			else:
				var direction = vector_to_target.normalized()
				movement_system.apply_rotation(direction, delta)
				movement_system.apply_acceleration(direction, delta)

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				movement_system.apply_rotation(move_dir, delta)
				movement_system.apply_acceleration(move_dir, delta)
			else:
				movement_system.apply_deceleration(delta)

		CommandType.APPROACH:
			var target_pos = target_node.global_transform.origin
			var target_size = _get_target_effective_size(target_node)
			var desired_stop_dist = max(
				APPROACH_MIN_DISTANCE, target_size * APPROACH_DISTANCE_MULTIPLIER
			)
			var upper_bound = desired_stop_dist * 1.10
			var lower_bound = desired_stop_dist * 0.98

			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			var direction = Vector3.ZERO
			if distance > 0.01:
				direction = vector_to_target.normalized()

			movement_system.apply_rotation(direction, delta)

			if distance > upper_bound:
				movement_system.apply_acceleration(direction, delta)
			elif distance <= lower_bound:
				set_command_stopping()  # Initiate stop
			else:
				movement_system.apply_deceleration(delta)

		CommandType.ORBIT:
			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.get("distance", 100.0)
			var clockwise = _current_command.get("clockwise", false)

			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			if distance < 0.1:
				distance = 0.1
			var direction_to_target = vector_to_target / distance

			# Calculate tangent direction
			var target_up = Vector3.UP
			var tangent_dir = Vector3.ZERO
			# Use local X axis as fallback if target is directly above/below
			var cross_fallback_axis = agent_body.global_transform.basis.x
			if clockwise:
				tangent_dir = target_up.cross(direction_to_target).normalized()
				if tangent_dir.length_squared() < 0.1:  # Check if cross product is near zero
					tangent_dir = cross_fallback_axis.cross(direction_to_target).normalized()
			else:
				tangent_dir = direction_to_target.cross(target_up).normalized()
				if tangent_dir.length_squared() < 0.1:  # Check if cross product is near zero
					tangent_dir = direction_to_target.cross(cross_fallback_axis).normalized()

			# Rotate to face tangent direction
			movement_system.apply_rotation(tangent_dir, delta)

			# Calculate Target Tangential Speed based on distance
			var target_tangential_speed = 0.0
			# Ensure full_speed_radius is positive to avoid division issues
			var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
			if orbit_dist <= 0:
				target_tangential_speed = 0.0
			elif orbit_dist < full_speed_radius:
				# Scale speed linearly based on distance within the full speed radius
				target_tangential_speed = (
					movement_system.max_move_speed
					* (distance / full_speed_radius)
				)
			else:
				# Use full speed outside the designated radius
				target_tangential_speed = movement_system.max_move_speed

			# Clamp speed to ensure it doesn't exceed maximum capabilities
			target_tangential_speed = clamp(
				target_tangential_speed, 0.0, movement_system.max_move_speed
			)

			# Calculate target velocity based only on tangential component
			var target_velocity = tangent_dir * target_tangential_speed

			# Interpolate current velocity towards the target *tangential* velocity
			# Let the PID controller apply radial correction *after* move_and_slide
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)

		CommandType.FLEE:
			var target_pos = target_node.global_transform.origin
			var vector_away = agent_body.global_transform.origin - target_pos
			# Default flee direction is current forward if vector is zero
			var direction_away = -agent_body.global_transform.basis.z
			if vector_away.length_squared() > 0.01:
				direction_away = vector_away.normalized()

			movement_system.apply_rotation(direction_away, delta)
			movement_system.apply_acceleration(direction_away, delta)

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			movement_system.apply_rotation(target_dir, delta)
			movement_system.apply_deceleration(delta)  # Slow down while aligning
			var current_fwd = -agent_body.global_transform.basis.z
			# Check if alignment is very close using dot product
			if current_fwd.dot(target_dir) > 0.998:
				set_command_idle()  # Switch to idle once aligned


# --- PID Correction Logic (Called by AgentBody._physics_process AFTER move_and_slide) ---
func apply_orbit_pid_correction(delta: float):
	# Only apply if the current command is still ORBIT
	if _current_command.get("type") != CommandType.ORBIT:
		return
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return
	if not is_instance_valid(_orbit_pid):  # Check if PID controller is valid
		printerr("NavigationSystem Error: Orbit PID controller instance is invalid!")
		return

	var target_node = _current_command.get("target_node", null)
	if is_instance_valid(target_node):
		var desired_orbit_dist = _current_command.get("distance", 100.0)
		var target_pos = target_node.global_transform.origin
		# Use the agent body's *current* position post-move_and_slide
		var current_pos = agent_body.global_transform.origin

		var vector_to_target = target_pos - current_pos  # Vector from ship to target
		var current_distance = vector_to_target.length()

		# Error: Positive if too far, Negative if too close
		var distance_error = current_distance - desired_orbit_dist

		# --- PID Calculation (Using the PIDController instance) --- # MODIFIED SECTION
		var pid_output = _orbit_pid.update(distance_error, delta)
		# --- End PID Calculation ---

		# Calculate correction velocity vector (radially in/out from target)
		# Points OUT from target center towards the agent
		var radial_direction = -vector_to_target.normalized()
		if vector_to_target.length_squared() < 0.001:
			radial_direction = Vector3.ZERO

		# Apply PID output as velocity correction FOR THE NEXT FRAME
		# Negative sign needed because a positive pid_output (meaning too far)
		# should result in velocity pulling *towards* the target (positive radial_direction).
		var velocity_correction = radial_direction * pid_output
		# --- IMPORTANT: Modify the PARENT's velocity ---
		agent_body.current_velocity -= velocity_correction * delta  # Apply correction


# --- Helper Functions ---

# REMOVED _reset_orbit_pid() function


# Target Size Helper (Copied from agent.gd)
func _get_target_effective_size(target_node: Spatial) -> float:
	# This function needs access to the target node, but not agent state directly
	var calculated_size = 1.0
	var default_size = 50.0
	var found_source = false
	if not is_instance_valid(target_node):
		return default_size
	if target_node.has_method("get_interaction_radius"):
		var explicit_size = target_node.get_interaction_radius()
		if (explicit_size is float or explicit_size is int) and explicit_size > 0:
			calculated_size = explicit_size
			found_source = true
	if not found_source:
		var model_node = target_node.get_node_or_null("Model")  # Assuming model node is named "Model"
		if is_instance_valid(model_node) and model_node is Spatial:
			# Attempt to get AABB size if model is VisualInstance based
			if model_node is VisualInstance:
				var aabb: AABB = model_node.get_aabb()
				# Use the largest dimension of the AABB as the size proxy
				calculated_size = (
					max(aabb.size.x, max(aabb.size.y, aabb.size.z))
					* max(
						model_node.global_transform.basis.get_scale().x,
						max(
							model_node.global_transform.basis.get_scale().y,
							model_node.global_transform.basis.get_scale().z
						)
					)
				)
			else:
				# Fallback for non-VisualInstance models: Use scale
				var model_scale = model_node.global_transform.basis.get_scale()
				calculated_size = max(model_scale.x, max(model_scale.y, model_scale.z))

			if calculated_size <= 0:
				calculated_size = 1.0  # Ensure size is at least 1
			found_source = true

	if not found_source:
		calculated_size = default_size  # Fallback to default if no size found

	return max(calculated_size, 1.0)  # Ensure minimum size of 1
