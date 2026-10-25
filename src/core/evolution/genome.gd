# Genome: what an arena NPC is made of, as plain data (saved as is), and how it varies.
#   {"ship": ShipLaws ship genes, "tools": [part per hardpoint], "modules": [part per bay],
#    "behavior": {gene: value} (Constants EVO_BEHAVIOR_RANGES)}
#   part: {} (empty slot) or {"kind", "type", "genes"}; kinds "laser", "harpoon" (tools) and
#   ShipLaws.MODULE_KINDS (modules). The harpoon has no genes: it is the registry one.
# Every stat comes from the genes through ShipLaws, so a mutant is as lawful as its parent.

extends Reference

const ShipLaws = preload("res://src/core/systems/ship_laws.gd")

const TOOL_KINDS = ["laser", "harpoon"]


# --- Making genomes ---

static func random_genome() -> Dictionary:
	var ship_type: int = 1 + randi() % 3
	var seed_genes: Dictionary = Constants.SHIP_TYPE_SEEDS[ship_type]
	var genome := {
		"ship": {"type": ship_type, "size": float(seed_genes["size"]), "shares": seed_genes.shares.duplicate()},
		"tools": [],
		"modules": [],
		"behavior": default_behavior(),
	}
	_mutate_ship(genome.ship, 3.0)
	_fit_slots(genome)
	for i in range(genome.tools.size()):
		genome.tools[i] = random_part("laser" if i == 0 else _random_tool_kind(), slot_mass_limit(genome))
	for i in range(genome.modules.size()):
		genome.modules[i] = {} if randf() < Constants.EVO_EMPTY_SLOT_CHANCE else random_part(ShipLaws.MODULE_KINDS[randi() % ShipLaws.MODULE_KINDS.size()])
	return genome


static func default_behavior() -> Dictionary:
	var behavior := {}
	for gene in Constants.EVO_BEHAVIOR_RANGES:
		behavior[gene] = float(Constants.EVO_BEHAVIOR_RANGES[gene][2])
	return behavior


static func _random_tool_kind() -> String:
	var roll: float = randf()
	if roll < Constants.EVO_EMPTY_SLOT_CHANCE:
		return ""
	return "harpoon" if roll < 0.5 else "laser"


# A part of `kind` ("" for an empty slot) of a random type, from that type's seed genes, varied.
static func random_part(kind: String, max_mass: float = INF) -> Dictionary:
	if kind == "":
		return {}
	if kind == "harpoon":
		return {"kind": "harpoon", "type": 0, "genes": {}}
	var part_type: int = 1 + randi() % 3
	var part := {"kind": kind, "type": part_type, "genes": Constants.PART_TYPE_SEEDS[kind][part_type].duplicate()}
	_mutate_genes(part.genes, 1.0)
	_clamp_part(part, max_mass)
	return part


# --- Mutation ---

# A mutant copy. Behaviour genes vary only with `behavior_on` (they start once the hardware has
# settled a little: Constants EVO_BEHAVIOR_START_LIVES).
static func mutate(genome: Dictionary, behavior_on: bool) -> Dictionary:
	var child: Dictionary = genome.duplicate(true)
	var scale: float = 5.0 if randf() < Constants.EVO_MACRO_MUTATION_CHANCE else 1.0
	_mutate_ship(child.ship, scale)
	_fit_slots(child)
	var max_mass: float = slot_mass_limit(child)
	for i in range(child.tools.size()):
		if randf() < Constants.EVO_PART_SWAP_CHANCE * scale:
			child.tools[i] = random_part(_random_tool_kind(), max_mass)
		elif not child.tools[i].empty():
			_mutate_genes(child.tools[i].genes, scale)
		_clamp_part(child.tools[i], max_mass)
	for i in range(child.modules.size()):
		if randf() < Constants.EVO_PART_SWAP_CHANCE * scale:
			var kind: String = "" if randf() < Constants.EVO_EMPTY_SLOT_CHANCE else ShipLaws.MODULE_KINDS[randi() % ShipLaws.MODULE_KINDS.size()]
			child.modules[i] = random_part(kind)
		elif not child.modules[i].empty():
			_mutate_genes(child.modules[i].genes, scale)
		_clamp_part(child.modules[i])
	if behavior_on:
		_mutate_behavior(child, scale)
	return child


static func _step(scale: float) -> float:
	return exp(_gauss() * Constants.EVO_MUTATION_SIGMA * scale)


static func _gauss() -> float:
	return sqrt(-2.0 * log(max(randf(), 1e-9))) * cos(TAU * randf())


static func _mutate_ship(ship: Dictionary, scale: float) -> void:
	if randf() < Constants.EVO_GENE_MUTATION_CHANCE * scale:
		ship["size"] = ShipLaws.clamp_size(float(ship["size"]) * _step(scale))
	for key in ShipLaws.SHARE_KEYS:
		if randf() < Constants.EVO_GENE_MUTATION_CHANCE * scale:
			ship.shares[key] = max(0.001, float(ship.shares.get(key, Constants.LAW_SHIP_SHARES[key])) * _step(scale))
	ship.shares = ShipLaws.normalized_shares(ship.shares)


static func _mutate_genes(genes: Dictionary, scale: float) -> void:
	for gene in genes:
		if randf() < Constants.EVO_GENE_MUTATION_CHANCE * scale:
			genes[gene] = float(genes[gene]) * _step(scale)


static func _mutate_behavior(genome: Dictionary, scale: float) -> void:
	if not genome.has("behavior"):
		genome.behavior = default_behavior()
	for gene in Constants.EVO_BEHAVIOR_RANGES:
		if randf() >= Constants.EVO_GENE_MUTATION_CHANCE * scale:
			continue
		var bounds: Array = Constants.EVO_BEHAVIOR_RANGES[gene]
		var span: float = float(bounds[1]) - float(bounds[0])
		var value: float = float(genome.behavior.get(gene, bounds[2])) + _gauss() * Constants.EVO_MUTATION_SIGMA * scale * span
		genome.behavior[gene] = clamp(value, float(bounds[0]), float(bounds[1]))
	genome.behavior.disengage = min(genome.behavior.disengage, genome.behavior.engage * 0.95)  # Never fights on past what it would start


# Slot lists sized to the ship (ShipLaws): new slots come empty, extra ones are dropped.
static func _fit_slots(genome: Dictionary) -> void:
	var size: float = float(genome.ship["size"])
	genome.tools = _resized(genome.tools, ShipLaws.tool_slot_count(size))
	genome.modules = _resized(genome.modules, ShipLaws.module_slot_count(size))


static func _resized(parts: Array, count: int) -> Array:
	var result: Array = parts.slice(0, count - 1) if count > 0 and not parts.empty() else []
	while result.size() < count:
		result.append({})
	return result


# Heaviest laser the ship's hardpoints take (a laser's mount size follows its mass).
static func slot_mass_limit(genome: Dictionary) -> float:
	match ShipLaws.slot_size_for(float(genome.ship["size"])):
		"small":
			return Constants.LAW_LASER_MEDIUM_MASS - 1.0
		"medium":
			return Constants.LAW_LASER_LARGE_MASS - 1.0
	return INF


static func _clamp_part(part: Dictionary, max_mass: float = INF) -> void:
	if part.empty() or part.kind == "harpoon":
		return
	if part.kind == "laser":
		part.genes = ShipLaws.clamp_laser_genes(part.genes)
		part.genes.mass = min(part.genes.mass, max_mass)
	else:
		part.genes = ShipLaws.clamp_module_genes(part.genes)


# --- Templates ---

# Id of the template a part flies as: the same genes (to the gram) share one.
static func part_template_id(part: Dictionary) -> String:
	if part.empty():
		return ""
	if part.kind == "harpoon":
		return Constants.HARPOON_TEMPLATE_ID
	var key: String = "%s_%d" % [part.kind, int(part.type)]
	for gene in ["mass", "energy"]:
		if part.genes.has(gene):
			key += "_%d" % int(round(float(part.genes[gene]) * (10.0 if gene == "energy" else 1.0)))
	return "evo_" + key


# Registers (once) the template a part flies as; returns its id.
static func ensure_part_template(part: Dictionary) -> String:
	var template_id: String = part_template_id(part)
	if template_id == "" or TemplateDatabase.get_template(template_id) != null:
		return template_id
	if part.kind == "laser":
		TemplateDatabase.register_evolved(ShipLaws.build_laser_template(part.genes, int(part.type), template_id))
	else:
		TemplateDatabase.register_evolved(ShipLaws.build_module_template(part.kind, part.genes, int(part.type), template_id))
	return template_id


# Registers the ship and parts of a genome; returns {"ship_template_id", "fit"} (ShipFit fit).
static func build(genome: Dictionary, genome_id: String, faction: String) -> Dictionary:
	var ship_id: String = "evo_ship_%s" % genome_id
	if not TemplateDatabase.evolved.has(ship_id):
		var name: String = "Phoenix %s %s" % [Constants.PART_TYPE_NAMES.get(int(genome.ship.type), ""), genome_id]  # The genome shows on the HUD
		TemplateDatabase.register_evolved(ShipLaws.build_ship_template(genome.ship, ship_id, name, faction))
	var fit := {"tools": [], "modules": []}
	for part in genome.tools:
		fit.tools.append(ensure_part_template(part))
	for part in genome.modules:
		fit.modules.append(ensure_part_template(part))
	return {"ship_template_id": ship_id, "fit": fit}


# What the ship and its parts are worth (WP): the denominator of fitness.
static func cost(genome: Dictionary) -> float:
	var total: float = ShipLaws.ship_stats(genome.ship).base_value
	for part in genome.tools + genome.modules:
		if part.empty():
			continue
		if part.kind == "laser":
			total += ShipLaws.laser_stats(part.genes).base_value
		elif part.kind == "harpoon":
			var harpoon = TemplateDatabase.get_template(Constants.HARPOON_TEMPLATE_ID)
			total += harpoon.base_value if harpoon != null else 80
		else:
			total += ShipLaws.module_stats(part.kind, part.genes).base_value
	return max(total, 1.0)


# What the bare ship is worth (WP): repairs are priced from it.
static func hull_value(genome: Dictionary) -> float:
	return float(ShipLaws.ship_stats(genome.ship).base_value)


# --- Niches and descriptions ---

# The niche a genome belongs to: size class (half-octaves of size), role, laser range class.
static func niche(genome: Dictionary) -> String:
	var lasers := 0
	var harpoons := 0
	var range_sum := 0.0
	for part in genome.tools:
		if part.empty():
			continue
		if part.kind == "laser":
			lasers += 1
			range_sum += ShipLaws.laser_stats(part.genes).optimal_range
		elif part.kind == "harpoon":
			harpoons += 1
	var role: String = "drifter"
	if lasers > 0:
		role = "raider" if harpoons > 0 else "fighter"
	elif harpoons > 0:
		role = "scavenger"
	var range_class: String = "-"
	if lasers > 0:
		var mean_range: float = range_sum / lasers
		range_class = "short" if mean_range < 800.0 else ("mid" if mean_range < 1400.0 else "long")
	var size_class: float = round(log(float(genome.ship["size"])) / log(2.0) * 2.0) / 2.0
	if abs(size_class) < 0.01:
		size_class = 0.0  # Not "-0.0"
	return "s%+.1f|%s|%s" % [size_class, role, range_class]


static func describe_part(part: Dictionary) -> String:
	if part.empty():
		return "-"
	if part.kind == "harpoon":
		return "HARPOON"
	var label: String = "%s %s" % [part.kind.to_upper(), Constants.PART_TYPE_NAMES.get(int(part.type), "?")]
	if part.kind == "laser":
		var stats: Dictionary = ShipLaws.laser_stats(part.genes)
		return "%s(%.0fkg %.1fE dmg%.1f/%.2fs %.0fm trk%.2f)" % [label, part.genes.mass, part.genes.energy, stats.damage, stats.cycle_time, stats.optimal_range, stats.tracking]
	return "%s(%.0fkg)" % [label, part.genes.mass]


# One line: ship, mass split, parts and behaviour.
static func describe(genome: Dictionary) -> String:
	var ship: Dictionary = genome.ship
	var stats: Dictionary = ShipLaws.ship_stats(ship)
	var sh: Dictionary = ShipLaws.normalized_shares(ship.shares)
	var tools: Array = []
	for part in genome.tools:
		tools.append(describe_part(part))
	var modules: Array = []
	for part in genome.modules:
		modules.append(describe_part(part))
	var b: Dictionary = genome.get("behavior", default_behavior())
	return "PHOENIX %s s=%.2f %.0fkg hull%d thr%.0fk pwr%.0f/%.1f hold%d [st%.2f en%.2f re%.2f ca%.2f ho%.2f] tools{%s} mods{%s} beh{eng%.2f dis%.2f rng%.2f ret%.2f}" % [
		Constants.PART_TYPE_NAMES.get(int(ship.type), "?"), ship["size"], stats.mass, stats.hull_integrity, stats.linear_thrust / 1000.0,
		stats.power_capacity, stats.power_regen, stats.cargo_capacity,
		sh.structure, sh.engine, sh.reactor, sh.capacitor, sh.hold,
		PoolStringArray(tools).join(" "), PoolStringArray(modules).join(" "),
		b.get("engage", 1.0), b.get("disengage", 0.8), b.get("range", 1.0), b.get("retreat_hull", 0.0),
	]
