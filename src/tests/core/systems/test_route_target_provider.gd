# Tests for RouteTargetProvider: jump-route targets built from the static sector graph.

extends GutTest

const RouteTargetProviderScript = preload("res://src/core/targeting/route_target_provider.gd")
const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

var route_target_provider: Reference = null
var _saved_locations: Dictionary = {}


func before_each():
	GameState.reset_state()
	_saved_locations = TemplateDatabase.locations
	TemplateDatabase.locations = {
		"sector_star_elace": {
			"global_position": Vector3.ZERO,
			"location_name": "Elace System",
			"connections": ["sector_star_cob"],
		},
		"sector_star_cob": {
			"global_position": Vector3(100, 0, 0),
			"location_name": "Cob System",
		},
	}
	route_target_provider = RouteTargetProviderScript.new()


func after_each():
	GameState.reset_state()
	TemplateDatabase.locations = _saved_locations
	route_target_provider = null


func test_build_targets_for_sector_returns_logical_route_targets():
	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_star_elace")
	assert_eq(route_targets.size(), 1, "Expected one logical jump-route target for the seeded connection.")
	var route_target = route_targets[0]
	assert_eq(route_target.target_sector_id, "sector_star_cob")
	assert_eq(route_target.display_name, "Cob System")
	assert_eq(route_target.route_direction, Vector3(1, 0, 0))


func test_build_targets_skips_missing_target_templates():
	TemplateDatabase.locations.erase("sector_star_cob")
	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_star_elace")
	assert_eq(route_targets.size(), 0, "Missing target templates should not create logical route targets.")


func test_build_targets_for_location_template_connection():
	var discovered_template = LocationTemplateScript.new()
	discovered_template.template_id = "discovered_1"
	discovered_template.location_name = "Amber Gate"
	discovered_template.global_position = Vector3(48000, 0, 0)
	discovered_template.is_procedural = true
	discovered_template.procedural_type = "asteroid_field"
	TemplateDatabase.locations["discovered_1"] = discovered_template
	TemplateDatabase.locations["sector_star_elace"]["connections"] = ["discovered_1"]

	var route_targets: Array = route_target_provider.build_targets_for_sector("sector_star_elace")
	assert_eq(route_targets.size(), 1, "LocationTemplate targets should create logical jump-route targets.")
	var route_target = route_targets[0]
	assert_eq(route_target.target_sector_id, "discovered_1")
	assert_eq(route_target.display_name, "Amber Gate")
	assert_eq(route_target.route_direction, Vector3(1, 0, 0))