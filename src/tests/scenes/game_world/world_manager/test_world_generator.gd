# Tests for WorldGenerator: new-run setup from a GameStartTemplate.

extends GutTest

const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")

const TEST_START_ID = "start_test_world_generator"

var generator_instance = null


func before_each():
	GameState.reset_state()
	generator_instance = WorldGenerator.new()
	add_child_autofree(generator_instance)


func after_each():
	TemplateDatabase.game_starts.erase(TEST_START_ID)
	GameState.reset_state()


func test_applies_game_start_template():
	var game_start = GameStartTemplate.new()
	game_start.template_id = TEST_START_ID
	game_start.player_ship_template = "ship_hostile_default"
	game_start.player_starting_location = "sector_cob"
	TemplateDatabase.game_starts[TEST_START_ID] = game_start

	generator_instance.generate_new_world(TEST_START_ID)

	assert_eq(GameState.player_ship_template_id, "ship_hostile_default")
	assert_eq(GameState.player_docked_at, "sector_cob")
	assert_eq_deep(GameState.player_storage, {})


func test_the_default_start_comes_with_a_starter_pack_of_real_parts():
	var game_start = load("res://database/registry/game_starts/start_default.tres")
	TemplateDatabase.game_starts[TEST_START_ID] = game_start
	generator_instance.generate_new_world(TEST_START_ID)
	assert_false(GameState.player_storage.empty(), "Spare parts at home")
	for part_id in GameState.player_storage:  # Registry parts (the test run indexes no registry)
		var folder: String = "tools/" if part_id.begins_with("tool_") else "assets/modules/"
		var part = load("res://database/registry/%s%s.tres" % [folder, part_id])
		assert_true(part is UtilityToolTemplate or part is ModuleTemplate, part_id + " is a part")
	GameState.player_storage["tool_rail_cannon"] = 0
	generator_instance.generate_new_world(TEST_START_ID)
	assert_eq(GameState.player_storage["tool_rail_cannon"], 1, "Each run gets its own copy")
	assert_eq(game_start.starting_storage["tool_rail_cannon"], 1)


func test_missing_game_start_falls_back_to_default_ship():
	generator_instance.generate_new_world("start_does_not_exist")
	assert_eq(GameState.player_ship_template_id, Constants.FALLBACK_SHIP_TEMPLATE_ID)
	assert_eq(GameState.player_docked_at, "")
