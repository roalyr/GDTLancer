# tests/core/agents/components/test_movement_system.gd
extends GutTest

var MovementSystem = load("res://core/agents/components/movement_system.gd")
var agent_body
var movement_system


# Use a test-specific KinematicBody to add the `current_velocity` var
class TestAgentBody:
	extends KinematicBody
	var current_velocity = Vector3.ZERO


func before_each():
	# Create a mock agent body scene for the test
	agent_body = TestAgentBody.new()
	agent_body.name = "TestAgentBody"

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
		"max_move_speed": 100.0,
		"acceleration": 0.5,
		"deceleration": 0.5,
		"max_turn_speed": 1.0,  # rad/s
		"brake_strength": 1.0,
		"alignment_threshold_angle_deg": 30.0
	}
	movement_system.initialize_movement_params(move_params)


func after_each():
	if is_instance_valid(agent_body):
		agent_body.queue_free()


func test_initialization():
	assert_eq(movement_system.max_move_speed, 100.0)
	assert_eq(movement_system.acceleration, 0.5)
	assert_almost_eq(movement_system._alignment_threshold_rad, deg2rad(30.0), 0.001)
	assert_true(
		is_instance_valid(movement_system.agent_body),
		"It should have a valid reference to its parent agent body."
	)


func test_accelerates_when_aligned():
	agent_body.current_velocity = Vector3.ZERO
	agent_body.transform = agent_body.transform.looking_at(Vector3.FORWARD, Vector3.UP)

	movement_system.apply_acceleration(Vector3.FORWARD, 0.1)

	assert_true(
		agent_body.current_velocity.length() > 0.0,
		"Velocity should increase when accelerating while aligned."
	)
	assert_true(
		agent_body.current_velocity.z < 0,
		"Velocity should be in the local forward direction (negative Z)."
	)


func test_does_not_accelerate_when_not_aligned():
	agent_body.current_velocity = Vector3.ZERO
	# Agent looks forward, but tries to accelerate to the right (90 deg diff > 30 deg threshold)
	agent_body.transform = agent_body.transform.looking_at(Vector3.FORWARD, Vector3.UP)

	movement_system.apply_acceleration(Vector3.RIGHT, 0.1)

	assert_almost_eq(
		agent_body.current_velocity.length(),
		0.0,
		0.001,
		"Velocity should not increase when not aligned."
	)


func test_deceleration_reduces_speed():
	agent_body.current_velocity = Vector3(0, 0, -100)
	var initial_speed = agent_body.current_velocity.length()

	movement_system.apply_deceleration(0.1)
	var final_speed = agent_body.current_velocity.length()

	assert_true(final_speed < initial_speed, "Deceleration should reduce the agent's speed.")


func test_braking_reduces_speed_faster_than_deceleration():
	agent_body.current_velocity = Vector3(0, 0, -100)
	movement_system.apply_deceleration(0.1)
	var speed_after_decel = agent_body.current_velocity.length()

	agent_body.current_velocity = Vector3(0, 0, -100)
	movement_system.apply_braking(0.1)
	var speed_after_brake = agent_body.current_velocity.length()

	assert_true(
		speed_after_brake < speed_after_decel,
		"Braking should be stronger than natural deceleration."
	)


func test_braking_reports_stopped():
	agent_body.current_velocity = Vector3(0, 0, -0.1)
	var stopped = movement_system.apply_braking(1.0)
	assert_true(stopped, "Braking should return true when velocity is near zero.")

	agent_body.current_velocity = Vector3(0, 0, -50)
	stopped = movement_system.apply_braking(0.01)
	assert_false(stopped, "Braking should return false when velocity is still high.")


func test_rotation_turns_towards_target():
	var target_dir = Vector3.RIGHT
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)

	var initial_forward_vec = -agent_body.global_transform.basis.z
	var initial_dot = initial_forward_vec.dot(target_dir)

	movement_system.apply_rotation(target_dir, 0.1)

	var final_forward_vec = -agent_body.global_transform.basis.z
	var final_dot = final_forward_vec.dot(target_dir)

	assert_true(
		final_dot > initial_dot, "Agent should turn to be more aligned with the target direction."
	)
