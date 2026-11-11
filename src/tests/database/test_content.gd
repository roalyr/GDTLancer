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
	assert_eq(Validator.archetype_names().size(), 12, "Twelve archetypes: fighter, prospector, raider, scavenger by weight (no lance family since era 67)")
	assert_eq(_texts(Validator.archetypes()), [])


# Every ship and station model the game flies or places keeps the model rules (ModelCheck).
func test_every_model_in_use_keeps_the_rules():
	var used: Dictionary = Validator.models_in_use()
	assert_gt(used.ships.size(), 12, "Archetypes' hulls and the xenohive's")
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


func test_locations_keep_the_rules():
	assert_eq(_texts(Validator.locations()), [])
	assert_eq(Validator.section_for("res://database/registry/locations/sector_elace.tres"), "locations")


func test_a_broken_sector_graph_is_caught():
	var dir := "user://test_validator_locations/"
	Directory.new().make_dir_recursive(dir)
	var a = load("res://database/registry/locations/sector_cob.tres").duplicate()
	a.template_id = "sector_a"
	a.connections = PoolStringArray(["sector_b", "sector_nowhere", "sector_a"])
	a.sector_scene_path = "res://scenes/levels/sectors/sector_a/sector_a.tscn"
	var b = a.duplicate()
	b.template_id = "sector_b"
	b.connections = PoolStringArray()
	b.sector_scene_path = ""
	ResourceSaver.save(dir + "sector_a.tres", a)
	ResourceSaver.save(dir + "sector_b.tres", b)
	var texts: Array = []
	for problem in Validator.locations(dir):
		texts.append(problem.problem)
	assert_has(texts, "It connects to 'sector_b', which does not connect back")
	assert_has(texts, "Connection 'sector_nowhere' is not a location")
	assert_has(texts, "It connects to itself")
	assert_has(texts, "Sector scene 'res://scenes/levels/sectors/sector_a/sector_a.tscn' does not exist")
	assert_eq(texts.size(), 4, "Sector b (no scene, no connections) is fine")
	for name in ["sector_a.tres", "sector_b.tres"]:
		Directory.new().remove(dir + name)
	Directory.new().remove(dir)


func test_game_starts_keep_the_rules():
	assert_eq(_texts(Validator.starts()), [])


func test_a_broken_game_start_is_caught():
	var start = load("res://database/registry/game_starts/start_default.tres").duplicate()
	start.starting_storage = {"tool_nothing": 1, "preset_cannon_medium": 0}
	start.player_starting_location = "nowhere"
	start.player_ship_template = "ship_nothing"
	var dir := "user://test_validator_starts/"
	Directory.new().make_dir_recursive(dir)
	ResourceSaver.save(dir + "start_broken.tres", start)
	var texts: Array = []
	for problem in Validator.starts(dir):
		texts.append(problem.problem)
	assert_has(texts, "Its kit holds 'tool_nothing', which is not a weapon, tool or module")
	assert_has(texts, "Its kit's count of 'preset_cannon_medium' should be a whole number from 1")
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


# SHOWN_WHEN (the dev tool hides fields that do not apply): every field it names is the script's,
# and so is every field it depends on; a list's values are among that field's choices.
func test_shown_when_rules_name_real_fields():
	var scripts := [
		"res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd",
		"res://src/scenes/game_world/sector_layout/markers/haven_marker.gd",
		"res://database/definitions/faction_template.gd",
		"res://database/definitions/asset_module_template.gd",
		"res://database/definitions/location_template.gd",
		"res://database/definitions/utility_tool_template.gd",
	]
	for path in scripts:
		var script: Script = load(path)
		var rules: Dictionary = script.get_script_constant_map().get("SHOWN_WHEN", {})
		assert_false(rules.empty(), "%s has rules" % path)
		var fields := {}
		for property in script.get_script_property_list():
			fields[property.name] = property
		for name in rules:
			assert_true(fields.has(name), "%s: SHOWN_WHEN names %s, not one of its fields" % [path, name])
			for other in rules[name]:
				assert_true(fields.has(other), "%s: %s depends on %s, not one of its fields" % [path, name, other])
				var rule = rules[name][other]
				var values: Array = rule.get("not", []) if rule is Dictionary else rule
				var choices: String = fields[other].hint_string if fields.has(other) and fields[other].hint == PROPERTY_HINT_ENUM else ""
				for value in values:
					if choices != "":
						assert_true(value in choices.split(","), "%s: %s is no choice of %s" % [path, value, other])
