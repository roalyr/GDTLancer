# File: core/agents/agent.gd
# Version 3.19 - Uses Body's Model node global scale for distance calculation (as is).

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

	_set_command_idle() # Start idle
	print(self.name + " initialized template '", self.template_id, "'.")

# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	set_physics_process(true)

func _physics_process(delta):
	_execute_current_command(delta)
	current_velocity = move_and_slide(current_velocity, Vector3.UP)

# --- Command Execution Logic ---
func _execute_current_command(delta):
	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	var is_target_cmd = cmd_type in [CommandType.APPROACH,
			CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd:
		if not is_instance_valid(target_node):
			command_stop()
			cmd_type = _current_command.get("type", CommandType.STOPPING)

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
				_apply_acceleration(delta, direction)

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				_apply_rotation(delta, move_dir)
				_apply_acceleration(delta, move_dir)
			else:
				_apply_deceleration(delta)

		CommandType.APPROACH:
			if not is_instance_valid(target_node): 
				command_stop()
				return

			var target_pos = target_node.global_transform.origin
			var target_size = _get_target_effective_size(target_node)
			var desired_stop_dist = max(APPROACH_MIN_DISTANCE,
					target_size * APPROACH_DISTANCE_MULTIPLIER)
			var upper_bound = desired_stop_dist * 1.10
			var lower_bound = desired_stop_dist

			var current_pos = global_transform.origin
			var vector_to_target = target_pos - current_pos
			var distance = vector_to_target.length()
			var direction = Vector3.ZERO
			if distance > 0.01: direction = vector_to_target / distance

			_apply_rotation(delta, direction)

			if distance > upper_bound: _apply_acceleration(delta, direction)
			elif distance <= lower_bound: command_stop()
			else: _apply_deceleration(delta)

		CommandType.ORBIT:
			if not is_instance_valid(target_node): 
				command_stop()
				return

			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.distance
			var vector_to_target = target_pos - global_transform.origin
			var distance = vector_to_target.length()
			var direction_to_target = -global_transform.basis.z
			if distance > 0.01: direction_to_target = vector_to_target / distance

			_apply_rotation(delta, direction_to_target)

			var target_up = Vector3.UP
			var tangent_dir = direction_to_target.cross(target_up).normalized()
			if tangent_dir.length_squared() < 0.1:
				tangent_dir = direction_to_target.cross(Vector3.RIGHT).normalized()

			var speed_factor = 1.0
			if distance < orbit_dist * 0.95: speed_factor = 0.7
			elif distance > orbit_dist * 1.05: speed_factor = 1.0

			_apply_acceleration(delta, tangent_dir * speed_factor)

		CommandType.FLEE:
			if not is_instance_valid(target_node): 
				command_stop()
				return

			var target_pos = target_node.global_transform.origin
			var vector_away = global_transform.origin - target_pos
			var direction_away = -global_transform.basis.z
			if vector_away.length_squared() > 0.01: direction_away = vector_away.normalized()

			_apply_rotation(delta, direction_away)
			_apply_acceleration(delta, direction_away)

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			_apply_rotation(delta, target_dir)
			_apply_deceleration(delta)
			var current_fwd = -global_transform.basis.z
			if current_fwd.dot(target_dir) > 0.998: _set_command_idle()


# --- Internal Movement Helpers ---
func _apply_acceleration(delta, direction):
	if direction.length_squared() < 0.001:
		_apply_deceleration(delta)
		return

	var target_velocity = direction.normalized() * max_move_speed
	current_velocity = current_velocity.linear_interpolate(target_velocity, acceleration * delta)
	_is_braking = false

func _apply_deceleration(delta):
	current_velocity = current_velocity.linear_interpolate(Vector3.ZERO, deceleration * delta)
	_is_braking = false

func _apply_braking(delta) -> bool:
	current_velocity = current_velocity.linear_interpolate(Vector3.ZERO, brake_strength * delta)
	_is_braking = true
	return current_velocity.length_squared() < 0.5

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
	# This can be overridden by specific agent types or use value from AgentTemplate.
	return interaction_radius


# --- Target Size Helper --- REFACTORED
# Version 3.19 - Returns max extent/size based on "Model" node global scale.
func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0 # Default minimum size
	var default_size = 50.0   # Fallback size if nothing else found (was default_radius)
	var found_source = false

	# print("--- Calculating Size for: ", target_node.name, " ---") # Keep for debug if needed

	if not is_instance_valid(target_node):
		# print("Debug Size: Target node invalid.")
		return default_size

	# --- PRIORITY 1: Check for explicit method on the target ---
	# Use get_interaction_radius, but interpret as size/extent now
	if target_node.has_method("get_interaction_radius"):
		var explicit_size = target_node.get_interaction_radius() # Treat value as size
		if (explicit_size is float or explicit_size is int) and explicit_size > 0:
			# print("Debug Size: Using get_interaction_radius() as size: ", explicit_size)
			calculated_size = explicit_size
			found_source = true
		# else: print("Debug Size: get_interaction_radius() invalid: ", explicit_size)

	# --- PRIORITY 2: Find DIRECT CHILD node named "Model" (only if not found via method)---
	if not found_source:
		var model_node = target_node.get_node_or_null("Model")
		# print("Debug Size: Result of get_node_or_null('Model'): ", model_node)

		if is_instance_valid(model_node) and model_node is Spatial:
			var model_scale_vector = model_node.global_transform.basis.get_scale()
			# print("Debug Size: Model Global Scale Vector: ", model_scale_vector)

			# --- Use the maximum scale value directly as the size ---
			var max_scale_value = max(model_scale_vector.x, max(model_scale_vector.y, model_scale_vector.z))
			# print("Debug Size: Model Max Scale Value: ", max_scale_value)

			calculated_size = max_scale_value # REMOVED / 2.0
			# print("Debug Size: Calculated Size (Before 0 Check): ", calculated_size)

			# Ensure size is not zero or negative
			if calculated_size <= 0:
				# print("Debug Size: Calculated size was <= 0, setting to 1.0")
				calculated_size = 1.0 # Fallback to minimum size 1.0

			found_source = true
		# else: print("Debug Size: No valid direct child 'Model' node found.")

	# --- Fallback if no source found ---
	if not found_source:
		# print("Debug Size: No source found, using default size: ", default_size)
		calculated_size = default_size

	# Final minimum check (size must be at least 1.0)
	var final_size = max(calculated_size, 1.0)
	# print("Debug Size: Final Size Returned: ", final_size)
	# print("-----------------------------------------------")
	return final_size



# --- Public Command Methods ---
# (No changes to command methods from v3.16)
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

func command_orbit(target: Spatial, distance: float):
	if not is_instance_valid(target):
		printerr("Orbit command: Invalid target node.")
		command_stop(); return
	_current_command = { "type": CommandType.ORBIT, "target_node": target, "distance": max(10.0, distance) }

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
	if _current_command and "target_dir" in _current_command: last_look = _current_command.target_dir
	_current_command = { "type": CommandType.IDLE, "target_dir": last_look }
	_is_braking = false

# --- Despawn ---
func despawn():
	print("Agent ", self.name, " despawning...")
	EventBus.emit_signal("agent_despawning", self)
	set_physics_process(false)
	call_deferred("queue_free")
