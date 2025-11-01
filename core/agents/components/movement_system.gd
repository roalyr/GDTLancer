# File: res://core/agents/components/movement_system.gd
# Version: 1.4 - Added smooth deceleration when max_move_speed is lowered.
# Purpose: Handles the low-level execution of agent movement and rotation physics.
# Called by NavigationSystem.

extends Node

# --- Movement Capabilities (Set by AgentBody during initialize) ---
var max_move_speed: float = Constants.DEFAULT_MAX_MOVE_SPEED
var acceleration: float = Constants.DEFAULT_ACCELERATION
var deceleration: float = Constants.DEFAULT_DECELERATION
var brake_strength: float = Constants.DEFAULT_DECELERATION
var max_turn_speed: float = Constants.DEFAULT_MAX_TURN_SPEED
var alignment_threshold_angle_deg: float = 45.0
var _alignment_threshold_rad: float = deg2rad(alignment_threshold_angle_deg)

# --- Angular Velocity & Damping ---
var angular_velocity := Vector3.ZERO
var turn_damping := 5.0

# Reference to the parent AgentBody KinematicBody
var agent_body: KinematicBody = null


func _ready():
	agent_body = get_parent()
	if not agent_body is KinematicBody:
		printerr("MovementSystem Error: Parent is not a KinematicBody!")
		agent_body = null
		set_process(false)


func initialize_movement_params(params: Dictionary):
	max_move_speed = params.get("max_move_speed", max_move_speed)
	acceleration = params.get("acceleration", acceleration)
	deceleration = params.get("deceleration", deceleration)
	brake_strength = params.get("brake_strength", deceleration)
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


# --- Public Methods Called by NavigationSystem & AgentBody ---


# Applies acceleration towards max_move_speed ONLY if aligned within threshold.
func apply_acceleration(target_direction: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	if target_direction.length_squared() < 0.001:
		apply_deceleration(delta)
		return

	var target_dir_norm = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	var angle = current_forward.angle_to(target_dir_norm)

	if angle <= _alignment_threshold_rad:
		var target_velocity = target_dir_norm * max_move_speed
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			target_velocity, acceleration * delta
		)
	else:
		# If not aligned, we just decelerate naturally instead of accelerating.
		apply_deceleration(delta)


# Applies natural deceleration (drag).
func apply_deceleration(delta: float):
	if not is_instance_valid(agent_body):
		return
	# We only apply natural deceleration if we are NOT over the speed limit.
	# If we are over, enforce_speed_limit() will handle the deceleration.
	if agent_body.current_velocity.length_squared() <= max_move_speed * max_move_speed:
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			Vector3.ZERO, deceleration * delta
		)


# Applies active braking force.
func apply_braking(delta: float) -> bool:
	if not is_instance_valid(agent_body):
		return true
	agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
		Vector3.ZERO, brake_strength * delta
	)
	return agent_body.current_velocity.length_squared() < 0.5


# Handles rotation and calculates resulting angular velocity.
func apply_rotation(target_look_dir: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	var basis_before_rotation = agent_body.global_transform.basis

	if target_look_dir.length_squared() < 0.001:
		angular_velocity = Vector3.ZERO
		return

	var target_dir = target_look_dir.normalized()
	var current_basis = basis_before_rotation.orthonormalized()

	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD

	var target_basis = Transform(Basis(), Vector3.ZERO).looking_at(target_dir, up_vector).basis.orthonormalized()

	if current_basis.is_equal_approx(target_basis):
		angular_velocity = Vector3.ZERO
		return

	var new_basis: Basis
	if max_turn_speed > 0.001:
		var turn_step = max_turn_speed * delta
		new_basis = current_basis.slerp(target_basis, turn_step)
	else:
		new_basis = target_basis

	agent_body.global_transform.basis = new_basis

	var rotation_diff_basis = new_basis * basis_before_rotation.inverse()
	var rotation_diff_quat = Quat(rotation_diff_basis)

	var angle = 2 * acos(rotation_diff_quat.w)
	var axis: Vector3
	var sin_half_angle = sin(angle / 2)

	if sin_half_angle > 0.0001:
		axis = (
			Vector3(rotation_diff_quat.x, rotation_diff_quat.y, rotation_diff_quat.z)
			/ sin_half_angle
		)
	else:
		axis = Vector3.UP

	if delta > 0.0001:
		angular_velocity = axis * (angle / delta)
	else:
		angular_velocity = Vector3.ZERO


# Smoothly dampens rotation to a stop.
func damp_rotation(delta: float):
	if not is_instance_valid(agent_body):
		return

	if angular_velocity.length_squared() > 0.0001:
		var rotation_axis = angular_velocity.normalized()
		var rotation_angle = angular_velocity.length() * delta
		agent_body.rotate(rotation_axis, rotation_angle)

		angular_velocity = angular_velocity.linear_interpolate(Vector3.ZERO, turn_damping * delta)


# NEW: Smoothly reduces speed if current velocity is over the max_move_speed limit.
func enforce_speed_limit(delta: float):
	if not is_instance_valid(agent_body):
		return

	var current_speed_sq = agent_body.current_velocity.length_squared()
	var max_speed_sq = max_move_speed * max_move_speed

	if current_speed_sq > max_speed_sq:
		# We are over the speed limit. Smoothly decelerate to the new cap.
		var direction = agent_body.current_velocity.normalized()
		var target_velocity = direction * max_move_speed

		# Use the existing deceleration property for a consistent feel.
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			target_velocity, deceleration * delta
		)
