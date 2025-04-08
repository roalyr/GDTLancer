# File: core/agents/components/movement_component.gd
# Attach to a Node child of the Agent KinematicBody in agent.tscn
# Version: 1.1 - Reads parameters from agent.gd, uses agent state for velocity

extends Node

# --- References ---
# Set in _ready()
var body: KinematicBody = null
var agent_script: Node = null # Reference to the agent.gd script instance

# --- Initialization ---
func _ready():
	# Get references to the parent KinematicBody and its script safely
	var parent = get_parent()
	if parent is KinematicBody:
		body = parent
		# Check if the parent node actually has the expected script/methods
		# We assume agent.gd is attached to the parent KinematicBody
		if body.has_method("set_movement_input") and body.has_method("_get_movement_input_vector"):
			agent_script = body
		else:
			printerr("MovementComponent Error: Parent KinematicBody node '", body.name, "' is missing expected methods from agent.gd!")
			set_physics_process(false) # Disable if setup is wrong
	else:
		printerr("MovementComponent Error: Parent node is not a KinematicBody!")
		set_physics_process(false) # Disable if setup is wrong

# --- Physics Update ---
# Handles applying velocity and deceleration
func _physics_process(delta):
	if not body or not agent_script: # Should not happen if _ready checks pass
		return

	# Check if any controller provided movement input this frame via agent script
	var intended_move_vector = agent_script._get_movement_input_vector()

	# Apply deceleration if no specific movement input was given
	if intended_move_vector == Vector3.ZERO:
		agent_script.current_velocity = agent_script.current_velocity.linear_interpolate(
			Vector3.ZERO,
			agent_script.deceleration * delta
		)

	# --- Apply Movement ---
	# move_and_slide handles collisions and updates velocity based on slides
	# We store the resulting velocity back onto the agent script
	agent_script.current_velocity = body.move_and_slide(agent_script.current_velocity, Vector3.UP)


# --- Public Functions (Called by Controller Scripts, usually via agent_script ref) ---

# Call this to apply acceleration towards a desired direction
# 'direction' is the intended normalized movement vector (e.g., agent's forward)
func move(delta, direction: Vector3):
	if not body or not agent_script:
		return

	# Signal to the agent script that movement input was provided this frame
	agent_script.set_movement_input(direction)

	# Calculate the target velocity vector
	var target_velocity = direction.normalized() * agent_script.max_move_speed

	# Smoothly interpolate towards the target velocity using acceleration
	agent_script.current_velocity = agent_script.current_velocity.linear_interpolate(
		target_velocity,
		agent_script.acceleration * delta
	)
	# Note: Actual movement application happens in _physics_process using move_and_slide

# Call this to smoothly rotate the agent towards a target direction vector
func rotate_towards(delta, target_direction: Vector3):
	if not body or not agent_script or target_direction.is_normalized() == false:
		# Ensure target_direction is normalized or non-zero before proceeding
		if target_direction.length_squared() < 0.001: return # Avoid issues with zero vector
		target_direction = target_direction.normalized()

	var current_transform = body.global_transform
	var current_basis = current_transform.basis

	# Calculate the target basis looking in the desired direction
	# We use Transform.looking_at and extract the basis (Godot 3 standard)
	# The position part doesn't matter here, only the direction Vector3.UP is world up
	var look_at_transform = Transform(Basis(), Vector3.ZERO).looking_at(target_direction, Vector3.UP)
	var target_basis = look_at_transform.basis
	
	current_basis = current_basis.orthonormalized()
	target_basis = target_basis.orthonormalized()

	# Use spherical linear interpolation (slerp) for smooth rotation
	var new_basis = current_basis.slerp(target_basis, agent_script.max_turn_speed * delta)

	# Apply the new rotation, keeping position the same
	body.global_transform = Transform(new_basis, current_transform.origin)


# Helper function often useful for controllers
func get_direction_to(global_position: Vector3) -> Vector3:
	if body:
		var direction = global_position - body.global_transform.origin
		if direction.length_squared() > 0.001: # Avoid normalizing zero vector
			return direction.normalized()
	# Return agent's current forward direction if target is same as current position or no body
	return -body.global_transform.basis.z if body else Vector3.FORWARD
