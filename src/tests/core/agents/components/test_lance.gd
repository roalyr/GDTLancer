# Tests for the kinetic lance: its law (ShipLaws.lance_stats, lance_damage), LanceController
# (strikes, glances, the knock, lances left in the hull, reload, restock) and the ram command's
# run-up distance.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const LanceScript = preload("res://src/core/agents/components/lance_controller.gd")
const CommandRam = preload("res://src/core/agents/components/navigation_system/command_ram.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")

var rammer: RigidBody = null
var target: RigidBody = null
var lance: Spatial = null


func before_each():
	rammer = _make_body(Vector3.ZERO)
	target = _make_body(Vector3(0, 0, -30))
	lance = LanceScript.new()
	rammer.add_child(lance)
	lance.setup(rammer, "test_lance", ShipLaws.lance_stats(Constants.PART_TYPE_SEEDS.lance[2]))


func _make_body(position: Vector3) -> RigidBody:
	var body = AgentScript.new()
	add_child_autofree(body)
	body.global_transform.origin = position
	body.hull_max = 200.0
	body.hull = 200.0
	body.mass = 6000.0
	return body


func test_law():
	var stats: Dictionary = ShipLaws.lance_stats({"nail_mass": 200.0, "count": 3.0})
	assert_eq(stats.count, 3)
	assert_almost_eq(stats.mass, 200.0 * (3 + Constants.LAW_LANCE_SEAT_NAILS), 0.01, "Seat and quiver")
	assert_almost_eq(stats.damage, Constants.LAW_LANCE_DAMAGE[1], 0.01)
	assert_eq(ShipLaws.lance_damage(stats, Constants.LAW_LANCE_MIN_SPEED - 1.0, 0.0), 0.0, "Too slow: glances off")
	assert_almost_eq(ShipLaws.lance_damage(stats, Constants.LAW_LANCE_REF_SPEED, 0.0), stats.damage, 0.01)
	assert_almost_eq(ShipLaws.lance_damage(stats, 160.0, 0.0), stats.damage * 160.0 / Constants.LAW_LANCE_REF_SPEED, 0.01, "Damage grows with speed")
	assert_eq(ShipLaws.lance_damage(stats, 300.0, Constants.LAW_LANCE_GLANCE_ANGLE + 5.0), 0.0, "Too oblique: glances off")
	assert_gt(ShipLaws.lance_stats({"nail_mass": 400.0, "count": 3.0}).damage, stats.damage, "A heavier lance hits harder")
	assert_eq(ShipLaws.lance_stats({"nail_mass": 200.0, "count": 3.4}).count, 3, "The count gene rounds")


func test_a_strike_damages_knocks_and_leaves_the_lance_in():
	rammer.linear_velocity = Vector3(0, 0, -200)  # Nose on (-Z) at 200 m/s
	var damage: float = lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1))
	assert_almost_eq(damage, lance.lance.damage, 0.01)
	assert_almost_eq(target.hull, 200.0 - damage, 0.01)
	assert_eq(lance.nails, 2, "One lance used")
	assert_false(lance.is_seated(), "The next is sliding in")
	assert_almost_eq(rammer.linear_velocity.z, target.linear_velocity.z, 0.01, "Stopped against each other")
	assert_almost_eq(target.linear_velocity.z, -100.0, 0.01, "Equal masses: the target takes half the speed")
	var stuck := 0
	for child in target.get_children():
		if child.is_in_group(LanceScript.LANCE_GROUP):
			stuck += 1
	assert_eq(stuck, 1, "The lance stays in the hull")
	lance._physics_process(lance.lance.reload + 0.1)
	assert_true(lance.is_seated(), "Reloaded")
	target.repair_hull()
	yield(get_tree(), "idle_frame")
	for child in target.get_children():
		assert_false(child.is_in_group(LanceScript.LANCE_GROUP), "Repairs take it out")


func test_too_slow_or_oblique_glances_off():
	rammer.linear_velocity = Vector3(0, 0, -(Constants.LAW_LANCE_MIN_SPEED - 10.0))
	assert_eq(lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1)), 0.0)
	assert_eq(lance.nails, 3, "The lance stays seated")
	assert_eq(target.hull, 200.0)
	rammer.linear_velocity = Vector3(0, 0, -250)
	assert_eq(lance.strike(target, Vector3(0, 0, -20), Vector3(1, 0, 0.2).normalized()), 0.0, "Side-on")


func test_last_lance_then_restock():
	rammer.linear_velocity = Vector3(0, 0, -200)
	for i in range(3):
		lance.reload_left = 0.0
		target.linear_velocity = Vector3.ZERO
		rammer.linear_velocity = Vector3(0, 0, -200)
		lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1))
	assert_eq(lance.nails, 0)
	assert_false(lance.is_seated())
	assert_eq(lance.restock(1), 1, "Restocks at most what it may")
	assert_eq(lance.restock(), 2)
	assert_true(lance.is_seated())


func test_a_lance_adds_to_damage_per_second_while_it_has_lances():
	var movement = load("res://src/core/agents/components/movement_system.gd").new()
	rammer.add_child(movement)
	rammer.movement_system = movement
	movement.linear_thrust = Constants.LAW_LANCE_REF_SPEED * rammer.mass * Constants.LINEAR_DRAG  # Top speed: the reference speed
	assert_almost_eq(rammer.get_damage_per_second(), lance.lance.damage / max(lance.lance.reload, Constants.AI_RAM_PASS_TIME), 0.01, "One strike per pass")
	lance.nails = 0
	assert_eq(rammer.get_damage_per_second(), 0.0, "No lasers, no lances left")


func test_aim_stiffens_as_the_charge_closes():
	assert_eq(CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_RANGE * 2.0), 1.0, "Usual aim from afar")
	assert_almost_eq(CommandRam.aim_gain(0.0), Constants.NAV_RAM_PID_GAIN, 0.001)
	var middle: float = CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_RANGE * 0.5)
	assert_lt(middle, (1.0 + Constants.NAV_RAM_PID_GAIN) * 0.5, "Most of the rise is near the end")


func test_run_up_distance():
	assert_eq(CommandRam.run_up_distance(150.0, Constants.LAW_LANCE_MIN_SPEED + 1.0, 0.0), 0.0, "Fast enough already")
	assert_eq(CommandRam.run_up_distance(Constants.LAW_LANCE_MIN_SPEED - 1.0, 0.0, 0.0), INF, "Never fast enough")
	var from_rest: float = CommandRam.run_up_distance(150.0, 0.0, 0.0)
	var t: float = -log((150.0 - Constants.LAW_LANCE_MIN_SPEED) / 150.0) / Constants.LINEAR_DRAG
	assert_almost_eq(from_rest, 150.0 * t - 150.0 * (1.0 - exp(-Constants.LINEAR_DRAG * t)) / Constants.LINEAR_DRAG, 1.0, "Thrust against drag from rest")
	assert_gt(CommandRam.run_up_distance(150.0, 0.0, 10.0), from_rest, "A target pulling away needs more")
