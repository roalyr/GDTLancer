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


func test_planets_are_obstacles_the_autopilot_steers_round():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var planet = load("res://src/scenes/game_world/celestial/celestial_body.gd").new()
	var shape = CollisionShape.new()
	shape.name = "CollisionShape"
	shape.shape = SphereShape.new()
	shape.shape.radius = 1000.0
	planet.add_child(shape)
	add_child_autofree(planet)
	planet.global_transform.origin = Vector3(300, 0, -3000)
	assert_true(planet.is_in_group("obstacle"))
	assert_almost_eq(planet.get_obstacle_radius(), 1000.0, 0.001, "Its size")
	var push: Vector3 = Nav.compute_avoidance(Vector3.ZERO, Vector3(0, 0, -300), 12.0, [[planet.global_transform.origin, planet.get_obstacle_radius(), planet]])
	assert_lt(push.x, 0.0, "A leg heading into it is pushed off to the side")


func test_a_ship_stopped_against_an_obstacle_slides_off_the_way_it_pushes():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var planet = [Vector3(300, 0, -1010), 1000.0]  # Pressed against its face, a little off its middle
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, Vector3.ZERO, 12.0, [planet]), Vector3.ZERO, "Not pushing anywhere: nothing in the way")
	var push: Vector3 = Nav.compute_avoidance(Vector3.ZERO, Vector3(0, 0, -0.1), 12.0, [planet], Vector3(0, 0, -1000))
	assert_lt(push.x, 0.0, "Pushing into it: sidesteps along its face")



func test_against_a_planet_only_planets_and_moons_count_as_contact():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var planet := Spatial.new()
	planet.add_to_group("celestial")
	var rock := Spatial.new()
	add_child_autofree(planet)
	add_child_autofree(rock)
	var found: Array = Nav.contacts(Vector3.ZERO, 12.0, [[Vector3(0, 0, -1020), 1000.0, planet], [Vector3(0, -150, 0), 140.0, rock]])
	assert_eq(found.size(), 1, "The planet it touches, not the rock it works by")
	assert_almost_eq(found[0].z, -1.0, 0.001)
	assert_eq(Nav.contacts(Vector3.ZERO, 12.0, [[Vector3(0, 0, -3000), 1000.0, planet]]).size(), 0, "Clear of it")


func test_thrust_off_the_way_it_moves_is_checked_too():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var planet = [Vector3(0, 0, -1700), 1000.0]
	var moving := Vector3(50, 0, 0)  # Clear along its way
	assert_eq(Nav.compute_avoidance(Vector3.ZERO, moving, 12.0, [planet]), Vector3.ZERO)
	assert_gt(Nav.compute_avoidance(Vector3.ZERO, moving, 12.0, [planet], Vector3(0, 0, -1000)).length(), 0.0, "But it thrusts toward the planet: pushed")


func test_nested_bins_push_as_every_obstacle_looked_at_does():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var obstacles: Array = []
	for i in range(120):
		var at := Vector3(rng.randf_range(-15000, 15000), rng.randf_range(-1500, 1500), rng.randf_range(-15000, 15000))
		if i % 3 == 0:  # Some clumped, as in a field
			at = obstacles[i - 1][0] + Vector3(rng.randf_range(-400, 400), rng.randf_range(-400, 400), rng.randf_range(-400, 400)) if i > 0 else at
		obstacles.append([at, rng.randf_range(20.0, 1200.0) if i % 17 == 0 else rng.randf_range(15.0, 200.0), null])
	for layout in [[2000.0, 3.0, 3], [500.0, 2.0, 4], [8000.0, 4.0, 1]]:
		var tree: Array = Nav.nest(obstacles, layout[0], layout[1], layout[2])
		var pushed := 0
		for _try in range(300):
			var position := Vector3(rng.randf_range(-16000, 16000), rng.randf_range(-2000, 2000), rng.randf_range(-16000, 16000))
			var velocity := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.0, 350.0)
			var intent := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) if rng.randf() < 0.5 else Vector3.ZERO
			var own_radius: float = rng.randf_range(5.0, 150.0)
			var every: Vector3 = Nav.compute_avoidance(position, velocity, own_radius, obstacles, intent)
			var binned: Vector3 = Nav._avoidance(position, velocity, own_radius, tree, intent, null)
			assert_almost_eq(binned.distance_to(every), 0.0, 0.0001, "Same push, %s" % str(layout))
			if every != Vector3.ZERO:
				pushed += 1
		assert_gt(pushed, 10, "Some paths do pass obstacles")


func test_the_command_target_is_left_out_of_the_look_ahead():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var station := Spatial.new()
	add_child_autofree(station)
	var obstacles: Array = [[Vector3(0, 0, -300), 100.0, station]]
	var tree: Array = Nav.nest(obstacles, 2000.0, 3.0, 3)
	assert_ne(Nav._avoidance(Vector3.ZERO, Vector3(0, 0, -100), 12.0, tree, Vector3.ZERO, null), Vector3.ZERO, "In the way")
	assert_eq(Nav._avoidance(Vector3.ZERO, Vector3(0, 0, -100), 12.0, tree, Vector3.ZERO, station), Vector3.ZERO, "Flying to it")


func _planet(radius: float, at: Vector3) -> StaticBody:
	var planet = load("res://src/scenes/game_world/celestial/celestial_body.gd").new()
	var shape = CollisionShape.new()
	shape.name = "CollisionShape"
	shape.shape = SphereShape.new()
	shape.shape.radius = radius
	planet.add_child(shape)
	planet.transform.origin = at
	return planet


func test_in_the_game_world_obstacles_are_kept_until_one_comes_or_goes():
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var StepCache = load("res://src/core/utils/step_cache.gd")
	StepCache.set_active(true)
	var index: Dictionary = Nav.get_obstacle_index(get_tree())
	var before: int = index.obstacles.size()
	index["marked"] = true
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	assert_true(Nav.get_obstacle_index(get_tree()).has("marked"), "Kept from step to step")
	var planet = _planet(500.0, Vector3(0, 0, -5000))
	add_child(planet)
	index = Nav.get_obstacle_index(get_tree())
	assert_false(index.has("marked"), "One came: gathered again")
	assert_eq(index.obstacles.size(), before + 1)
	assert_eq(index.celestials.back()[2], planet, "Among the planets, for contacts")
	remove_child(planet)
	planet.free()
	index = Nav.get_obstacle_index(get_tree())
	assert_eq(index.obstacles.size(), before, "One went: gathered again")
	StepCache.set_active(false)


func test_a_charge_leads_a_crossing_target_to_where_they_meet():
	var Charge = load("res://src/core/agents/components/navigation_system/command_charge.gd")
	var t: float = Charge.intercept_time(Vector3(0, 0, -1000), Vector3(100, 0, 0), 200.0)
	var meet: Vector3 = Vector3(0, 0, -1000) + Vector3(100, 0, 0) * t
	assert_almost_eq(meet.length(), 200.0 * t, 0.01, "Both get there at once")
	assert_eq(Charge.intercept_time(Vector3(0, 0, -1000), Vector3(0, 0, -300), 200.0), -1.0, "A faster runner is never caught")
