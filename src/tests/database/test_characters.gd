# Characters (CharacterSheet, database/characters/): each archetype is built from one, its evolved base
# genome with hand tweaks to pilot genes, hull shares and parts; the content rules hold the sheets to
# what a genome can take and the archetype files to what their sheet makes.

extends GutTest

const Validator = preload("res://src/core/validation/content_validator.gd")
const Sheet = preload("res://database/definitions/character_sheet.gd")

const BASE = {"behavior": {"quiet": 0.1, "mercy": 0.5},
	"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.4, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.25}},
	"tools": [{"kind": "laser", "type": 2, "genes": {}}], "modules": [{"kind": "damper", "type": 1, "genes": {}}]}


func _sheet() -> Resource:
	var sheet = Sheet.new()
	sheet.template_id = "character_trader_medium"
	sheet.display_name = "Test"
	sheet.base_genome = BASE.duplicate(true)
	return sheet


func test_every_archetype_has_a_character_and_is_what_it_makes():
	for name in Validator.archetype_names():
		var path: String = Validator.character_path(name)
		assert_true(ResourceLoader.exists(path), "%s has a character" % name)
		var agent = load(Validator._archetype_agent_path(name))
		assert_true(load("res://src/core/systems/ship_laws.gd").same_value(agent.genome, load(path).built_genome()), "%s is built from it" % name)


func test_tweaks_set_genes_and_shares_over_the_base():
	var sheet = _sheet()
	assert_false(sheet.tweaked())
	sheet.genes = {"quiet": 0.8}
	sheet.shares = {"engine": 0.35}
	var genome: Dictionary = sheet.genome()
	assert_true(sheet.tweaked())
	assert_eq(genome.behavior.quiet, 0.8)
	assert_eq(genome.behavior.mercy, 0.5, "Genes not named stay the base's")
	assert_eq(genome.ship.shares.engine, 0.35)
	assert_eq(sheet.base_genome.behavior.quiet, 0.1, "The base is left as it was")
	assert_eq(sheet.archetype(), "trader_medium")


func test_parts_are_added_and_taken_off():
	var sheet = _sheet()
	sheet.add_parts = ["preset_cannon_light", "preset_afterburner_medium", "preset_harpoon"]
	sheet.remove_parts = ["preset_laser_medium"]
	var genome: Dictionary = sheet.genome()
	assert_eq_deep(genome.tools[0], {})
	assert_eq(genome.tools[1].kind, "cannon", "A weapon is a tool")
	assert_eq(genome.tools[2].kind, "harpoon")
	assert_eq(genome.modules[1].kind, "afterburner", "Anything else a module")
	assert_eq(genome.modules[1].type, 2)
	assert_eq_deep(genome.tools[1].genes, load("res://src/core/systems/part_catalog.gd").genes("cannon", 1))  # With the catalogue's genes
	assert_true(sheet.base_has("preset_damper_light"))
	assert_false(sheet.base_has("preset_damper_heavy"))


func test_a_broken_character_is_caught():
	var dir_path := "user://test_characters/"
	Directory.new().make_dir_recursive(dir_path)
	var sheet = _sheet()
	sheet.template_id = "character_x"
	sheet.display_name = ""
	sheet.genes = {"bravery": 1.0, "quiet": 5.0}
	sheet.shares = {"wings": 0.2, "engine": 0.0}
	sheet.add_parts = ["preset_banana"]
	sheet.remove_parts = ["preset_cannon_heavy"]
	var path: String = dir_path.plus_file("character_x.tres")
	assert_eq(ResourceSaver.save(path, sheet), OK)
	var texts: String = PoolStringArray(_texts(Validator.characters(dir_path))).join("\n")
	for expected in ["No name", "Gene 'bravery' is not a pilot gene", "Gene 'quiet': 5 is outside", "Share 'wings' is not a hull share",
			"Share 'engine': below its least", "add_parts: 'preset_banana' is not a catalogue part", "remove_parts: its base has no preset_cannon_heavy"]:
		assert_string_contains(texts, expected)
	Directory.new().remove(path)
	Directory.new().remove(dir_path)


func _texts(problems: Array) -> Array:
	var out: Array = []
	for problem in problems:
		out.append(problem.problem)
	return out
