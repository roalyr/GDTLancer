extends GutTest

const RouteTargetProviderScript = preload("res://src/core/targeting/route_target_provider.gd")

var route_target_provider: Reference = null


func before_each():
	GameState.reset_state()
	GameState.world_topology = {
		"sector_system_elace": {"connections": ["sector_system_cob"]},
	}
	TemplateDatabase.locations = {
		"sector_system_elace": {
			"global_position": Vector3.ZERO,
			"location_name": "Elace System",
		},
		"sector_system_cob": {
			"global_position": Vector3(100, 0, 0),
			"location_name": "Cob System",
		},
	}
	route_target_provider = RouteTargetProviderScript.new()


func after_each():
	GameState.reset_state()
	TemplateDatabase.locations.clear()
	route_target_provider = null


func test_build_targets_for_sector_returns_logical_route_targets():
	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_system_elace")
	assert_eq(route_targets.size(), 1, "Expected one logical jump-route target for the seeded connection.")
	var route_target = route_targets[0]
	assert_eq(route_target.target_sector_id, "sector_system_cob")
	assert_eq(route_target.display_name, "Cob System")
	assert_eq(route_target.route_direction, Vector3(1, 0, 0))


func test_build_targets_skips_missing_target_templates():
	TemplateDatabase.locations.erase("sector_system_cob")
	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_system_elace")
	assert_eq(route_targets.size(), 0, "Missing target templates should not create logical route targets.")