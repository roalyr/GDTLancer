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
