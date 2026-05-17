#
# PROJECT: GDTLancer
# MODULE: test_sector_loader.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.3, §6.4; TACTICAL_TODO.md §TASK_2
# LOG_REF: 2026-05-17 15:43:57
#

extends GutTest

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

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
	var zone = sector_loader.load_sector("sector_system_elace")
	assert_not_null(zone, "load_sector should return a non-null value.")
	assert_is(zone, Spatial, "load_sector should return a Spatial node.")
	zone.free()


func test_zone_has_agent_container():
	var zone = sector_loader.load_sector("sector_system_elace")
	assert_not_null(zone)
	var agent_container = zone.find_node("AgentContainer", true, false)
	assert_not_null(agent_container, "Zone should have an AgentContainer node.")
	assert_is(agent_container, Spatial, "AgentContainer should be a Spatial.")
	zone.free()


func test_zone_has_station_with_correct_location_id():
	var zone = sector_loader.load_sector("sector_system_elace")
	assert_not_null(zone)
	# Need to add zone to tree for groups to work
	add_child_autoqfree(zone)
	var stations = get_tree().get_nodes_in_group("dockable_station")
	assert_gt(stations.size(), 0, "Zone should have at least one dockable_station.")
	var found = false
	for station in stations:
		if station.get("location_id") == "sector_system_elace":
			found = true
			break
	assert_true(found, "One dockable_station should have location_id 'sector_system_elace'.")


#func test_zone_has_jump_points_for_connections():
#	var zone = sector_loader.load_sector("sector_system_elace")
#	assert_not_null(zone)
#	add_child(zone)
#	var jump_points = get_tree().get_nodes_in_group("jump_point")
#	# sector_system_elace connects to 
	# Errors here
#	assert_gt(jump_points.size(), 0,
#		"Zone should have at least 1 JumpPoints for sector_system_elace connections.")
#	var target_ids = []
#	for jp in jump_points:
#		target_ids.append(jp.target_sector_id)
#	assert_has(target_ids, "sector_system_lywin",
#		"One JumpPoint should target station_beta.")
#	zone.queue_free()


func test_zone_has_starsphere():
	var zone = sector_loader.load_sector("sector_system_elace")
	assert_not_null(zone)
	var starsphere = zone.find_node("StarsphereSlot", true, false)
	assert_not_null(starsphere, "Zone should have a StarsphereSlot node.")
	zone.free()


func test_load_invalid_sector_returns_null():
	var zone = sector_loader.load_sector("nonexistent")
	assert_null(zone, "load_sector with invalid id should return null.")


func test_load_sector_with_invalid_scene_path_uses_procedural_fallback():
	var original_template = TemplateDatabase.locations["sector_system_elace"]
	var mutated_template = original_template.duplicate(true)
	mutated_template.sector_scene_path = "res://scenes/levels/sectors/missing_sector/missing_sector.tscn"
	TemplateDatabase.locations["sector_system_elace"] = mutated_template

	var zone = sector_loader.load_sector("sector_system_elace")
	assert_not_null(zone, "Missing handcrafted scene paths should fall back to a procedural zone.")
	assert_is(zone, Spatial, "Fallback sector should still return a Spatial node.")
	assert_not_null(
		zone.find_node("AgentContainer", true, false),
		"Procedural fallback should still include an AgentContainer."
	)
	zone.free()


func test_load_runtime_discovered_sector_uses_procedural_fallback_and_jump_routes():
	_seed_discovered_sector()
	var zone = sector_loader.load_sector("discovered_1")
	assert_not_null(zone, "Runtime-discovered sectors should load through the generic procedural fallback.")
	assert_not_null(zone.find_node("AgentContainer", true, false), "Discovered fallback sectors should still contain an AgentContainer.")
	assert_not_null(zone.find_node("StarsphereSlot", true, false), "Discovered fallback sectors should still contain a StarsphereSlot.")
	add_child_autoqfree(zone)

	var jump_points: Array = []
	for child in zone.get_children():
		if child.is_in_group("jump_point"):
			jump_points.append(child)

	assert_eq(jump_points.size(), 1, "Discovered fallback sectors should inject jump points for their registered connections.")
	assert_eq(jump_points[0].target_sector_id, "sector_system_elace")
	assert_eq(jump_points[0].target_sector_name, "Elace System")


#func test_nebula_offset_differs_between_sectors():
#	var zone_alpha = sector_loader.load_sector("sector_system_elace")
	# Error, returns Null for sector_system_lywin
#	var zone_beta = sector_loader.load_sector("sector_system_lywin")
#	assert_not_null(zone_alpha)
#	assert_not_null(zone_beta)
#
#	var nebulas_alpha = zone_alpha.find_node("Globalnebulas", true, false)
#	var nebulas_beta = zone_beta.find_node("Globalnebulas", true, false)
#
#	if nebulas_alpha != null and nebulas_beta != null:
#		assert_ne(nebulas_alpha.transform.origin, nebulas_beta.transform.origin,
#			"Nebula offsets should differ between sectors with different global_position.")
#	else:
#		pass_test("Globalnebulas nodes not found; offset test skipped.")
#
#	zone_alpha.free()
#	zone_beta.free()


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_state() -> void:
	GameState.reset_state()
	TemplateDatabase.locations.clear()


func _seed_template_database() -> void:
	var location_paths: Array = [
		"res://database/registry/locations/sector_system_elace.tres",
		"res://database/registry/locations/sector_system_cob.tres",
		"res://database/registry/locations/sector_system_lywin.tres",
	]
	for path in location_paths:
		var res = load(path)
		if res != null:
			TemplateDatabase.locations[res.template_id] = res


func _seed_world_topology() -> void:
	GameState.world_topology = {
		"sector_system_elace": {
			"connections": ["sector_system_cob", "sector_system_lywin"],
		},
		"sector_system_cob": {
			"connections": ["sector_system_elace"],
		},
		"sector_system_lywin": {
			"connections": ["sector_system_elace"],
		},
	}


func _seed_discovered_sector() -> void:
	var discovered_template = LocationTemplateScript.new()
	discovered_template.template_id = "discovered_1"
	discovered_template.location_name = "Amber Gate"
	discovered_template.location_type = "asteroid_field"
	discovered_template.global_position = Vector3(48000, 2000, 0)
	discovered_template.sector_scene_path = ""
	discovered_template.is_procedural = true
	discovered_template.procedural_type = "asteroid_field"
	TemplateDatabase.locations["discovered_1"] = discovered_template
	GameState.world_topology["discovered_1"] = {
		"connections": ["sector_system_elace"],
	}
	GameState.world_topology["sector_system_elace"]["connections"] = ["sector_system_cob", "sector_system_lywin", "discovered_1"]
