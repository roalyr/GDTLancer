# Genome: what an evolving NPC is made of, as plain data (saved as is), and how it varies.
#   {"ship": ShipLaws ship genes (and "tool_share": how its slots split between hardpoints and bays,
#    ShipLaws.slot_counts; absent until it first mutates), "tools": [part per hardpoint],
#    "modules": [part per bay],
#    "behavior": {gene: value} (Constants EVO_BEHAVIOR_RANGES)}
#   part: {} (empty slot) or {"kind", "type", "genes"}; kinds "laser", "missile", "cannon", "harpoon" (tools) and
#   ShipLaws.MODULE_KINDS (modules). The harpoon has no genes: it is the registry one.
# Every stat comes from the genes through ShipLaws, so a mutant is as lawful as its parent.

extends Reference

const ShipLaws = preload("res://src/core/systems/ship_laws.gd")

const TOOL_KINDS = ["laser", "missile", "cannon", "harpoon"]
const WEAPON_KINDS = ["laser", "missile", "cannon"]


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
		genome.tools[i] = random_part(_random_weapon_kind() if i == 0 else _random_tool_kind(_harpoons_in(genome.tools, i)), slot_mass_limit(genome))
	for i in range(genome.modules.size()):
		genome.modules[i] = {} if randf() < Constants.EVO_EMPTY_SLOT_CHANCE else random_part(ShipLaws.MODULE_KINDS[randi() % ShipLaws.MODULE_KINDS.size()])
	_one_lance(genome)
	return genome


# A starting design (Constants EVO_SEEDS): hull type and size, tool and module kinds in slot order
# (a kind, or [kind, part type]; "" leaves a slot empty), behaviour genes over the defaults. Parts
# get their type's seed genes; slots past the hull's are dropped, missing ones left empty.
static func seed_genome(spec: Dictionary) -> Dictionary:
	var ship_type: int = int(spec.get("type", 2))
	var seed_genes: Dictionary = Constants.SHIP_TYPE_SEEDS[ship_type]
	var genome := {
		"ship": {"type": ship_type, "size": float(spec.get("size", seed_genes["size"])), "shares": seed_genes.shares.duplicate()},
		"tools": [],
		"modules": [],
		"behavior": default_behavior(),
	}
	if spec.has("tool_share"):
		genome.ship["tool_share"] = float(spec.tool_share)
	for gene in spec.get("behavior", {}):
		genome.behavior[gene] = float(spec.behavior[gene])
	_fit_slots(genome)
	var max_mass: float = slot_mass_limit(genome)
	for group in [["tools", spec.get("tools", [])], ["modules", spec.get("modules", [])]]:
		var parts: Array = genome[group[0]]
		for i in range(min(parts.size(), group[1].size())):
			var item = group[1][i]
			var kind: String = str(item[0]) if item is Array else str(item)
			var part_type: int = int(item[1]) if item is Array else 1
			if kind == "":
				parts[i] = {}
			elif kind == "harpoon":
				parts[i] = {"kind": "harpoon", "type": 0, "genes": {}}
			else:
				parts[i] = {"kind": kind, "type": part_type, "genes": Constants.PART_TYPE_SEEDS[kind][part_type].duplicate()}
				_clamp_part(parts[i], max_mass if group[0] == "tools" else INF)
	_one_lance(genome)
	return genome


static func default_behavior() -> Dictionary:
	var behavior := {}
	for gene in Constants.EVO_BEHAVIOR_RANGES:
		behavior[gene] = float(Constants.EVO_BEHAVIOR_RANGES[gene][2])
	return behavior


# A tool for a slot picked anew: empty (EVO_EMPTY_SLOT_CHANCE), a harpoon (EVO_HARPOON_CHANCE; a
# second one on a ship that has one already, EVO_EXTRA_HARPOON_CHANCE) or a weapon.
static func _random_tool_kind(harpoons_fitted: int = 0) -> String:
	var roll: float = randf()
	if roll < Constants.EVO_EMPTY_SLOT_CHANCE:
		return ""
	var harpoon_chance: float = Constants.EVO_HARPOON_CHANCE if harpoons_fitted == 0 else Constants.EVO_EXTRA_HARPOON_CHANCE
	return "harpoon" if roll < Constants.EVO_EMPTY_SLOT_CHANCE + harpoon_chance else _random_weapon_kind()


static func _harpoons_in(tools: Array, except: int = -1) -> int:
	var count := 0
	for i in range(tools.size()):
		if i != except and not tools[i].empty() and tools[i].kind == "harpoon":
			count += 1
	return count


# A weapon, by Constants EVO_WEAPON_ODDS.
static func _random_weapon_kind() -> String:
	var total := 0.0
	for kind in Constants.EVO_WEAPON_ODDS:
		total += float(Constants.EVO_WEAPON_ODDS[kind])
	var roll: float = randf() * total
	for kind in Constants.EVO_WEAPON_ODDS:
		roll -= float(Constants.EVO_WEAPON_ODDS[kind])
		if roll <= 0.0:
			return kind
	return "laser"


# A saved genome's parts of a retired kind (ShipLaws.RETIRED_MODULE_KINDS) become their successor,
# the same mass; true if any did.
static func retire_parts(genome: Dictionary) -> bool:
	var changed := false
	for part in genome.get("modules", []):
		if not part.empty() and ShipLaws.RETIRED_MODULE_KINDS.has(part.kind):
			part.kind = ShipLaws.RETIRED_MODULE_KINDS[part.kind]
			part.genes = ShipLaws.clamp_module_genes(part.genes, part.kind)
			changed = true
	return changed


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
			child.tools[i] = random_part(_random_tool_kind(_harpoons_in(child.tools, i)), max_mass)
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
	_one_lance(child)
	if behavior_on:
		_mutate_behavior(child, scale)
	return child


# A ship takes one lance (ShipFit): later ones are emptied.
static func _one_lance(genome: Dictionary) -> void:
	var seen := false
	for i in range(genome.modules.size()):
		if not genome.modules[i].empty() and genome.modules[i].kind == "lance":
			if seen:
				genome.modules[i] = {}
			seen = true


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
	if randf() < Constants.EVO_GENE_MUTATION_CHANCE * scale:
		var counts: Array = ShipLaws.slot_counts(float(ship["size"]))
		var share: float = float(ship.get("tool_share", float(counts[0]) / max(1, counts[0] + counts[1])))
		ship["tool_share"] = clamp(share + _gauss() * Constants.EVO_SLOT_SHARE_SIGMA * scale, 0.0, 1.0)


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


# Slot lists sized to the ship (ShipLaws.slot_counts): new slots come empty, extra ones are dropped.
static func _fit_slots(genome: Dictionary) -> void:
	var counts: Array = ShipLaws.slot_counts(float(genome.ship["size"]), float(genome.ship.get("tool_share", -1.0)))
	genome.tools = _resized(genome.tools, counts[0])
	genome.modules = _resized(genome.modules, counts[1])


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
	elif part.kind == "missile":
		part.genes = ShipLaws.clamp_missile_genes(part.genes)
		part.genes.count = round(part.genes.count)  # The rack carries whole missiles (ShipLaws.missile_stats)
		var rack_rounds: float = part.genes.count + Constants.LAW_MISSILE_RACK_ROUNDS
		if part.genes.round_mass * rack_rounds > max_mass:  # Too heavy for the hardpoint: fewer missiles, then lighter ones
			part.genes.count = max(Constants.LAW_MISSILE_COUNT_RANGE[0], floor(max_mass / part.genes.round_mass - Constants.LAW_MISSILE_RACK_ROUNDS))
			part.genes.round_mass = max(Constants.LAW_MISSILE_MASS_RANGE[0], min(part.genes.round_mass, max_mass / (part.genes.count + Constants.LAW_MISSILE_RACK_ROUNDS)))
	elif part.kind == "cannon":
		part.genes = ShipLaws.clamp_cannon_genes(part.genes)
		part.genes.count = round(part.genes.count)  # Whole rounds in the magazine (ShipLaws.cannon_stats)
		var total: float = part.genes.mass + part.genes.round_mass * part.genes.count
		if total > max_mass:  # Too heavy for the hardpoint: gun and magazine both scaled down, then lighter rounds
			var share: float = max_mass / total
			part.genes.mass = max(Constants.LAW_CANNON_MASS_RANGE[0], part.genes.mass * share)
			part.genes.count = max(Constants.LAW_CANNON_COUNT_RANGE[0], floor(part.genes.count * share))
			if part.genes.mass + part.genes.round_mass * part.genes.count > max_mass:
				part.genes.round_mass = max(Constants.LAW_CANNON_ROUND_RANGE[0], (max_mass - part.genes.mass) / part.genes.count)
	else:
		part.genes = ShipLaws.clamp_module_genes(part.genes, part.kind)


# --- Templates ---

# Id of the template a part flies as: the same genes (to the gram) share one.
static func part_template_id(part: Dictionary) -> String:
	if part.empty():
		return ""
	if part.kind == "harpoon":
		return Constants.HARPOON_TEMPLATE_ID
	var key: String = "%s_%d" % [part.kind, int(part.type)]
	for gene in ["mass", "energy", "nail_mass", "round_mass", "count"]:
		if part.genes.has(gene):
			key += "_%d" % int(round(float(part.genes[gene]) * (10.0 if gene in ["energy", "round_mass"] else 1.0)))
	return "evo_" + key


# Registers (once) the template a part flies as; returns its id.
static func ensure_part_template(part: Dictionary) -> String:
	var template_id: String = part_template_id(part)
	if template_id == "" or TemplateDatabase.get_template(template_id) != null:
		return template_id
	TemplateDatabase.register_evolved(build_part_template(part, template_id))
	return template_id


# A part's template from its genes (a laser, a missile rack or cannon, or a module).
static func build_part_template(part: Dictionary, template_id: String) -> Resource:
	if part.kind == "laser":
		return ShipLaws.build_laser_template(part.genes, int(part.type), template_id)
	if part.kind in ["missile", "cannon"]:
		return ShipLaws.build_weapon_template(part.kind, part.genes, int(part.type), template_id)
	return ShipLaws.build_module_template(part.kind, part.genes, int(part.type), template_id)


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
		elif part.kind == "missile":
			total += ShipLaws.missile_stats(part.genes).base_value
		elif part.kind == "cannon":
			total += ShipLaws.cannon_stats(part.genes).base_value
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

# The niche a genome belongs to: size class (half-octaves of size), role, laser range class. The role
# is fighter / raider (with a harpoon) / scavenger / drifter, after its weapons; missiles, cannons
# and a lance each prefix it ("missile-fighter", "lance-cannon-raider"), so a new archetype grows on
# its own branch instead of competing head-on with lasers. A lance with no other weapon: "lancer".
# A niche whose job is fighting: fighters, raiders and lancers (not scavengers, prospectors or
# drifters), judged on the exchange (Evolution.fitness_of).
static func is_combat_role(niche_name: String) -> bool:
	var role: String = niche_name.split("|")[1] if niche_name.count("|") >= 2 else niche_name
	return role.ends_with("fighter") or role.ends_with("raider") or role == "lancer"


# A niche's family, what a spawn picks first (Evolution._pick_genome, so each gets its share of lives
# whatever its fitness): "lance" (lancer, lance-*), "raider", "fighter" (guns, with or without a
# harpoon), or the role itself (prospector, scavenger, drifter, and any role a new rule adds).
static func family(niche_name: String) -> String:
	var role: String = niche_name.split("|")[1] if niche_name.count("|") >= 2 else niche_name
	if role == "lancer" or role.begins_with("lance-"):
		return "lance"
	for kind in ["raider", "fighter"]:
		if role.ends_with(kind):
			return kind
	return role


static func niche(genome: Dictionary) -> String:
	var lasers := 0
	var harpoons := 0
	var kinds := {}
	var range_sum := 0.0
	for part in genome.tools:
		if part.empty():
			continue
		kinds[part.kind] = true
		if part.kind == "laser":
			lasers += 1
			range_sum += ShipLaws.laser_stats(part.genes).optimal_range
		elif part.kind == "harpoon":
			harpoons += 1
	var armed: bool = lasers > 0 or kinds.has("missile") or kinds.has("cannon")
	var role: String = "drifter"
	if armed:
		role = "raider" if harpoons > 0 else "fighter"
	elif harpoons > 0:
		role = "scavenger"
	for kind in ["cannon", "missile"]:
		if kinds.has(kind):
			role = kind + "-" + role
	var lance := false
	for part in genome.modules:
		if not part.empty() and part.kind == "lance":
			role = "lancer" if not armed else "lance-" + role
			lance = true
			break
	if lance and lasers > 0 and harpoons > 0 and float(genome.get("behavior", {}).get("prospect", 0.0)) >= 0.5:
		role = "prospector"  # Mines (ShipControllerAI): laser, lance and harpoon, and the will to
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
	if part.kind == "missile":
		var rack: Dictionary = ShipLaws.missile_stats(part.genes)
		return "%s(%dx%.0fkg dmg%.0f %.0fm/s trn%.2f %.0fm)" % [label, rack.ammo, rack.round_mass, rack.damage, rack.projectile_speed, rack.turn_rate, rack.optimal_range]
	if part.kind == "cannon":
		var gun: Dictionary = ShipLaws.cannon_stats(part.genes)
		return "%s(%.0fkg %dx%.1fkg dmg%.1f/%.2fs %.0fm/s)" % [label, part.genes.mass, gun.ammo, gun.round_mass, gun.damage, gun.cycle_time, gun.projectile_speed]
	if part.kind == "lance":
		var lance: Dictionary = ShipLaws.lance_stats(part.genes)
		return "%s(%dx%.0fkg dmg%.0f@%.0f)" % [label, lance.count, lance.nail_mass, lance.damage, Constants.LAW_LANCE_REF_SPEED]
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
	return "PHOENIX %s s=%.2f %.0fkg hull%d thr%.0fk pwr%.0f/%.1f hold%d [st%.2f en%.2f re%.2f ca%.2f ho%.2f] tools{%s} mods{%s} beh{eng%.2f dis%.2f rng%.2f ret%.2f pur%.2f mer%.2f rf%.2f tw%.2f ca%.2f bu%.2f}" % [
		Constants.PART_TYPE_NAMES.get(int(ship.type), "?"), ship["size"], stats.mass, stats.hull_integrity, stats.linear_thrust / 1000.0,
		stats.power_capacity, stats.power_regen, stats.cargo_capacity,
		sh.structure, sh.engine, sh.reactor, sh.capacitor, sh.hold,
		PoolStringArray(tools).join(" "), PoolStringArray(modules).join(" "),
		b.get("engage", 1.0), b.get("disengage", 0.8), b.get("range", 1.0), b.get("retreat_hull", 0.0),
		b.get("pursuit", Constants.AI_PURSUIT), b.get("mercy", Constants.AI_MERCY), b.get("return_fire", Constants.AI_RETURN_FIRE),
		b.get("teamwork", 1.0), b.get("caution", Constants.AI_AVOID_SHARE), b.get("burn", Constants.AI_AFTERBURNER_RESERVE),
	]
