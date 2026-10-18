# Tests for ToolController: hit quality, cycling, the power gate, wrecks, harpoon towing and salvage.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")

var shooter: RigidBody = null
var target: RigidBody = null
var controller: Node = null
var laser: UtilityToolTemplate = null


func before_each():
	laser = UtilityToolTemplate.new()
	laser.tool_type = "laser"
	laser.damage = 10.0
	laser.optimal_range = 500.0
	laser.falloff = 300.0
	laser.tracking = 0.2
	laser.cycle_time = 1.0
	laser.power_per_cycle = 12.0

	shooter = _make_body(Vector3.ZERO)
	target = _make_body(Vector3(0, 0, -400))
	controller = ToolControllerScript.new()
	shooter.add_child(controller)
	controller.set_tools([laser])


func _make_body(position: Vector3) -> RigidBody:
	var body = AgentScript.new()
	add_child_autofree(body)
	body.global_transform.origin = position
	body.hull_max = 50.0
	body.hull = 50.0
	body.power_max = 100.0
	body.power = 100.0
	body.power_regen = 10.0
	return body


func test_hit_quality_formula():
	assert_almost_eq(laser.get_hit_quality(400.0, 0.0), 1.0, 0.001, "Inside optimal and no transversal: full quality.")
	assert_almost_eq(laser.get_hit_quality(800.0, 0.0), 0.5, 0.001, "One falloff past optimal halves quality.")
	assert_almost_eq(laser.get_hit_quality(400.0, 0.2), 0.5, 0.001, "Angular velocity equal to tracking halves quality.")
	assert_almost_eq(laser.get_hit_quality(800.0, 0.2), 0.25, 0.001, "Range and tracking penalties combine.")
	assert_eq(laser.get_max_range(), 1100.0)


func test_angular_velocity_counts_only_transversal_motion():
	var head_on = ToolControllerScript.compute_angular_velocity(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -500), Vector3(0, 0, 100))
	assert_almost_eq(head_on, 0.0, 0.0001, "Radial motion does not spoil the aim.")
	var crossing = ToolControllerScript.compute_angular_velocity(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -500), Vector3(100, 0, 0))
	assert_almost_eq(crossing, 0.2, 0.0001, "100 m/s across at 500 m is 0.2 rad/s.")
	var matched = ToolControllerScript.compute_angular_velocity(Vector3.ZERO, Vector3(100, 0, 0), Vector3(0, 0, -500), Vector3(100, 0, 0))
	assert_almost_eq(matched, 0.0, 0.0001, "Matched velocities leave nothing to track.")


func test_first_cycle_damages_and_spends_power():
	assert_true(controller.activate(0, target).success)
	controller._physics_process(0.016)
	assert_almost_eq(target.hull, 40.0, 0.001, "Full-quality cycle deals full damage.")
	assert_almost_eq(shooter.power, 88.0, 0.001, "A cycle costs power_per_cycle.")
	controller._physics_process(0.5)
	assert_almost_eq(target.hull, 40.0, 0.001, "No second cycle before cycle_time has passed.")


func test_damage_scales_with_hit_quality():
	target.linear_velocity = Vector3(80, 0, 0)  # 0.2 rad/s at 400 m
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_almost_eq(target.hull, 45.0, 0.01, "Half quality deals half damage.")


func test_out_of_power_stops_tool_without_effect():
	shooter.power = 5.0
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_false(controller.is_active(0), "Tool switches off when a cycle cannot be paid for.")
	assert_eq(target.hull, 50.0)
	assert_eq(shooter.power, 5.0)


func test_out_of_range_stays_on_but_idles():
	shooter.fit_stats = {"sensor_strength": 10.0}  # Still seen; this test is about reach
	target.global_transform.origin = Vector3(0, 0, -2000)
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_true(controller.is_active(0), "Tool stays on beyond max range.")
	assert_eq(target.hull, 50.0)
	assert_eq(shooter.power, 100.0, "No power is spent while out of range.")


func test_zero_hull_makes_wreck_and_stops_tool():
	watch_signals(EventBus)
	target.hull = 5.0
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_true(target.is_wreck, "Hull at zero turns the ship into a wreck.")
	assert_true(target.is_in_group("wreck"))
	assert_signal_emitted(EventBus, "agent_disabled")
	controller._physics_process(1.0)
	assert_false(controller.is_active(0), "Tool releases a wrecked target.")
	assert_false(controller.activate(0, target).success, "Wrecks cannot be targeted by the laser.")


func test_unimplemented_tool_types_cannot_be_switched_on():
	var drill = UtilityToolTemplate.new()
	drill.tool_type = "drill"
	controller.set_tools([drill])
	assert_eq(controller.activate(0, target).reason, "not_implemented")


func test_wreck_drifts_and_cannot_spend_power():
	target.become_wreck()
	assert_false(target.try_spend_power(1.0))
	target._physics_process(1.0)
	assert_eq(target.power, 0.0, "Wrecks do not regenerate power.")
	shooter.power = 50.0
	shooter._physics_process(1.0)
	assert_almost_eq(shooter.power, 50.0 + shooter.power_regen, 0.001, "Live ships regenerate power.")


func test_hit_effect_intensity_follows_absolute_damage():
	var Effect = load("res://src/core/agents/effects/laser_hit_effect.gd")
	var reference: float = Constants.HIT_FX_REFERENCE_DAMAGE
	assert_eq(Effect.intensity_for_damage(0.0), 0.0, "No damage, no visible hit.")
	assert_almost_eq(Effect.intensity_for_damage(reference), 1.0, 0.001)
	assert_almost_eq(Effect.intensity_for_damage(reference * 0.25), 0.5, 0.001, "A weak beam shows weakly")
	assert_almost_eq(Effect.intensity_for_damage(reference * 4.0), 2.0, 0.001, "A powerful beam shows more, whatever tool fires it")
	assert_eq(Effect.intensity_for_damage(1e6), Constants.HIT_FX_MAX_INTENSITY)


func test_zero_damage_cycle_spawns_no_hit_effect():
	laser.damage = 0.0
	controller.activate(0, target)
	controller._physics_process(0.016)
	var effects := 0
	for child in target.get_children():
		if child.get_script() == load("res://src/core/agents/effects/laser_hit_effect.gd"):
			effects += 1
	assert_eq(effects, 0, "Zero-damage hits are invisible.")


# --- Harpoon, tether and salvage ---

func _make_harpoon() -> UtilityToolTemplate:
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	harpoon.optimal_range = 300.0
	harpoon.falloff = 100.0
	harpoon.power_per_cycle = 20.0
	harpoon.reel_speed = 15.0
	harpoon.strip_interval = 1.0
	return harpoon


func _make_stripped_ready_wreck(units: int) -> void:
	target.become_wreck()
	target.salvage = {"commodity_scrap": units}
	shooter.cargo_capacity = 10


func test_tools_are_picked_by_target_kind():
	controller.set_tools([laser, _make_harpoon()])
	assert_eq(controller.find_tool_for(target), 0, "Laser for a live ship.")
	target.become_wreck()
	assert_eq(controller.find_tool_for(target), 1, "Harpoon for a wreck.")
	assert_false(controller.activate(1, shooter).success, "Harpoon never targets its own ship.")


func test_harpoon_launch_attaches_tether_that_reels_to_clearance():
	_make_stripped_ready_wreck(3)
	controller.set_tools([laser, _make_harpoon()])
	assert_true(controller.activate(1, target).success)
	controller._physics_process(0.016)
	var tether = controller.get_tether(1)
	assert_not_null(tether, "Harpoon hit attaches a tether.")
	assert_almost_eq(shooter.power, 80.0, 0.001, "Launch costs power_per_cycle.")
	assert_almost_eq(tether.length, 400.0, 0.01, "Cable starts at the hit distance.")
	var expected_min: float = (shooter.get_apparent_radius() + target.get_apparent_radius()) * Constants.TETHER_CLEARANCE
	assert_almost_eq(tether.min_length, expected_min, 0.001, "Reels in to the sum of both apparent radii plus clearance.")
	tether._physics_process(100.0)
	assert_almost_eq(tether.length, expected_min, 0.001, "Never reels closer than the clearance.")


func test_harpoon_out_of_reach_stays_armed():
	_make_stripped_ready_wreck(3)
	shooter.fit_stats = {"sensor_strength": 10.0}  # Still seen; this test is about reach
	target.global_transform.origin = Vector3(0, 0, -2000)
	controller.set_tools([_make_harpoon()])
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_true(controller.is_active(0))
	assert_null(controller.get_tether(0))
	assert_eq(shooter.power, 100.0)


func test_reeled_in_wreck_is_stripped_into_cargo_then_released():
	_make_stripped_ready_wreck(3)
	controller.set_tools([_make_harpoon()])
	controller.activate(0, target)
	controller._physics_process(0.016)
	var tether = controller.get_tether(0)
	tether._physics_process(100.0)
	target.global_transform.origin = Vector3(0, 0, -tether.min_length)
	watch_signals(controller)
	for _i in range(5):
		controller._physics_process(1.0)
	assert_eq(shooter.cargo.get("commodity_scrap", 0), 3, "One unit per strip interval until the wreck is empty.")
	assert_eq(target.get_salvage_units(), 0)
	assert_false(controller.is_active(0), "Harpoon releases once the wreck is stripped.")
	assert_signal_emitted_with_parameters(controller, "tool_deactivated", [0, "stripped"])


func test_full_hold_keeps_towing_without_stripping():
	_make_stripped_ready_wreck(3)
	shooter.cargo_capacity = 0
	controller.set_tools([_make_harpoon()])
	controller.activate(0, target)
	controller._physics_process(0.016)
	var tether = controller.get_tether(0)
	tether._physics_process(100.0)
	target.global_transform.origin = Vector3(0, 0, -tether.min_length)
	controller._physics_process(1.0)
	controller._physics_process(1.0)
	assert_eq(target.get_salvage_units(), 3)
	assert_true(controller.is_active(0), "Still towing.")


func test_tether_pulls_both_bodies_only_when_stretched():
	var Tether = load("res://src/core/agents/components/tether.gd")
	var recorder_script = GDScript.new()
	recorder_script.source_code = "extends Node\nvar total = Vector3.ZERO\nfunc add_external_force(force):\n\ttotal += force\n"
	recorder_script.reload()
	for body in [shooter, target]:
		var recorder = Node.new()
		recorder.set_script(recorder_script)
		add_child_autofree(recorder)
		body.movement_system = recorder
	shooter.mass = 6000.0
	target.mass = 6000.0
	var tether = Tether.new()
	tether.setup(shooter, target, 500.0, 50.0, 0.0)
	add_child_autofree(tether)
	tether._physics_process(0.016)
	assert_eq(shooter.movement_system.total, Vector3.ZERO, "Slack cable (400 m apart, 500 m long) pulls nothing.")
	tether.length = 300.0
	tether._physics_process(0.016)
	var pull: Vector3 = shooter.movement_system.total
	assert_gt(pull.dot(Vector3(0, 0, -1)), 0.0, "Holder is pulled toward the towed body.")
	assert_eq(target.movement_system.total, -pull, "Equal and opposite.")


func test_wreck_salvage_includes_its_cargo_and_cargo_adds_mass():
	var scrap = CommodityTemplate.new()
	scrap.template_id = "test_scrap"
	scrap.unit_mass = 100.0
	var saved: Dictionary = TemplateDatabase.assets_commodities
	TemplateDatabase.assets_commodities = {"test_scrap": scrap}
	shooter.cargo_capacity = 5
	shooter._update_mass()
	var base_mass: float = shooter.mass
	assert_eq(shooter.add_cargo("test_scrap", 8), 5, "Hold capacity caps what fits.")
	assert_almost_eq(shooter.mass, base_mass + 500.0, 0.01, "Cargo mass adds to the ship.")
	shooter.become_wreck()
	assert_eq(shooter.salvage.get("test_scrap", 0), 5, "A wreck's hold becomes salvage.")
	assert_eq(shooter.get_cargo_units(), 0)
	TemplateDatabase.assets_commodities = saved



# --- Hit spread and damage effects ---

func test_aim_points_spread_inside_the_hull_bounds():
	var inner := AABB(
		target.hull_bounds.position + target.hull_bounds.size * (0.5 - Constants.HIT_AIM_SPREAD * 0.5),
		target.hull_bounds.size * Constants.HIT_AIM_SPREAD
	).grow(0.001)
	var distinct := {}
	for _i in range(50):
		var aim: Vector3 = target.to_local(target.get_random_aim_point())
		assert_true(inner.has_point(aim), "Aim stays in the central part of the hull.")
		distinct[aim.round()] = true
	assert_gt(distinct.size(), 10, "Hits spread instead of landing on one spot.")


func test_fuel_leaks_open_with_damage_and_are_capped():
	var from: Vector3 = shooter.global_transform.origin
	target.register_hit(from, Constants.FUEL_LEAK_EVERY_DAMAGE * 0.5)
	assert_eq(target.get_leak_count(), 0, "Not enough damage for a leak yet.")
	target.register_hit(from, Constants.FUEL_LEAK_EVERY_DAMAGE * 0.5)
	assert_eq(target.get_leak_count(), 1)
	for _i in range(20):
		target.register_hit(from, Constants.FUEL_LEAK_EVERY_DAMAGE)
	yield(get_tree(), "idle_frame")
	assert_eq(target.get_leak_count(), Constants.FUEL_LEAK_MAX_PER_SHIP, "The oldest leaks give way.")


func test_wreck_explodes_into_cloud_carrying_ship_momentum():
	target.linear_velocity = Vector3(12, 0, -3)
	target.become_wreck()
	var explosion = null
	for child in target.get_parent().get_children():
		if child.filename == target.WreckExplosionScene.resource_path:
			explosion = child
	assert_not_null(explosion, "Destruction spawns an explosion in the zone, not on the wreck.")
	assert_eq(explosion.velocity, Vector3(12, 0, -3))
	assert_eq(explosion.radius, target.get_apparent_radius())
	explosion.queue_free()


func test_leaks_push_back_against_their_jet_and_weaken_with_pressure():
	var recorder_script = GDScript.new()
	recorder_script.source_code = "extends Node\nvar calls = []\nfunc add_external_force_at(force, point):\n\tcalls.append([force, point])\n"
	recorder_script.reload()
	var recorder = Node.new()
	recorder.set_script(recorder_script)
	add_child_autofree(recorder)
	target.movement_system = recorder
	target.register_hit(shooter.global_transform.origin, Constants.FUEL_LEAK_EVERY_DAMAGE)
	yield(get_tree(), "idle_frame")
	assert_eq(target.get_leak_count(), 1)
	var leak = target._leaks[0]
	target._physics_process(0.016)
	var force: Vector3 = recorder.calls[0][0]
	assert_almost_eq(force.length(), Constants.FUEL_LEAK_THRUST, Constants.FUEL_LEAK_THRUST * 0.01, "Full thrust while fresh (the leak ages a frame or two under load).")
	assert_almost_eq(force.normalized().dot(leak.outward), -1.0, 0.001, "Pushes opposite the gas jet.")
	assert_eq(recorder.calls[0][1], leak.global_transform.origin, "Acts at the leak, so off-centre leaks turn the ship.")
	leak._age = Constants.FUEL_LEAK_DURATION * 0.5
	recorder.calls.clear()
	target._physics_process(0.016)
	assert_almost_eq(recorder.calls[0][0].length(), Constants.FUEL_LEAK_THRUST * 0.5, 1.0, "Thrust falls with pressure.")


func test_rock_in_the_line_of_fire_takes_the_shot():
	var rock = load("res://scenes/prefabs/celestial/asteroid.tscn").instance()
	add_child_autofree(rock)
	rock.global_transform = Transform(Basis().scaled(Vector3.ONE * 30.0), Vector3(0, 0, -200))
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	watch_signals(controller)
	controller.activate(0, target)
	controller._physics_process(0.016)
	assert_eq(target.hull, 50.0, "The hidden ship takes nothing.")
	assert_signal_emitted(controller, "tool_blocked")
	assert_gt(rock._hull_scorch.get_average_mark(), 0.0, "The rock is marked where the shot landed.")
	assert_almost_eq(shooter.power, 100.0 - laser.power_per_cycle, 0.001, "The shot still cost power.")
	rock.global_transform.origin = Vector3(500, 0, -200)
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	controller._physics_process(1.0)
	assert_lt(target.hull, 50.0, "With the line clear the ship is hit.")


# --- Tether cable ---

func _make_tether(distance: float) -> Node:
	var a = RigidBody.new()
	var b = RigidBody.new()
	add_child_autofree(a)
	add_child_autofree(b)
	b.global_transform.origin = Vector3(0, 0, -distance)
	var tether = load("res://src/core/agents/components/tether.gd").new()
	tether.setup(a, b, distance, 30.0, 15.0)
	add_child_autofree(tether)
	return tether


func test_tether_takes_up_slack_at_a_limited_rate():
	var tether = _make_tether(400.0)
	tether.towed.global_transform.origin = Vector3(0, 0, -150)
	tether._physics_process(1.0)
	assert_almost_eq(tether.length, 400.0 - 15.0 - Constants.TETHER_SLACK_TAKEUP_SPEED, 0.01, "Slack shows for a moment")
	var per_step: float = 15.0 + Constants.TETHER_SLACK_TAKEUP_SPEED
	var steps: int = int(floor((tether.length - 150.0) / per_step))
	for _i in range(steps):
		tether._physics_process(1.0)
	assert_true(tether.length >= 150.0 and tether.length < 150.0 + per_step, "Taken up step by step, never shorter than the actual distance: %.1f" % tether.length)
	assert_eq(tether.strain, 0.0, "Still loose.")
	var before: float = tether.length
	tether._physics_process(1.0)
	assert_almost_eq(tether.length, before - 15.0, 0.01, "Slack gone: it reels in as usual.")





func test_strain_grows_with_stretch():
	var tether = _make_tether(100.0)
	tether.towed.global_transform.origin = Vector3(0, 0, -100 - Constants.TETHER_STRAIN_FULL_STRETCH * 0.5)
	tether._physics_process(0.0)
	assert_almost_eq(tether.strain, 0.5, 0.01)


# --- Cable shape (TetherRope) ---

func test_rope_pulls_straight_when_taut_and_bunches_when_slack():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	var rope = Rope.new()
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -100)
	rope.reset(a, b)
	for _i in range(60):
		rope.step(a, b, 100.0, Vector3.ZERO, 1.0 / 60.0)
	var mid: Vector3 = rope.points[rope.points.size() / 2]
	assert_almost_eq(Vector2(mid.x, mid.y).length(), 0.0, 0.05, "Taut: straight between the anchors.")
	var close := Vector3(0, 0, -40)
	for _i in range(240):
		rope.step(a, close, 100.0, Vector3.ZERO, 1.0 / 60.0)
	assert_almost_eq(rope.get_length(), 100.0, 3.0, "Slack: keeps its length")
	var widest := 0.0
	for p in rope.points:
		widest = max(widest, Vector2(p.x, p.y).length())
	assert_gt(widest, 5.0, "so it bows out of line.")


func test_rope_travels_with_the_ships():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	var rope = Rope.new()
	var v := Vector3(100, 0, 0)
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -50)
	rope.reset(a, b)
	for _i in range(60):
		a += v / 60.0
		b += v / 60.0
		rope.step(a, b, 60.0, v, 1.0 / 60.0)
	var mid: Vector3 = rope.points[rope.points.size() / 2]
	assert_almost_eq(mid.x, a.x, 10.0, "No drag in vacuum: the slack cable keeps up with the ships.")


func test_rope_is_kept_out_of_hull_boxes():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	var box := AABB(Vector3(-5, -5, -30), Vector3(10, 10, 10))  # Sits across the straight line
	var pushed = Rope._push_out(Vector3(1, 0, -25), [[Transform.IDENTITY, box]])
	assert_false(box.has_point(pushed) and pushed.x < 4.999, "Pushed out through the nearest face.")
	assert_almost_eq(pushed, Vector3(5, 0, -25), Vector3(0.001, 0.001, 0.001), "The +x face is 4 m away, the others 5 m.")



# --- Letting go: hook off, cable winched in, then the harpoon is free again ---

func test_released_harpoon_winches_in_before_it_can_fire_again():
	_make_stripped_ready_wreck(3)
	controller.set_tools([laser, _make_harpoon()])
	controller.activate(1, target)
	controller._physics_process(0.016)
	var tether = controller.get_tether(1)
	tether._physics_process(0.016)  # Lays out the cable
	controller.deactivate(1)
	assert_null(controller.get_tether(1), "No longer holding the wreck")
	assert_true(controller.is_retracting(1), "but the cable is still out.")
	assert_true(tether.retracting)
	assert_false(tether.is_valid(), "Pulls nothing while winching in.")
	var result: Dictionary = controller.activate(1, target)
	assert_false(result.success)
	assert_eq(result.reason, "retracting")
	var out: float = tether.get_paid_out_length()
	assert_gt(out, 300.0)
	tether._physics_process(1.0)
	assert_almost_eq(tether.get_paid_out_length(), out - Constants.TETHER_RETRACT_SPEED, 0.01)
	tether._physics_process(100.0)
	yield(get_tree(), "idle_frame")
	assert_false(controller.is_retracting(1), "All in")
	assert_true(controller.activate(1, target).success, "so it can fire again.")


func test_hook_tears_free_when_overstretched_and_winches_in():
	var tether = _make_tether(200.0)
	tether._physics_process(0.016)
	tether.towed.global_transform.origin = Vector3(0, 0, -200 - Constants.TETHER_SNAP_STRETCH - 10)
	tether._physics_process(0.016)
	assert_true(tether.snapped)
	assert_true(tether.retracting, "The cable comes home on its own.")


func test_free_cable_end_is_pulled_home_as_it_shortens():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	var rope = Rope.new()
	rope.reset(Vector3.ZERO, Vector3(0, 0, -100))
	var rest := 100.0
	for _i in range(120):
		rest = max(1.0, rest - 1.0)
		rope.step(Vector3.ZERO, Vector3.ZERO, rest, Vector3.ZERO, 1.0 / 60.0, [], false)
	var tip: Vector3 = rope.points[rope.points.size() - 1]
	assert_true(tip.length() <= 1.5, "The hook end follows the winch in: %.2f m out" % tip.length())


func test_drawn_curve_passes_through_the_rope_points():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	var source := [Vector3.ZERO, Vector3(1, 2, 0), Vector3(3, 0, 1), Vector3(4, 4, 4)]
	var smooth: Array = Rope.smooth_points(source, 4)
	assert_eq(smooth.size(), (source.size() - 1) * 4 + 1)
	for i in range(source.size()):
		assert_almost_eq(smooth[i * 4], source[i], Vector3(0.0001, 0.0001, 0.0001))


func test_drawn_cable_takes_in_slack_below_the_towing_distance():
	var Tether = load("res://src/core/agents/components/tether.gd")
	assert_almost_eq(Tether.get_next_paid_out(36.0, 36.0, 18.0, 0.1), 36.0 - Constants.TETHER_SLACK_TAKEUP_SPEED * 0.1, 0.001, "Closer than towing distance: still takes in slack")
	assert_almost_eq(Tether.get_next_paid_out(19.0, 36.0, 18.0, 1.0), 18.0, 0.001, "down to the actual distance")
	assert_almost_eq(Tether.get_next_paid_out(18.0, 36.0, 30.0, 0.1), 30.0, 0.001, "and pays out as they drift apart")
	assert_almost_eq(Tether.get_next_paid_out(30.0, 36.0, 50.0, 0.1), 36.0, 0.001, "never past the cable's length.")


func test_rope_uses_fewer_points_as_the_cable_shortens():
	var Rope = load("res://src/core/agents/components/tether_rope.gd")
	assert_eq(Rope.point_count_for(1000.0), Constants.TETHER_ROPE_POINTS, "Long cable: the most points")
	assert_eq(Rope.point_count_for(10.0), Constants.TETHER_ROPE_MIN_POINTS, "short one: the fewest")
	var rope = Rope.new()
	var a := Vector3.ZERO
	rope.reset(a, Vector3(0, 0, -150))
	var long_count: int = rope.points.size()
	for rest in [150.0, 120.0, 90.0, 60.0, 40.0]:
		for _i in range(30):
			rope.step(a, Vector3(0, 0, -rest), rest, Vector3.ZERO, 1.0 / 60.0)
	assert_lt(rope.points.size(), long_count, "Reeled in: fewer points (%d of %d)" % [rope.points.size(), long_count])
	assert_almost_eq(rope.get_length(), 40.0, 0.5, "and still the right length")
	assert_almost_eq(rope.points[rope.points.size() - 1], Vector3(0, 0, -40), Vector3(0.01, 0.01, 0.01), "ending at the anchor.")
