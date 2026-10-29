# Tests for the ammunition weapons: missile racks (guided rounds, the salvo held back once enough is
# on its way), cannons (fixed forward: they fire only when the nose leads the target), magazines
# (mass, restock, salvage from a wreck) and the aim command.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const MissileScript = preload("res://src/core/agents/components/missile.gd")

var shooter: RigidBody = null
var target: RigidBody = null
var controller: Node = null


func before_each():
	shooter = _make_body(Vector3.ZERO)
	target = _make_body(Vector3(0, 0, -800))


# Rounds still in flight belong to the test that fired them: none may reach the next one's ships.
func after_each():
	for child in get_children():
		if child.has_method("_steer") or child.is_in_group("decoy"):
			child.free()


func _make_body(position: Vector3) -> RigidBody:
	var body = AgentScript.new()
	add_child_autofree(body)
	body.global_transform.origin = position
	body.hull_max = 300.0
	body.hull = 300.0
	body.power_max = 100.0
	body.power = 100.0
	body.fit_stats = {"sensor_strength": 10.0}
	return body


func _arm(body: RigidBody, kind: String, genes: Dictionary) -> Node:
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	tools.set_tools([ShipLaws.build_weapon_template(kind, genes, 2, "test_" + kind)])
	return tools


# Steps every projectile under the test node.
func _fly(seconds: float, step: float = 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds:
		for child in get_children():
			if child.has_method("_steer") and not child.done:
				child._physics_process(step)
		for body in [shooter, target]:
			if is_instance_valid(body):
				body.global_transform.origin += body.linear_velocity * step
		t += step


func test_laws():
	var rack: Dictionary = ShipLaws.missile_stats(Constants.PART_TYPE_SEEDS.missile[2])
	assert_eq(rack.ammo, 4)
	assert_almost_eq(rack.damage, Constants.LAW_MISSILE_DAMAGE[1], 0.01, "The reference missile")
	assert_almost_eq(rack.mass, 500.0, 0.01, "Four missiles and a frame of one")
	assert_gt(rack.optimal_range, 2000.0, "Launches from well beyond a laser's reach")
	var gun: Dictionary = ShipLaws.cannon_stats(Constants.PART_TYPE_SEEDS.cannon[2])
	assert_almost_eq(gun.projectile_speed, Constants.LAW_CANNON_SPEED[1], 0.01)
	assert_almost_eq(gun.damage, Constants.LAW_CANNON_DAMAGE[1], 0.01)
	assert_lt(gun.power_per_cycle, ShipLaws.laser_stats(Constants.PART_TYPE_SEEDS.laser[2]).power_per_cycle, "Lighter on power than a laser")
	assert_almost_eq(gun.mass, 600.0, 0.01, "Gun and a full magazine")


func test_a_missile_flies_to_its_target_and_bursts():
	controller = _arm(shooter, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	target.linear_velocity = Vector3(40, 0, 0)
	assert_true(controller.activate(0, target).success)
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 3, "One launched")
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 3, "No second launch before its cycle")
	_fly(15.0)
	assert_almost_eq(target.hull, 300.0 - Constants.LAW_MISSILE_DAMAGE[1], 0.5, "It caught the crossing target")


func test_no_more_missiles_once_enough_are_on_their_way():
	controller = _arm(shooter, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	target.hull = 50.0
	controller.activate(0, target)
	controller._physics_process(0.016)
	controller._cycle_timers[0] = 0.0
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 3, "One is enough for what is left of it")


func test_a_tight_turn_makes_a_heavy_missile_overshoot():
	var missile = MissileScript.new()
	missile.setup({"projectile_speed": 300.0, "projectile_accel": 300.0, "turn_rate": 0.3, "round_mass": 100.0})
	target.global_transform.origin = Vector3(0, 0, -150)
	target.linear_velocity = Vector3(150, 0, 0)  # Crossing fast, near: it cannot turn in time
	missile.launch(shooter, target, Vector3(0, 0, -10), Vector3(0, 0, -300), 80.0, 1.0)
	_fly(1.2)
	assert_eq(target.hull, 300.0, "Missed, and burnt out")


func test_a_cannon_fires_only_when_the_nose_leads_the_target():
	controller = _arm(shooter, "cannon", Constants.PART_TYPE_SEEDS.cannon[2])
	target.global_transform.origin = Vector3(0, 0, -900)
	target.linear_velocity = Vector3(100, 0, 0)
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 60, "Nose on the target, but it will have moved on: holds fire")
	var aim: Vector3 = controller.cannon_aim_direction(0, target)
	shooter.global_transform = Transform(Transform().looking_at(aim, Vector3.UP).basis, Vector3.ZERO)
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 59, "Leading it: fires")
	_fly(2.0)
	assert_almost_eq(target.hull, 300.0 - Constants.LAW_CANNON_DAMAGE[1], 0.5, "and the round meets it")


func test_magazines_lighten_the_ship_refill_and_salvage():
	controller = _arm(shooter, "cannon", Constants.PART_TYPE_SEEDS.cannon[2])
	controller._set_ammo(0, 50)
	assert_almost_eq(controller.spent_ammo_mass(), 50.0, 0.01, "Ten 5 kg rounds fired")
	var wreck = _make_body(Vector3(0, 0, -50))
	var wreck_tools = _arm(wreck, "cannon", {"mass": 300.0, "round_mass": 5.2, "count": 60.0})
	assert_eq(wreck_tools.recoverable_ammo_for(controller), 10, "Its rounds fit (within the tolerance)")
	var moved: Dictionary = wreck_tools.recover_ammo_into(controller)
	assert_eq(moved.rounds, 6, "A strip takes a tenth of a magazine")
	assert_eq(controller.get_ammo(0), 56)
	var other = _make_body(Vector3(0, 0, -50))
	var missiles = _arm(other, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	assert_eq(missiles.recoverable_ammo_for(controller), 0, "Missiles do not fit a cannon")
	assert_eq_deep(controller.restock_ammo(), {0: 4})
	assert_eq(controller.get_ammo(0), 60)


func test_aim_command_points_the_nose_at_the_lead():
	controller = _arm(shooter, "cannon", Constants.PART_TYPE_SEEDS.cannon[2])
	assert_true(controller.find_cannon_for(target) >= 0)
	controller._ammo[0] = 0
	assert_eq(controller.find_cannon_for(target), -1, "Empty: no cannon to aim")


func test_lasers_shoot_down_missiles_coming_at_their_ship():
	controller = _arm(shooter, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	var laser: UtilityToolTemplate = ShipLaws.build_laser_template(Constants.PART_TYPE_SEEDS.laser[3], 3, "test_pd")  # A heavy laser
	var defence = ToolControllerScript.new()
	defence.name = "ToolController"
	target.add_child(defence)
	defence.set_tools([laser])
	target.global_transform.origin = Vector3(0, 0, -3000)
	controller.activate(0, target)
	controller._physics_process(0.016)
	var missile = controller._in_flight[0]
	watch_signals(defence)
	var t := 0.0
	while t < 15.0 and is_instance_valid(missile) and not missile.done:
		defence._physics_process(1.0 / 60.0)
		_fly(1.0 / 60.0)
		t += 1.0 / 60.0
	assert_signal_emitted(defence, "missile_intercepted", "Its laser (switched off) fired at the missile")
	assert_eq(target.hull, 300.0, "and shot it down before it got there")


func test_missiles_and_cannons_hold_fire_behind_a_rock():
	var rock = load(Constants.FIELD_ROCK_SCENE).instance()
	rock.transform = Transform(Basis().scaled(Vector3.ONE * 40.0), Vector3(0, 0, -400))
	add_child_autofree(rock)
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	controller = _arm(shooter, "cannon", Constants.PART_TYPE_SEEDS.cannon[2])
	assert_true(controller.rock_in_the_way(target), "The rock is between them")
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_eq(controller.get_ammo(0), 60, "The gun holds fire")
	var rack = _arm(target, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	rack.activate(0, shooter)
	rack._physics_process(0.016)
	assert_eq(rack.get_ammo(0), 4, "and so does the rack")
	rock.global_transform.origin = Vector3(500, 0, -400)
	yield(get_tree(), "physics_frame")
	assert_false(controller.rock_in_the_way(target), "Moved aside: a clear line")


func test_a_decoy_takes_a_missile_off():
	seed(2)
	target.decoys = 2
	controller = _arm(shooter, "missile", Constants.PART_TYPE_SEEDS.missile[2])
	target.global_transform.origin = Vector3(0, 0, -1500)
	controller.activate(0, target)
	controller._physics_process(0.016)
	var missile = controller._in_flight[0]
	var t := 0.0
	while t < 15.0 and is_instance_valid(missile) and not missile.done:
		target._launch_decoys()
		for child in get_children():
			if child.is_in_group("decoy"):
				child._physics_process(1.0 / 60.0)
		_fly(1.0 / 60.0)
		t += 1.0 / 60.0
	assert_eq(target.decoys, 1, "One flare for the one missile")
	assert_eq(target.hull, 300.0, "which took it, and burst on it")


func test_afterburner_on_the_signature_and_a_damper_off_it():
	var body = _make_body(Vector3(0, 0, 500))
	body.fit_stats = {"sensor_strength": 1.0, "signature": 1000.0, "linear_thrust": 300000.0}
	assert_false(body.set_afterburner(true), "None fitted: nothing to light")
	body.fit_stats["afterburner_thrust"] = 500000.0
	assert_true(body.set_afterburner(true), "Lit")
	var quiet: float = body.get_signature()
	body.fit_stats["jamming"] = 0.3
	assert_almost_eq(body.get_signature(), quiet, 0.01, "A sensor damper jams locks, not sight: still seen")
	body.power = 0.0
	body.set_afterburner(false)
	assert_false(body.set_afterburner(true), "No power: it will not light")
