# tests/core/agents/components/test_movement_system.gd
# Version: 2.0 - Updated for RigidBody physics with thrust-based flight.
extends GutTest

var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
var agent_body
var movement_system


func before_each():
	# Create a RigidBody as the agent body
	agent_body = RigidBody.new()
	agent_body.name = "TestAgentBody"
	agent_body.mode = RigidBody.MODE_RIGID
	agent_body.gravity_scale = 0.0

	# The movement system must be a child of the body to work
	movement_system = MovementSystem.new()
	movement_system.name = "MovementSystem"
	agent_body.add_child(movement_system)

	# Add to tree so get_parent() works
	get_tree().get_root().add_child(agent_body)

	# Manually call ready to ensure parent references are set
	movement_system._ready()

	# Initialize with known test parameters
	var move_params = {
		"mass": 100.0,
		"linear_thrust": 5000.0,
		"angular_thrust": 2000.0,
		"alignment_threshold_angle_deg": 30.0
	}
	movement_system.initialize_movement_params(move_params)


func after_each():
	if is_instance_valid(agent_body):
		agent_body.queue_free()


func test_initialization():
	assert_eq(movement_system.linear_thrust, 5000.0)
	assert_eq(movement_system.angular_thrust, 2000.0)
	assert_almost_eq(movement_system._alignment_threshold_rad, deg2rad(30.0), 0.001)
	assert_true(
		is_instance_valid(movement_system.agent_body),
		"It should have a valid reference to its parent agent body."
	)
	assert_eq(agent_body.mass, 100.0, "Mass should be set on the RigidBody.")


func test_request_thrust_forward_accumulates_force():
	movement_system._accumulated_force = Vector3.ZERO
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)
	
	movement_system.request_thrust_forward()
	
	assert_true(
		movement_system._accumulated_force.length() > 0.0,
		"Forward thrust should accumulate force."
	)
	assert_true(
		movement_system._accumulated_force.z < 0,
		"Force should be in the forward direction (negative Z)."
	)


func test_request_thrust_brake_opposes_velocity():
	movement_system._accumulated_force = Vector3.ZERO
	agent_body.linear_velocity = Vector3(0, 0, -50)
	
	movement_system.request_thrust_brake()
	
	assert_true(
		movement_system._accumulated_force.z > 0,
		"Brake thrust should oppose current velocity direction."
	)


func test_request_thrust_direction():
	movement_system._accumulated_force = Vector3.ZERO
	
	movement_system.request_thrust_direction(Vector3.RIGHT)
	
	assert_true(
		movement_system._accumulated_force.x > 0,
		"Thrust should be applied in the requested direction."
	)


func test_request_rotation_accumulates_torque():
	movement_system._accumulated_torque = Vector3.ZERO
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)
	
	movement_system.request_rotation_to(Vector3.RIGHT)
	
	assert_true(
		movement_system._accumulated_torque.length() > 0.0,
		"Rotation request should accumulate torque."
	)


func test_is_aligned_to():
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)
	
	# Should be aligned to forward (within threshold)
	assert_true(
		movement_system.is_aligned_to(Vector3.FORWARD),
		"Should be aligned when looking at target."
	)
	
	# Should not be aligned to right (90 deg > 30 deg threshold)
	assert_false(
		movement_system.is_aligned_to(Vector3.RIGHT),
		"Should not be aligned when target is outside threshold."
	)


func test_is_stopped():
	agent_body.linear_velocity = Vector3.ZERO
	assert_true(movement_system.is_stopped(), "Should report stopped when velocity is zero.")
	
	agent_body.linear_velocity = Vector3(0, 0, -50)
	assert_false(movement_system.is_stopped(), "Should not report stopped when moving.")


func test_throttle_affects_force():
	movement_system._accumulated_force = Vector3.ZERO
	movement_system.thrust_throttle = 0.5
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)
	
	movement_system.request_thrust_forward()
	var full_force = movement_system._accumulated_force.length()
	
	# The throttle is applied during integrate_forces, not during request
	# So the accumulated force should be full thrust
	assert_almost_eq(full_force, 5000.0, 1.0, "Accumulated force should be full thrust.")
