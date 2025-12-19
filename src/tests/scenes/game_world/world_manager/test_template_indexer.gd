# File: tests/scenes/game_world/world_manager/test_template_indexer.gd
# GUT Test Script for the TemplateIndexer component.
# Version: 1.0

extends GutTest

const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
var indexer_instance = null

func before_each():
	# Ensure a clean slate before each test by clearing the database.
	TemplateDatabase.characters.clear()
	TemplateDatabase.assets_ships.clear()
	# ... clear other template dictionaries as they are added ...

	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)

func test_indexing_populates_template_database():
	# Pre-check: Ensure the database is empty before the test.
	assert_eq(TemplateDatabase.characters.size(), 0, "Character templates should be empty initially.")
	assert_eq(TemplateDatabase.assets_ships.size(), 0, "Ship templates should be empty initially.")

	# Run the indexing process.
	indexer_instance.index_all_templates()

	# Post-check: Assert that the database now contains data.
	assert_gt(TemplateDatabase.characters.size(), 0, "Character templates should be populated after indexing.")
	assert_gt(TemplateDatabase.assets_ships.size(), 0, "Ship templates should be populated after indexing.")

func test_indexing_loads_known_templates_correctly():
	# Run the indexing process.
	indexer_instance.index_all_templates()

	# Check for a specific, known character template.
	var default_char_id = "character_default"
	assert_has(TemplateDatabase.characters, default_char_id, "Database should contain 'character_default'.")
	var char_template = TemplateDatabase.characters[default_char_id]
	assert_true(is_instance_valid(char_template), "'character_default' should be a valid instance.")
	assert_true(char_template is CharacterTemplate, "'character_default' should be of type CharacterTemplate.")

	# Check for a specific, known ship template.
	var default_ship_id = "ship_default"
	assert_has(TemplateDatabase.assets_ships, default_ship_id, "Database should contain 'ship_default'.")
	var ship_template = TemplateDatabase.assets_ships[default_ship_id]
	assert_true(is_instance_valid(ship_template), "'ship_default' should be a valid instance.")
	assert_true(ship_template is ShipTemplate, "'ship_default' should be of type ShipTemplate.")
