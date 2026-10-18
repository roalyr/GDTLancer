# Tests for Constants.

extends GutTest


func test_core_scene_paths_exist():
	# Check if the constants point to *something* - doesn't guarantee validity yet
	assert_ne(Constants.NPC_AGENT_SCENE_PATH, "", "NPC Agent Scene Path should not be empty")
	assert_ne(Constants.PLAYER_AGENT_SCENE_PATH, "", "Player Agent Scene Path should not be empty")
	prints("Tested Core Scene Paths Existence (basic check)")


func test_core_node_names_exist():
	assert_ne(Constants.AGENT_CONTAINER_NAME, "", "Agent Container Name check")
	assert_ne(Constants.AGENT_BODY_NODE_NAME, "", "Agent Body Node Name check")
	prints("Tested Core Node Names Existence")


func test_jump_travel_duration_is_symmetric_by_sector_type():
	assert_eq(Constants.get_jump_travel_duration("star", "planet"), Constants.JUMP_DURATION_STAR_PLANET)
	assert_eq(Constants.get_jump_travel_duration("planet", "star"), Constants.JUMP_DURATION_STAR_PLANET)
	assert_eq(Constants.get_jump_travel_duration("moon", "deep_space"), Constants.JUMP_DURATION_ANY_DEEP_SPACE)
