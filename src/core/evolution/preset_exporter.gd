# PresetExporter: writes a saved evolution's best genomes as template files (tools/export_presets.gd).
# Presets are what the evolution is for, whatever the faction: the factions' pools are ranked as one.
# Each archetype (a niche's role: "lance-missile-raider", "scavenger", ...) in each weight class
# (light, medium, heavy: PRESET_WEIGHT_CLASSES) gives its fittest genome with at least `min_lives`
# lives, fittest first, `top` of them. Each becomes a
# ShipTemplate (its default fit the genome's parts, one harpoon at most), the part templates it names,
# and a faction-free AgentTemplate with the behaviour genes. Ids are stable for the same genes, so
# exporting again overwrites rather than duplicates.

extends Reference

const Genome = preload("res://src/core/evolution/genome.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const PresetClassifier = preload("res://src/core/evolution/preset_classifier.gd")


static func shrunk(entry: Dictionary) -> float:
	return float(entry.fitness_sum) / (float(entry.lives) + Constants.EVO_PRIOR_LIVES)


# "role weight": a niche's role and its hull's weight class.
static func archetype(niche: String) -> String:
	var fields: PoolStringArray = niche.split("|")
	if fields.size() < 2:
		return niche
	return "%s %s" % [fields[1], weight_class(float(fields[0].substr(1)))]


# Light, medium or heavy, from the niche's size class (log2 of the hull's size, in half steps).
static func weight_class(size_class: float) -> String:
	for weight in Constants.PRESET_WEIGHT_CLASSES:
		if size_class <= weight[1]:
			return weight[0]
	return Constants.PRESET_WEIGHT_CLASSES.back()[0]


# Returns a line per preset written.
static func export_all(evolution: Dictionary, top: int, min_lives: int, folder: String) -> Array:
	var lines: Array = []
	var genomes: Dictionary = evolution.get("genomes", {})
	var best: Dictionary = {}  # Archetype -> its fittest pick
	for faction in evolution.get("pools", {}):
		var cells: Dictionary = evolution.pools[faction].cells
		for niche in cells:
			var entry = genomes.get(cells[niche])
			if not (entry is Dictionary and int(entry.lives) >= min_lives):
				continue
			if niche.find("|drifter|") >= 0:
				continue  # Unarmed and without a harpoon: no use as a preset
			var pick := {"fitness": shrunk(entry), "niche": niche, "id": cells[niche], "entry": entry}
			var kind: String = archetype(niche)
			if not best.has(kind) or pick.fitness > best[kind].fitness:
				best[kind] = pick
	var ranked: Array = best.values()
	ranked.sort_custom(Sorter, "fitter_first")
	Directory.new().make_dir_recursive(folder)
	for i in range(min(top, ranked.size())):
		var pick: Dictionary = ranked[i]
		lines.append("#%d %s (%s) %s fit %+.2f n=%d -> %s" % [i + 1, archetype(pick.niche), pick.niche, pick.id, pick.fitness, int(pick.entry.lives),
			write_preset(pick.entry.genome, pick.id, folder, {"lives": int(pick.entry.lives), "fitness": pick.fitness})])
	if ranked.empty():
		lines.append("no niche's best has %d lives yet" % min_lives)
	return lines


# Writes one genome's files; returns the agent template's path.
# `record`: {"lives", "fitness"} of the design, kept on the agent with its classification.
static func write_preset(genome: Dictionary, genome_id: String, dir_path: String, record: Dictionary = {}) -> String:
	var tools: Array = []
	var harpoon := false
	for part in genome.tools:
		var template_id: String = _write_part(part, dir_path)
		if template_id == Constants.HARPOON_TEMPLATE_ID:
			if harpoon:
				continue  # Spare harpoons are junk genes: one is the scavenging kit
			harpoon = true
		tools.append(template_id)
	var modules: Array = []
	for part in genome.modules:
		modules.append(_write_part(part, dir_path))
	var ship_id: String = "preset_ship_%s" % genome_id.to_lower()
	var ship = ShipLaws.build_ship_template(genome.ship, ship_id, "Phoenix %s %s" % [Constants.PART_TYPE_NAMES.get(int(genome.ship.type), ""), genome_id], "")
	ship.equipped_tools = _filled(tools)
	ship.equipped_modules = _filled(modules)
	ResourceSaver.save(dir_path.plus_file(ship_id + ".tres"), ship)
	var agent = load("res://database/definitions/agent_template.gd").new()
	agent.template_id = "agent_preset_%s" % genome_id.to_lower()
	agent.agent_type = "npc"
	agent.ship_template_id = ship_id
	agent.faction = ""  # Archetypes belong to no faction; the spawner gives one
	agent.behavior = genome.get("behavior", {}).duplicate()
	var niche: String = Genome.niche(genome)
	apply_classification(agent, PresetClassifier.classify(ship, agent.behavior, niche.split("|")[1] if niche.count("|") >= 2 else ""))
	agent.lives = int(record.get("lives", 0))
	agent.fitness = float(record.get("fitness", 0.0))
	var agent_path: String = dir_path.plus_file(agent.template_id + ".tres")
	ResourceSaver.save(agent_path, agent)
	return agent_path


static func apply_classification(agent, classification: Dictionary) -> void:
	for field in classification:
		agent.set(field, classification[field])


static func _filled(ids: Array) -> Array:
	var result: Array = []
	for template_id in ids:
		if template_id != "":
			result.append(template_id)
	return result


static func _write_part(part: Dictionary, dir_path: String) -> String:
	var template_id: String = Genome.part_template_id(part)
	if template_id == "" or template_id == Constants.HARPOON_TEMPLATE_ID:
		return template_id
	template_id = template_id.replace("evo_", "preset_")
	ResourceSaver.save(dir_path.plus_file(template_id + ".tres"), Genome.build_part_template(part, template_id))
	return template_id


class Sorter:
	static func fitter_first(a: Dictionary, b: Dictionary) -> bool:
		return a.fitness > b.fitness
