#
# PROJECT: GDTLancer
# MODULE: test_world_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §4.2, §6.1, §6.3
# LOG_REF: 2026-05-13 16:32:50
#

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
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO
	GlobalRefs.player_agent_body = null
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


func test_snapshot_player_state_for_sector_travel_preserves_rotation_and_clears_saved_position():
	var player = Spatial.new()
	add_child_autofree(player)
	player.rotation_degrees = Vector3(12, 34, 56)
	GlobalRefs.player_agent_body = player
	GameState.player_position = Vector3(10, 20, 30)

	world_manager._snapshot_player_state_for_sector_travel()

	assert_eq(
		GameState.player_position,
		Vector3.ZERO,
		"Sector travel should clear saved-position priority so arrival spawn rules can take over."
	)
	assert_eq(
		GameState.player_rotation,
		Vector3(12, 34, 56),
		"Sector travel should snapshot the current player orientation for the next-sector spawn."
	)