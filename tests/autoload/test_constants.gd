# File: tests/autoload/test_constants.gd
# GUT Test Script for Constants.gd Autoload

extends GutTest

func test_action_check_thresholds():
	assert_eq(Constants.ACTION_CHECK_FAIL_THRESHOLD, 10, "Failure threshold check")
	assert_eq(Constants.ACTION_CHECK_SWC_THRESHOLD, 10, "Success w/ Comp threshold check (>=)")
	assert_eq(Constants.ACTION_CHECK_CRIT_THRESHOLD, 14, "Critical Success threshold check (>=)")
	prints("Tested Action Check Thresholds")

func test_focus_constants():
	assert_eq(Constants.FOCUS_MAX_DEFAULT, 3, "Default Max Focus check")
	assert_eq(Constants.FOCUS_BOOST_PER_POINT, 1, "Focus boost per point check")
	prints("Tested Focus Constants")

func test_core_scene_paths_exist():
	# Check if the constants point to *something* - doesn't guarantee validity yet
	assert_ne(Constants.NPC_AGENT_SCENE_PATH, "", "NPC Agent Scene Path should not be empty")
	assert_ne(Constants.PLAYER_AGENT_SCENE_PATH, "", "Player Agent Scene Path should not be empty")
	assert_ne(Constants.INITIAL_ZONE_SCENE_PATH, "", "Initial Zone Scene Path should not be empty")
	prints("Tested Core Scene Paths Existence (basic check)")

func test_core_node_names_exist():
	assert_ne(Constants.AGENT_CONTAINER_NAME, "", "Agent Container Name check")
	assert_ne(Constants.AGENT_BODY_NODE_NAME, "", "Agent Body Node Name check")
	assert_true(Constants.ENTRY_POINT_NAMES is Array, "Entry Point Names should be an Array")
	assert_true(Constants.ENTRY_POINT_NAMES.size() > 0, "Entry Point Names should not be empty")
	prints("Tested Core Node Names Existence")

# Add more tests for other constants as needed...
