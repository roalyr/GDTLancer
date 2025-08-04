# File: tests/core/systems/test_character_system.gd
# GUT Test Script for CharacterSystem
# Version: 1.1

extends GutTest

var CharacterSystem = load("res://core/systems/character_system.gd")
var character_system_instance = null

func before_each():
	character_system_instance = CharacterSystem.new()
	add_child_autofree(character_system_instance)
	# Assuming GlobalRefs and Constants are autoloads as per project structure
	GlobalRefs.set_character_system(character_system_instance)

func after_each():
	character_system_instance = null
	GlobalRefs.set_character_system(null)

func test_initial_state():
	var player_data = character_system_instance.get_player_character()
	assert_eq(player_data.wealth_points, 0, "Initial WP should be 0.")
	assert_eq(player_data.focus_points, 0, "Initial FP should be 0.")
	assert_eq(player_data.skills.piloting, 1, "Initial piloting skill should be 1.")
	assert_true(player_data.faction_standings.empty(), "Initial faction standings should be empty.")

func test_wp_management():
	character_system_instance.add_wp(100)
	assert_eq(character_system_instance.get_wp(), 100, "WP should be 100 after adding.")
	character_system_instance.subtract_wp(25)
	assert_eq(character_system_instance.get_wp(), 75, "WP should be 75 after subtracting.")

func test_fp_management():
	character_system_instance.add_fp(2)
	assert_eq(character_system_instance.get_fp(), 2, "FP should be 2 after adding.")
	character_system_instance.subtract_fp(1)
	assert_eq(character_system_instance.get_fp(), 1, "FP should be 1 after subtracting.")
	character_system_instance.add_fp(Constants.FOCUS_MAX_DEFAULT + 1) # Adding more than max
	assert_eq(character_system_instance.get_fp(), Constants.FOCUS_MAX_DEFAULT, "FP should be clamped to max value.")
	character_system_instance.subtract_fp(Constants.FOCUS_MAX_DEFAULT + 1) # Subtracting more than available
	assert_eq(character_system_instance.get_fp(), 0, "FP should be clamped to 0.")

func test_skill_retrieval():
	assert_eq(character_system_instance.get_skill_level("piloting"), 1, "Default piloting skill should be 1.")
	assert_eq(character_system_instance.get_skill_level("non_existent_skill"), 0, "Non-existent skill should return 0.")

func test_upkeep_cost():
	character_system_instance.add_wp(50)
	character_system_instance.apply_upkeep_cost(10)
	assert_eq(character_system_instance.get_wp(), 40, "WP should be 40 after upkeep.")

func test_save_and_load():
	# Setup initial data
	character_system_instance.add_wp(200)
	character_system_instance.add_fp(3)
	
	# Get save data
	var save_data = character_system_instance.get_player_save_data()
	
	# Create a new instance to load into
	var new_character_system = CharacterSystem.new()
	add_child_autofree(new_character_system)
	
	# Load data and verify
	new_character_system.load_player_save_data(save_data)
	assert_eq(new_character_system.get_wp(), 200, "Loaded WP should be 200.")
	assert_eq(new_character_system.get_fp(), 3, "Loaded FP should be 3.")
	assert_eq(new_character_system.get_skill_level("tactics"), 1, "Loaded tactics skill should be 1.")
