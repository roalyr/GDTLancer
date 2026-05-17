##
## PROJECT: GDTLancer
## MODULE: test_route_target_provider.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.3, §6.4; TACTICAL_TODO.md §TASK_2
## LOG_REF: 2026-05-17 15:43:57
##

extends GutTest

const RouteTargetProviderScript = preload("res://src/core/targeting/route_target_provider.gd")
const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

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


func test_build_targets_for_runtime_discovered_sector_uses_registered_template():
	var discovered_template = LocationTemplateScript.new()
	discovered_template.template_id = "discovered_1"
	discovered_template.location_name = "Amber Gate"
	discovered_template.global_position = Vector3(48000, 0, 0)
	discovered_template.is_procedural = true
	discovered_template.procedural_type = "asteroid_field"
	TemplateDatabase.locations["discovered_1"] = discovered_template
	GameState.world_topology["sector_system_elace"] = {"connections": ["discovered_1"]}

	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_system_elace")
	assert_eq(route_targets.size(), 1, "Runtime-discovered sectors should still create logical jump-route targets.")
	var route_target = route_targets[0]
	assert_eq(route_target.target_sector_id, "discovered_1")
	assert_eq(route_target.display_name, "Amber Gate")
	assert_eq(route_target.route_direction, Vector3(1, 0, 0))