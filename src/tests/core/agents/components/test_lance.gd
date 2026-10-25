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
	assert_eq(ShipLaws.lance_damage(stats, Constants.LAW_LANCE_MIN_SPEED - 1.0), 0.0, "Too slow: glances off")
	assert_almost_eq(ShipLaws.lance_damage(stats, Constants.LAW_LANCE_REF_SPEED), stats.damage, 0.01)
	assert_almost_eq(ShipLaws.lance_damage(stats, 160.0), stats.damage * 160.0 / Constants.LAW_LANCE_REF_SPEED, 0.01, "Damage grows with speed")
	assert_eq(ShipLaws.lance_hit_chance(stats, 0.0), 1.0, "Square-on: sure")
	var slip: float = ShipLaws.lance_hit_chance(stats, Constants.LAW_LANCE_GLANCE_ANGLE)
	assert_almost_eq(slip, Constants.LAW_LANCE_SLIP_CHANCE, 0.001, "At the glance angle: only the slip chance (a 12 m lance)")
	assert_gt(ShipLaws.lance_hit_chance(stats, 20.0), 0.85, "Shallow off-angle: still likely")
	assert_gt(ShipLaws.lance_hit_chance(stats, 75.0), 0.0, "Past it: may slip in")
	assert_lt(ShipLaws.lance_hit_chance(stats, 75.0), slip)
	assert_eq(ShipLaws.lance_hit_chance(stats, 90.0), 0.0, "Side-on: never")
	var long_lance: Dictionary = ShipLaws.lance_stats({"nail_mass": 1000.0, "count": 3.0})
	assert_gt(ShipLaws.lance_hit_chance(long_lance, 70.0), ShipLaws.lance_hit_chance(stats, 70.0), "A longer lance slips in more often")
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
	assert_eq(lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1), 0.0), 0.0)
	assert_eq(lance.nails, 3, "The lance stays seated")
	assert_eq(target.hull, 200.0)
	rammer.linear_velocity = Vector3(0, 0, -250)
	assert_eq(lance.strike(target, Vector3(8, 0, -30), Vector3(1, 0, 0.2).normalized(), 0.99), 0.0, "Nearly side-on, off the hull's middle: glances off")
	lance._glanced.clear()
	assert_gt(lance.strike(target, Vector3(8, 0, -30), Vector3(1, 0, 0.2).normalized(), 0.0), 0.0, "unless it slips between parts")
	lance._glanced.clear()
	lance.reload_left = 0.0
	rammer.linear_velocity = Vector3(0, 0, -250)  # The knock stopped it
	target.linear_velocity = Vector3.ZERO
	assert_gt(lance.strike(target, Vector3(0, 0, -25), Vector3(1, 0, 0.2).normalized(), 0.5), 0.0, "Driving at the hull's middle: in, whichever face of its box it meets")
	lance._glanced.clear()
	lance.reload_left = 0.0
	rammer.linear_velocity = Vector3(-250, 0, -60)
	target.linear_velocity = Vector3.ZERO
	assert_eq(lance.strike(target, Vector3(0, 0, -25), Vector3(0, 0, 1), 0.99), 0.0, "Moving mostly sideways: a sideswipe glances")


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
	assert_eq(CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_FROM + 1.0), 1.0, "Usual aim from afar")
	assert_almost_eq(CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_FULL), Constants.NAV_RAM_PID_GAIN, 0.001)
	var middle: float = CommandRam.aim_gain((Constants.NAV_RAM_PID_GAIN_FROM + Constants.NAV_RAM_PID_GAIN_FULL) * 0.5)
	assert_almost_eq(middle, (1.0 + Constants.NAV_RAM_PID_GAIN) * 0.5, 0.001, "Eases between")


func test_run_up_distance():
	assert_eq(CommandRam.run_up_distance(150.0, Constants.LAW_LANCE_MIN_SPEED + 1.0, 0.0), 0.0, "Fast enough already")
	assert_eq(CommandRam.run_up_distance(Constants.LAW_LANCE_MIN_SPEED - 1.0, 0.0, 0.0), INF, "Never fast enough")
	var from_rest: float = CommandRam.run_up_distance(150.0, 0.0, 0.0)
	var t: float = -log((150.0 - Constants.LAW_LANCE_MIN_SPEED) / 150.0) / Constants.LINEAR_DRAG
	assert_almost_eq(from_rest, 150.0 * t - 150.0 * (1.0 - exp(-Constants.LINEAR_DRAG * t)) / Constants.LINEAR_DRAG, 1.0, "Thrust against drag from rest")
	assert_gt(CommandRam.run_up_distance(150.0, 0.0, 10.0), from_rest, "A target pulling away needs more")


func test_salvage_recovers_lances_that_fit_the_seat():
	rammer.linear_velocity = Vector3(0, 0, -200)
	lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1))
	assert_eq(lance.nails, 2)
	target.is_wreck = true
	var other = _make_body(Vector3(50, 0, 0))
	var heavy = LanceScript.new()
	other.add_child(heavy)
	heavy.setup(other, "heavy", ShipLaws.lance_stats({"nail_mass": 600.0, "count": 3.0}), 1)
	assert_eq(target.recoverable_lances_for(other), 0, "A lance of another size does not fit that seat")
	assert_eq(target.recoverable_lances_for(rammer), 1)
	assert_true(target.recover_lance_into(rammer))
	assert_eq(lance.nails, 3, "Back in the quiver")
	assert_eq(target.recoverable_lances_for(rammer), 0)
	assert_false(target.recover_lance_into(rammer), "Nothing left to recover (and the quiver is full)")


func test_the_tip_strikes_by_proximity_to_the_hull_box_and_the_lance_points_inward():
	rammer.linear_velocity = Vector3(0, 0, -200)
	lance.armed = true
	target.global_transform.origin = Vector3(3, 0, -40)  # Box (+-5 m) reaches z -35: out of reach
	lance._sweep(1.0 / 60.0)
	assert_eq(target.hull, 200.0, "Out of reach")
	target.global_transform.origin = Vector3(3, 0, -lance.get_reach() - 5.0 - Constants.LANCE_TIP_MARGIN + 0.2)
	lance._sweep(1.0 / 60.0)
	assert_lt(target.hull, 200.0, "The tip came within the margin of its hull box: a strike")
	var stuck: Spatial = null
	for child in target.get_children():
		if child.is_in_group(LanceScript.LANCE_GROUP):
			stuck = child
	var tip_direction: Vector3 = stuck.global_transform.basis.y.normalized()
	assert_gt(tip_direction.dot(Vector3(1, 0, 0)), 0.0, "Turned toward the target's centre (off to the side)")


func test_a_thin_ship_crossing_fast_cannot_slip_past_the_tip_within_a_step():
	rammer.linear_velocity = Vector3(0, 0, -150)
	target.linear_velocity = Vector3(300, 0, 0)  # Across the lance: 5 m a step
	target.hull_bounds = AABB(Vector3(-1, -5, -5), Vector3(2, 10, 10))  # 2 m thick
	lance.armed = true
	target.global_transform.origin = Vector3(2.5 + Constants.LANCE_TIP_MARGIN, 0, -lance.get_reach())  # Just past the lance's line now
	watch_signals(lance)
	lance._sweep(1.0 / 60.0)
	assert_true(get_signal_emit_count(lance, "glanced") + get_signal_emit_count(lance, "struck") > 0, "The tip's path this step crossed it: met (mostly sideways, so likely a glance)")


func test_a_run_up_never_runs_away_for_good():
	assert_lt(min(CommandRam.run_up_distance(150.0, 0.0, 0.0) + Constants.NAV_RAM_TURN_ROOM, Constants.NAV_RAM_MAX_RUN_UP), INF)
	assert_eq(CommandRam.run_up_distance(150.0, 0.0, 100.0), INF, "Against a target pulling away it could never build strike speed: the run-up must not use this")
