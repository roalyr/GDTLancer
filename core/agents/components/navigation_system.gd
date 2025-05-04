# File: res://core/agents/components/navigation_system.gd
# Version: 1.2.1 - Fixed PID instantiation order.
extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.5
const APPROACH_MIN_DISTANCE = 500.0
# Thresholds for considering PID-controlled arrival complete (tune these)
const ARRIVAL_DISTANCE_THRESHOLD = 5.0
const ARRIVAL_SPEED_THRESHOLD_SQ = 1.0  # Squared speed (1 m/s)^2

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
	# Note: PIDs are now instantiated in initialize_navigation
	if not _current_command:
		set_command_idle()

# Called by AgentBody's initialize method
func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	# Store references provided by AgentBody
	movement_system = move_sys_ref
	agent_body = get_parent() # Assume NavigationSystem is a direct child of AgentBody

	# Safety check references BEFORE using them
	if not is_instance_valid(agent_body):
		printerr("NavigationSystem Error: Parent AgentBody is not valid!")
		return # Cannot proceed without agent body
	if not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: MovementSystem reference is not valid!")
		# Could potentially continue without movement system for some logic,
		# but PID initialization relies on it for max speed, so return here too.
		return

	# --- Instantiate PID Controllers HERE ---
	var PIDControllerScript = load("res://core/utils/pid_controller.gd")
	if PIDControllerScript:
		_orbit_pid = PIDControllerScript.new()
		_approach_pid = PIDControllerScript.new()
		_move_to_pid = PIDControllerScript.new()
		print("NavigationSystem: PID Controllers instantiated.") # Moved print here
	else:
		printerr("NavigationSystem Error: Failed to load PIDController script! Cannot initialize PIDs.")
		# PIDs will remain null, subsequent checks will fail gracefully
		# but PID functionality will be disabled.

	# --- Initialize PID controllers ---
	# Now we can safely check is_instance_valid because we *attempted* instantiation above.

	# Orbit PID
	if is_instance_valid(_orbit_pid):
		var pid_kp = nav_params.get("orbit_kp", 0.1)
		var pid_ki = nav_params.get("orbit_ki", 0.0)
		var pid_kd = nav_params.get("orbit_kd", 0.05)
		var pid_i_limit = nav_params.get("orbit_pid_integral_limit", 1000.0)
		var pid_o_limit = nav_params.get("orbit_pid_output_limit", 50.0)
		_orbit_pid.initialize(pid_kp, pid_ki, pid_kd, pid_i_limit, pid_o_limit)
		print("  Orbit PID Initialized (Kp=%.2f, Ki=%.2f, Kd=%.2f)" % [pid_kp, pid_ki, pid_kd])
	else:
		# This error now means instantiation failed (script load error)
		printerr("NavigationSystem Error: _orbit_pid instance is not valid during initialization (Instantiation likely failed).")

	# Approach PID (Gains suggested for 300 m/s max speed, 150 m/s^2 accel - **NEEDS TUNING**)
	if is_instance_valid(_approach_pid):
		var ap_kp = nav_params.get("approach_kp", 0.1)
		var ap_ki = nav_params.get("approach_ki", 0.0)
		var ap_kd = nav_params.get("approach_kd", 0.5)
		# Safely access max_move_speed now that move_sys_ref check passed
		var ap_o_limit = movement_system.max_move_speed
		_approach_pid.initialize(ap_kp, ap_ki, ap_kd, 1000.0, ap_o_limit)
		print("  Approach PID Initialized (Kp=%.3f, Ki=%.3f, Kd=%.3f)" % [ap_kp, ap_ki, ap_kd])
	else:
		printerr("NavigationSystem Error: _approach_pid instance not valid during init (Instantiation likely failed).")

	# Move To PID (Gains suggested for 300 m/s max speed, 150 m/s^2 accel - **NEEDS TUNING**)
	if is_instance_valid(_move_to_pid):
		var mt_kp = nav_params.get("move_to_kp", 0.1)
		var mt_ki = nav_params.get("move_to_ki", 0.0)
		var mt_kd = nav_params.get("move_to_kd", 0.5)
		# Safely access max_move_speed now that move_sys_ref check passed
		var mt_o_limit = movement_system.max_move_speed
		_move_to_pid.initialize(mt_kp, mt_ki, mt_kd, 1000.0, mt_o_limit)
		print("  MoveTo PID Initialized (Kp=%.3f, Ki=%.3f, Kd=%.3f)" % [mt_kp, mt_ki, mt_kd])
	else:
		printerr("NavigationSystem Error: _move_to_pid instance not valid during init (Instantiation likely failed).")

	print("NavigationSystem Initialized.")
	# Set initial command *after* everything is set up, if needed
	# Or rely on AgentBody to issue the first command post-initialization.
	# Let's keep the _ready check for a default idle state for safety.
	# if not _current_command:
	#     set_command_idle()


# --- Public Command Setting Methods (Called by AgentBody) ---
# (Reset logic remains the same, but now we are sure the PIDs exist
# or are properly null if instantiation failed)

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
			var cmd_target = _current_command.target_node
			if is_instance_valid(cmd_target) and is_instance_valid(agent_body):
				last_look = (cmd_target.global_transform.origin - agent_body.global_transform.origin).normalized()

	_current_command = {"type": CommandType.IDLE, "target_dir": last_look}
	# No need to reset PIDs on idle

func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for MOVE_DIRECTION.")
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for APPROACH.")
		set_command_stopping()
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	# Re-issue check
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

	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": distance,
		"clockwise": clockwise
	}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_flee(target: Spatial):
	if not is_instance_valid(target):
		printerr("NavigationSystem: Invalid target node for FLEE.")
		set_command_stopping()
		return
	_current_command = {"type": CommandType.FLEE, "target_node": target}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()

func set_command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("NavigationSystem: Invalid direction vector for ALIGN_TO.")
		set_command_idle() # Go idle if direction is invalid
		return
	_current_command = {"type": CommandType.ALIGN_TO, "target_dir": direction.normalized()}
	if is_instance_valid(_orbit_pid): _orbit_pid.reset()
	if is_instance_valid(_approach_pid): _approach_pid.reset()
	if is_instance_valid(_move_to_pid): _move_to_pid.reset()


# --- Main Update Logic (Called by AgentBody._physics_process before move_and_slide) ---
func update_navigation(delta: float):
	# Check basic validity early
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		# Print error only once maybe? Or rely on initialization errors.
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null) # Get potential target node

	# --- Target Validity Check (for commands requiring a target node) ---
	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd and not is_instance_valid(target_node):
		# Target became invalid after command was issued
		printerr("NavigationSystem: Target node for command %s became invalid." % CommandType.keys()[cmd_type])
		set_command_stopping()
		cmd_type = CommandType.STOPPING # Update local type for this frame's match

	# --- Command Execution Logic ---
	match cmd_type:
		CommandType.IDLE:
			movement_system.apply_deceleration(delta)

		CommandType.STOPPING:
			var stopped = movement_system.apply_braking(delta)
			if stopped and not _current_command.get("signaled_stop", false):
				EventBus.emit_signal("agent_reached_destination", agent_body)
				_current_command["signaled_stop"] = true
			# Stay stopping even after signal

		CommandType.MOVE_TO:
			# Check PID validity specifically for this command
			if not is_instance_valid(_move_to_pid):
				printerr("NavigationSystem Error: MOVE_TO requires a valid _move_to_pid instance.")
				set_command_stopping() # Fallback if PID isn't available
				return # Skip rest of MOVE_TO logic

			var target_pos = _current_command.target_pos
			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			var distance_error = distance
			var pid_target_speed = _move_to_pid.update(distance_error, delta)
			pid_target_speed = clamp(pid_target_speed, 0, movement_system.max_move_speed)

			var direction = Vector3.ZERO
			if distance > 0.01: # Avoid normalization of zero vector
				direction = vector_to_target.normalized()

			movement_system.apply_rotation(direction, delta)

			var target_velocity = direction * pid_target_speed
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)

			# Completion Check
			if (distance < ARRIVAL_DISTANCE_THRESHOLD and
				agent_body.current_velocity.length_squared() < ARRIVAL_SPEED_THRESHOLD_SQ):
				if not _current_command.get("signaled_stop", false):
					print("Agent ", agent_body.name, " reached move_to destination.")
					EventBus.emit_signal("agent_reached_destination", agent_body)
					_current_command["signaled_stop"] = true
				movement_system.apply_braking(delta) # Gentle stop
			else:
				_current_command["signaled_stop"] = false # Reset if we overshoot or condition not met

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				movement_system.apply_rotation(move_dir, delta)
				movement_system.apply_acceleration(move_dir, delta)
			else:
				# Invalid direction likely handled by setter, but decelerate just in case
				movement_system.apply_deceleration(delta)

		CommandType.APPROACH:
			# Check PID validity specifically for this command
			if not is_instance_valid(_approach_pid):
				printerr("NavigationSystem Error: APPROACH requires a valid _approach_pid instance.")
				set_command_stopping() # Fallback if PID isn't available
				return # Skip rest of APPROACH logic

			# Target validity already checked at the start of the function
			var target_pos = target_node.global_transform.origin
			var target_size = _get_target_effective_size(target_node)
			var desired_stop_dist = max(
				APPROACH_MIN_DISTANCE, target_size * APPROACH_DISTANCE_MULTIPLIER
			)

			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			var direction = Vector3.ZERO
			if distance > 0.01:
				direction = vector_to_target.normalized()

			movement_system.apply_rotation(direction, delta)

			var distance_error = distance - desired_stop_dist
			var pid_target_speed = _approach_pid.update(distance_error, delta)
			pid_target_speed = clamp(
				pid_target_speed,
				-movement_system.max_move_speed * 0.1, # Allow slight reverse
				movement_system.max_move_speed
			)

			var target_velocity = direction * pid_target_speed
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)

			# Completion Check
			if (abs(distance_error) < ARRIVAL_DISTANCE_THRESHOLD and
				agent_body.current_velocity.length_squared() < ARRIVAL_SPEED_THRESHOLD_SQ):
				if not _current_command.get("signaled_stop", false):
					print("Agent ", agent_body.name, " reached approach destination.")
					EventBus.emit_signal("agent_reached_destination", agent_body)
					_current_command["signaled_stop"] = true
				movement_system.apply_braking(delta) # Gentle stop
			else:
				_current_command["signaled_stop"] = false # Reset if we overshoot or condition not met

		CommandType.ORBIT:
			# Check PID validity specifically for this command (used in apply_orbit_pid_correction)
			if not is_instance_valid(_orbit_pid):
				printerr("NavigationSystem Error: ORBIT requires a valid _orbit_pid instance.")
				set_command_stopping() # Fallback if PID isn't available
				return # Skip rest of ORBIT logic

			# Target validity already checked at the start of the function
			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.get("distance", 100.0)
			var clockwise = _current_command.get("clockwise", false)

			var vector_to_target = target_pos - agent_body.global_transform.origin
			var distance = vector_to_target.length()
			# Avoid division by zero if exactly on top of target
			if distance < 0.01: distance = 0.01
			var direction_to_target = vector_to_target / distance

			# Determine tangent direction (simplified, assumes mostly planar movement for Up vector)
			var target_up = Vector3.UP
			var tangent_dir : Vector3
			# Use agent's right vector as fallback if target is directly above/below
			var cross_fallback_axis = agent_body.global_transform.basis.x
			var cross_product = direction_to_target.cross(target_up) if not clockwise else target_up.cross(direction_to_target)

			if cross_product.length_squared() < 0.01: # Check if aligned with target_up
				cross_product = direction_to_target.cross(cross_fallback_axis) if not clockwise else cross_fallback_axis.cross(direction_to_target)

			tangent_dir = cross_product.normalized()

			# Apply rotation towards the tangent
			movement_system.apply_rotation(tangent_dir, delta)

			# Calculate target speed based on orbit distance (same as before)
			var target_tangential_speed = 0.0
			var full_speed_radius = Constants.ORBIT_FULL_SPEED_RADIUS
			if orbit_dist <= 0:
				target_tangential_speed = 0.0
			elif orbit_dist < full_speed_radius:
				target_tangential_speed = movement_system.max_move_speed * (distance / full_speed_radius)
			else:
				target_tangential_speed = movement_system.max_move_speed
			target_tangential_speed = clamp(target_tangential_speed, 0.0, movement_system.max_move_speed)

			# Interpolate velocity towards tangential target velocity
			var target_velocity = tangent_dir * target_tangential_speed
			agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
				target_velocity, movement_system.acceleration * delta
			)
			# PID correction for distance applied in apply_orbit_pid_correction

		CommandType.FLEE:
			# Target validity already checked at the start of the function
			var target_pos = target_node.global_transform.origin
			var vector_away = agent_body.global_transform.origin - target_pos
			var direction_away = Vector3.ZERO
			if vector_away.length_squared() > 0.01:
				direction_away = vector_away.normalized()
			else:
				# If exactly on top, flee in current forward direction or an arbitrary one
				direction_away = -agent_body.global_transform.basis.z if agent_body.global_transform.basis.z.length_squared() > 0.01 else Vector3.FORWARD

			movement_system.apply_rotation(direction_away, delta)
			movement_system.apply_acceleration(direction_away, delta)

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			movement_system.apply_rotation(target_dir, delta)
			movement_system.apply_deceleration(delta) # Slow down while aligning

			# Check if alignment is complete
			var current_fwd = -agent_body.global_transform.basis.z
			# Use a tolerance for floating point comparison
			if current_fwd.dot(target_dir) > 0.999: # Increased precision slightly
				set_command_idle() # Alignment complete, go idle

# --- PID Correction Logic (Called by AgentBody._physics_process AFTER move_and_slide) ---
func apply_orbit_pid_correction(delta: float):
	# Only apply ORBIT PID correction here
	if _current_command.get("type") != CommandType.ORBIT:
		return
	# Check validity again, could have become invalid between update and correction
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return
	# Ensure the PID controller specifically needed is valid
	if not is_instance_valid(_orbit_pid):
		# Error already printed during update, no need to repeat spam usually
		# printerr("NavigationSystem Error: Orbit PID controller instance is invalid in correction!")
		return

	var target_node = _current_command.get("target_node", null)
	# Also re-check target validity here
	if is_instance_valid(target_node):
		var desired_orbit_dist = _current_command.get("distance", 100.0)
		var target_pos = target_node.global_transform.origin
		var current_pos = agent_body.global_transform.origin
		var vector_to_target = target_pos - current_pos
		var current_distance = vector_to_target.length()

		# Avoid issues if distance is zero
		if current_distance < 0.01:
			# Cannot determine radial direction, skip correction this frame
			return

		var distance_error = current_distance - desired_orbit_dist
		var pid_output = _orbit_pid.update(distance_error, delta)

		# Radial direction points from target towards agent
		var radial_direction = -vector_to_target.normalized()

		# Apply correction *against* current velocity
		# Subtracting means positive PID output (too far) pushes towards target
		# Negative PID output (too close) pushes away from target
		var velocity_correction = radial_direction * pid_output

		# Apply the correction scaled by delta
		# Note: Applying directly to velocity *after* move_and_slide can feel 'snappy'.
		# Consider if applying force/acceleration based on PID output is smoother.
		# For now, keeping direct velocity adjustment as implied by original code.
		agent_body.current_velocity -= velocity_correction # Removed delta scaling here - PID output often represents a target *rate* or *force*, applying directly might be intended. If it feels too strong, re-add * delta. Check PIDController implementation details. Assuming output is corrective velocity delta.

# --- Helper Functions ---

# Target Size Helper (Unchanged - Make sure Constants exists and has the key if used)
func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0
	var default_size = 50.0
	var found_source = false

	if not is_instance_valid(target_node):
		return default_size

	# 1. Check for explicit method
	if target_node.has_method("get_interaction_radius"):
		var explicit_size = target_node.get_interaction_radius()
		if (explicit_size is float or explicit_size is int) and explicit_size > 0:
			calculated_size = float(explicit_size) # Cast to float
			found_source = true
			# print("Found size via get_interaction_radius: ", calculated_size) # Debug

	# 2. Check for 'Model' child VisualInstance AABB (more reliable for meshes)
	if not found_source:
		var model_node = target_node.get_node_or_null("Model")
		if is_instance_valid(model_node) and model_node is VisualInstance: # Check if it's renderable
			var aabb: AABB = model_node.get_aabb()
			# Use the largest dimension of the AABB multiplied by the largest scale component
			var model_scale = model_node.global_transform.basis.get_scale()
			var max_scale = max(model_scale.x, max(model_scale.y, model_scale.z))
			calculated_size = aabb.get_longest_axis_size() * max_scale
			if calculated_size > 0.01: # Ensure valid size
				found_source = true
				# print("Found size via Model AABB: ", calculated_size) # Debug
			else:
				# Fallback if AABB is zero/invalid but Model exists
				calculated_size = max(max_scale, 1.0) # Use scale directly
				found_source = true # Still counts as found from Model node
				# print("Found size via Model Scale (AABB fallback): ", calculated_size) # Debug


	# 3. Fallback to target node's own scale if no explicit size or valid Model found
	if not found_source:
		var node_scale = target_node.global_transform.basis.get_scale()
		calculated_size = max(node_scale.x, max(node_scale.y, node_scale.z))
		if calculated_size <= 0.01: # Check for zero or negative scale
			calculated_size = 1.0 # Use minimum size
		# print("Found size via Node Scale: ", calculated_size) # Debug
		# No need to set found_source = true, if we reach here, we use this or default

	# 4. Final fallback to default size if no other source worked or calculated size is tiny
	if not found_source or calculated_size < 1.0:
		# print("Using default size: ", default_size) # Debug
		calculated_size = default_size


	return max(calculated_size, 1.0) # Ensure size is at least 1.0
