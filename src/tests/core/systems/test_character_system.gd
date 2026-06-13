# PROJECT: GDTLancer
# MODULE: test_character_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 01:00:09

extends GutTest

## Unit tests for CharacterSystem: wealth tier, progress, and skill management operations.

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
	player_char_instance.wealth_tier = "COMFORTABLE"
	player_char_instance.wealth_progress = 5
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = str(PLAYER_UID)

	# 4. Create and register an NPC character instance for multi-character tests
	var npc_char_instance = default_char_template.duplicate()
	npc_char_instance.character_name = "Test NPC"
	npc_char_instance.wealth_tier = "BROKE"
	npc_char_instance.wealth_progress = 2
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


func test_wealth_management():
	# Test adding wealth progress
	character_system_instance.add_wealth_progress(PLAYER_UID, 3)
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 8, "Wealth progress should be 8.")
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "COMFORTABLE", "Wealth tier should remain Comfortable.")

	# Test subtracting wealth progress
	character_system_instance.subtract_wealth_progress(PLAYER_UID, 4)
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 4, "Wealth progress should be 4.")
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "COMFORTABLE", "Wealth tier should remain Comfortable.")


func test_promotion_wrap_around():
	# Comfortable 5 + 5 = Wealthy 0
	character_system_instance.add_wealth_progress(PLAYER_UID, 5)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "WEALTHY", "Promotion to Wealthy tier.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 0, "Progress should wrap to 0.")

	# Comfortable 5 + 6 = Wealthy 1 (wrapped over)
	# Reset
	GameState.characters[PLAYER_UID].wealth_tier = "COMFORTABLE"
	GameState.characters[PLAYER_UID].wealth_progress = 5
	character_system_instance.add_wealth_progress(PLAYER_UID, 6)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "WEALTHY", "Promotion to Wealthy tier.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 1, "Progress should wrap to 1.")


func test_demotion_wrap_around():
	# Comfortable 5 - 6 = Broke 10
	character_system_instance.subtract_wealth_progress(PLAYER_UID, 6)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "BROKE", "Demotion to Broke tier.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 10, "Progress should wrap to 10 (Comfortable 0 -> Broke 10).")

	# Comfortable 5 - 7 = Broke 9
	# Reset
	GameState.characters[PLAYER_UID].wealth_tier = "COMFORTABLE"
	GameState.characters[PLAYER_UID].wealth_progress = 5
	character_system_instance.subtract_wealth_progress(PLAYER_UID, 7)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "BROKE", "Demotion to Broke tier.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 9, "Progress should wrap to 9.")


func test_wealth_clamping_at_boundaries():
	# Wealthy 10 + 5 should stay Wealthy 10
	GameState.characters[PLAYER_UID].wealth_tier = "WEALTHY"
	GameState.characters[PLAYER_UID].wealth_progress = 10
	character_system_instance.add_wealth_progress(PLAYER_UID, 5)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "WEALTHY", "Stays Wealthy.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 10, "Clamped to 10.")

	# Broke 0 - 5 should stay Broke 0
	GameState.characters[PLAYER_UID].wealth_tier = "BROKE"
	GameState.characters[PLAYER_UID].wealth_progress = 0
	character_system_instance.subtract_wealth_progress(PLAYER_UID, 5)
	assert_eq(character_system_instance.get_wealth_tier(PLAYER_UID), "BROKE", "Stays Broke.")
	assert_eq(character_system_instance.get_wealth_progress(PLAYER_UID), 0, "Clamped to 0.")


func test_skill_retrieval():
	var piloting_level = character_system_instance.get_skill_level(PLAYER_UID, "piloting")
	assert_eq(piloting_level, 2, "Default piloting skill should be 2 (from character_default.tres).")

	var non_existent_skill = character_system_instance.get_skill_level(PLAYER_UID, "basket_weaving")
	assert_eq(non_existent_skill, 0, "A non-existent skill should return 0.")


func test_apply_upkeep_cost():
	var initial_progress = character_system_instance.get_wealth_progress(PLAYER_UID)
	character_system_instance.apply_upkeep_cost(PLAYER_UID, 3)
	var final_progress = character_system_instance.get_wealth_progress(PLAYER_UID)
	assert_eq(final_progress, initial_progress - 3, "Upkeep cost should correctly subtract wealth progress.")
