# File: src/tests/scenes/game_world/world_manager/test_faction_loading.gd
# GUT Test Script for Faction Loading
# Version: 2.0 - Removed contacts and narrative_state (deleted in TASK_15)

extends GutTest

const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")

var indexer_instance = null
var generator_instance = null

func before_each():
	# 1. Index templates
	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)
	indexer_instance.index_all_templates()
	
	# 2. Instantiate WorldGenerator
	generator_instance = WorldGenerator.new()
	add_child_autofree(generator_instance)
	
	# 3. Clean GameState
	GameState.factions.clear()

func test_load_factions():
	assert_eq(GameState.factions.size(), 0, "Factions should be empty initially")
	
	generator_instance._load_factions()
	
	assert_gt(GameState.factions.size(), 0, "Factions should be populated")
	assert_true(GameState.factions.has("faction_miners"), "Should have faction_miners")
