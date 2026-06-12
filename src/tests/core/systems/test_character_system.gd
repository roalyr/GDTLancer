# PROJECT: GDTLancer
# MODULE: test_character_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: gameplay_milestone_audit.md
# LOG_REF: 2026-06-12 22:36:42

extends GutTest

## Unit tests for CharacterSystem: credits, FP, and skill management operations.

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
	GameState.player_character_uid = ""

	# 2. Load the base template resource
	default_char_template = load("res://database/registry/characters/character_default.tres")
	assert_true(is_instance_valid(default_char_template), "Pre-check: Default character template must load.")

	# 3. Create and register a player character instance in GameState
	var player_char_instance = default_char_template.duplicate()
	player_char_instance.credits = 100 # Start with some money for tests
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = str(PLAYER_UID)

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
	GameState.player_character_uid = ""
	character_system_instance = null # autofree handles the instance


# --- Test Cases ---

func test_get_player_character():
	var player_char = character_system_instance.get_player_character()
	assert_not_null(player_char, "Should return a valid character object for the player.")
	assert_eq(player_char, GameState.characters[PLAYER_UID], "Should return the correct player character instance from GameState.")


func test_credits_management():
	# Test adding credits
	character_system_instance.add_credits(PLAYER_UID, 50)
	assert_eq(GameState.characters[PLAYER_UID].credits, 150, "Credits should be 150 after adding 50.")

	# Test subtracting credits
	character_system_instance.subtract_credits(PLAYER_UID, 25)
	assert_eq(GameState.characters[PLAYER_UID].credits, 125, "Credits should be 125 after subtracting 25.")

	# Test getting credits
	assert_eq(character_system_instance.get_credits(PLAYER_UID), 125, "get_credits should return the correct value.")


func test_credits_clamping():
	# Start a character with 100 credits, subtract 150, assert that the remaining balance is 0 rather than -50
	GameState.characters[PLAYER_UID].credits = 100
	character_system_instance.subtract_credits(PLAYER_UID, 150)
	assert_eq(GameState.characters[PLAYER_UID].credits, 0, "Credits should be clamped to 0 on negative mutation.")


# NOTE: GDD REVISION - test_fp_management was pruned as focus points are no longer featured.


func test_skill_retrieval():
	var piloting_level = character_system_instance.get_skill_level(PLAYER_UID, "piloting")
	assert_eq(piloting_level, 2, "Default piloting skill should be 2 (from character_default.tres).")

	var non_existent_skill = character_system_instance.get_skill_level(PLAYER_UID, "basket_weaving")
	assert_eq(non_existent_skill, 0, "A non-existent skill should return 0.")


func test_apply_upkeep_cost():
	var initial_credits = character_system_instance.get_credits(PLAYER_UID)
	character_system_instance.apply_upkeep_cost(PLAYER_UID, 10)
	var final_credits = character_system_instance.get_credits(PLAYER_UID)
	assert_eq(final_credits, initial_credits - 10, "Upkeep cost should correctly subtract Credits.")
