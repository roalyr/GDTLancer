# File: tests/core/systems/test_asset_system.gd
# GUT Test for the stateless AssetSystem.
# Version: 2.1 - Corrected dependency mocking.

extends GutTest

# --- Test Subjects ---
const AssetSystem = preload("res://core/systems/asset_system.gd")
const CharacterSystem = preload("res://core/systems/character_system.gd") # To create a double
const CharacterTemplate = preload("res://core/resource/character_template.gd")
const ShipTemplate = preload("res://core/resource/asset_ship_template.gd")

# --- Test State ---
var asset_system_instance = null
var mock_character_system = null
const PLAYER_UID = 0
const SHIP_UID = 100

func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = -1

	# 2. Create a mock CharacterSystem and stub its methods
	mock_character_system = double(CharacterSystem).new()
	add_child_autofree(mock_character_system)

	var player_char = CharacterTemplate.new()
	player_char.active_ship_uid = SHIP_UID # Link character to the ship
	stub(mock_character_system, "get_player_character").to_return(player_char)
	
	# 3. Set the mock system in GlobalRefs so AssetSystem can find it
	GlobalRefs.character_system = mock_character_system

	# 4. Create and register a mock ship asset directly in GameState
	var ship_asset = ShipTemplate.new()
	ship_asset.ship_model_name = "Test Vessel"
	GameState.assets_ships[SHIP_UID] = ship_asset

	# 5. Instantiate the system we are testing
	asset_system_instance = AssetSystem.new()
	add_child_autofree(asset_system_instance)

func after_each():
	# Clean up global state to ensure test isolation
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = -1
	GlobalRefs.character_system = null
	asset_system_instance = null

# --- Test Cases ---

func test_get_ship_by_uid():
	var ship = asset_system_instance.get_ship(SHIP_UID)
	assert_not_null(ship, "Should return a valid ship object for a valid UID.")
	assert_eq(ship.ship_model_name, "Test Vessel", "Should return the correct ship instance from GameState.")

	var non_existent_ship = asset_system_instance.get_ship(999)
	assert_null(non_existent_ship, "Should return null for a non-existent UID.")

func test_get_player_ship():
	var player_ship = asset_system_instance.get_player_ship()
	assert_not_null(player_ship, "Should find the player's active ship.")
	assert_eq(player_ship, GameState.assets_ships[SHIP_UID], "Should return the correct ship linked to the player.")

func test_get_player_ship_returns_null_if_no_player():
	stub(mock_character_system, "get_player_character").to_return(null) # Simulate no player
	var player_ship = asset_system_instance.get_player_ship()
	assert_null(player_ship, "Should return null if there is no player character.")

func test_get_player_ship_returns_null_if_no_ship_assigned():
	var player_char_no_ship = CharacterTemplate.new()
	player_char_no_ship.active_ship_uid = -1 # Simulate no assigned ship
	stub(mock_character_system, "get_player_character").to_return(player_char_no_ship)
	var player_ship = asset_system_instance.get_player_ship()
	assert_null(player_ship, "Should return null if the player has no active ship assigned.")
