# Tests for NavigationSystem commands on a RigidBody agent.

extends GutTest

var NavigationSystem = load("res://src/core/agents/components/navigation_system.gd")
var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")

var agent_body
var nav_system
var mock_movement_system
var signal_catcher


# Test helper class that extends RigidBody
class TestAgentBody:
	extends RigidBody
	var interaction_radius: float = 10.0
	func get_interaction_radius() -> float:
		return interaction_radius


func before_each():
	signal_catcher = SignalCatcher.new()
	EventBus.connect("agent_reached_destination", signal_catcher, "_on_signal_received")

	agent_body = TestAgentBody.new()
	agent_body.name = "TestAgent"
	agent_body.mode = RigidBody.MODE_RIGID
	agent_body.gravity_scale = 0.0

	mock_movement_system = double(MovementSystem).new()
	# Stub methods for the new RigidBody-based API
	stub(mock_movement_system, "_ready").to_return(null)
	stub(mock_movement_system, "request_thrust_forward").to_return(null)
	stub(mock_movement_system, "request_thrust_brake").to_return(null)
	stub(mock_movement_system, "request_thrust_direction").to_return(null)
	stub(mock_movement_system, "request_rotation_to").to_return(null)
	stub(mock_movement_system, "request_rotation_to_pid").to_return(null)
	stub(mock_movement_system, "request_rotation_damping").to_return(null)
	stub(mock_movement_system, "request_rotation_damping_pid").to_return(null)
	stub(mock_movement_system, "is_aligned_to").to_return(true)
	stub(mock_movement_system, "is_stopped").to_return(false)
	stub(mock_movement_system, "is_rotation_stopped").to_return(false)
	stub(mock_movement_system, "get_current_speed").to_return(0.0)
	stub(mock_movement_system, "get_velocity").to_return(Vector3.ZERO)
	stub(mock_movement_system, "linear_thrust").to_return(5000.0)

	nav_system = NavigationSystem.new()
	nav_system.name = "NavigationSystem"

	agent_body.add_child(mock_movement_system)
	agent_body.add_child(nav_system)

	get_tree().get_root().add_child(agent_body)

	nav_system._ready()
	nav_system.initialize_navigation({}, mock_movement_system)


func after_each():
	if EventBus.is_connected("agent_reached_destination", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_reached_destination", signal_catcher, "_on_signal_received")

	if is_instance_valid(agent_body):
		agent_body.queue_free()
	if is_instance_valid(signal_catcher):
		signal_catcher.free()


func test_initial_state_is_idle():
	signal_catcher.reset()
	assert_eq(
		nav_system._current_command.type,
		nav_system.CommandType.IDLE,
		"Default command should be IDLE."
	)
	# Idle state does nothing (drag handles deceleration)
	nav_system.update_navigation(0.1)


func test_set_command_stopping():
	signal_catcher.reset()
	nav_system.set_command_stopping()
	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_damping_pid")


func test_stop_command_emits_reached_destination_signal():
	signal_catcher.reset()
	# Make the movement system report stopped
	stub(mock_movement_system, "is_stopped").to_return(true)
	stub(mock_movement_system, "is_rotation_stopped").to_return(true)

	nav_system.set_command_stopping()
	nav_system.update_navigation(0.1)

	var captured_args = signal_catcher.get_last_args()
	assert_not_null(captured_args, "A signal should have been captured.")
	assert_eq(
		captured_args[0], agent_body, "The first argument of the signal should be the agent_body."
	)


func test_set_command_move_to():
	signal_catcher.reset()
	var target_pos = Vector3(100, 200, 300)
	nav_system.set_command_move_to(target_pos)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.MOVE_TO)
	assert_eq(nav_system._current_command.target_pos, target_pos)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")


func test_set_command_approach():
	signal_catcher.reset()
	var target_node = TestAgentBody.new()
	agent_body.add_child(target_node)
	# Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)
	assert_eq(nav_system._current_command.target_node, target_node)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")


func test_approach_holds_on_arrival_and_closes_in_again():
	stub(mock_movement_system, "request_velocity_pid").to_return(null)
	signal_catcher.reset()
	var target_node = TestAgentBody.new()
	add_child_autofree(target_node)
	var safe: float = Constants.NAV_APPROACH_MIN_DISTANCE
	target_node.global_transform.origin = agent_body.global_transform.origin + Vector3(0, 0, -safe)
	nav_system.set_command_approach(target_node)
	nav_system.update_navigation(0.1)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH, "Arriving does not end the command")
	assert_called(mock_movement_system, "request_velocity_pid")
	assert_eq(signal_catcher.get_last_args()[0], agent_body, "Arrival is announced")
	signal_catcher.reset()
	nav_system.update_navigation(0.1)
	assert_null(signal_catcher.get_last_args(), "once.")
	var hold: float = safe + Constants.NAV_ARRIVAL_DISTANCE_THRESHOLD
	target_node.global_transform.origin = agent_body.global_transform.origin + Vector3(0, 0, -(hold + Constants.NAV_APPROACH_RESUME_MARGIN * 0.5))
	nav_system.update_navigation(0.1)
	assert_true(nav_system._current_command.get("holding", false), "A little drift: still holding")
	target_node.global_transform.origin = agent_body.global_transform.origin + Vector3(0, 0, -(hold + Constants.NAV_APPROACH_RESUME_MARGIN * 2.0))
	nav_system.update_navigation(0.1)
	assert_false(nav_system._current_command.get("holding", false), "pulled away: closing in again")
	assert_called(mock_movement_system, "request_thrust_forward")


func test_orbit_holds_the_distance_it_was_given_around_a_moving_target():
	var Orbit = load("res://src/core/agents/components/navigation_system/command_orbit.gd")
	var cmd = {"distance": 2000.0}
	var radius: float = Orbit.get_orbit_radius(cmd, 2000.0, 30.0)
	assert_eq(radius, 2000.0, "The distance at the command")
	assert_eq(Orbit.get_orbit_radius({"distance": 10.0}, 10.0, 30.0), 30.0 * Constants.NAV_CLOSE_ORBIT_DISTANCE_FACTOR, "but never inside the target's safe distance.")
	# Follow the commanded velocity (as the velocity PID would) around a target flying past.
	var target := Vector3.ZERO
	var target_velocity := Vector3(80, 0, -40)
	var ship := Vector3(2000, 0, 0)
	var normal: Vector3 = Orbit.pick_orbit_normal(Vector3.RIGHT, Vector3(0, 0, -50), false)
	var worst := 0.0
	for step in range(1200):  # 120 s
		var radial: Vector3 = ship - target
		var radial_dir: Vector3 = radial.normalized()
		var tangent: Vector3 = normal.cross(radial_dir).normalized()
		var velocity: Vector3 = target_velocity + Orbit.get_orbit_velocity(radial_dir, tangent, radial.length(), radius, 200.0, 100.0)
		ship += velocity * 0.1
		target += target_velocity * 0.1
		if step > 100:
			worst = max(worst, abs((ship - target).length() - radius))
	assert_lt(worst, 50.0, "The ship stays near 2 km from the target wherever it goes.")


func test_orbit_steers_back_to_its_radius_and_keeps_its_plane():
	var Orbit = load("res://src/core/agents/components/navigation_system/command_orbit.gd")
	var normal: Vector3 = Orbit.pick_orbit_normal(Vector3.RIGHT, Vector3(0, 0, -50), false)
	assert_almost_eq(normal.cross(Vector3.RIGHT).normalized(), Vector3(0, 0, -1), Vector3.ONE * 0.001, "The way the ship already moves round the target")
	var outside: Vector3 = Orbit.get_orbit_velocity(Vector3.RIGHT, Vector3.FORWARD, 3000.0, 2000.0, 200.0, 100.0)
	assert_lt(outside.x, 0.0, "Too far out: heads back in")
	var inside: Vector3 = Orbit.get_orbit_velocity(Vector3.RIGHT, Vector3.FORWARD, 1000.0, 2000.0, 200.0, 100.0)
	assert_gt(inside.x, 0.0, "too close: backs out.")
	var tight: Vector3 = Orbit.get_orbit_velocity(Vector3.RIGHT, Vector3.FORWARD, 50.0, 50.0, 200.0, 100.0)
	assert_lt(tight.length(), 200.0 * Constants.NAV_ORBIT_SPEED_SHARE, "Tight orbits go slower.")


func test_set_command_orbit():
	signal_catcher.reset()
	var target_node = TestAgentBody.new()
	agent_body.add_child(target_node)
	# Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_orbit(target_node, 500.0, true)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ORBIT)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")


func test_set_command_flee():
	signal_catcher.reset()
	var target_node = TestAgentBody.new()
	agent_body.add_child(target_node)
	# Move the target so there is a direction to flee from.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_flee(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.FLEE)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")
	assert_called(mock_movement_system, "request_thrust_forward")


func test_set_command_align_to():
	signal_catcher.reset()
	var direction = (-agent_body.global_transform.basis.z).normalized()
	agent_body.angular_velocity = Vector3.ZERO
	nav_system.set_command_align_to(direction)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ALIGN_TO)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")
	assert_eq(nav_system._current_command.type, nav_system.CommandType.IDLE)


func test_set_command_align_to_with_forward_thrust():
	signal_catcher.reset()
	var direction = Vector3.BACK.normalized()
	nav_system.set_command_align_to(direction, true, 1.0, true)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ALIGN_TO)
	assert_true(nav_system._current_command.apply_forward_thrust)
	assert_eq(nav_system._current_command.forward_thrust_scale, 1.0)
	assert_true(nav_system._current_command.persist_until_cleared)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "request_rotation_to_pid")
	assert_called(mock_movement_system, "request_thrust_forward")
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ALIGN_TO)


func test_invalid_target_in_update_switches_to_stopping():
	signal_catcher.reset()
	var target_node = TestAgentBody.new()

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)

	target_node.free()
	yield(get_tree(), "idle_frame")

	nav_system.update_navigation(0.1)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	assert_called(mock_movement_system, "request_rotation_damping_pid")


func test_avoidance_sidesteps_a_rock_on_the_path():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var rock = [Vector3(5, 0, -300), 40.0]  # Slightly right of a straight path along -Z
	var push: Vector3 = Nav.compute_avoidance(Vector3.ZERO, Vector3(0, 0, -50), 12.0, [rock])
	assert_lt(push.x, 0.0, "Pushes left, away from the rock's side of the path.")
	assert_almost_eq(push.z, 0.0, 0.001, "Sideways only; the command keeps its own speed.")


func test_avoidance_ignores_rocks_behind_far_or_off_the_path():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var velocity = Vector3(0, 0, -50)
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, velocity, 12.0, [[Vector3(0, 0, 300), 40.0]]), Vector3.ZERO, "Behind")
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, velocity, 12.0, [[Vector3(0, 0, -5000), 40.0]]), Vector3.ZERO, "Beyond the look-ahead")
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, velocity, 12.0, [[Vector3(500, 0, -300), 40.0]]), Vector3.ZERO, "Well clear of the path")
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, Vector3(0, 0, -1), 12.0, [[Vector3(0, 0, -30), 40.0]]), Vector3.ZERO, "Drifting too slowly to matter")


func test_avoidance_is_more_urgent_for_closer_rocks():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var velocity = Vector3(0, 0, -50)
	var near: Vector3 = Nav.compute_avoidance(Vector3.ZERO, velocity, 12.0, [[Vector3(10, 0, -100), 40.0]])
	var far: Vector3 = Nav.compute_avoidance(Vector3.ZERO, velocity, 12.0, [[Vector3(10, 0, -350), 40.0]])
	assert_gt(near.length(), far.length())
