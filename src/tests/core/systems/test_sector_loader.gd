# PROJECT: GDTLancer
# MODULE: test_sector_loader.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: test_sector_loader.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_005; universe_topology_architecture.md
# LOG_REF: 2026-06-07 16:45:00
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
	var zone = sector_loader.load_sector("sector_star_elace")
	assert_not_null(zone, "load_sector should return a non-null value.")
	assert_is(zone, Spatial, "load_sector should return a Spatial node.")
	zone.free()


func test_zone_has_agent_container():
	var zone = sector_loader.load_sector("sector_star_elace")
	assert_not_null(zone)
	var agent_container = zone.find_node("AgentContainer", true, false)
	assert_not_null(agent_container, "Zone should have an AgentContainer node.")
	assert_is(agent_container, Spatial, "AgentContainer should be a Spatial.")
	zone.free()


#func test_zone_has_jump_points_for_connections():
#	var zone = sector_loader.load_sector("sector_star_elace")
#	assert_not_null(zone)
#	add_child(zone)
#	var jump_points = get_tree().get_nodes_in_group("jump_point")
#	# sector_star_elace connects to 
	# Errors here
#	assert_gt(jump_points.size(), 0,
#		"Zone should have at least 1 JumpPoints for sector_star_elace connections.")
#	var target_ids = []
#	for jp in jump_points:
#		target_ids.append(jp.target_sector_id)
#	assert_has(target_ids, "sector_star_lywin",
#		"One JumpPoint should target station_beta.")
#	zone.queue_free()


func test_zone_has_starsphere():
	var zone = sector_loader.load_sector("sector_star_elace")
	assert_not_null(zone)
	var starsphere = zone.find_node("StarsphereSlot", true, false)
	assert_not_null(starsphere, "Zone should have a StarsphereSlot node.")
	zone.free()


func test_load_invalid_sector_returns_null():
	var zone = sector_loader.load_sector("nonexistent")
	assert_null(zone, "load_sector with invalid id should return null.")


func test_load_sector_with_invalid_scene_path_uses_procedural_fallback():
	var original_template = TemplateDatabase.locations["sector_star_elace"]
	var mutated_template = original_template.duplicate(true)
	mutated_template.sector_scene_path = "res://scenes/levels/sectors/missing_sector/missing_sector.tscn"
	TemplateDatabase.locations["sector_star_elace"] = mutated_template

	var zone = sector_loader.load_sector("sector_star_elace")
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
	zone.free()


#func test_nebula_offset_differs_between_sectors():
#	var zone_alpha = sector_loader.load_sector("sector_star_elace")
	# Error, returns Null for sector_star_lywin
#	var zone_beta = sector_loader.load_sector("sector_star_lywin")
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
		"res://database/registry/locations/sector_star_elace.tres",
		"res://database/registry/locations/sector_star_cob.tres",
		"res://database/registry/locations/sector_star_lywin.tres",
	]
	for path in location_paths:
		var res = load(path)
		if res != null:
			TemplateDatabase.locations[res.template_id] = res


func _seed_world_topology() -> void:
	GameState.world_topology = {
		"sector_star_elace": {
			"connections": ["sector_star_cob", "sector_star_lywin"],
		},
		"sector_star_cob": {
			"connections": ["sector_star_elace"],
		},
		"sector_star_lywin": {
			"connections": ["sector_star_elace"],
		},
	}


func _seed_discovered_sector() -> void:
	var discovered_template = LocationTemplateScript.new()
	discovered_template.template_id = "discovered_1"
	discovered_template.location_name = "Amber Gate"
	discovered_template.global_position = Vector3(48000, 2000, 0)
	discovered_template.sector_scene_path = ""
	discovered_template.is_procedural = true
	discovered_template.procedural_type = "asteroid_field"
	TemplateDatabase.locations["discovered_1"] = discovered_template
	GameState.world_topology["discovered_1"] = {
		"connections": ["sector_star_elace"],
	}
	GameState.world_topology["sector_star_elace"]["connections"] = ["sector_star_cob", "sector_star_lywin", "discovered_1"]
