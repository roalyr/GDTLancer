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


func test_hit_effect_intensity_follows_damage():
	var Effect = load("res://src/core/agents/effects/laser_hit_effect.gd")
	assert_eq(Effect.intensity_for_damage(0.0, 8.0), 0.0, "No damage, no visible hit.")
	assert_almost_eq(Effect.intensity_for_damage(8.0, 8.0), 1.0, 0.001, "The tool's preset damage is a full-strength hit.")
	assert_almost_eq(Effect.intensity_for_damage(2.0, 8.0), 0.5, 0.001)
	assert_eq(Effect.intensity_for_damage(1000.0, 8.0), Effect.MAX_INTENSITY)


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
	var expected_min: float = (shooter.get_apparent_radius() + target.get_apparent_radius()) * controller.TETHER_CLEARANCE
	assert_almost_eq(tether.min_length, expected_min, 0.001, "Reels in to the sum of both apparent radii plus clearance.")
	tether._physics_process(100.0)
	assert_almost_eq(tether.length, expected_min, 0.001, "Never reels closer than the clearance.")


func test_harpoon_out_of_reach_stays_armed():
	_make_stripped_ready_wreck(3)
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

