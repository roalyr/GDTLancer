# File: res://core/agents/components/movement_system.gd
# Version: 1.0
# Purpose: Handles the low-level execution of agent movement and rotation physics.
# Called by NavigationSystem.

extends Node

# --- Movement Capabilities (Set by AgentBody during initialize) ---
var max_move_speed: float = Constants.DEFAULT_MAX_MOVE_SPEED
var acceleration: float = Constants.DEFAULT_ACCELERATION
var deceleration: float = Constants.DEFAULT_DECELERATION
var brake_strength: float = Constants.DEFAULT_DECELERATION * 1.5  # Default derived value
var max_turn_speed: float = Constants.DEFAULT_MAX_TURN_SPEED
var alignment_threshold_angle_deg: float = 45.0
var _alignment_threshold_rad: float = deg2rad(alignment_threshold_angle_deg)

# Reference to the parent AgentBody KinematicBody
var agent_body: KinematicBody = null


func _ready():
	# Get reference to parent body ONCE. Assumes this node is direct child.
	agent_body = get_parent()
	if not agent_body is KinematicBody:
		printerr("MovementSystem Error: Parent is not a KinematicBody!")
		agent_body = null  # Invalidate if wrong type
		set_process(false)  # Disable if setup fails


# Called by AgentBody's initialize method
func initialize_movement_params(params: Dictionary):
	max_move_speed = params.get("max_move_speed", max_move_speed)
	acceleration = params.get("acceleration", acceleration)
	deceleration = params.get("deceleration", deceleration)
	brake_strength = params.get("brake_strength", deceleration * 1.5)  # Use provided or derive default
	max_turn_speed = params.get("max_turn_speed", max_turn_speed)
	alignment_threshold_angle_deg = params.get(
		"alignment_threshold_angle_deg", alignment_threshold_angle_deg
	)
	_alignment_threshold_rad = deg2rad(alignment_threshold_angle_deg)
	print(
		(
			"MovementSystem Initialized: Speed=%.1f, Accel=%.1f, Decel=%.1f, Turn=%.1f, Align=%.1f"
			% [
				max_move_speed,
				acceleration,
				deceleration,
				max_turn_speed,
				alignment_threshold_angle_deg
			]
		)
	)


# --- Public Methods Called by NavigationSystem ---


# Applies acceleration towards max_move_speed ONLY if aligned within threshold.
# Modifies agent_body.current_velocity directly.
func apply_acceleration(target_direction: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	if target_direction.length_squared() < 0.001:
		# If target direction is zero, just decelerate
		apply_deceleration(delta)
		return

	var target_dir_norm = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	# Calculate the angle between current forward and target direction
	var angle = current_forward.angle_to(target_dir_norm)

	# Check if angle is within the alignment threshold
	if angle <= _alignment_threshold_rad:
		# Aligned: Interpolate towards target velocity
		var target_velocity = target_dir_norm * max_move_speed
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			target_velocity, acceleration * delta
		)
		# agent_body._is_braking = false # State managed by NavigationSystem or AgentBody now
	else:
		# Not aligned: Apply natural deceleration while turning continues
		apply_deceleration(delta)


# Applies natural deceleration (drag). Modifies agent_body.current_velocity.
func apply_deceleration(delta: float):
	if not is_instance_valid(agent_body):
		return
	agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
		Vector3.ZERO, deceleration * delta
	)
	# agent_body._is_braking = false


# Applies active braking force. Modifies agent_body.current_velocity.
# Returns true if velocity is considered stopped.
func apply_braking(delta: float) -> bool:
	if not is_instance_valid(agent_body):
		return true  # Assume stopped if no body
	agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
		Vector3.ZERO, brake_strength * delta
	)
	# agent_body._is_braking = true
	# Return true if velocity is very close to zero
	return agent_body.current_velocity.length_squared() < 0.5


# Handles rotation towards a target look direction using Slerp.
# Modifies agent_body.global_transform.basis directly.
func apply_rotation(target_look_dir: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	if target_look_dir.length_squared() < 0.001:
		return  # Ignore zero vector

	var target_dir = target_look_dir.normalized()
	# --- IMPORTANT: Operate on the PARENT's basis ---
	var current_basis = agent_body.global_transform.basis.orthonormalized()

	# Determine the 'up' vector for looking_at, avoiding gimbal lock
	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD  # Use Forward as fallback up vector

	# Calculate the target basis using looking_at
	var target_basis = Transform(Basis(), Vector3.ZERO).looking_at(target_dir, up_vector).basis.orthonormalized()

	# Check if already aligned (approximately)
	if current_basis.is_equal_approx(target_basis):
		return

	# Rotate towards the target basis using Slerp if turn speed is positive
	if max_turn_speed > 0.001:
		var turn_step = max_turn_speed * delta  # Rotation amount this frame
		var new_basis = current_basis.slerp(target_basis, turn_step)
		# --- IMPORTANT: Apply result back to PARENT's basis ---
		agent_body.global_transform.basis = new_basis
	else:
		# If turn speed is zero, snap instantly
		agent_body.global_transform.basis = target_basis
