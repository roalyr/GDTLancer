# PresetExporter: writes a saved evolution's best genomes as template files (tools/export_presets.gd).
# Presets are what the evolution is for, whatever the faction: the factions' pools are ranked as one.
# Each archetype (a niche's role: "missile-raider", "scavenger", ...) in each weight class
# (light, medium, heavy, superheavy: PRESET_WEIGHT_CLASSES) gives its fittest genome (ranked: the
# cautious estimate) with at least `min_lives` lives, fittest first, `top` of them. Each becomes a
# ShipTemplate (its default fit the genome's parts, one harpoon at most), the part templates it names,
# and a faction-free AgentTemplate with the behaviour genes. Ids and names are generic (design_id: the
# archetype and the genome's number, never its faction's letter), as the factions are not known yet;
# they are stable for the same genes, so exporting again overwrites rather than duplicates.

extends Reference

const Genome = preload("res://src/core/evolution/genome.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const PresetClassifier = preload("res://src/core/evolution/preset_classifier.gd")


static func shrunk(entry: Dictionary) -> float:
	return float(entry.fitness_sum) / (float(entry.lives) + Constants.EVO_PRIOR_LIVES)


# The cautious estimate genomes are ranked by (Constants EVO_RANK_SE_WEIGHT): the shrunk mean less
# its standard error, the spread of its lives taken with EVO_PRIOR_LIVES lives of EVO_PRIOR_SD. A record
# without its squares (before they were kept) counts as no spread past the prior's.
static func ranked(entry: Dictionary) -> float:
	var lives: float = float(entry.get("lives", 0))
	var total: float = float(entry.get("fitness_sum", 0.0))
	var prior: float = Constants.EVO_PRIOR_LIVES
	var spread: float = 0.0
	if lives > 0.0 and entry.has("fitness_sq"):
		spread = max(float(entry.fitness_sq) - total * total / lives, 0.0)
	var variance: float = (spread + prior * Constants.EVO_PRIOR_SD * Constants.EVO_PRIOR_SD) / (max(lives - 1.0, 0.0) + prior)
	return total / (lives + prior) - Constants.EVO_RANK_SE_WEIGHT * sqrt(variance / (lives + prior))


# "role weight": a niche's role and its hull's weight class.
static func archetype(niche: String) -> String:
	var fields: PoolStringArray = niche.split("|")
	if fields.size() < 2:
		return niche
	return "%s %s" % [fields[1], weight_class(float(fields[0].substr(1)))]


# Light, medium, heavy or superheavy, from the niche's size class (log2 of the hull's size, in half steps).
static func weight_class(size_class: float) -> String:
	for weight in Constants.PRESET_WEIGHT_CLASSES:
		if size_class <= weight[1]:
			return weight[0]
	return Constants.PRESET_WEIGHT_CLASSES.back()[0]


# A design's id: its archetype and its genome's number ("missile_raider_light_12085"), no faction.
static func design_id(genome_id: String, niche: String) -> String:
	var number: String = genome_id
	while number != "" and not number[0].is_valid_integer():
		number = number.substr(1)
	return ("%s_%s" % [archetype(niche), number]).replace("-", "_").replace(" ", "_").to_lower()


# Returns a line per preset written.
static func export_all(evolution: Dictionary, top: int, min_lives: int, folder: String) -> Array:
	var lines: Array = []
	var genomes: Dictionary = evolution.get("genomes", {})
	var baseline: Dictionary = baselines(genomes)
	var best: Dictionary = {}  # Archetype -> its fittest pick
	for faction in evolution.get("pools", {}):
		var cells: Dictionary = evolution.pools[faction].cells
		for cell in cells:
			var entry = genomes.get(cells[cell])
			if not (entry is Dictionary and int(entry.lives) >= min_lives):
				continue
			var niche: String = Genome.niche(entry.genome)  # As niches are named now (a save from before a renaming)
			if niche.find("|drifter|") >= 0:
				continue  # Unarmed and without a harpoon: no use as a preset
			# Against its own faction's family: a design is not better for flying where its faction does well
			# (era 53-57: xenohive and raider genomes won archetypes on their faction's luck)
			var own: float = float(baseline.get("%s|%s" % [faction, Genome.family(niche)], 0.0))
			var pick := {"fitness": ranked(entry) - own, "raw": ranked(entry), "niche": niche, "id": cells[cell], "entry": entry}
			var kind: String = archetype(niche)
			if not best.has(kind) or pick.fitness > best[kind].fitness:
				best[kind] = pick
	var ranked: Array = best.values()
	ranked.sort_custom(Sorter, "fitter_first")
	Directory.new().make_dir_recursive(folder)
	for i in range(min(top, ranked.size())):
		var pick: Dictionary = ranked[i]
		lines.append("#%d %s (%s) %s fit %+.2f over its faction's family (%+.2f) n=%d -> %s" % [i + 1, archetype(pick.niche), pick.niche, pick.id, pick.fitness, pick.raw, int(pick.entry.lives),
			write_preset(pick.entry.genome, pick.id, folder, {"lives": int(pick.entry.lives), "fitness": pick.fitness})])
	if ranked.empty():
		lines.append("no niche's best has %d lives yet" % min_lives)
	return lines


# Faction and family ("verdant|fighter") -> the mean fitness of all its lives: what a design is
# measured against at export.
static func baselines(genomes: Dictionary) -> Dictionary:
	var sums := {}
	var lives := {}
	for genome_id in genomes:
		var entry: Dictionary = genomes[genome_id]
		if int(entry.get("lives", 0)) <= 0 or not entry.has("genome"):
			continue
		var key: String = "%s|%s" % [str(entry.get("faction", "")), Genome.family(Genome.niche(entry.genome))]
		sums[key] = float(sums.get(key, 0.0)) + float(entry.fitness_sum)
		lives[key] = int(lives.get(key, 0)) + int(entry.lives)
	var result := {}
	for key in sums:
		result[key] = float(sums[key]) / max(lives[key], 1)
	return result


# Parts that do nothing on this design: a shell bay without a cannon, a missile bay without a
# missile rack (the exporter leaves them off; a spare harpoon likewise).
static func is_junk(part: Dictionary, genome: Dictionary) -> bool:
	if part.empty() or not part.get("kind", "") in ["magazine", "rack"]:
		return false
	var feeds: String = "cannon" if part.kind == "magazine" else "missile"
	for weapon in genome.tools:
		if not weapon.empty() and weapon.get("kind", "") == feeds:
			return false
	return true


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
		modules.append("" if is_junk(part, genome) else _write_part(part, dir_path))
	var niche: String = Genome.niche(genome)
	var design: String = design_id(genome_id, niche)
	var ship_id: String = "preset_ship_%s" % design
	var ship = ShipLaws.build_ship_template(genome.ship, ship_id, "%s %s" % [design.capitalize(), Constants.PART_MARK], "")
	ship.equipped_tools = _filled(tools)
	ship.equipped_modules = _filled(modules)
	ResourceSaver.save(dir_path.plus_file(ship_id + ".tres"), ship)
	var agent = load("res://database/definitions/agent_template.gd").new()
	agent.template_id = "agent_preset_%s" % design
	agent.agent_type = "npc"
	agent.ship_template_id = ship_id
	agent.faction = ""  # Archetypes belong to no faction; the spawner gives one
	agent.behavior = genome.get("behavior", {}).duplicate()
	agent.genome = genome.duplicate(true)  # What the game flies once picked as an archetype (tools/pick_archetypes.gd)
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


# A design's part is the catalogue's (PartCatalog): it is named, not written.
static func _write_part(part: Dictionary, _dir_path: String) -> String:
	return Genome.part_template_id(part)


class Sorter:
	static func fitter_first(a: Dictionary, b: Dictionary) -> bool:
		return a.fitness > b.fitness
