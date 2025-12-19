# File: tests/core/systems/test_character_system.gd
# GUT Test Script for the stateless CharacterSystem.
# Version: 2.0 - Rewritten for GameState architecture.

extends GutTest

# --- Test Subjects ---
const CharacterSystem = preload("res://src/core/systems/character_system.gd")
const CharacterTemplate = preload("res://database/definitions/character_template.gd")

# --- Test State ---
var character_system_instance = null
var default_char_template: CharacterTemplate = null
const PLAYER_UID = 0
const NPC_UID = 1


# Runs before each test. Sets up a clean GameState with known characters.
func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.player_character_uid = -1

	# 2. Load the base template resource
	default_char_template = load("res://database/registry/characters/character_default.tres")
	assert_true(is_instance_valid(default_char_template), "Pre-check: Default character template must load.")

	# 3. Create and register a player character instance in GameState
	var player_char_instance = default_char_template.duplicate()
	player_char_instance.wealth_points = 100 # Start with some money for tests
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = PLAYER_UID

	# 4. Create and register an NPC character instance for multi-character tests
	var npc_char_instance = default_char_template.duplicate()
	npc_char_instance.character_name = "Test NPC"
	GameState.characters[NPC_UID] = npc_char_instance

	# 5. Instantiate the system we are testing
	character_system_instance = CharacterSystem.new()
	add_child_autofree(character_system_instance)


# Runs after each test to ensure a clean environment.
func after_each():
	GameState.characters.clear()
	GameState.player_character_uid = -1
	character_system_instance = null # autofree handles the instance


# --- Test Cases ---

func test_get_player_character():
	var player_char = character_system_instance.get_player_character()
	assert_not_null(player_char, "Should return a valid character object for the player.")
	assert_eq(player_char, GameState.characters[PLAYER_UID], "Should return the correct player character instance from GameState.")


func test_wp_management():
	# Test adding WP
	character_system_instance.add_wp(PLAYER_UID, 50)
	assert_eq(GameState.characters[PLAYER_UID].wealth_points, 150, "WP should be 150 after adding 50.")

	# Test subtracting WP
	character_system_instance.subtract_wp(PLAYER_UID, 25)
	assert_eq(GameState.characters[PLAYER_UID].wealth_points, 125, "WP should be 125 after subtracting 25.")

	# Test getting WP
	assert_eq(character_system_instance.get_wp(PLAYER_UID), 125, "get_wp should return the correct value.")


func test_fp_management():
	# Test adding FP
	character_system_instance.add_fp(PLAYER_UID, 2)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 2, "FP should be 2 after adding.")

	# Test subtracting FP
	character_system_instance.subtract_fp(PLAYER_UID, 1)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 1, "FP should be 1 after subtracting.")

	# Test clamping when adding too much
	character_system_instance.add_fp(PLAYER_UID, Constants.FOCUS_MAX_DEFAULT + 5)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, Constants.FOCUS_MAX_DEFAULT, "FP should be clamped to max value.")

	# Test clamping when subtracting too much
	character_system_instance.subtract_fp(PLAYER_UID, Constants.FOCUS_MAX_DEFAULT + 5)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 0, "FP should be clamped to 0.")


func test_skill_retrieval():
	var piloting_level = character_system_instance.get_skill_level(PLAYER_UID, "piloting")
	assert_eq(piloting_level, 2, "Default piloting skill should be 2 (from character_default.tres).")

	var non_existent_skill = character_system_instance.get_skill_level(PLAYER_UID, "basket_weaving")
	assert_eq(non_existent_skill, 0, "A non-existent skill should return 0.")


func test_apply_upkeep_cost():
	var initial_wp = character_system_instance.get_wp(PLAYER_UID)
	character_system_instance.apply_upkeep_cost(PLAYER_UID, 10)
	var final_wp = character_system_instance.get_wp(PLAYER_UID)
	assert_eq(final_wp, initial_wp - 10, "Upkeep cost should correctly subtract WP.")
