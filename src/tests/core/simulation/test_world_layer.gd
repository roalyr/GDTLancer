#
# PROJECT: GDTLancer
# MODULE: test_world_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §3.4, TRUTH_SIMULATION-GRAPH.md §2.1, §3.3
# LOG_REF: 2026-05-10 16:13:36
#

extends GutTest

## Unit tests for WorldLayer: topology initialization from templates.

var world_layer: Reference = null

const TEST_SEED: String = "world_test_seed"


func before_each():
	_clear_state()
	_seed_template_database()
	var Script = load("res://src/core/simulation/world_layer.gd")
	world_layer = Script.new()


func after_each():
	_clear_state()
	world_layer = null


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_initialize_world_populates_topology():
	world_layer.initialize_world(TEST_SEED)
	assert_gt(GameState.world_topology.size(), 0,
		"world_topology should have at least one sector after init.")

func test_all_sectors_have_hazards():
	world_layer.initialize_world(TEST_SEED)
	for sector_id in GameState.world_topology:
		assert_true(GameState.world_hazards.has(sector_id),
			"Sector '%s' should have hazard data." % sector_id)

func test_connections_are_bidirectional():
	world_layer.initialize_world(TEST_SEED)
	for sector_id in GameState.world_topology:
		var connections: Array = GameState.world_topology[sector_id].get("connections", [])
		for conn in connections:
			assert_true(GameState.world_topology.has(conn),
				"Connection target '%s' must exist in topology." % conn)
			var back_connections: Array = GameState.world_topology[conn].get("connections", [])
			assert_has(back_connections, sector_id,
				"Connection %s → %s must be bidirectional." % [sector_id, conn])

func test_seed_stored_in_game_state():
	world_layer.initialize_world(TEST_SEED)
	assert_eq(GameState.world_seed, TEST_SEED, "world_seed should be stored in GameState.")

func test_get_neighbors_returns_connections():
	world_layer.initialize_world(TEST_SEED)
	var first_sector: String = GameState.world_topology.keys()[0]
	var expected: Array = GameState.world_topology[first_sector].get("connections", [])
	var actual: Array = world_layer.get_neighbors(first_sector)
	assert_eq(actual, expected, "get_neighbors should return connection list.")


func test_invalid_connections_are_filtered_from_topology():
	TemplateDatabase.locations.clear()
	var starter_sector: Resource = load("res://database/registry/locations/sector_system_elace.tres")
	var station_beta: Resource = load("res://database/registry/locations/station_beta.tres")
	assert_not_null(starter_sector, "Starter sector template should load.")
	assert_not_null(station_beta, "Station Beta template should load.")
	if starter_sector == null or station_beta == null:
		return

	var mutated_starter: Resource = starter_sector.duplicate(true)
	mutated_starter.connections = PoolStringArray(["station_beta", "sector_missing_renamed_away"])

	TemplateDatabase.locations[mutated_starter.template_id] = mutated_starter
	TemplateDatabase.locations[station_beta.template_id] = station_beta

	world_layer.initialize_world(TEST_SEED)

	var connections: Array = GameState.world_topology["sector_system_elace"].get("connections", [])
	assert_has(connections, "station_beta", "Valid connections should remain in topology.")
	assert_false(
		"sector_missing_renamed_away" in connections,
		"Invalid renamed-away sectors should be filtered from topology."
	)


func test_initial_sector_id_exists_in_topology():
	world_layer.initialize_world(TEST_SEED)
	assert_true(
		GameState.world_topology.has(Constants.INITIAL_SECTOR_ID),
		"INITIAL_SECTOR_ID should resolve to a sector that exists in world_topology."
	)


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.world_seed = ""
	GameState.sector_tags.clear()
	TemplateDatabase.locations.clear()


func _seed_template_database() -> void:
	## Seed TemplateDatabase.locations with real .tres files so world_layer can init.
	var location_paths: Array = [
		"res://database/registry/locations/sector_system_elace.tres",
		"res://database/registry/locations/station_beta.tres",
		"res://database/registry/locations/sector_gamma.tres",
		"res://database/registry/locations/station_delta.tres",
		"res://database/registry/locations/sector_epsilon.tres",
	]
	TemplateDatabase.locations.clear()
	for path in location_paths:
		var res = load(path)
		if res != null:
			TemplateDatabase.locations[res.template_id] = res
