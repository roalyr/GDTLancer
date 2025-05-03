# File: core/agents/agent.gd
# Version 3.26 - Added direct post-move velocity correction for orbit distance maintenance.
extends KinematicBody

# --- Command Types Enumeration ---
enum CommandType {
	IDLE,         # Drifting, decelerating naturally
	STOPPING,     # Actively braking to a halt
	MOVE_TO,      # Move towards a specific Vector3 position
	MOVE_DIRECTION,# Move continuously in a specific direction vector
	APPROACH,     # Move towards a target node, stopping at a set distance
	ORBIT,        # Attempt to orbit a target node at a set distance
	FLEE,         # Move directly away from a target node
	ALIGN_TO      # Rotate to face a specific direction vector
}

# --- Agent Identification ---
var agent_name: String = "Default Agent"
var faction_id: String = "Neutral"
var template_id: String = "default"

# --- Movement Capabilities ---
var max_move_speed: float = 0.0
var acceleration: float = 0.0
var deceleration: float = 0.0
var brake_strength: float = 0.0
var max_turn_speed: float = 0.0

var interaction_radius: float = 0.0 # Can still be used as override via template/method

# --- Alignment Threshold (Read from Template) ---
# Agent will only accelerate forward if facing within this angle (degrees) of the target direction.
var alignment_threshold_angle_deg: float = 45.0 # Default, overridden by template/override
var _alignment_threshold_rad: float = 0.0 # Calculated in initialize

# --- Constants for Approach ---
const APPROACH_DISTANCE_MULTIPLIER = 1.5
const APPROACH_MIN_DISTANCE = 500.0 # Minimum distance regardless of target size

# --- Current State ---
var current_velocity: Vector3 = Vector3.ZERO
var _current_command = {} # Set in initialize
var _is_braking: bool = false

# --- Initialization ---
func initialize(template: AgentTemplate, overrides: Dictionary = {}):
	if not template is AgentTemplate:
		printerr("Agent Initialize Error: Invalid template for ", self.name)
		return

	# Load base stats from template, apply overrides
	self.template_id = template.template_id
	var default_name = template.default_agent_name + \
			"_" + str(get_instance_id())
	self.agent_name = overrides.get("name", default_name)
	self.faction_id = overrides.get("faction", template.default_faction_id)
	self.max_move_speed = overrides.get("max_move_speed",
		template.max_move_speed)
	self.acceleration = overrides.get("acceleration",
		template.acceleration)
	self.deceleration = overrides.get("deceleration",
		template.deceleration)
	self.max_turn_speed = overrides.get("max_turn_speed",
		template.max_turn_speed)
	var default_brake = self.deceleration * 1.5
	self.brake_strength = overrides.get("brake_strength", default_brake)
	self.name = self.agent_name # Set Node name
	self.interaction_radius = overrides.get("interaction_radius", template.interaction_radius)

	# Read alignment threshold from template, apply overrides, calculate radians
	self.alignment_threshold_angle_deg = overrides.get("alignment_threshold_angle_deg", template.alignment_threshold_angle_deg)
	_alignment_threshold_rad = deg2rad(self.alignment_threshold_angle_deg)

	_set_command_idle() # Start idle
	print(self.name + " initialized template '", self.template_id, "'. Alignment Threshold: ", alignment_threshold_angle_deg, " deg")

# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	set_physics_process(true)
	# Basic check if initialize might not have run (e.g., if placed directly in scene)
	if _alignment_threshold_rad == 0.0 and alignment_threshold_angle_deg != 0.0:
		_alignment_threshold_rad = deg2rad(alignment_threshold_angle_deg)


func _physics_process(delta):
	# Calculate desired velocity based on current command
	_execute_current_command(delta)

	# Apply calculated velocity and handle collisions using move_and_slide
	current_velocity = move_and_slide(current_velocity, Vector3.UP)

	# --- Post-Move Orbit Distance Correction (Velocity Adjustment) ---
	# If orbiting, check distance *after* move_and_slide and apply a velocity correction for the *next* frame
	if _current_command.get("type") == CommandType.ORBIT:
		var target_node = _current_command.get("target_node", null)
		if is_instance_valid(target_node):
			var orbit_dist = _current_command.get("distance", 100.0)
			var target_pos = target_node.global_transform.origin
			var current_pos = global_transform.origin

			var current_distance = current_pos.distance_to(target_pos)
			var distance_error = current_distance - orbit_dist

			var correction_tolerance = 1.0 # Allowable deviation before correction starts (TUNABLE)
			# Strength factor for the velocity nudge (Higher = stronger correction) (TUNABLE)
			var radial_velocity_correction_strength = 5.0

			# If distance error exceeds tolerance, apply a corrective nudge to velocity
			if abs(distance_error) > correction_tolerance:
				# Calculate direction pointing radially outward from the target center
				var radial_direction = (current_pos - target_pos).normalized()
				# Calculate velocity adjustment nudge based on error and strength
				# Points outwards if error is positive (too far)
				# Points inwards if error is negative (too close)
				var velocity_nudge = radial_direction * distance_error * radial_velocity_correction_strength

				# Apply the nudge to the current velocity, scaled by delta, for the next frame's calculation
				# We SUBTRACT the nudge:
				# - If too far (error > 0), nudge points OUT, subtracting adds INWARD velocity.
				# - If too close (error < 0), nudge points IN, subtracting adds OUTWARD velocity.
				current_velocity -= velocity_nudge * delta
				# print("Orbit Correction: Dist=", current_distance, " Err=", distance_error, " Nudge=", velocity_nudge * delta) # Debug

	# --- Final Velocity Clamp ---
	# Clamp velocity magnitude *after* move_and_slide AND correction to ensure max speed is respected
	if current_velocity.length_squared() > max_move_speed * max_move_speed:
		 current_velocity = current_velocity.normalized() * max_move_speed


# --- Command Execution Logic ---
# Calculates the *target* velocity for interpolation based on the command
func _execute_current_command(delta):
	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	var is_target_cmd = cmd_type in [CommandType.APPROACH,
			CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd:
		if not is_instance_valid(target_node):
			command_stop()
			cmd_type = _current_command.get("type", CommandType.STOPPING) # Re-get type after command change

	match cmd_type:
		CommandType.IDLE:
			_apply_deceleration(delta)

		CommandType.STOPPING:
			var stopped = _apply_braking(delta)
			if stopped:
				EventBus.emit_signal("agent_reached_destination", self)
				_set_command_idle()

		CommandType.MOVE_TO:
			var target_pos = _current_command.target_pos
			var vector_to_target = target_pos - global_transform.origin
			var distance_sq = vector_to_target.length_squared()
			var stopping_dist_sq = pow(10.0, 2)

			if distance_sq < stopping_dist_sq:
				command_stop()
			else:
				var direction = vector_to_target.normalized()
				_apply_rotation(delta, direction)
				_apply_acceleration(delta, direction) # Applies acceleration towards target velocity if aligned

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				_apply_rotation(delta, move_dir)
				_apply_acceleration(delta, move_dir) # Applies acceleration towards target velocity if aligned
			else:
				_apply_deceleration(delta)

		CommandType.APPROACH:
			if not is_instance_valid(target_node):
				command_stop(); return
			var target_pos = target_node.global_transform.origin
			var target_size = _get_target_effective_size(target_node)
			var desired_stop_dist = max(APPROACH_MIN_DISTANCE, target_size * APPROACH_DISTANCE_MULTIPLIER)
			var upper_bound = desired_stop_dist * 1.10
			var lower_bound = desired_stop_dist * 0.98

			var vector_to_target = target_pos - global_transform.origin
			var distance = vector_to_target.length()
			var direction = Vector3.ZERO
			if distance > 0.01: direction = vector_to_target.normalized()

			_apply_rotation(delta, direction)

			if distance > upper_bound:
				_apply_acceleration(delta, direction) # Applies acceleration towards target velocity if aligned
			elif distance <= lower_bound:
				command_stop()
			else:
				_apply_deceleration(delta)


		CommandType.ORBIT:
			# This block now calculates the *ideal* target velocity for this frame,
			# combining tangential speed and a basic radial correction hint.
			# The more aggressive correction happens post-move_and_slide in _physics_process.
			if not is_instance_valid(target_node):
				command_stop(); return

			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.get("distance", 100.0)
			var clockwise = _current_command.get("clockwise", false)

			var vector_to_target = target_pos - global_transform.origin
			var distance = vector_to_target.length()
			if distance < 0.1: distance = 0.1
			var direction_to_target = vector_to_target / distance

			# Calculate tangent direction
			var target_up = Vector3.UP
			var tangent_dir = Vector3.ZERO
			var cross_fallback_axis = global_transform.basis.x
			if clockwise:
				tangent_dir = target_up.cross(direction_to_target).normalized()
				if tangent_dir.length_squared() < 0.1: tangent_dir = cross_fallback_axis.cross(direction_to_target).normalized()
			else:
				tangent_dir = direction_to_target.cross(target_up).normalized()
				if tangent_dir.length_squared() < 0.1: tangent_dir = direction_to_target.cross(cross_fallback_axis).normalized()

			# Rotate to face tangent
			_apply_rotation(delta, tangent_dir)

			# Calculate Target Tangential Speed (Radius-Scaled, Capped)
			var target_tangential_speed = 0.0
			var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
			if orbit_dist <= 0: target_tangential_speed = 0.0
			elif orbit_dist < full_speed_radius:
				target_tangential_speed = max_move_speed * (orbit_dist / full_speed_radius)
			else: target_tangential_speed = max_move_speed
			target_tangential_speed = clamp(target_tangential_speed, 0.0, max_move_speed)

			# Calculate initial target velocity (tangential only for interpolation)
			# The radial correction is now primarily handled post-move
			var target_velocity = tangent_dir * target_tangential_speed

			# Interpolate towards the tangential target velocity
			current_velocity = current_velocity.linear_interpolate(target_velocity, acceleration * delta)
			_is_braking = false

		CommandType.FLEE:
			if not is_instance_valid(target_node):
				command_stop(); return
			var target_pos = target_node.global_transform.origin
			var vector_away = global_transform.origin - target_pos
			var direction_away = -global_transform.basis.z
			if vector_away.length_squared() > 0.01: direction_away = vector_away.normalized()

			_apply_rotation(delta, direction_away)
			_apply_acceleration(delta, direction_away) # Applies acceleration towards target velocity if aligned

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			_apply_rotation(delta, target_dir)
			_apply_deceleration(delta)
			var current_fwd = -global_transform.basis.z
			if current_fwd.dot(target_dir) > 0.998:
				_set_command_idle()


# --- Internal Movement Helpers ---

# Applies acceleration towards max_move_speed ONLY if aligned within threshold.
func _apply_acceleration(delta, target_direction: Vector3):
	if target_direction.length_squared() < 0.001:
		_apply_deceleration(delta)
		return

	var target_dir_norm = target_direction.normalized()
	var current_forward = -global_transform.basis.z.normalized()
	var angle = current_forward.angle_to(target_dir_norm)

	if angle <= _alignment_threshold_rad:
		# Aligned: Interpolate towards target velocity (max speed in target direction)
		var target_velocity = target_dir_norm * max_move_speed
		current_velocity = current_velocity.linear_interpolate(target_velocity, acceleration * delta)
		_is_braking = false
	else:
		# Not aligned: Apply natural deceleration while turning
		_apply_deceleration(delta)


# Applies natural deceleration (drag)
func _apply_deceleration(delta):
	current_velocity = current_velocity.linear_interpolate(Vector3.ZERO, deceleration * delta)
	_is_braking = false


# Applies active braking force
func _apply_braking(delta) -> bool:
	current_velocity = current_velocity.linear_interpolate(Vector3.ZERO, brake_strength * delta)
	_is_braking = true
	return current_velocity.length_squared() < 0.5


# Handles rotation towards a target direction
func _apply_rotation(delta, target_look_dir):
	if target_look_dir.length_squared() < 0.001: return

	var target_dir = target_look_dir.normalized()
	var current_basis = global_transform.basis.orthonormalized()
	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999: up_vector = Vector3.FORWARD

	var target_basis = Transform(Basis(), Vector3.ZERO).looking_at(target_dir, up_vector).basis.orthonormalized()

	if current_basis.is_equal_approx(target_basis): return

	if max_turn_speed > 0.001:
		var turn_step = max_turn_speed * delta
		var new_basis = current_basis.slerp(target_basis, turn_step)
		global_transform.basis = new_basis


# --- Public Getter for Explicit Interaction Radius ---
func get_interaction_radius() -> float:
	return interaction_radius


# --- Target Size Helper ---
func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0
	var default_size = 50.0
	var found_source = false
	if not is_instance_valid(target_node): return default_size
	if target_node.has_method("get_interaction_radius"):
		var explicit_size = target_node.get_interaction_radius()
		if (explicit_size is float or explicit_size is int) and explicit_size > 0:
			calculated_size = explicit_size; found_source = true
	if not found_source:
		var model_node = target_node.get_node_or_null("Model")
		if is_instance_valid(model_node) and model_node is Spatial:
			var model_scale = model_node.global_transform.basis.get_scale()
			calculated_size = max(model_scale.x, max(model_scale.y, model_scale.z))
			if calculated_size <= 0: calculated_size = 1.0
			found_source = true
	if not found_source: calculated_size = default_size
	return max(calculated_size, 1.0)


# --- Public Command Methods ---

func command_stop():
	_current_command = { "type": CommandType.STOPPING }

func command_move_to(position: Vector3):
	_current_command = { "type": CommandType.MOVE_TO, "target_pos": position }

func command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("MoveDirection command: Invalid direction vector.")
		command_stop(); return
	_current_command = { "type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized() }

func command_approach(target: Spatial):
	if not is_instance_valid(target):
		printerr("Approach command: Invalid target node.")
		command_stop(); return
	_current_command = { "type": CommandType.APPROACH, "target_node": target }

# Captures current distance, determines orbit direction, prevents re-issue
func command_orbit(target: Spatial):
	if _current_command.get("type") == CommandType.ORBIT and \
	   _current_command.get("target_node") == target:
		return # Already orbiting this target

	if not is_instance_valid(target):
		printerr("Orbit command: Invalid target node.")
		command_stop(); return

	var vec_to_target_local = to_local(target.global_transform.origin)
	var orbit_clockwise = (vec_to_target_local.x > 0.01)

	var current_dist = global_transform.origin.distance_to(target.global_transform.origin)
	var min_orbit_dist = _get_target_effective_size(target) * 1.2 + 10.0
	var captured_orbit_dist = max(current_dist, min_orbit_dist)

	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": captured_orbit_dist,
		"clockwise": orbit_clockwise
	}
	print("Orbit command issued: Target=", target.name, ", Captured Dist=", captured_orbit_dist, ", Clockwise=", orbit_clockwise)


func command_flee(target: Spatial):
	if not is_instance_valid(target):
		printerr("Flee command: Invalid target node.")
		command_stop(); return
	_current_command = { "type": CommandType.FLEE, "target_node": target }

func command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("AlignTo command: Invalid direction vector.")
		_set_command_idle(); return
	_current_command = { "type": CommandType.ALIGN_TO, "target_dir": direction.normalized() }

# Internal helper to set state to Idle
func _set_command_idle():
	var last_look = -global_transform.basis.z
	if _current_command and "target_dir" in _current_command:
		last_look = _current_command.target_dir
	elif _current_command and "target_node" in _current_command:
		var cmd_target = _current_command.target_node
		if is_instance_valid(cmd_target):
		   last_look = (cmd_target.global_transform.origin - global_transform.origin).normalized()

	_current_command = { "type": CommandType.IDLE, "target_dir": last_look }
	_is_braking = false

# --- Despawn ---
func despawn():
	print("Agent ", self.name, " despawning...")
	EventBus.emit_signal("agent_despawning", self)
	set_physics_process(false)
	call_deferred("queue_free")
