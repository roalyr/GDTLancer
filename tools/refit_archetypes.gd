# Builds the archetypes (database/presets/archetypes/) from their characters (database/characters/,
# CharacterSheet): each pilot's genome is its character's base with its tweaks, every part the
# catalogue's (CharacterSheet.built_genome), and its ship the stats, slot sizes and fit that follow
# (a bay without its weapon left off, as export does), named as its character. Its origin, lives and fitness are the base's.
# An archetype without a character keeps its own genome (the content rules flag it). Run after editing
# a character, or after a law or catalogue change (the Overview says when, f), then classify_presets:
#     godot --no-window -s tools/refit_archetypes.gd
extends SceneTree

var Genome = null  # Loaded once the autoloads are in (the laws read Constants)
var ShipLaws = null
var Validator = null
var PresetExporter = null


func _initialize():
	call_deferred("_run")


func _run() -> void:
	Genome = load("res://src/core/evolution/genome.gd")
	ShipLaws = load("res://src/core/systems/ship_laws.gd")
	Validator = load("res://src/core/validation/content_validator.gd")
	PresetExporter = load("res://src/core/evolution/preset_exporter.gd")
	var constants: Node = root.get_node("Constants")
	for name in Validator.archetype_names():
		var agent_path: String = Validator._archetype_agent_path(name)
		var agent = ResourceLoader.load(agent_path, "", true)
		var ship_path: String = constants.ARCHETYPES_DIR.plus_file(agent.ship_template_id + ".tres")
		var ship = ResourceLoader.load(ship_path, "", true)
		var genome: Dictionary
		var from := "its own genome (no character)"
		if ResourceLoader.exists(Validator.character_path(name)):
			var sheet = ResourceLoader.load(Validator.character_path(name), "", true)
			genome = sheet.built_genome()
			agent.origin = sheet.base_origin + (", tuned by hand" if sheet.tweaked() else "")
			agent.lives = sheet.base_lives
			agent.fitness = sheet.base_fitness
			from = "%s (%s)" % [sheet.display_name, sheet.base_origin]
		else:
			genome = agent.genome.duplicate(true)
			Genome.retire_parts(genome)
		agent.genome = genome
		agent.behavior = genome.get("behavior", {}).duplicate()
		var stats: Dictionary = ShipLaws.ship_stats(genome.ship)
		for field in stats:
			ship.set(field, stats[field])
		ship.law_genes = genome.ship.duplicate(true)
		var tools: Array = []
		var harpoon := false
		for part in genome.tools:
			var template_id: String = Genome.part_template_id(part)
			if template_id == constants.HARPOON_TEMPLATE_ID:
				if harpoon:
					continue
				harpoon = true
			if template_id != "":
				tools.append(template_id)
		var modules: Array = []
		for part in genome.modules:
			if not part.empty() and not PresetExporter.is_junk(part, genome):  # A bay without its weapon is left off, as export does
				modules.append(Genome.part_template_id(part))
		ship.ship_model_name = Validator.archetype_ship_name(name)  # Its character's name, in the store and on the HUD
		ship.equipped_tools = tools
		ship.equipped_modules = modules
		ResourceSaver.save(agent_path, agent)
		ResourceSaver.save(ship_path, ship)
		print("REFIT %s from %s: %s | %s (%s slots)" % [name, from, PoolStringArray(tools).join(", "), PoolStringArray(modules).join(", "), stats.module_slot_size])
	quit()
