# File: tests/scenes/game_world/world_manager/test_world_generator.gd
# GUT Test Script for the WorldGenerator component.
# Version: 1.0

extends GutTest

const TemplateIndexer = preload("res://scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://scenes/game_world/world_manager/world_generator.gd")

var indexer_instance = null
var generator_instance = null

func before_each():
	# The generator depends on the indexer having run first.
	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)
	indexer_instance.index_all_templates()

	generator_instance = WorldGenerator.new()
	add_child_autofree(generator_instance)

	# Ensure a clean GameState for every test.
	GameState.characters.clear()
	GameState.player_character_uid = -1

func test_generates_characters_in_game_state():
	# Pre-check: GameState should be empty.
	assert_eq(GameState.characters.size(), 0, "GameState.characters should be empty before generation.")

	# Run the world generation.
	generator_instance.generate_new_world()

	# Post-check: GameState should now be populated.
	assert_gt(GameState.characters.size(), 0, "GameState.characters should be populated after generation.")
	# It should create one instance for each template found.
	assert_eq(GameState.characters.size(), TemplateDatabase.characters.size(), "Should create one character instance per template.")

func test_assigns_player_character_uid():
	# Pre-check: Player UID should be invalid.
	assert_eq(GameState.player_character_uid, -1, "Player UID should be -1 before generation.")

	# Run the world generation.
	generator_instance.generate_new_world()

	# Post-check: A valid player UID should be set.
	assert_ne(GameState.player_character_uid, -1, "A valid player UID should be set after generation.")
	assert_has(GameState.characters, GameState.player_character_uid, "The player UID must exist as a key in the characters dictionary.")

	# Verify the correct character was assigned as the player.
	var player_char_instance = GameState.characters[GameState.player_character_uid]
	assert_eq(player_char_instance.template_id, "character_default", "The player character should have the 'character_default' template_id.")
