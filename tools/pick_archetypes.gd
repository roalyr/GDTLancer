# Picks archetypes from a drafts folder: each archetype (database/presets/archetypes/, one per family
# and weight class) that the folder has a design for is replaced by it: the pilot as
# agent_archetype_<family>_<weight>, the ship as preset_ship_archetype_<family>_<weight> on its
# family's placeholder hull (Genome.placeholder_model), named "<Family> Mk I-<weight>", its origin the
# design it came from. Archetypes the folder has nothing for stay; no new ones are made (--add makes
# them too: a superheavy, a trader). Then run tools/classify_presets.gd for the catalog.
#     godot --no-window -s tools/pick_archetypes.gd -- --from=res://database/presets/drafts_era65_min10/ --era=65
extends SceneTree

var from_dir := ""
var era := ""
var add := false


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--from="):
			from_dir = arg.split("=")[1]
		elif arg.begins_with("--era="):
			era = arg.split("=")[1]
		elif arg == "--add":
			add = true
	call_deferred("_run")


func _run() -> void:
	var Genome = load("res://src/core/evolution/genome.gd")
	var Validator = load("res://src/core/validation/content_validator.gd")
	var archetypes_dir: String = root.get_node("Constants").ARCHETYPES_DIR
	var existing: Array = Validator.archetype_names()
	var dir := Directory.new()
	if from_dir == "" or dir.open(from_dir) != OK:
		print("ARCHETYPES no drafts folder: --from=", from_dir)
		quit(1)
		return
	dir.list_dir_begin(true, true)
	var picked := 0
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("agent_preset_") and name.ends_with(".tres"):
			var agent = ResourceLoader.load(from_dir.plus_file(name), "", true)
			var archetype: String = "%s_%s" % [agent.family, agent.weight_class]
			if archetype in existing or add:
				var ship = ResourceLoader.load(from_dir.plus_file(agent.ship_template_id + ".tres"), "", true)
				var design: String = str(agent.template_id).trim_prefix("agent_preset_")
				var ship_id: String = "preset_ship_archetype_" + archetype
				ship.template_id = ship_id
				ship.ship_model_name = "%s Mk I-%s" % [str(agent.family).capitalize(), agent.weight_class]
				ship.ship_scene = load("res://scenes/prefabs/ships/placeholders/%s.tscn" % Genome.placeholder_model(agent.family, agent.weight_class))
				agent.template_id = "agent_archetype_" + archetype
				agent.ship_template_id = ship_id
				agent.faction = ""
				agent.origin = "%s (era %s)" % [design, era] if era != "" else design
				ResourceSaver.save(archetypes_dir.plus_file(ship_id + ".tres"), ship)
				ResourceSaver.save(archetypes_dir.plus_file(agent.template_id + ".tres"), agent)
				print("ARCHETYPES %s <- %s (%d lives, %+.2f)" % [archetype, design, agent.lives, agent.fitness])
				picked += 1
		name = dir.get_next()
	print("ARCHETYPES %d picked from %s" % [picked, from_dir])
	quit(0)
