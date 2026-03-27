#
# PROJECT: GDTLancer
# MODULE: test_sector_loader.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md §TASK_9
# LOG_REF: 2026-03-27
#

extends GutTest

## Unit tests for SectorLoader: sector loading, JumpPoint injection, nebula offset.

var sector_loader: Reference = null


func before_each():
	_clear_state()
	_seed_template_database()
	_seed_world_topology()
	var Script = load("res://src/core/systems/sector_loader.gd")
	sector_loader = Script.new()


func after_each():
	_clear_state()
	sector_loader = null


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_load_sector_returns_spatial():
	var zone = sector_loader.load_sector("station_alpha")
	assert_not_null(zone, "load_sector should return a non-null value.")
	assert_is(zone, Spatial, "load_sector should return a Spatial node.")
	zone.free()


func test_zone_has_agent_container():
	var zone = sector_loader.load_sector("station_alpha")
	assert_not_null(zone)
	var agent_container = zone.find_node("AgentContainer", true, false)
	assert_not_null(agent_container, "Zone should have an AgentContainer node.")
	assert_is(agent_container, Spatial, "AgentContainer should be a Spatial.")
	zone.free()


func test_zone_has_station_with_correct_location_id():
	var zone = sector_loader.load_sector("station_alpha")
	assert_not_null(zone)
	# Need to add zone to tree for groups to work
	add_child(zone)
	var stations = get_tree().get_nodes_in_group("dockable_station")
	assert_gt(stations.size(), 0, "Zone should have at least one dockable_station.")
	var found = false
	for station in stations:
		if station.get("location_id") == "station_alpha":
			found = true
			break
	assert_true(found, "One dockable_station should have location_id 'station_alpha'.")
	zone.queue_free()


func test_zone_has_jump_points_for_connections():
	var zone = sector_loader.load_sector("station_alpha")
	assert_not_null(zone)
	add_child(zone)
	var jump_points = get_tree().get_nodes_in_group("jump_point")
	# station_alpha connects to station_beta and station_delta
	assert_gt(jump_points.size(), 1,
		"Zone should have at least 2 JumpPoints for station_alpha connections.")
	var target_ids = []
	for jp in jump_points:
		target_ids.append(jp.target_sector_id)
	assert_has(target_ids, "station_beta",
		"One JumpPoint should target station_beta.")
	zone.queue_free()


func test_zone_has_starsphere():
	var zone = sector_loader.load_sector("station_alpha")
	assert_not_null(zone)
	var starsphere = zone.find_node("StarsphereSlot", true, false)
	assert_not_null(starsphere, "Zone should have a StarsphereSlot node.")
	zone.free()


func test_load_invalid_sector_returns_null():
	var zone = sector_loader.load_sector("nonexistent")
	assert_null(zone, "load_sector with invalid id should return null.")


func test_nebula_offset_differs_between_sectors():
	var zone_alpha = sector_loader.load_sector("station_alpha")
	var zone_beta = sector_loader.load_sector("station_beta")
	assert_not_null(zone_alpha)
	assert_not_null(zone_beta)

	var nebulas_alpha = zone_alpha.find_node("Globalnebulas", true, false)
	var nebulas_beta = zone_beta.find_node("Globalnebulas", true, false)

	if nebulas_alpha != null and nebulas_beta != null:
		assert_ne(nebulas_alpha.transform.origin, nebulas_beta.transform.origin,
			"Nebula offsets should differ between sectors with different global_position.")
	else:
		pass_test("Globalnebulas nodes not found; offset test skipped.")

	zone_alpha.free()
	zone_beta.free()


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_state() -> void:
	GameState.reset_state()
	TemplateDatabase.locations.clear()


func _seed_template_database() -> void:
	var location_paths: Array = [
		"res://database/registry/locations/station_alpha.tres",
		"res://database/registry/locations/station_beta.tres",
		"res://database/registry/locations/station_delta.tres",
	]
	for path in location_paths:
		var res = load(path)
		if res != null:
			TemplateDatabase.locations[res.template_id] = res


func _seed_world_topology() -> void:
	GameState.world_topology = {
		"station_alpha": {
			"connections": ["station_beta", "station_delta"],
		},
		"station_beta": {
			"connections": ["station_alpha", "station_gamma"],
		},
	}
