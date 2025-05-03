# File: tests/autoload/test_game_state_manager.gd
# Version 1.2 - Modified cleanup strategy

extends GutTest

const TEST_SLOT_ID = 999
var test_save_path = ""
var _dummy_player = null
var _dummy_zone = null


# Helper to setup dummy nodes and refs needed for save_game
func setup_dummy_refs():
	cleanup_dummy_refs()  # Ensure clean slate first
	_dummy_player = KinematicBody.new()
	add_child_autofree(_dummy_player)
	_dummy_player.name = "DummyPlayer"
	_dummy_zone = Node.new()
	add_child_autofree(_dummy_zone)
	_dummy_zone.filename = "res://dummy_zone.tscn"
	_dummy_zone.name = "DummyZone"
	GlobalRefs.player_agent_body = _dummy_player
	GlobalRefs.current_zone = _dummy_zone
	assert_true(is_instance_valid(GlobalRefs.player_agent_body), "Check dummy player valid")
	assert_true(is_instance_valid(GlobalRefs.current_zone), "Check dummy zone valid")


# Helper to clear refs
func cleanup_dummy_refs():
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	# Nodes added with add_child_autofree are handled by GUT


# Helper to clean the test save file
func _cleanup_test_save():
	var file = File.new()
	if file.file_exists(test_save_path):
		var dir = Directory.new()
		var err = dir.remove(test_save_path)
		# if err != OK: printerr("Cleanup Warning: Could not remove test save: ", test_save_path)


func before_all():
	test_save_path = GameStateManager.get_save_slot_path(TEST_SLOT_ID)
	var dir = Directory.new()
	if not dir.dir_exists(GameStateManager.SAVE_DIR):
		dir.make_dir_recursive(GameStateManager.SAVE_DIR)


func before_each():
	# Clean file and refs *before* each test run ensures isolation
	_cleanup_test_save()
	cleanup_dummy_refs()


# --- REMOVED after_each ---
# func after_each():
#	_cleanup_test_save() # This was causing interference
#	cleanup_dummy_refs()

# --- Test Methods ---


func test_save_directory_exists_after_init():
	var dir = Directory.new()
	assert_true(dir.dir_exists(GameStateManager.SAVE_DIR), "Save directory check.")
	prints("Tested GSM: Save Directory Creation")


func test_get_save_slot_path_format():
	var expected_path = "user://savegames/save_" + str(TEST_SLOT_ID) + ".sav"
	assert_eq(
		GameStateManager.get_save_slot_path(TEST_SLOT_ID), expected_path, "Save path format check."
	)
	prints("Tested GSM: get_save_slot_path format")


func test_save_exists_functionality():
	assert_false(GameStateManager.save_exists(TEST_SLOT_ID), "Save should not exist initially.")
	# Create dummy file manually
	var file = File.new()
	var err = file.open(test_save_path, File.WRITE)
	assert_eq(err, OK, "Setup: Open dummy")
	if err == OK:
		file.store_string("d")
		file.close()
	assert_true(GameStateManager.save_exists(TEST_SLOT_ID), "Save should exist after creating.")
	# No cleanup needed here, before_each handles next test
	prints("Tested GSM: save_exists functionality")


func test_basic_save_game_creates_file():
	setup_dummy_refs()  # Setup required refs
	var success = GameStateManager.save_game(TEST_SLOT_ID)
	assert_true(success, "save_game should return true.")
	var file = File.new()
	assert_true(file.file_exists(test_save_path), "Save file should be created.")
	# No cleanup needed here, before_each handles next test
	prints("Tested GSM: Basic Save Creates File")


func test_basic_load_game_returns_true_for_existing_file():
	# 1. Setup and Save *within this test*
	setup_dummy_refs()
	var save_success = GameStateManager.save_game(TEST_SLOT_ID)
	assert_true(save_success, "Test Setup: save_game call needed for load.")
	# Clear refs *after* saving to ensure load doesn't rely on existing state
	cleanup_dummy_refs()

	# 2. Attempt to load the file just created in step 1
	var load_success = GameStateManager.load_game(TEST_SLOT_ID)
	# Re-add debug prints to GameStateManager.load_game if this still fails
	assert_true(load_success, "load_game should return true for file created in this test.")
	prints("Tested GSM: Basic Load Reads File")


func test_load_game_fails_for_non_existent_file():
	# before_each cleaned any old file
	assert_false(GameStateManager.save_exists(TEST_SLOT_ID), "Pre-check: File shouldn't exist.")
	var load_success = GameStateManager.load_game(TEST_SLOT_ID)
	assert_false(load_success, "load_game should return false for non-existent file.")
	prints("Tested GSM: Load Fails Non-Existent File")


func test_save_and_get_metadata():
	# Setup and save
	setup_dummy_refs()
	assert_true(GameStateManager.save_game(TEST_SLOT_ID), "Test Setup: save_game for metadata.")
	# Clear refs after save
	cleanup_dummy_refs()

	# Test metadata retrieval
	var metadata = GameStateManager.get_save_metadata(TEST_SLOT_ID)
	assert_typeof(metadata, TYPE_DICTIONARY, "Metadata type check.")
	assert_has(metadata, "save_time", "Metadata has 'save_time'.")
	assert_has(metadata, "game_version", "Metadata has 'game_version'.")
	# ... (rest of metadata value checks) ...
	assert_typeof(metadata.save_time, TYPE_INT, "Save time type check.")
	assert_gt(metadata.save_time, 0, "Save time positive check.")
	var expected_version = ProjectSettings.get_setting("application/config/version")
	if expected_version == null:
		expected_version = "0.0.1"
	assert_eq(metadata.game_version, str(expected_version), "Game version value check.")

	prints("Tested GSM: Save and Get Metadata")


func test_get_metadata_returns_empty_for_non_existent_file():
	assert_false(GameStateManager.save_exists(TEST_SLOT_ID), "Pre-check: File shouldn't exist.")
	var metadata = GameStateManager.get_save_metadata(TEST_SLOT_ID)
	assert_typeof(metadata, TYPE_DICTIONARY, "Metadata empty dict type check.")
	assert_eq(metadata.size(), 0, "Metadata should be empty for non-existent file.")
	prints("Tested GSM: Get Metadata Fails Non-Existent")
