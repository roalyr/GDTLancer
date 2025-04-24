# File: core/agents/agent.gd
# Version: 3.11 - Strict formatting applied (Tabs, Line Length, Expanded Conditionals)

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

# --- Constants for Approach ---
const APPROACH_DISTANCE_MULTIPLIER = 1.5
const APPROACH_MIN_DISTANCE = 50.0

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

	# Validate target node if required by the command type
	var is_target_cmd = cmd_type in [CommandType.APPROACH,
			CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd:
		if not is_instance_valid(target_node):
			command_stop()
			cmd_type = _current_command.get("type", CommandType.STOPPING)

	# Execute logic based on command type
	match cmd_type:
		CommandType.IDLE:
			_apply_deceleration(delta)

		CommandType.STOPPING:
			var stopped = _apply_braking(delta)
			if stopped:
				print(agent_name, ": Stopped. Emitting agent_reached_destination.")
				EventBus.emit_signal("agent_reached_destination", self)
				_set_command_idle()

		CommandType.MOVE_TO:
			var target_pos = _current_command.target_pos
			var vector_to_target = target_pos - global_transform.origin
			var distance_sq = vector_to_target.length_squared()
			var stopping_dist_sq = pow(10.0, 2) # Example

			if distance_sq < stopping_dist_sq:
				command_stop()
			else:
				var direction = vector_to_target.normalized()
				_apply_rotation(delta, direction)
				_apply_acceleration(delta, direction)

		CommandType.MOVE_DIRECTION:
			var move_dir = _current_command.get("target_dir", Vector3.ZERO)
			if move_dir.length_squared() > 0.001:
				# Optional: Align to move direction?
				_apply_rotation(delta, move_dir)
				_apply_acceleration(delta, move_dir)
			else:
				# Invalid direction, slow down
				_apply_deceleration(delta)

		CommandType.APPROACH:
			if not is_instance_valid(target_node):
				# Target check again inside case for safety
				command_stop()
				return

			var target_pos = target_node.global_transform.origin
			var target_radius = _get_target_effective_radius(target_node)
			var desired_stop_dist = max(APPROACH_MIN_DISTANCE,
					target_radius * APPROACH_DISTANCE_MULTIPLIER)
			var upper_bound = desired_stop_dist * 1.10
			var lower_bound = desired_stop_dist

			var current_pos = global_transform.origin
			var vector_to_target = target_pos - current_pos
			var distance = vector_to_target.length()
			var direction = Vector3.ZERO
			if distance > 0.01:
				direction = vector_to_target / distance

			_apply_rotation(delta, direction) # Always face target

			if distance > upper_bound:
				_apply_acceleration(delta, direction)
			elif distance <= lower_bound:
				# print(agent_name, " APPROACH: Reached target distance.")
				command_stop()
			else: # Within tolerance band
				_apply_deceleration(delta)

		CommandType.ORBIT:
			if not is_instance_valid(target_node):
				command_stop()
				return

			var target_pos = target_node.global_transform.origin
			var orbit_dist = _current_command.distance
			var vector_to_target = target_pos - global_transform.origin
			var distance = vector_to_target.length()
			var direction_to_target = -global_transform.basis.z
			if distance > 0.01:
				direction_to_target = vector_to_target / distance

			_apply_rotation(delta, direction_to_target)

			var target_up = Vector3.UP
			if target_node is Spatial:
				target_up = target_node.global_transform.basis.y
			var tangent_dir = direction_to_target.cross(target_up).normalized()

			var speed_factor = 1.0
			if distance < orbit_dist * 0.95:
				speed_factor = 0.7
			elif distance > orbit_dist * 1.05:
				speed_factor = 1.0
			_apply_acceleration(delta, tangent_dir * speed_factor)

		CommandType.FLEE:
			if not is_instance_valid(target_node):
				command_stop() # Or switch to IDLE? Stop seems safer.
				return

			var target_pos = target_node.global_transform.origin
			var vector_away = global_transform.origin - target_pos
			var direction_away = -global_transform.basis.z
			if vector_away.length_squared() > 0.01:
				direction_away = vector_away.normalized()

			_apply_rotation(delta, direction_away)
			_apply_acceleration(delta, direction_away)

		CommandType.ALIGN_TO:
			var target_dir = _current_command.target_dir
			_apply_rotation(delta, target_dir)
			_apply_deceleration(delta)
			var current_fwd = -global_transform.basis.z
			if current_fwd.dot(target_dir) > 0.998:
				_set_command_idle()


# --- Internal Movement Helpers ---
func _apply_acceleration(delta, direction):
	if direction.length_squared() < 0.001:
		_apply_deceleration(delta)
		return
	var target_velocity = direction.normalized() * max_move_speed
	current_velocity = current_velocity.linear_interpolate(
		target_velocity,
		acceleration * delta
	)
	_is_braking = false

func _apply_deceleration(delta):
	current_velocity = current_velocity.linear_interpolate(
		Vector3.ZERO,
		deceleration * delta
	)
	_is_braking = false

func _apply_braking(delta) -> bool:
	current_velocity = current_velocity.linear_interpolate(
		Vector3.ZERO,
		brake_strength * delta
	)
	_is_braking = true
	return current_velocity.length_squared() < 0.5

func _apply_rotation(delta, target_look_dir):
	if target_look_dir.length_squared() < 0.001:
		return

	var target_dir = target_look_dir.normalized()
	var current_transform = global_transform
	var current_basis = current_transform.basis

	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD

	var look_at_transform = Transform(Basis(), Vector3.ZERO).looking_at(
		target_dir,
		up_vector
	)
	var target_basis = look_at_transform.basis

	current_basis = current_basis.orthonormalized()
	target_basis = target_basis.orthonormalized()

	if current_basis.is_equal_approx(target_basis):
		return

	if max_turn_speed > 0.001:
		var turn_step = max_turn_speed * delta
		var new_basis = current_basis.slerp(target_basis, turn_step)
		global_transform.basis = new_basis

# --- Target Size Helper ---
func _get_target_effective_radius(target_node: Spatial) -> float:
	var longest_half_extent = 1.0 # Minimum radius default
	var default_radius = 25.0     # Fallback if nothing found
	var shape_found = false

	if not is_instance_valid(target_node):
		return default_radius

	if target_node.has_method("get_interaction_radius"):
		return max(target_node.get_interaction_radius(), 1.0)

	if target_node.get_child_count() > 0:
		for child in target_node.get_children():
			if child is CollisionShape and is_instance_valid(child.shape):
				var shape = child.shape
				if shape is SphereShape:
					longest_half_extent = shape.radius
					shape_found = true
					break
				elif shape is BoxShape:
					longest_half_extent = shape.extents.max_axis()
					shape_found = true
					break
				elif shape is CapsuleShape:
					longest_half_extent = max(shape.radius, shape.height / 2.0)
					shape_found = true
					break
				elif shape is CylinderShape:
					longest_half_extent = max(shape.radius, shape.height / 2.0)
					shape_found = true
					break

	if not shape_found and target_node.get_child_count() > 0:
		for child in target_node.get_children():
			if child is MeshInstance and is_instance_valid(child.mesh):
				var aabb = child.mesh.get_aabb()
				longest_half_extent = aabb.get_longest_axis_size() / 2.0
				shape_found = true
				# print("Warning: Using Mesh AABB for target radius") # Optional
				break

	if not shape_found:
		# print("Warning: Using default radius for target") # Optional
		return default_radius

	return max(longest_half_extent, 1.0)


# --- Public Command Methods ---
func command_stop():
	_current_command = { "type": CommandType.STOPPING }

func command_move_to(position: Vector3):
	_current_command = { "type": CommandType.MOVE_TO, "target_pos": position }

func command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("MoveDirection command: Invalid direction vector.")
		command_stop()
		return
	_current_command = {
		"type": CommandType.MOVE_DIRECTION,
		"target_dir": direction.normalized()
	}

func command_approach(target: Spatial): # Removed distance arg
	if not is_instance_valid(target):
		printerr("Approach command: Invalid target node.")
		return
	_current_command = {
		"type": CommandType.APPROACH,
		"target_node": target
	}

func command_orbit(target: Spatial, distance: float):
	if not is_instance_valid(target):
		printerr("Orbit command: Invalid target node.")
		return
	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": max(10.0, distance)
	}

func command_flee(target: Spatial): # Renamed from keep_at_range
	if not is_instance_valid(target):
		printerr("Flee command: Invalid target node.")
		return
	_current_command = {
		"type": CommandType.FLEE,
		"target_node": target
	}

func command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		printerr("AlignTo command: Invalid direction vector.")
		return
	_current_command = {
		"type": CommandType.ALIGN_TO,
		"target_dir": direction.normalized()
	}

# Internal helper
func _set_command_idle():
	var last_look = -global_transform.basis.z
	# Expanded if
	if _current_command and "target_dir" in _current_command:
		last_look = _current_command.target_dir
	_current_command = { "type": CommandType.IDLE, "target_dir": last_look }
	_is_braking = false

# --- Despawn ---
func despawn():
	print("Agent ", self.name, " despawning...")
	EventBus.emit_signal("agent_despawning", self)
	queue_free()

# --- Placeholders ---
# ...
