# File: core/agents/components/navigation_system/command_orbit.gd
# Version: 5.0 - Stateless tangential orbit: ship follows tangent based on velocity & turn rate.
# The ship will naturally settle into an orbit radius determined by its turning capability.
# At closer distances it needs to turn faster; if it can't, it spirals outward until stable.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	if delta <= 0.0:
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return

	var target_pos = target_node.global_transform.origin
	var ship_pos = _agent_body.global_transform.origin
	
	# --- Vector Calculations ---
	var radial_vector = ship_pos - target_pos  # Points outward from target
	var current_radius = radial_vector.length()
	
	if current_radius < 0.01:
		current_radius = 0.01
	
	var radial_dir = radial_vector / current_radius  # Unit vector pointing outward (away from target)
	
	# --- Safety Distance Check ---
	var safe_dist = (
		_nav_sys._get_target_effective_size(target_node)
		* _nav_sys.CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
	)
	
	if current_radius < safe_dist:
		# TOO CLOSE: Emergency escape - thrust outward
		_movement_system.request_rotation_to_pid(radial_dir, delta)
		if _movement_system.is_aligned_to(radial_dir):
			_movement_system.request_thrust_forward()
		return

	# --- Determine Orbit Direction from Current Velocity ---
	var velocity = _movement_system.get_velocity()
	var speed = velocity.length()
	
	# Calculate tangent direction based on current velocity
	# Project velocity onto the plane perpendicular to radial
	var velocity_tangent = velocity - radial_dir * velocity.dot(radial_dir)
	var tangent_speed = velocity_tangent.length()
	
	var tangent_dir: Vector3
	if tangent_speed > 1.0:
		# Use velocity-derived tangent (preserves orbit direction from current motion)
		tangent_dir = velocity_tangent.normalized()
	else:
		# No tangential motion - use clockwise parameter or default
		var clockwise = cmd.get("clockwise", false)
		var orbit_normal = Vector3.UP
		tangent_dir = (
			radial_dir.cross(orbit_normal) if clockwise 
			else orbit_normal.cross(radial_dir)
		).normalized()
		
		# Handle degenerate case (radial aligned with UP)
		if tangent_dir.length_squared() < 0.5:
			orbit_normal = Vector3.FORWARD
			tangent_dir = (
				radial_dir.cross(orbit_normal) if clockwise 
				else orbit_normal.cross(radial_dir)
			).normalized()

	# --- Calculate Required Turn Rate for Current Orbit ---
	# For circular motion: angular_velocity = tangent_speed / radius
	# The ship can only turn so fast (limited by angular_thrust and mass)
	var required_angular_velocity = tangent_speed / current_radius if current_radius > 1.0 else 0.0
	
	# Estimate max angular velocity from ship specs
	# At steady state with angular drag: torque = drag * angular_vel * I
	# So max_angular_vel ≈ angular_thrust / (angular_drag * mass * r^2)
	# Simplified estimate using inertia approximation
	var mass = _agent_body.mass
	var estimated_inertia = mass * 10.0  # Rough approximation
	var max_turn_rate = _movement_system.angular_thrust / (Constants.ANGULAR_DRAG * estimated_inertia + 0.1)
	
	# --- Determine if Ship Can Maintain This Orbit ---
	var can_maintain_orbit = required_angular_velocity < max_turn_rate * 0.8  # 80% margin
	
	# --- Stateless Thrust Direction ---
	# Always point tangentially and thrust forward
	# The physics (centripetal requirement) naturally determines if orbit tightens or widens
	
	var desired_dir: Vector3
	
	if not can_maintain_orbit and tangent_speed > 5.0:
		# Ship is going too fast for this radius - it will naturally spiral out
		# Thrust slightly outward to accelerate the transition to a stable wider orbit
		var outward_bias = radial_dir * 0.2
		desired_dir = (tangent_dir + outward_bias).normalized()
	else:
		# Ship can maintain orbit or is slow enough - just follow tangent
		desired_dir = tangent_dir
	
	# --- Apply Controls ---
	_movement_system.request_rotation_to_pid(desired_dir, delta)
	
	# Thrust if reasonably aligned
	if _movement_system.is_aligned_to(desired_dir):
		_movement_system.request_thrust_forward()
	elif _movement_system.get_forward().dot(desired_dir) > 0.3:
		# Partially aligned - reduced thrust
		_movement_system.request_thrust_forward(0.4)
	# Otherwise, let drag slow us while we turn

