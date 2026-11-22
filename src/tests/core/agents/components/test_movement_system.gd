# tests/core/agents/components/test_movement_system.gd

extends GutTest

var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
const Autolevel = preload("res://src/core/agents/components/autolevel.gd")
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
		movement_system.get_requested_force().z > 0,
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

func test_force_at_a_point_off_centre_adds_torque():
	movement_system.add_external_force_at(Vector3(0, 0, 100), agent_body.global_transform.origin + Vector3(5, 0, 0))
	assert_eq(movement_system._external_force, Vector3(0, 0, 100))
	assert_eq(movement_system._external_torque, Vector3(0, -500, 0), "Torque is r x F about the centre of mass.")
	movement_system.add_external_force_at(Vector3(0, 0, 100), agent_body.global_transform.origin)
	assert_eq(movement_system._external_torque, Vector3(0, -500, 0), "A force through the centre adds no torque.")


func test_thrust_into_a_planet_it_is_against_is_dropped():
	movement_system.request_thrust_direction(Vector3(1, 0, -1), 1.0)
	movement_system.cancel_thrust_toward(Vector3(0, 0, -1))
	var left: Vector3 = movement_system.get_requested_force()
	assert_almost_eq(left.z, 0.0, 0.001, "None into it")
	assert_gt(left.x, 0.0, "The sideways part stays: it slides off")
	movement_system.cancel_thrust_toward(Vector3(-1, 0, 0))
	assert_gt(movement_system.get_requested_force().x, 0.0, "Thrust away from one is let be")


# The roll about the nose from `basis`'s up to the level up (signed), as autolevel measures it.
func _roll(basis: Basis) -> float:
	var forward: Vector3 = -basis.z.normalized()
	var level: Vector3 = (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
	return atan2(basis.y.cross(level).dot(forward), basis.y.dot(level))


func test_autolevel_rolls_about_the_nose_towards_level():
	var heading := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.3)  # Turned and pitched a little
	assert_lt(Autolevel.torque(heading, 4000.0, 5e6).length(), 0.01, "Level: nothing (pitch is the pilot's)")
	for angle in [0.5, -0.5, 2.5, -2.5]:
		var rolled: Basis = heading * Basis(Vector3.BACK, angle)  # Rolled about the nose
		var torque: Vector3 = Autolevel.torque(rolled, 4000.0, 5e6)
		var forward: Vector3 = -rolled.z
		assert_almost_eq(abs(torque.normalized().dot(forward)), 1.0, 0.001, "About the nose only: the heading stays")
		var nudged: Basis = Basis(torque.normalized(), 0.01) * rolled
		assert_lt(abs(_roll(nudged)), abs(_roll(rolled)), "Turning with it rolls towards level (%s rad)" % angle)


func test_autolevel_is_a_small_share_of_steering_and_none_nose_up():
	var upside_down: Basis = Basis(Vector3.BACK, PI * 0.9)
	var torque: Vector3 = Autolevel.torque(upside_down, 1e9, 5e6)
	assert_almost_eq(torque.length(), 5e6 * Constants.AUTOLEVEL_TORQUE_SHARE, 1.0, "Capped: steering always wins")
	var nose_up: Basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 1.0)
	assert_eq(Autolevel.torque(nose_up, 4000.0, 5e6), Vector3.ZERO, "No level to roll to")
	assert_true(Settings.get_option("autolevel"), "On by default")
