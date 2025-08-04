# File: tests/core/systems/test_asset_system.gd
# GUT Test for AssetSystem
# Version: 1.3 - Mocks the Constants autoload for stable loading

extends "res://addons/gut/test.gd"

# --- Test Subjects ---
# Declare as null. We will load them AFTER setting up the mock dependency.
var AssetSystem = null
var ShipAsset = null
var ShipAgentData = null

# --- Test State ---
var asset_system_inst
var test_ship_asset
var mock_constants # To hold our fake autoload

# This runs ONCE before any tests. It's our setup phase.
func before_all():
	# --- THE FIX: Create and inject a fake Constants node ---
	mock_constants = Node.new()
	# Add the properties that agent_template.gd needs to parse successfully.
	# The actual values don't matter, only that they exist.
	mock_constants.set("DEFAULT_MAX_MOVE_SPEED", 0.0)
	mock_constants.set("DEFAULT_ACCELERATION", 0.0)
	mock_constants.set("DEFAULT_DECELERATION", 0.0)
	mock_constants.set("DEFAULT_MAX_TURN_SPEED", 0.0)

	# Add the mock to the scene tree and give it the global name.
	get_tree().get_root().add_child(mock_constants)
	mock_constants.set_name("Constants")

	# --- Load Game Scripts ---
	# Now that "Constants" exists in the tree, these load operations will succeed.
	AssetSystem = load("res://core/systems/asset_system.gd")
	ShipAsset = load("res://core/resource/ship_asset.gd")
	ShipAgentData = load("res://core/resource/ship_agent_data.gd")

# This runs after all tests are done. It's our cleanup phase.
func after_all():
	if is_instance_valid(mock_constants):
		mock_constants.free()

func before_each():
	# This line will now work because ShipAgentData loaded correctly.
	var test_template = ShipAgentData.new()
	test_template.ship_class_name = "Test Freighter"
	test_template.base_cargo_capacity = 100
	test_template.base_hull_integrity = 150

	test_ship_asset = ShipAsset.new()
	test_ship_asset.template = test_template
	test_ship_asset.ship_name = "My Test Ship"
	test_ship_asset.current_hull_integrity = 88

	asset_system_inst = AssetSystem.new()
	add_child(asset_system_inst)
	asset_system_inst.initialize_player_ship(test_ship_asset)

func after_each():
	if is_instance_valid(asset_system_inst):
		asset_system_inst.free()


# --- Tests (Unchanged) ---

func test_initialization_successful():
	assert_not_null(asset_system_inst, "AssetSystem should be instantiated.")
	var internal_asset = asset_system_inst.get("_player_ship_asset")
	assert_eq(internal_asset.ship_name, "My Test Ship", "System should hold the correct ship asset.")

func test_get_stat_from_instance():
	var hull = asset_system_inst.get_player_ship_stat("current_hull_integrity")
	assert_eq(hull, 88, "Should return the instance-specific value for 'current_hull_integrity'.")

func test_get_stat_from_template():
	var capacity = asset_system_inst.get_player_ship_stat("cargo_capacity")
	assert_eq(capacity, 100, "Should fall back to the template and return 'base_cargo_capacity'.")
