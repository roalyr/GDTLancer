# File: src/tests/scenes/game_world/world_manager/test_faction_loading.gd
# GUT Test Script for Faction and Contact Loading
# Version: 1.0

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
	GameState.contacts.clear()
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"contact_relationships": {},
		"chronicle_entries": []
	}

func test_load_factions():
	assert_eq(GameState.factions.size(), 0, "Factions should be empty initially")
	
	generator_instance._load_factions()
	
	assert_gt(GameState.factions.size(), 0, "Factions should be populated")
	assert_true(GameState.factions.has("faction_miners"), "Should have faction_miners")
	
	# Verify standing
	var standing = GameState.narrative_state.faction_standings.get("faction_miners", -999)
	assert_eq(standing, 0, "Default standing for miners should be 0")

func test_load_contacts():
	assert_eq(GameState.contacts.size(), 0, "Contacts should be empty initially")
	
	generator_instance._load_contacts()
	
	assert_gt(GameState.contacts.size(), 0, "Contacts should be populated")
	assert_true(GameState.contacts.has("contact_kai"), "Should have contact_kai")
	assert_true(GameState.contacts.has("contact_vera"), "Should have contact_vera")
	
	# Verify relationship
	var kai_rel = GameState.narrative_state.contact_relationships.get("contact_kai", -999)
	assert_eq(kai_rel, 10, "Kai should start with relationship 10")
	
	var vera_rel = GameState.narrative_state.contact_relationships.get("contact_vera", -999)
	assert_eq(vera_rel, 0, "Vera should start with relationship 0")
