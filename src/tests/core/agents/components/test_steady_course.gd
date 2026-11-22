# Tests for the rotation control as flown on the default ship: the rotation PID on a course
# (MovementSystem._rotate_pid) and the spin damper of a stop (request_rotation_damping_pid); a roll's
# fade; flight round a planet (NavigationSystem.steer_round).

extends GutTest
const AgentSystemScript = preload("res://src/core/systems/agent_system.gd")
var _container: Spatial = null
var _saved = []
func before_each():
	_container = Spatial.new()
	add_child_autofree(_container)
	_saved = [GlobalRefs.agent_container, GlobalRefs.asset_system, Engine.time_scale, Engine.iterations_per_second]
	GlobalRefs.agent_container = _container
	var assets = load("res://src/core/systems/asset_system.gd").new()
	add_child_autofree(assets)
	GlobalRefs.asset_system = assets
func after_each():
	GlobalRefs.agent_container = _saved[0]
	GlobalRefs.asset_system = _saved[1]
	Engine.time_scale = _saved[2]
	Engine.iterations_per_second = _saved[3]
func _body():
	var ship_id = "preset_ship_archetype_prospector_light"
	var preset = load(Constants.ARCHETYPES_DIR.plus_file(ship_id + ".tres"))
	TemplateDatabase.register_evolved(preset)
	for part_id in preset.equipped_tools + preset.equipped_modules:
		if TemplateDatabase.get_template(part_id) == null:
			TemplateDatabase.register_evolved(load("res://database/presets/parts/%s.tres" % part_id))
	var spawner = AgentSystemScript.new()
	autofree(spawner)
	var body = spawner.spawn_npc_from_template(Constants.NPC_BASE_TEMPLATE_PATH, Vector3.ZERO, {"faction": "verdant", "ship_template_id": ship_id, "fit": {"tools": preset.equipped_tools, "modules": preset.equipped_modules}})
	body.get_node(Constants.AI_CONTROLLER_NODE_NAME).set_physics_process(false)
	return body
# Flown on a course the nose settles on it and stays: the turn it had was left to coast inside the
# alignment window and the nose wandered round its course for good (about 0.8 degrees each way).
func test_the_nose_settles_on_its_course():
	Engine.iterations_per_second = 60
	Engine.time_scale = 1.0
	var body = _body()
	yield(get_tree(), "idle_frame")
	var course := Vector3(1, 0, 0)
	body.command_move_direction(course)
	var worst_swing := 0.0
	var worst_off := 0.0
	for i in range(60 * 9):
		yield(get_tree(), "physics_frame")
		if i >= 60 * 6:  # Turned and up to speed
			worst_swing = max(worst_swing, body.angular_velocity.length())
			worst_off = max(worst_off, rad2deg((-body.global_transform.basis.z).angle_to(course)))
	assert_lt(worst_swing, 0.01, "No swing left on course (rad/s)")
	assert_lt(worst_off, 0.2, "The nose on its course (degrees)")


# A stop keeps the heading and brakes against the motion (no flip). Stopped, the ship is still: the stop's spin damper (a PD on the spin) reversed the spin every step,
# shaking the ship at rest for good.
func test_a_stopped_ship_holds_still():
	Engine.iterations_per_second = 60
	Engine.time_scale = 1.0
	var body = _body()
	yield(get_tree(), "idle_frame")
	body.command_move_direction(Vector3(1, 0, 0))
	for i in range(60 * 4):
		yield(get_tree(), "physics_frame")
	var heading: Vector3 = -body.global_transform.basis.z
	body.command_stop()
	var turned := 0.0
	var flips := 0
	var worst_spin := 0.0
	var prev := Vector3.ZERO
	for i in range(60 * 7):
		yield(get_tree(), "physics_frame")
		turned = max(turned, rad2deg(heading.angle_to(-body.global_transform.basis.z)))
		if i >= 60 * 4:  # Stopped
			var spin: Vector3 = body.angular_velocity
			worst_spin = max(worst_spin, spin.length())
			if spin.dot(prev) < 0.0:
				flips += 1
			prev = spin
	assert_lt(body.linear_velocity.length(), 1.0, "Stopped")
	assert_lt(worst_spin, 0.005, "No spin left (rad/s)")
	assert_eq(flips, 0, "and none flipping back and forth")
	assert_lt(turned, 10.0, "Stopped in place, its heading kept: no flip to face back")


# A ship flying to a point behind a planet goes round it, at its keep-out (radius and its own, times
# NAV_AVOID_CLEARANCE): the velocity hold flies the avoidance's tangent, not a nudge it undoes.
# A roll it is given fades: the heading's hold lets go of it (no roll kept against the drag).
func test_round_a_planet_at_its_keep_out_and_a_roll_fades():
	Engine.iterations_per_second = 60
	Engine.time_scale = 4.0
	var body = _body()
	var planet = load("res://src/scenes/game_world/celestial/celestial_body.gd").new()
	var shape = CollisionShape.new()
	shape.name = "CollisionShape"
	shape.shape = SphereShape.new()
	shape.shape.radius = 1000.0
	planet.add_child(shape)
	add_child_autofree(planet)
	planet.global_transform.origin = Vector3(150, 0, -3000)
	load("res://src/core/agents/components/navigation_system.gd").forget_obstacles(get_tree())
	yield(get_tree(), "idle_frame")
	body.command_move_to(Vector3(0, 0, -6500))
	var closest := INF
	for i in range(60 * 60):
		yield(get_tree(), "physics_frame")
		var d: float = body.global_transform.origin.distance_to(planet.global_transform.origin) - 1000.0
		closest = min(closest, d)
	var keep_out: float = (1000.0 + body.get_apparent_radius()) * Constants.NAV_AVOID_CLEARANCE - 1000.0
	assert_gt(closest, keep_out * 0.9, "Round it, at its keep-out (m off its surface)")
	assert_lt(body.global_transform.origin.distance_to(Vector3(0, 0, -6500)), Constants.NAV_ARRIVAL_DISTANCE_THRESHOLD + 5.0, "and there")
	body.angular_velocity = -body.global_transform.basis.z * 1.0
	body.command_move_direction(-body.global_transform.basis.z)
	for i in range(60 * 3):
		yield(get_tree(), "physics_frame")
	assert_lt(body.angular_velocity.length(), 0.01, "The roll faded")
