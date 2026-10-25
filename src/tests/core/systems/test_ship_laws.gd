# Tests for ShipLaws: the reference genes give the Phoenix Light and Ablative Laser, and the laws
# trade one stat for another the way the physics says.

extends GutTest

const ShipLaws = preload("res://src/core/systems/ship_laws.gd")

const PHOENIX = {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}}


func test_reference_ship_is_the_phoenix_light():
	var stats: Dictionary = ShipLaws.ship_stats(PHOENIX)
	assert_almost_eq(stats.mass, 6000.0, 0.01)
	assert_eq(stats.hull_integrity, int(Constants.LAW_HULL[1]))
	assert_almost_eq(stats.linear_thrust, 450000.0, 1.0)
	assert_almost_eq(stats.power_capacity, 100.0, 0.01)
	assert_almost_eq(stats.power_regen, 10.0, 0.01)
	assert_almost_eq(stats.signature, 1500.0, 0.01)
	assert_almost_eq(stats.apparent_radius, 12.0, 0.01)
	assert_eq(stats.tool_slots_small, 2)
	assert_eq(stats.module_slots, 2)
	assert_eq(stats.base_value, 1000)


func test_reference_laser_is_the_ablative_laser():
	var stats: Dictionary = ShipLaws.laser_stats({"mass": 300.0, "energy": 5.0})
	assert_almost_eq(stats.damage, 6.0, 0.001)
	assert_almost_eq(stats.optimal_range, 1000.0, 0.01)
	assert_almost_eq(stats.falloff, 250.0, 0.01)
	assert_almost_eq(stats.tracking, Constants.LAW_LASER_TRACKING[0], 0.0001)
	assert_almost_eq(stats.cycle_time, 1.0, 0.0001)
	assert_eq(stats.power_per_cycle, 5.0)
	assert_eq(stats.mount_size, "small")
	assert_eq(stats.base_value, 100)


func test_bigger_ships_are_longer_tougher_and_turn_slower():
	var small: Dictionary = ShipLaws.ship_stats({"size": 0.25, "shares": PHOENIX.shares})
	var big: Dictionary = ShipLaws.ship_stats({"size": 4.0, "shares": PHOENIX.shares})
	assert_lt(small.hull_integrity, Constants.LAW_HULL[1])
	assert_gt(big.hull_integrity, Constants.LAW_HULL[1])
	assert_lt(big.hull_integrity, Constants.LAW_HULL[1] * 4, "Hull grows slower than mass")
	assert_almost_eq(big.apparent_radius / small.apparent_radius, pow(16.0, 1.0 / 3.0), 0.001)
	assert_lt(big.linear_thrust / big.mass, small.linear_thrust / small.mass, "Thrust per kg falls with size")
	assert_eq(small.tool_slots_small, 1, "Even the smallest ship has one hardpoint")
	assert_eq(big.tool_slots_medium, 5, "Hardpoints grow with the surface, and take bigger tools")


func test_shares_are_normalized_with_minimums():
	var shares: Dictionary = ShipLaws.normalized_shares({"structure": 0.0, "engine": 10.0, "reactor": 0.0, "capacitor": 0.0, "hold": 0.0})
	var total := 0.0
	for key in shares:
		total += shares[key]
	assert_almost_eq(total, 1.0, 0.0001)
	assert_gt(shares.structure, 0.0, "A frame always has structure")


func test_laser_energy_trades_reach_and_punch_for_cycle_time():
	var light: Dictionary = ShipLaws.laser_stats({"mass": 300.0, "energy": 2.5})
	var hot: Dictionary = ShipLaws.laser_stats({"mass": 300.0, "energy": 10.0})
	assert_gt(hot.damage, light.damage)
	assert_gt(hot.optimal_range, light.optimal_range)
	assert_gt(hot.cycle_time, light.cycle_time)
	assert_lt(hot.damage / hot.cycle_time, light.damage / light.cycle_time, "Hotter shots: less damage per second")
	var heavy: Dictionary = ShipLaws.laser_stats({"mass": 1200.0, "energy": 5.0})
	assert_lt(heavy.tracking, light.tracking, "Heavier turrets track worse")
	assert_eq(heavy.mount_size, "medium")


func test_module_laws_match_the_ship_subsystems():
	assert_eq(ShipLaws.module_stats("plating", {"mass": 3300.0}).stat_modifiers.hull, int(Constants.LAW_HULL[1]))
	assert_almost_eq(ShipLaws.module_stats("thruster", {"mass": 1200.0}).stat_modifiers.linear_thrust, 450000.0, 1.0)
	assert_almost_eq(ShipLaws.module_stats("power_cell", {"mass": 600.0}).stat_modifiers.power_regen, 10.0, 0.001)
	assert_almost_eq(ShipLaws.module_stats("capacitor", {"mass": 300.0}).stat_modifiers.power_capacity, 100.0, 0.001)


func test_registry_parts_follow_their_genes():
	for template_id in ["tools/tool_ablative_laser", "tools/tool_ablative_laser_long_range", "assets/modules/module_hull_plating", "assets/modules/module_thruster", "assets/modules/module_power_cell", "assets/modules/module_capacitor", "assets/ships/ship_default", "assets/ships/ship_hostile_default"]:
		var template = load("res://database/registry/%s.tres" % template_id)
		assert_not_null(template, template_id)
		if template == null:
			continue
		var copy = template.duplicate()
		var stats: Dictionary = ShipLaws.reapply(copy)
		assert_false(stats.empty(), template_id + " has law genes")
		for field in stats:
			if stats[field] is float:
				assert_almost_eq(float(template.get(field)), stats[field], 0.01 + abs(stats[field]) * 0.0001, "%s.%s (run tools/apply_laws.gd)" % [template_id, field])


func test_built_ship_scales_its_model_and_paints_its_type():
	var ship = ShipLaws.build_ship_template({"type": 3, "size": 2.0, "shares": PHOENIX.shares}, "evo_ship_test", "Phoenix III", "violet")
	assert_almost_eq(ship.model_scale, pow(2.0, 1.0 / 3.0), 0.0001)
	assert_eq(ship.panel_material, Constants.SHIP_TYPE_PANEL_MATERIALS[3])
	assert_eq(ship.ship_scene.resource_path, Constants.SHIP_FACTION_SCENES.violet)
