# Content checks (CONTENT.md): every faction, sector layout, haven, archetype, model in use and the
# sound bank keep the rules in ContentValidator, so a content edit that breaks one fails here rather
# than in play. The development tool (tools/dev.py) checks saves with the same rules.

extends GutTest

const Validator = preload("res://src/core/validation/content_validator.gd")


func _texts(problems: Array) -> Array:
	var out: Array = []
	for problem in problems:
		out.append("%s: %s" % [problem.file, problem.problem])
	return out


func test_factions_are_complete():
	assert_gt(Validator.faction_files().size(), 0, "Factions load from %s" % Constants.FACTIONS_DIR)
	assert_eq(_texts(Validator.factions()), [])


func test_sector_layouts_and_havens_are_complete():
	assert_gt(Validator.layout_files().size(), 0, "Layouts load from %s" % Constants.SECTORS_SCENES_DIR)
	assert_eq(_texts(Validator.sectors()), [])


func test_archetypes_are_complete():
	assert_eq(Validator.archetype_names().size(), 15, "Fifteen archetypes")
	assert_eq(_texts(Validator.archetypes()), [])


# Every ship and station model the game flies or places keeps the model rules (ModelCheck).
func test_every_model_in_use_keeps_the_rules():
	var used: Dictionary = Validator.models_in_use()
	assert_gt(used.ships.size(), 15, "Archetypes' hulls and the xenohive's")
	assert_true(used.stations.has(Constants.STATION_DEFAULT_MODEL))
	assert_eq(_texts(Validator.models()), [])


func test_the_material_library_keeps_the_rules():
	assert_eq(_texts(Validator.materials()), [])
	assert_eq(Validator.section_for(Validator.MATERIALS_DIR.plus_file("mat_hull_glow.tres")), "materials")


func test_the_sound_bank_keeps_the_rules():
	assert_eq(_texts(Validator.sounds()), [])


func test_every_section_runs_and_files_find_their_section():
	for section in Validator.SECTIONS:
		assert_true(Validator.section(section) is Array, section)
	assert_eq(Validator.section_for(Constants.FACTIONS_DIR.plus_file("verdant.tres")), "factions")
	assert_eq(Validator.section_for(Validator.SOUND_BANK_PATH), "sounds")
	assert_eq(Validator.section_for("res://README.md"), "")
	assert_eq(Validator.for_file("res://README.md"), [], "No rules: no problems")


func test_a_broken_faction_is_caught():
	var dir_path := "user://test_validator_factions/"
	Directory.new().make_dir_recursive(dir_path)
	var faction = load(Constants.FACTIONS_DIR.plus_file("verdant.tres")).duplicate()
	faction.display_name = ""
	faction.enemies = ["nobody"]
	faction.roster = ["no_such_archetype"]
	assert_eq(ResourceSaver.save(dir_path.plus_file("broken.tres"), faction), OK)
	var texts: Array = _texts(Validator.factions(dir_path))
	var path: String = dir_path.plus_file("broken.tres")
	assert_has(texts, path + ": No name")
	assert_has(texts, path + ": Enemy 'nobody' is not a faction")
	assert_has(texts, path + ": Roster archetype 'no_such_archetype' does not exist")
	Directory.new().remove(path)
	Directory.new().remove(dir_path)


func test_game_starts_keep_the_rules():
	assert_eq(_texts(Validator.starts()), [])


func test_a_broken_game_start_is_caught():
	var start = load("res://database/registry/game_starts/start_default.tres").duplicate()
	start.starting_storage = {"tool_nothing": 1, "tool_rail_cannon": 0}
	start.player_starting_location = "nowhere"
	start.player_ship_template = "ship_nothing"
	var dir := "user://test_validator_starts/"
	Directory.new().make_dir_recursive(dir)
	ResourceSaver.save(dir + "start_broken.tres", start)
	var texts: Array = []
	for problem in Validator.starts(dir):
		texts.append(problem.problem)
	assert_has(texts, "Its kit holds 'tool_nothing', which is not a weapon, tool or module")
	assert_has(texts, "Its kit's count of 'tool_rail_cannon' should be a whole number from 1")
	assert_has(texts, "It starts at 'nowhere', which is not a haven")
	assert_has(texts, "Its ship 'ship_nothing' is not a ship template")
	Directory.new().remove(dir + "start_broken.tres")
	Directory.new().remove(dir)


func test_a_station_placed_in_a_sector_scene_is_caught():
	var text := '[ext_resource path="res://src/scenes/game_world/station/dockable_station.gd" type="Script" id=1]\n'
	text += '[ext_resource path="res://scenes/prefabs/station/faction_station.tscn" type="PackedScene" id=2]\n'
	text += '[ext_resource path="res://scenes/prefabs/celestial/asteroid.tscn" type="PackedScene" id=3]\n'
	assert_eq(Validator.stations_placed_in(text), ["res://src/scenes/game_world/station/dockable_station.gd", "res://scenes/prefabs/station/faction_station.tscn"])


func test_node_paths_are_found_in_scene_text():
	var text := '[node name="Sector" type="Spatial"]\n\n[node name="SceneAssets" type="Spatial" parent="."]\n\n[node name="Star Elace" parent="SceneAssets" instance=ExtResource( 4 )]\n'
	assert_true(Validator.has_node_path(text, "SceneAssets/Star Elace"))
	assert_true(Validator.has_node_path(text, "SceneAssets"))
	assert_false(Validator.has_node_path(text, "SceneAssets/Star Cob"))
	assert_false(Validator.has_node_path(text, "Elsewhere/Star Elace"))
