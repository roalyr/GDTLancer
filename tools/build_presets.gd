# Builds archetypes from their character sheets (docs/PRESETS.md), as tools/devtool/presets.py hands
# them over: archetype -> {"genome_id", "genome" (the base with the sheet's tweaks), "lives",
# "fitness", "era"}. Each is written as the exporter writes a design and placed as pick_archetypes
# places one (agent_archetype_<archetype>, preset_ship_archetype_<archetype> on its family's
# placeholder hull), its origin "<design> (era N), tuned by hand (docs/PRESETS.md)". A sheet whose genome is the
# archetype's as it is (after the catalogue's parts) leaves its files alone; one that reads as another
# family or weight class is refused. Then refit_archetypes and classify_presets (presets.py runs them).
#     godot --no-window -s tools/build_presets.gd -- --json=/path/preset_sheets.json
extends SceneTree

const SAME = 1e-4  # Genes this close are the same (the life log keeps six digits)

var json_path := ""


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--json="):
			json_path = arg.split("=", true, 1)[1]
	call_deferred("_run")


func _run() -> void:
	var Genome = load("res://src/core/evolution/genome.gd")
	var PresetExporter = load("res://src/core/evolution/preset_exporter.gd")
	var archetypes_dir: String = root.get_node("Constants").ARCHETYPES_DIR
	var f := File.new()
	if json_path == "" or f.open(json_path, File.READ) != OK:
		print("BUILD no sheets file: --json=", json_path)
		quit(1)
		return
	var parsed := JSON.parse(f.get_as_text())
	f.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		print("BUILD unreadable sheets file ", json_path)
		quit(1)
		return
	var scratch: String = "user://build_presets/"
	Directory.new().make_dir_recursive(scratch)
	var refused := 0
	for archetype in parsed.result:
		var sheet: Dictionary = parsed.result[archetype]
		var genome: Dictionary = _typed(sheet.genome)
		Genome.retire_parts(genome)
		var agent_file: String = archetypes_dir.plus_file("agent_archetype_%s.tres" % archetype)
		var existing = ResourceLoader.load(agent_file, "", true) if ResourceLoader.exists(agent_file) else null
		if existing != null and _same(existing.genome, genome):
			print("BUILD %s: as it is" % archetype)
			continue
		var agent_path: String = PresetExporter.write_preset(genome, str(sheet.genome_id), scratch, {"lives": sheet.lives, "fitness": sheet.fitness})
		var agent = ResourceLoader.load(agent_path, "", true)
		var built: String = "%s_%s" % [agent.family, agent.weight_class]
		if built != archetype:
			print("BUILD %s: refused, its genome reads as %s" % [archetype, built])
			refused += 1
			continue
		var ship = ResourceLoader.load(scratch.plus_file(agent.ship_template_id + ".tres"), "", true)
		var design: String = str(agent.template_id).trim_prefix("agent_preset_")
		var ship_id: String = "preset_ship_archetype_" + archetype
		ship.template_id = ship_id
		ship.ship_model_name = "%s Mk I-%s" % [str(agent.family).capitalize(), agent.weight_class]
		ship.ship_scene = load("res://scenes/prefabs/ships/placeholders/%s.tscn" % Genome.placeholder_model(agent.family, agent.weight_class))
		agent.template_id = "agent_archetype_" + archetype
		agent.ship_template_id = ship_id
		agent.faction = ""
		agent.origin = "%s (era %d), tuned by hand (docs/PRESETS.md)" % [design, int(sheet.get("era", 0))]
		ResourceSaver.save(archetypes_dir.plus_file(ship_id + ".tres"), ship)
		ResourceSaver.save(agent_file, agent)
		print("BUILD %s <- %s: %s; %s" % [archetype, design, agent.temperament, PoolStringArray(agent.traits).join(", ")])
	_clear(scratch)
	quit(1 if refused > 0 else 0)


# JSON's numbers are all floats: a genome's types and counts are whole.
static func _typed(genome: Dictionary) -> Dictionary:
	var out: Dictionary = genome.duplicate(true)
	out.ship.type = int(out.ship.get("type", 1))
	for part in out.get("tools", []) + out.get("modules", []):
		if part.has("type"):
			part.type = int(part.type)
		if part.get("genes", {}).has("count"):
			part.genes.count = int(part.genes.count)
	return out


# Two genomes alike to SAME (numbers), key for key and part for part.
static func _same(a, b) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_REAL] and typeof(b) in [TYPE_INT, TYPE_REAL]:
		return abs(float(a) - float(b)) <= SAME * max(1.0, abs(float(a)))
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


static func _clear(folder: String) -> void:
	var dir := Directory.new()
	if dir.open(folder) != OK:
		return
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		dir.remove(folder.plus_file(name))
		name = dir.get_next()
	Directory.new().remove(folder)
