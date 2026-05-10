extends GutTest

const WorldManagerScript = preload("res://src/scenes/game_world/world_manager.gd")

var world_manager = null


func before_each():
	GameState.world_topology = {
		Constants.INITIAL_SECTOR_ID: {"connections": ["station_beta"]},
		"station_beta": {"connections": [Constants.INITIAL_SECTOR_ID]},
	}
	TemplateDatabase.locations = {
		Constants.INITIAL_SECTOR_ID: {"global_position": Vector3(0, 0, 0)},
		"station_beta": {"global_position": Vector3(100, 0, 0)},
	}
	world_manager = WorldManagerScript.new()


func after_each():
	GameState.world_topology.clear()
	TemplateDatabase.locations.clear()
	world_manager = null


func test_resolve_known_sector_id_returns_requested_sector_when_present():
	assert_eq(
		world_manager._resolve_known_sector_id("station_beta", "test"),
		"station_beta",
		"Known sectors should pass through unchanged."
	)


func test_resolve_known_sector_id_falls_back_to_initial_sector_for_missing_ids():
	assert_eq(
		world_manager._resolve_known_sector_id("sector_missing_renamed_away", "test"),
		Constants.INITIAL_SECTOR_ID,
		"Missing sectors should fall back to INITIAL_SECTOR_ID."
	)


func test_get_arrival_direction_for_route_points_back_to_source_sector():
	assert_eq(
		world_manager._get_arrival_direction_for_route(Constants.INITIAL_SECTOR_ID, "station_beta"),
		Vector3(-1, 0, 0),
		"Arrival direction should point from destination back toward the source sector."
	)


func test_get_arrival_direction_for_route_returns_zero_when_positions_match():
	TemplateDatabase.locations["station_beta"] = {"global_position": Vector3(0, 0, 0)}
	assert_eq(
		world_manager._get_arrival_direction_for_route(Constants.INITIAL_SECTOR_ID, "station_beta"),
		Vector3.ZERO,
		"Identical sector positions should not fabricate an arrival direction."
	)