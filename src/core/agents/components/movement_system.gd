# File: res://core/agents/components/movement_system.gd
# Version: 3.0 - RigidBody physics with PID-controlled 6DOF thrust-based flight system.
# Purpose: Handles the low-level execution of agent movement via forces and torques.
# Called by NavigationSystem. Parent must be RigidBody with custom_integrator = true.

extends Node

# --- Movement Capabilities (Set by AgentBody during initialize) ---
var linear_thrust: float = Constants.DEFAULT_LINEAR_THRUST
var angular_thrust: float = Constants.DEFAULT_ANGULAR_THRUST
var alignment_threshold_angle_deg: float = Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD
var _alignment_threshold_rad: float = deg2rad(alignment_threshold_angle_deg)

# --- Throttle Control (0.0 to 1.0) ---
var thrust_throttle: float = 1.0

# --- Accumulated Forces/Torques for Current Frame ---
# These are accumulated by commands and applied in _integrate_forces
var _accumulated_force := Vector3.ZERO
var _accumulated_torque := Vector3.ZERO

# Reference to the parent AgentBody RigidBody
var agent_body: RigidBody = null

# --- PID Controller State for Rotation ---
var _rotation_error_integral := Vector3.ZERO
var _rotation_error_prev := Vector3.ZERO
var _rotation_integral_limit := 2.0  # Anti-windup limit

# --- PID Controller State for Position/Stopping ---
var _position_error_integral := Vector3.ZERO
var _position_error_prev := Vector3.ZERO
var _position_integral_limit := 50.0


func _ready():
	agent_body = get_parent()
	if not agent_body is RigidBody:
		printerr("MovementSystem Error: Parent is not a RigidBody!")
		agent_body = null
		return
	
	# Enable custom integrator so we can apply drag and forces manually
	agent_body.custom_integrator = true


func initialize_movement_params(params: Dictionary):
	linear_thrust = params.get("linear_thrust", linear_thrust)
	angular_thrust = params.get("angular_thrust", angular_thrust)
	alignment_threshold_angle_deg = params.get(
		"alignment_threshold_angle_deg", alignment_threshold_angle_deg
	)
	_alignment_threshold_rad = deg2rad(alignment_threshold_angle_deg)
	
	# Set mass on the RigidBody if provided
	var mass = params.get("mass", Constants.DEFAULT_SHIP_MASS)
	if is_instance_valid(agent_body):
		agent_body.mass = mass
	
	# Reset PID states
	reset_pid_states()
	
	print(
		(
			"MovementSystem Initialized: LinearThrust=%.1f, AngularThrust=%.1f, Mass=%.1f, Align=%.1f"
			% [
				linear_thrust,
				angular_thrust,
				mass,
				alignment_threshold_angle_deg
			]
		)
	)


func reset_pid_states():
	_rotation_error_integral = Vector3.ZERO
	_rotation_error_prev = Vector3.ZERO
	_position_error_integral = Vector3.ZERO
	_position_error_prev = Vector3.ZERO


# --- Called by AgentBody in _integrate_forces ---
func integrate_forces(state: PhysicsDirectBodyState):
	if not is_instance_valid(agent_body):
		return
	
	# Apply global linear drag
	var linear_drag_force = -state.linear_velocity * Constants.LINEAR_DRAG * agent_body.mass
	state.add_central_force(linear_drag_force)
	
	# Apply global angular drag
	var angular_drag_torque = -state.angular_velocity * Constants.ANGULAR_DRAG * agent_body.mass
	state.add_torque(angular_drag_torque)
	
	# Apply accumulated forces from navigation commands (scaled by throttle)
	state.add_central_force(_accumulated_force * thrust_throttle)
	state.add_torque(_accumulated_torque)
	
	# Clear accumulated forces for next frame
	_accumulated_force = Vector3.ZERO
	_accumulated_torque = Vector3.ZERO


# --- Public Methods Called by NavigationSystem Commands ---


# Request thrust in a specific world direction (autopilot decides direction)
func request_thrust_direction(direction: Vector3, magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	if direction.length_squared() < 0.001:
		return
	_accumulated_force += direction.normalized() * linear_thrust * clamp(magnitude_scale, 0.0, 1.0)


# Request thrust along the ship's forward axis
func request_thrust_forward(magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	var forward = -agent_body.global_transform.basis.z.normalized()
	_accumulated_force += forward * linear_thrust * clamp(magnitude_scale, 0.0, 1.0)


# Request thrust along the ship's backward axis (rear thrusters)
func request_thrust_backward(magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	var backward = agent_body.global_transform.basis.z.normalized()
	_accumulated_force += backward * linear_thrust * clamp(magnitude_scale, 0.0, 1.0)


# Request reverse thrust (brake by thrusting opposite to velocity)
# Uses ship orientation - prefer braking with aligned thrusters
func request_thrust_brake():
	if not is_instance_valid(agent_body):
		return
	var velocity = agent_body.linear_velocity
	var speed = velocity.length()
	if speed < 0.1:
		return
	
	var velocity_dir = velocity / speed
	var forward = -agent_body.global_transform.basis.z.normalized()
	var backward = -forward
	
	# Check alignment with velocity for efficient braking
	var forward_dot = forward.dot(velocity_dir)  # Positive if facing velocity direction
	var backward_dot = backward.dot(velocity_dir)  # Positive if facing away from velocity
	
	# Use forward thrust if facing away from velocity (retrograde)
	# Use backward thrust if facing toward velocity (prograde)
	if backward_dot > 0.7:
		# Mostly aligned backward to velocity - use forward thrust
		_accumulated_force += forward * linear_thrust
	elif forward_dot > 0.7:
		# Mostly aligned forward to velocity - use backward thrust
		_accumulated_force += backward * linear_thrust
	else:
		# Not well aligned - thrust opposite to velocity at reduced power
		_accumulated_force += -velocity_dir * linear_thrust * 0.5


# Request PID-controlled rotation torque to align ship's forward (-Z) to target direction
func request_rotation_to_pid(target_direction: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return
	if target_direction.length_squared() < 0.001:
		return
	if delta <= 0.0:
		return
	
	var target_dir = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	
	# Calculate the rotation axis and angle error
	var cross = current_forward.cross(target_dir)
	var dot = current_forward.dot(target_dir)
	
	# Already aligned
	if dot > 0.9999:
		_rotation_error_integral = Vector3.ZERO
		return
	
	var angle_error = acos(clamp(dot, -1.0, 1.0))
	
	if cross.length_squared() < 0.0001:
		# Parallel or anti-parallel - pick an arbitrary axis
		cross = current_forward.cross(Vector3.UP)
		if cross.length_squared() < 0.0001:
			cross = current_forward.cross(Vector3.RIGHT)
	
	var torque_axis = cross.normalized()
	
	# Error vector for PID (angle error along torque axis)
	var error = torque_axis * angle_error
	
	# PID calculation
	_rotation_error_integral += error * delta
	# Anti-windup: clamp integral
	if _rotation_error_integral.length() > _rotation_integral_limit:
		_rotation_error_integral = _rotation_error_integral.normalized() * _rotation_integral_limit
	
	var error_derivative = (error - _rotation_error_prev) / delta
	_rotation_error_prev = error
	
	# Include current angular velocity as additional damping term
	var angular_vel_error = -agent_body.angular_velocity
	
	var pid_output = (
		Constants.PID_ROTATION_KP * error +
		Constants.PID_ROTATION_KI * _rotation_error_integral +
		Constants.PID_ROTATION_KD * (error_derivative + angular_vel_error * 0.5)
	)
	
	# Scale by angular thrust and clamp magnitude
	var torque_magnitude = pid_output.length()
	if torque_magnitude > 1.0:
		pid_output = pid_output / torque_magnitude
	
	_accumulated_torque += pid_output * angular_thrust


# Simple proportional rotation (for non-PID cases)
func request_rotation_to(target_direction: Vector3):
	if not is_instance_valid(agent_body):
		return
	if target_direction.length_squared() < 0.001:
		return
	
	var target_dir = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	
	var cross = current_forward.cross(target_dir)
	var dot = current_forward.dot(target_dir)
	
	if dot > 0.9999:
		return
	
	var angle_error = acos(clamp(dot, -1.0, 1.0))
	
	if cross.length_squared() > 0.0001:
		var torque_axis = cross.normalized()
		# Proportional + derivative (P+D) for basic stability
		var torque_mag = min(angle_error * 3.0, 1.0)
		# Add damping from current angular velocity
		var angular_vel_component = agent_body.angular_velocity.dot(torque_axis)
		torque_mag = max(0.0, torque_mag - angular_vel_component * 0.5)
		_accumulated_torque += torque_axis * torque_mag * angular_thrust


# PID-controlled damping for stopping rotation precisely
func request_rotation_damping_pid(delta: float):
	if not is_instance_valid(agent_body):
		return
	if delta <= 0.0:
		return
	
	var angular_vel = agent_body.angular_velocity
	if angular_vel.length_squared() < 0.0001:
		return
	
	# Target is zero angular velocity - error is current angular velocity
	var error = -angular_vel
	
	# Simple PD controller (no integral for damping)
	var error_derivative = (error - _rotation_error_prev) / delta
	_rotation_error_prev = error
	
	var pid_output = (
		Constants.PID_ROTATION_KP * error +
		Constants.PID_ROTATION_KD * error_derivative
	)
	
	var torque_magnitude = pid_output.length()
	if torque_magnitude > 1.0:
		pid_output = pid_output / torque_magnitude
	
	_accumulated_torque += pid_output * angular_thrust


# Dampen angular velocity (used by stop command)
func request_rotation_damping():
	if not is_instance_valid(agent_body):
		return
	var angular_vel = agent_body.angular_velocity
	if angular_vel.length_squared() < 0.01:
		return
	# Apply counter-torque to slow rotation
	var damping_torque = -angular_vel.normalized() * angular_thrust * 0.5
	_accumulated_torque += damping_torque


# PID-controlled thrust to achieve target velocity
func request_velocity_pid(target_velocity: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return
	if delta <= 0.0:
		return
	
	var current_vel = agent_body.linear_velocity
	var error = target_velocity - current_vel
	
	_position_error_integral += error * delta
	if _position_error_integral.length() > _position_integral_limit:
		_position_error_integral = _position_error_integral.normalized() * _position_integral_limit
	
	var error_derivative = (error - _position_error_prev) / delta
	_position_error_prev = error
	
	var pid_output = (
		Constants.PID_POSITION_KP * error +
		Constants.PID_POSITION_KI * _position_error_integral +
		Constants.PID_POSITION_KD * error_derivative
	)
	
	# Normalize and scale by thrust
	var force_magnitude = pid_output.length()
	if force_magnitude > 1.0:
		pid_output = pid_output / force_magnitude
	
	_accumulated_force += pid_output * linear_thrust


# Check if ship is approximately aligned with target direction
func is_aligned_to(target_direction: Vector3) -> bool:
	if not is_instance_valid(agent_body):
		return false
	if target_direction.length_squared() < 0.001:
		return true
	
	var target_dir = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	var angle = current_forward.angle_to(target_dir)
	return angle <= _alignment_threshold_rad


# Check if ship has (approximately) stopped moving
func is_stopped() -> bool:
	if not is_instance_valid(agent_body):
		return true
	return agent_body.linear_velocity.length_squared() < 1.0


# Check if ship has (approximately) stopped rotating
func is_rotation_stopped() -> bool:
	if not is_instance_valid(agent_body):
		return true
	return agent_body.angular_velocity.length_squared() < 0.01


# Get current speed (magnitude of linear velocity)
func get_current_speed() -> float:
	if not is_instance_valid(agent_body):
		return 0.0
	return agent_body.linear_velocity.length()


# Get current velocity vector
func get_velocity() -> Vector3:
	if not is_instance_valid(agent_body):
		return Vector3.ZERO
	return agent_body.linear_velocity


# Get ship's forward direction
func get_forward() -> Vector3:
	if not is_instance_valid(agent_body):
		return -Vector3.FORWARD
	return -agent_body.global_transform.basis.z.normalized()
