# PresetExporter: writes a saved evolution's best genomes as template files (tools/export_presets.gd).
# Per faction: the niches' best genomes with at least `min_lives` lives, fittest first, `top` of
# them. Each becomes a ShipTemplate (its default fit the genome's parts), the part templates it
# names, and an AgentTemplate with the faction and behaviour genes. Ids are stable for the same
# genes, so exporting again overwrites rather than duplicates.

extends Reference

const Genome = preload("res://src/core/evolution/genome.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")


static func shrunk(entry: Dictionary) -> float:
	return float(entry.fitness_sum) / (float(entry.lives) + Constants.EVO_PRIOR_LIVES)


# Returns a line per preset written.
static func export_all(evolution: Dictionary, top: int, min_lives: int, folder: String) -> Array:
	var lines: Array = []
	var genomes: Dictionary = evolution.get("genomes", {})
	for faction in evolution.get("pools", {}):
		var ranked: Array = []
		var cells: Dictionary = evolution.pools[faction].cells
		for niche in cells:
			var entry = genomes.get(cells[niche])
			if entry is Dictionary and int(entry.lives) >= min_lives:
				ranked.append({"fitness": shrunk(entry), "niche": niche, "id": cells[niche], "entry": entry})
		ranked.sort_custom(Sorter, "fitter_first")
		var dir_path: String = folder.plus_file(faction)
		Directory.new().make_dir_recursive(dir_path)
		for i in range(min(top, ranked.size())):
			var pick: Dictionary = ranked[i]
			lines.append("%s #%d %s %s fit %+.2f n=%d -> %s" % [faction, i + 1, pick.niche, pick.id, pick.fitness, int(pick.entry.lives),
				write_preset(pick.entry.genome, faction, pick.id, dir_path)])
		if ranked.empty():
			lines.append("%s: no niche's best has %d lives yet" % [faction, min_lives])
	return lines


# Writes one genome's files; returns the agent template's path.
static func write_preset(genome: Dictionary, faction: String, genome_id: String, dir_path: String) -> String:
	var tools: Array = []
	for part in genome.tools:
		tools.append(_write_part(part, dir_path))
	var modules: Array = []
	for part in genome.modules:
		modules.append(_write_part(part, dir_path))
	var ship_id: String = "preset_ship_%s_%s" % [faction, genome_id.to_lower()]
	var ship = ShipLaws.build_ship_template(genome.ship, ship_id, "Phoenix %s %s" % [Constants.PART_TYPE_NAMES.get(int(genome.ship.type), ""), genome_id], faction)
	ship.equipped_tools = _filled(tools)
	ship.equipped_modules = _filled(modules)
	ResourceSaver.save(dir_path.plus_file(ship_id + ".tres"), ship)
	var agent = load("res://database/definitions/agent_template.gd").new()
	agent.template_id = "agent_preset_%s_%s" % [faction, genome_id.to_lower()]
	agent.agent_type = "npc"
	agent.ship_template_id = ship_id
	agent.faction = faction
	agent.behavior = genome.get("behavior", {}).duplicate()
	var agent_path: String = dir_path.plus_file(agent.template_id + ".tres")
	ResourceSaver.save(agent_path, agent)
	return agent_path


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
	var template
	if part.kind == "laser":
		template = ShipLaws.build_laser_template(part.genes, int(part.type), template_id)
	else:
		template = ShipLaws.build_module_template(part.kind, part.genes, int(part.type), template_id)
	ResourceSaver.save(dir_path.plus_file(template_id + ".tres"), template)
	return template_id


class Sorter:
	static func fitter_first(a: Dictionary, b: Dictionary) -> bool:
		return a.fitness > b.fitness
