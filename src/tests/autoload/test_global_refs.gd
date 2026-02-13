# File: tests/autoload/test_global_refs.gd
# GUT Test Script for GlobalRefs.gd Autoload
# Version: 1.2

extends GutTest

# Dummy nodes used for testing references
var test_node_player = null
var test_node_camera = null
var test_node_other = null
var test_system_node = null


# Setup before each test method
func before_each():
	# Create fresh dummy nodes for isolation
	test_node_player = Node.new()
	test_node_player.name = "DummyPlayer"
	test_node_camera = Camera.new()
	test_node_camera.name = "DummyCamera"
	test_node_other = Node.new()
	test_node_other.name = "DummyOther"
	test_system_node = Node.new()
	test_system_node.name = "DummySystem"

	# GUT's autofree will handle removal and freeing
	add_child_autofree(test_node_player)
	add_child_autofree(test_node_camera)
	add_child_autofree(test_node_other)
	add_child_autofree(test_system_node)

	# Reset all global refs to a known null state before each test
	reset_all_global_refs()


func after_each():
	# Reset global refs after test completion to avoid interfering with other tests
	reset_all_global_refs()
	# Dummy nodes are freed by autofree


# Helper function to reset all references
func reset_all_global_refs():
	GlobalRefs.player_agent_body = null
	GlobalRefs.main_camera = null
	GlobalRefs.world_manager = null
	GlobalRefs.main_hud = null
	GlobalRefs.current_zone = null
	GlobalRefs.agent_container = null
	GlobalRefs.game_state_manager = null
	GlobalRefs.agent_spawner = null
	GlobalRefs.asset_system = null
	GlobalRefs.character_system = null
	GlobalRefs.event_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.time_system = null
	GlobalRefs.simulation_engine = null


# --- Test Methods ---


func test_initial_references_are_null():
	assert_null(GlobalRefs.player_agent_body, "Player ref should start null.")
	assert_null(GlobalRefs.main_camera, "Camera ref should start null.")
	assert_null(GlobalRefs.world_manager, "World Manager ref should start null.")
	assert_null(GlobalRefs.time_system, "Time System ref should start null.")
	assert_null(GlobalRefs.character_system, "Character System ref should start null.")
	prints("Tested GlobalRefs: Initial Null State")


func test_can_set_and_get_valid_reference():
	assert_null(GlobalRefs.player_agent_body, "Pre-check: Player ref is null.")
	# Assign using the variable, which triggers the setter via setget
	GlobalRefs.player_agent_body = test_node_player
	assert_true(
		is_instance_valid(GlobalRefs.player_agent_body), "Player ref should be a valid instance."
	)
	assert_eq(
		GlobalRefs.player_agent_body,
		test_node_player,
		"Player ref should hold the assigned valid node."
	)
	prints("Tested GlobalRefs: Set/Get Valid Reference")


func test_can_set_and_get_system_references():
	assert_null(GlobalRefs.time_system, "Pre-check: TimeSystem ref is null.")
	GlobalRefs.time_system = test_system_node
	assert_true(is_instance_valid(GlobalRefs.time_system), "TimeSystem ref should be valid.")
	assert_eq(GlobalRefs.time_system, test_system_node, "TimeSystem ref holds the correct node.")
	prints("Tested GlobalRefs: Set/Get System References")


func test_setting_null_clears_reference():
	# Set a valid reference first
	GlobalRefs.main_camera = test_node_camera
	assert_true(is_instance_valid(GlobalRefs.main_camera), "Pre-check: Camera ref is set.")
	# Set back to null
	GlobalRefs.main_camera = null
	assert_null(GlobalRefs.main_camera, "Camera ref should be null after setting null.")
	prints("Tested GlobalRefs: Set Null Clears Reference")


func test_overwriting_reference_with_valid_node():
	GlobalRefs.world_manager = test_node_player # Assign Node type to Node var
	assert_eq(GlobalRefs.world_manager, test_node_player, "Check initial assignment.")
	# Assign a different valid node
	GlobalRefs.world_manager = test_node_other
	assert_true(is_instance_valid(GlobalRefs.world_manager), "New WM ref should be valid.")
	assert_eq(
		GlobalRefs.world_manager, test_node_other, "World Manager ref should hold the new node."
	)
	assert_ne(
		GlobalRefs.world_manager,
		test_node_player,
		"World Manager ref should no longer hold the old node."
	)
	prints("Tested GlobalRefs: Overwriting Reference")


func test_setting_invalid_freed_reference_is_handled():
	# Set a valid reference first
	GlobalRefs.player_agent_body = test_node_player
	assert_true(is_instance_valid(GlobalRefs.player_agent_body), "Pre-check: Player ref is valid.")

	# Create and free a temporary node *before* assigning it
	var freed_node = Node.new()
	freed_node.free() # Free it immediately

	# Attempt to assign the freed node via the setter (setget triggers this)
	GlobalRefs.player_agent_body = freed_node

	# Assert that the reference DID NOT change to the invalid node
	# It should have remained the previously valid node because the setter rejected the freed one.
	assert_true(
		is_instance_valid(GlobalRefs.player_agent_body), "Player ref should still be valid."
	)
	assert_eq(
		GlobalRefs.player_agent_body,
		test_node_player,
		"Player ref should remain the original valid node."
	)
	assert_ne(
		GlobalRefs.player_agent_body,
		freed_node,
		"Player ref should not be the freed node instance."
	)
	prints("Tested GlobalRefs: Ignore Setting Freed Reference")
