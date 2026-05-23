#
# PROJECT: GDTLancer
# MODULE: test_world_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §7; TRUTH_SIMULATION-GRAPH.md §1, §3.2, §3.3; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-05-23 16:43:24
#

extends GutTest

const WorldManagerScript = preload("res://src/scenes/game_world/world_manager.gd")

var world_manager = null


func before_each():
	GameState.world_topology = {
		Constants.INITIAL_SECTOR_ID: {"connections": ["sector_system_cob"]},
		"sector_system_cob": {"connections": [Constants.INITIAL_SECTOR_ID]},
	}
	TemplateDatabase.locations = {
		Constants.INITIAL_SECTOR_ID: {"global_position": Vector3(0, 0, 0)},
		"sector_system_cob": {"global_position": Vector3(100, 0, 0)},
	}
	world_manager = WorldManagerScript.new()


func after_each():
	GameState.world_topology.clear()
	TemplateDatabase.locations.clear()
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO
	GlobalRefs.player_agent_body = null
	if is_instance_valid(world_manager) and not is_instance_valid(world_manager.get_parent()):
		world_manager.free()
	world_manager = null


func test_resolve_known_sector_id_returns_requested_sector_when_present():
	assert_eq(
		world_manager._resolve_known_sector_id("sector_system_cob", "test"),
		"sector_system_cob",
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
		world_manager._get_arrival_direction_for_route(Constants.INITIAL_SECTOR_ID, "sector_system_cob"),
		Vector3(-1, 0, 0),
		"Arrival direction should point from destination back toward the source sector."
	)


func test_get_arrival_direction_for_route_returns_zero_when_positions_match():
	TemplateDatabase.locations["sector_system_cob"] = {"global_position": Vector3(0, 0, 0)}
	assert_eq(
		world_manager._get_arrival_direction_for_route(Constants.INITIAL_SECTOR_ID, "sector_system_cob"),
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


func test_jump_transition_active_defaults_false():
	assert_false(
		world_manager.is_jump_transition_active(),
		"WorldManager should start with no active jump transition foundation."
	)


func test_begin_jump_transition_foundation_uses_rig_when_enabled():
	var harness = _create_jump_transition_harness(true)
	world_manager._begin_jump_transition_foundation(Constants.INITIAL_SECTOR_ID, "sector_system_cob")
	var expected_direction = _compute_expected_departure_direction(
		Constants.INITIAL_SECTOR_ID,
		"sector_system_cob"
	)

	assert_true(
		world_manager.is_jump_transition_active(),
		"Enabled transition foundations should mark the world manager as active."
	)
	assert_eq(
		harness["rig"].departure_calls.size(),
		1,
		"Enabled transition foundations should enter the rig departure stage exactly once."
	)
	_assert_vector3_almost_eq(
		harness["rig"].departure_calls[0][2],
		expected_direction,
		0.0001,
		"Departure travel direction should point from the source sector toward the destination sector."
	)


func test_begin_jump_transition_foundation_resets_when_disabled():
	var harness = _create_jump_transition_harness(false)
	world_manager._begin_jump_transition_foundation(Constants.INITIAL_SECTOR_ID, "sector_system_cob")

	assert_false(
		world_manager.is_jump_transition_active(),
		"Disabled transition foundations should leave the world manager inactive."
	)
	assert_eq(
		harness["rig"].reset_calls,
		1,
		"Disabled transition foundations should reset the rig instead of starting departure or cruise."
	)
	assert_eq(
		harness["rig"].departure_calls.size(),
		0,
		"Disabled transition foundations should not start departure."
	)


func test_reset_jump_transition_foundation_clears_active_state_and_resets_rig():
	var harness = _create_jump_transition_harness(true)
	world_manager._begin_jump_transition_foundation(Constants.INITIAL_SECTOR_ID, "sector_system_cob")
	world_manager._reset_jump_transition_foundation()

	assert_false(
		world_manager.is_jump_transition_active(),
		"Resetting the transition foundation should clear the active flag."
	)
	assert_eq(
		harness["rig"].reset_calls,
		1,
		"Resetting the transition foundation should forward the reset to the rig."
	)


func _create_jump_transition_harness(is_enabled: bool) -> Dictionary:
	var container = Node.new()
	add_child_autofree(container)
	container.add_child(world_manager)

	var rendering_script = GDScript.new()
	rendering_script.source_code = "extends Node\nvar jump_transition_enabled = true\n"
	rendering_script.reload()
	var world_rendering = Node.new()
	world_rendering.name = "WorldRendering"
	world_rendering.set_script(rendering_script)
	world_rendering.jump_transition_enabled = is_enabled
	container.add_child(world_rendering)

	var rig_script = GDScript.new()
	rig_script.source_code = "extends Node\nvar departure_calls = []\nvar reset_calls = 0\nfunc begin_departure(source_sector_id, target_sector_id, travel_direction):\n\tdeparture_calls.append([source_sector_id, target_sector_id, travel_direction])\nfunc reset_transition_state():\n\treset_calls += 1\n"
	rig_script.reload()
	var jump_transition_rig = Node.new()
	jump_transition_rig.name = Constants.JUMP_TRANSITION_RIG_NODE_NAME
	jump_transition_rig.set_script(rig_script)
	container.add_child(jump_transition_rig)

	return {
		"container": container,
		"rig": jump_transition_rig,
		"world_rendering": world_rendering,
	}


func _compute_expected_departure_direction(source_sector_id: String, target_sector_id: String) -> Vector3:
	var source_position = world_manager._get_sector_global_position(source_sector_id)
	var target_position = world_manager._get_sector_global_position(target_sector_id)
	if source_position == target_position:
		return Constants.JUMP_TRANSITION_DEFAULT_DIRECTION
	return (target_position - source_position).normalized()


func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	assert_almost_eq(actual.x, expected.x, tolerance, "%s (x component)" % message)
	assert_almost_eq(actual.y, expected.y, tolerance, "%s (y component)" % message)
	assert_almost_eq(actual.z, expected.z, tolerance, "%s (z component)" % message)
