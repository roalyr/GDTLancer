# Tests for the kinetic lance: its law (ShipLaws.lance_stats, lance_damage), LanceController
# (the throw and its aim, strikes, glances, the shove, lances left in the hull, reload, restock) and
# the ram command's run-up distance.

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


func test_a_strike_damages_shoves_and_leaves_the_lance_in():
	rammer.linear_velocity = Vector3(0, 0, -200)  # Nose on (-Z) at 200 m/s
	var damage: float = lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1))
	assert_almost_eq(damage, lance.lance.damage, 0.01)
	assert_almost_eq(target.hull, 200.0 - damage, 0.01)
	assert_almost_eq(rammer.linear_velocity.z, -200.0, 0.01, "The ship flies on: only the lance met it")
	assert_almost_eq(target.linear_velocity.z, -200.0 * lance.lance.nail_mass / target.mass, 0.01, "Shoved by the lance's momentum")
	var stuck := 0
	for child in target.get_children():
		if child.is_in_group(LanceScript.LANCE_GROUP):
			stuck += 1
	assert_eq(stuck, 1, "The lance stays in the hull")
	target.repair_hull()
	yield(get_tree(), "idle_frame")
	for child in target.get_children():
		assert_false(child.is_in_group(LanceScript.LANCE_GROUP), "Repairs take it out")


func test_in_release_range_it_throws_straight_at_the_target_cancelling_its_drift():
	rammer.linear_velocity = Vector3(40, 0, -150)  # Slipping sideways past it
	target.global_transform.origin = Vector3(0, 0, -(lance.get_reach() + 5.0 + Constants.LANCE_RELEASE_RANGE + 20.0))
	assert_true(lance.firing_solution(target).empty(), "Out of release range")
	target.global_transform.origin = Vector3(0, 0, -(lance.get_reach() + Constants.LANCE_RELEASE_RANGE * 0.5))
	var solution: Dictionary = lance.firing_solution(target)
	assert_false(solution.empty())
	var line: Vector3 = (target.global_transform.origin - lance.get_tip()).normalized()
	var relative: Vector3 = solution.velocity - target.linear_velocity
	assert_almost_eq(relative.normalized().dot(line), 1.0, 0.0001, "Relative to the target, the lance flies straight at its middle")
	assert_almost_eq(solution.closing, relative.length(), 0.01)
	assert_gt(solution.closing, 150.0, "The throw adds to the ship's own closing speed")
	rammer.linear_velocity = Vector3(300, 0, -100)
	assert_true(lance.firing_solution(target).empty(), "Slipping by faster than a throw can make up")
	rammer.linear_velocity = Vector3.ZERO
	assert_false(lance.firing_solution(target).empty(), "From a standstill the throw alone is past strike speed")


func test_a_thrown_lance_flies_kicks_the_ship_back_and_strikes():
	rammer.linear_velocity = Vector3(0, 0, -100)
	target.global_transform.origin = Vector3(0, 0, -(lance.get_reach() + 40.0))
	var solution: Dictionary = lance.firing_solution(target)
	watch_signals(lance)
	lance.fire(target, solution)
	assert_eq(lance.nails, int(lance.lance.count) - 1, "One lance thrown")
	assert_false(lance.is_seated(), "The next is sliding in")
	assert_almost_eq(rammer.linear_velocity.z, -100.0 + Constants.LANCE_LAUNCH_SPEED * lance.lance.nail_mass / rammer.mass, 0.01, "Kicked back by the throw")
	assert_signal_emitted(lance, "launched")
	for i in range(30):
		yield(get_tree(), "physics_frame")
	assert_lt(target.hull, 200.0, "It flew to the target and struck")
	lance._physics_process(lance.lance.reload + 0.1)
	assert_true(lance.is_seated(), "Reloaded")


func test_too_slow_or_oblique_glances_off():
	rammer.linear_velocity = Vector3(0, 0, -(Constants.LAW_LANCE_MIN_SPEED - 10.0))
	assert_eq(lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1), 0.0), 0.0)
	assert_eq(target.hull, 200.0)
	rammer.linear_velocity = Vector3(0, 0, -250)
	assert_eq(lance.strike(target, Vector3(8, 0, -30), Vector3(1, 0, 0.2).normalized(), 0.99), 0.0, "Nearly side-on, off the hull's middle: glances off")
	lance._glanced.clear()
	assert_gt(lance.strike(target, Vector3(8, 0, -30), Vector3(1, 0, 0.2).normalized(), 0.0), 0.0, "unless it slips between parts")
	lance._glanced.clear()
	lance.reload_left = 0.0
	rammer.linear_velocity = Vector3(0, 0, -250)
	target.linear_velocity = Vector3.ZERO
	assert_gt(lance.strike(target, Vector3(0, 0, -25), Vector3(1, 0, 0.2).normalized(), 0.5), 0.0, "Driving at the hull's middle: in, whichever face of its box it meets")
	lance._glanced.clear()
	lance.reload_left = 0.0
	rammer.linear_velocity = Vector3(-250, 0, -60)
	target.linear_velocity = Vector3.ZERO
	assert_eq(lance.strike(target, Vector3(0, 0, -25), Vector3(0, 0, 1), 0.99), 0.0, "Moving mostly sideways: a sideswipe glances")


func test_last_lance_then_restock():
	for i in range(3):
		lance.reload_left = 0.0
		lance.fire(target, {"direction": Vector3.FORWARD, "velocity": Vector3(0, 0, -300)})
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
	var throw: float = lance.lance.damage * (Constants.LAW_LANCE_REF_SPEED + Constants.LANCE_LAUNCH_SPEED) / Constants.LAW_LANCE_REF_SPEED
	assert_almost_eq(rammer.get_damage_per_second(), throw / max(lance.lance.reload, Constants.AI_RAM_PASS_TIME), 0.01, "One throw per pass, at top speed plus the launch")
	lance.nails = 0
	assert_eq(rammer.get_damage_per_second(), 0.0, "No lasers, no lances left")


func test_aim_stiffens_as_the_charge_closes():
	assert_eq(CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_FROM + 1.0), 1.0, "Usual aim from afar")
	assert_almost_eq(CommandRam.aim_gain(Constants.NAV_RAM_PID_GAIN_FULL), Constants.NAV_RAM_PID_GAIN, 0.001)
	var middle: float = CommandRam.aim_gain((Constants.NAV_RAM_PID_GAIN_FROM + Constants.NAV_RAM_PID_GAIN_FULL) * 0.5)
	assert_almost_eq(middle, (1.0 + Constants.NAV_RAM_PID_GAIN) * 0.5, 0.001, "Eases between")


func test_run_up_distance():
	assert_eq(CommandRam.run_up_distance(150.0, 0.0, 0.0), 0.0, "The throw alone is past strike speed: no run-up while closing")
	assert_eq(CommandRam.run_up_distance(150.0, 10.0, 90.0), 0.0, "Gaining on a runner: none either")
	assert_eq(CommandRam.run_up_distance(150.0, -250.0, 200.0), INF, "Never fast enough for a runner faster than its top speed")


func test_salvage_recovers_lances_that_fit_the_seat():
	rammer.linear_velocity = Vector3(0, 0, -200)
	lance.nails -= 1  # Thrown (fire)
	lance.strike(target, Vector3(0, 0, -20), Vector3(0, 0, 1))
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


func test_a_run_up_never_runs_away_for_good():
	assert_lt(min(CommandRam.run_up_distance(150.0, 0.0, 0.0) + Constants.NAV_RAM_TURN_ROOM, Constants.NAV_RAM_MAX_RUN_UP), INF)
	assert_eq(CommandRam.run_up_distance(150.0, -250.0, 200.0), INF, "Against a target pulling away faster than it can fly the run-up must not use this")


func test_a_charge_is_seen_coming_and_makes_the_charger_an_enemy():
	target.global_transform.origin = Vector3(0, 0, -400)
	rammer.linear_velocity = Vector3(0, 0, -150)
	assert_false(lance.is_charging(target), "Disarmed: no charge")
	lance.armed = true
	assert_true(lance.is_charging(target), "Armed, nose on, closing fast on a line that meets it")
	rammer.linear_velocity = Vector3(0, 0, 30)
	assert_false(lance.is_charging(target), "Not closing")
	rammer.linear_velocity = Vector3(60, 0, -150)
	assert_false(lance.is_charging(target), "Its drift would carry it well wide")
	rammer.linear_velocity = Vector3(0, 0, -150)
	target.global_transform.origin = Vector3(0, 0, -1500)
	assert_false(lance.is_charging(target), "Still too far to tell")
	target.global_transform.origin = Vector3(0, 0, -400)
	target.faction = "verdant"
	rammer.faction = "verdant_other"
	assert_false(target.is_enemy_of(rammer))
	watch_signals(EventBus)
	lance._announce_charges()
	assert_signal_emitted_with_parameters(EventBus, "agent_charged", [target, rammer])
	assert_true(target.is_enemy_of(rammer), "Charged at: the charger is an enemy now")
	lance._announce_charges()
	assert_signal_emit_count(EventBus, "agent_charged", 1, "Once a pass")


func test_an_off_axis_launcher_twists_the_ship_and_a_pair_cancels():
	var left = LanceScript.new()
	var right = LanceScript.new()
	for launcher in [left, right]:
		rammer.add_child(launcher)
	left.setup(rammer, "left", lance.lance, -1, 0, 2)
	right.setup(rammer, "right", lance.lance, -1, 1, 2)
	assert_lt(left.mount_offset, 0.0)
	assert_gt(right.mount_offset, 0.0)
	var throw := {"direction": Vector3.FORWARD, "velocity": Vector3(0, 0, -300)}
	left.fire(target, throw)
	var twist: float = rammer.angular_velocity.y
	assert_ne(twist, 0.0, "Thrown off the axis: the kick twists the ship")
	right.fire(target, throw)
	assert_almost_eq(rammer.angular_velocity.y, 0.0, 0.0001, "A volley from both sides cancels")
	assert_almost_eq(rammer.linear_velocity.z, 2.0 * Constants.LANCE_LAUNCH_SPEED * lance.lance.nail_mass / rammer.mass, 0.01, "but the kicks add up")
