# Tests for ToolController: hit quality, cycling, the power gate and the wreck transition.

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
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	controller.set_tools([harpoon])
	assert_eq(controller.activate(0, target).reason, "not_implemented")


func test_wreck_drifts_and_cannot_spend_power():
	target.become_wreck()
	assert_false(target.try_spend_power(1.0))
	target._physics_process(1.0)
	assert_eq(target.power, 0.0, "Wrecks do not regenerate power.")
	shooter.power = 50.0
	shooter._physics_process(1.0)
	assert_almost_eq(shooter.power, 50.0 + shooter.power_regen, 0.001, "Live ships regenerate power.")
