# Refits the picked archetypes (database/presets/archetypes/) to the laws as they are now: each
# pilot's genome takes the catalogue's parts (Genome.retire_parts: the catalogue's genes, a lighter
# weight where a part no longer fits the hull's slot size), and its ship the stats, slot sizes and
# fit that follow. Run after a law or catalogue change that the archetypes should follow before new
# ones are picked:
#     godot --no-window -s tools/refit_archetypes.gd
extends SceneTree

var Genome = null  # Loaded once the autoloads are in (the laws read Constants)
var ShipLaws = null
var Validator = null


func _initialize():
	call_deferred("_run")


func _run() -> void:
	Genome = load("res://src/core/evolution/genome.gd")
	ShipLaws = load("res://src/core/systems/ship_laws.gd")
	Validator = load("res://src/core/validation/content_validator.gd")
	for name in Validator.archetype_names():
		var agent_path: String = Validator._archetype_agent_path(name)
		var agent = ResourceLoader.load(agent_path, "", true)
		var ship_path: String = root.get_node("Constants").ARCHETYPES_DIR.plus_file(agent.ship_template_id + ".tres")
		var ship = ResourceLoader.load(ship_path, "", true)
		var genome: Dictionary = agent.genome.duplicate(true)
		var changed: bool = Genome.retire_parts(genome)
		agent.genome = genome
		var stats: Dictionary = ShipLaws.ship_stats(genome.ship)
		for field in stats:
			ship.set(field, stats[field])
		ship.law_genes = genome.ship.duplicate(true)
		var tools: Array = []
		var harpoon := false
		for part in genome.tools:
			var template_id: String = Genome.part_template_id(part)
			if template_id == root.get_node("Constants").HARPOON_TEMPLATE_ID:
				if harpoon:
					continue
				harpoon = true
			if template_id != "":
				tools.append(template_id)
		var modules: Array = []
		for part in genome.modules:
			if not part.empty():
				modules.append(Genome.part_template_id(part))
		ship.equipped_tools = tools
		ship.equipped_modules = modules
		ResourceSaver.save(agent_path, agent)
		ResourceSaver.save(ship_path, ship)
		print("REFIT %s%s: %s | %s (%s slots)" % [name, " (parts changed)" if changed else "", PoolStringArray(tools).join(", "),
			PoolStringArray(modules).join(", "), stats.module_slot_size])
	quit()
