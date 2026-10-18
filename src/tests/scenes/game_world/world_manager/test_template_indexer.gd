# Tests for TemplateIndexer: registry scan into TemplateDatabase.

extends GutTest

const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const CATEGORIES = ["agents", "assets_ships", "assets_modules", "assets_commodities", "locations", "utility_tools", "game_starts"]

var indexer_instance = null
var _saved_categories: Dictionary = {}


func before_each():
	# Swap in empty categories so the scan is observable, then restore them afterwards.
	for category in CATEGORIES:
		_saved_categories[category] = TemplateDatabase.get(category)
		TemplateDatabase.set(category, {})
	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)


func after_each():
	for category in CATEGORIES:
		TemplateDatabase.set(category, _saved_categories[category])


func test_indexing_populates_every_category():
	indexer_instance.index_all_templates()
	for category in CATEGORIES:
		assert_gt(TemplateDatabase.get(category).size(), 0, "%s should be populated after indexing." % category)


func test_indexing_loads_known_templates_with_correct_types():
	indexer_instance.index_all_templates()

	assert_true(TemplateDatabase.assets_ships.get("ship_default") is ShipTemplate, "'ship_default' should be a ShipTemplate.")
	assert_true(TemplateDatabase.locations.get(Constants.INITIAL_SECTOR_ID) is LocationTemplate, "Initial sector should be a LocationTemplate.")
	assert_true(TemplateDatabase.game_starts.get("start_default") is GameStartTemplate, "'start_default' should be a GameStartTemplate.")
	assert_true(TemplateDatabase.agents.get("agent_npc_hostile_default") is AgentTemplate, "Hostile NPC should be an AgentTemplate.")


func test_agent_ship_references_resolve():
	indexer_instance.index_all_templates()
	for agent_id in TemplateDatabase.agents:
		var ship_id: String = TemplateDatabase.agents[agent_id].ship_template_id
		if ship_id != "":
			assert_has(TemplateDatabase.assets_ships, ship_id, "%s flies unknown ship '%s'." % [agent_id, ship_id])
	assert_has(TemplateDatabase.assets_ships, TemplateDatabase.game_starts["start_default"].player_ship_template)


func test_sector_connections_resolve():
	indexer_instance.index_all_templates()
	for sector_id in TemplateDatabase.locations:
		for target_sector_id in TemplateDatabase.get_sector_connections(sector_id):
			assert_true(TemplateDatabase.has_sector(target_sector_id), "%s connects to unknown sector '%s'." % [sector_id, target_sector_id])
