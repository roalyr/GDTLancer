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


# Top speed under linear drag is thrust / (mass * drag); hostiles stay catchable at 90% of the player's.
func test_hostile_top_speed_is_ninety_percent_of_player():
	indexer_instance.index_all_templates()
	var player_ship = TemplateDatabase.assets_ships[TemplateDatabase.game_starts["start_default"].player_ship_template]
	var hostile_ship = TemplateDatabase.assets_ships[TemplateDatabase.agents["agent_npc_hostile_default"].ship_template_id]
	var player_speed: float = player_ship.linear_thrust / player_ship.mass
	var hostile_speed: float = hostile_ship.linear_thrust / hostile_ship.mass
	assert_almost_eq(hostile_speed / player_speed, 0.9, 0.001)


# Godot silently drops .tres fields the script does not declare, so a renamed or misspelled field
# would just vanish. Every field written in a registry file must exist on its template script.
func test_registry_files_only_use_declared_fields():
	var problems: Array = []
	for path in _registry_files("res://database/registry/"):
		for field in TemplateIndexer.find_undeclared_fields(path, load(path)):
			problems.append("%s: %s" % [path, field])
	assert_eq(problems, [], "Registry fields not declared by their template script.")


func test_ship_tools_and_salvage_resolve():
	indexer_instance.index_all_templates()
	for ship_id in TemplateDatabase.assets_ships:
		var ship = TemplateDatabase.assets_ships[ship_id]
		for tool_id in ship.equipped_tools:
			assert_true(TemplateDatabase.utility_tools.get(tool_id) is UtilityToolTemplate, "%s fits unknown tool '%s'." % [ship_id, tool_id])
		for commodity_id in ship.salvage_yield:
			assert_has(TemplateDatabase.assets_commodities, commodity_id, "%s salvages unknown commodity '%s'." % [ship_id, commodity_id])


func _registry_files(path: String) -> Array:
	var files: Array = []
	var dir := Directory.new()
	if dir.open(path) != OK:
		return files
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			files += _registry_files(path.plus_file(name))
		elif name.ends_with(".tres"):
			files.append(path.plus_file(name))
		name = dir.get_next()
	return files

