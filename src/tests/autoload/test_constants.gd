# File: tests/autoload/test_constants.gd
# GUT Test Script for Constants.gd Autoload
# Version: 1.1 - Updated for ActionApproach thresholds

extends GutTest


func test_action_check_thresholds_are_correct():
	# Test Cautious thresholds
	assert_eq(
		Constants.ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS, 14, "Cautious Crit threshold should be 14."
	)
	assert_eq(
		Constants.ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS, 10, "Cautious SwC threshold should be 10."
	)

	# Test Risky thresholds
	assert_eq(Constants.ACTION_CHECK_CRIT_THRESHOLD_RISKY, 16, "Risky Crit threshold should be 16.")
	assert_eq(Constants.ACTION_CHECK_SWC_THRESHOLD_RISKY, 12, "Risky SwC threshold should be 12.")
	prints("Tested Action Check Thresholds")


func test_action_approach_enum_exists():
	# Test that the enum and its values exist and are correct.
	assert_not_null(Constants.ActionApproach, "ActionApproach enum should exist.")
	assert_eq(Constants.ActionApproach.CAUTIOUS, 0, "CAUTIOUS should be enum value 0.")
	assert_eq(Constants.ActionApproach.RISKY, 1, "RISKY should be enum value 1.")
	prints("Tested ActionApproach Enum")


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
