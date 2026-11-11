# Genome: what an evolving NPC is made of, as plain data (saved as is), and how it varies.
#   {"ship": ShipLaws ship genes (and "tool_share": how its slots split between hardpoints and bays,
#    ShipLaws.slot_counts; absent until it first mutates), "tools": [part per hardpoint],
#    "modules": [part per bay],
#    "behavior": {gene: value} (Constants EVO_BEHAVIOR_RANGES)}
#   part: {} (empty slot) or {"kind", "type", "genes"}; kinds "laser", "missile", "cannon", "harpoon" (tools) and
#   ShipLaws.MODULE_KINDS (modules), types 1-3 (light, medium, heavy). A part is the catalogue's
#   (PartCatalog): its genes are always that part's, so evolution picks parts (kind and weight) but
#   never makes new ones. The harpoon has no genes: there is one.
# Every stat comes from the genes through ShipLaws, so a mutant is as lawful as its parent.

extends Reference

const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const PartCatalog = preload("res://src/core/systems/part_catalog.gd")

const TOOL_KINDS = ["laser", "missile", "cannon", "harpoon"]
const WEAPON_KINDS = ["laser", "missile", "cannon"]
const SLOT_SIZES = ["small", "medium", "large"]


# --- Making genomes ---

static func random_genome() -> Dictionary:
	var ship_type: int = 1 + randi() % Constants.SHIP_TYPE_SEEDS.size()
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
		genome.tools[i] = random_part(_random_weapon_kind() if i == 0 else _random_tool_kind(_harpoons_in(genome.tools, i)), slot_size(genome))
	for i in range(genome.modules.size()):
		genome.modules[i] = {} if randf() < Constants.EVO_EMPTY_SLOT_CHANCE else random_part(ShipLaws.MODULE_KINDS[randi() % ShipLaws.MODULE_KINDS.size()], slot_size(genome))
	return genome


# A starting design (Constants EVO_SEEDS): hull type and size, tool and module kinds in slot order
# (a kind, or [kind, part type]; "" leaves a slot empty), behaviour genes over the defaults. Parts
# are the catalogue's (a lighter one where the hardpoint is too small); slots past the hull's are
# dropped, missing ones left empty.
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
	if spec.has("shares"):  # A seed's own hull proportions (a trader's big hold)
		genome.ship.shares = spec.shares.duplicate()
	for gene in spec.get("behavior", {}):
		genome.behavior[gene] = float(spec.behavior[gene])
	_fit_slots(genome)
	var slot: String = slot_size(genome)
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
				parts[i] = _fitted({"kind": kind, "type": part_type, "genes": {}}, slot)
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


# A saved genome's parts made the catalogue's: a retired kind (ShipLaws.RETIRED_MODULE_KINDS) becomes
# its successor, and every part takes its catalogue genes (an older era's own genes, evolved, give
# way to the part of that kind and weight; a lighter one where the hardpoint is too small). True if
# anything changed.
static func retire_parts(genome: Dictionary) -> bool:
	var changed := false
	for part in genome.get("modules", []):
		if not part.empty() and ShipLaws.RETIRED_MODULE_KINDS.has(part.kind):
			part.kind = ShipLaws.RETIRED_MODULE_KINDS[part.kind]
			changed = true
	if not genome.has("ship"):
		return changed
	var slot: String = slot_size(genome)
	for group in ["tools", "modules"]:
		var parts: Array = genome.get(group, [])
		for i in range(parts.size()):
			var fitted: Dictionary = _fitted(parts[i], slot)
			if fitted.hash() != parts[i].hash():
				parts[i] = fitted
				changed = true
	return changed


# The catalogue's part of `kind` ("" for an empty slot) of a random weight that fits the slot.
static func random_part(kind: String, slot: String = "large") -> Dictionary:
	if kind == "":
		return {}
	if kind == "harpoon":
		return {"kind": "harpoon", "type": 0, "genes": {}}
	return _fitted({"kind": kind, "type": 1 + randi() % 3, "genes": {}}, slot)


# `part` as the catalogue has it: its kind and weight, the catalogue's genes; the next lighter weight
# where it is too big for the slot (`slot`: "small", "medium" or "large"; PartCatalog.mount_size);
# {} if even the light one is.
static func _fitted(part: Dictionary, slot: String = "large") -> Dictionary:
	if part.empty():
		return {}
	if part.kind == "harpoon":
		return {"kind": "harpoon", "type": 0, "genes": {}}
	var part_type: int = int(clamp(int(part.get("type", 1)), 1, 3))
	while part_type >= 1:
		var genes: Dictionary = PartCatalog.genes(part.kind, part_type)
		if not genes.empty() and SLOT_SIZES.find(PartCatalog.mount_size(part.kind, part_type, genes)) <= SLOT_SIZES.find(slot):
			return {"kind": part.kind, "type": part_type, "genes": genes}
		part_type -= 1
	return {}


# A heavier or lighter part of the same kind, now and then (EVO_GENE_MUTATION_CHANCE): the part's
# own genes never vary, its weight does.
static func _mutate_weight(part: Dictionary, scale: float, slot: String) -> Dictionary:
	if part.empty() or part.kind == "harpoon" or randf() >= Constants.EVO_GENE_MUTATION_CHANCE * scale:
		return _fitted(part, slot)
	var part_type: int = int(clamp(int(part.type) + (1 if randf() < 0.5 else -1), 1, 3))
	return _fitted({"kind": part.kind, "type": part_type, "genes": {}}, slot)


# --- Mutation ---

# A mutant copy. Behaviour genes vary only with `behavior_on` (they start once the hardware has
# settled a little: Constants EVO_BEHAVIOR_START_LIVES).
static func mutate(genome: Dictionary, behavior_on: bool) -> Dictionary:
	var child: Dictionary = genome.duplicate(true)
	var scale: float = 5.0 if randf() < Constants.EVO_MACRO_MUTATION_CHANCE else 1.0
	_mutate_ship(child.ship, scale)
	_fit_slots(child)
	var slot: String = slot_size(child)
	for i in range(child.tools.size()):
		if randf() < Constants.EVO_PART_SWAP_CHANCE * scale:
			child.tools[i] = random_part(_random_tool_kind(_harpoons_in(child.tools, i)), slot)
		else:
			child.tools[i] = _mutate_weight(child.tools[i], scale, slot)
	for i in range(child.modules.size()):
		if randf() < Constants.EVO_PART_SWAP_CHANCE * scale:
			var kind: String = "" if randf() < Constants.EVO_EMPTY_SLOT_CHANCE else ShipLaws.MODULE_KINDS[randi() % ShipLaws.MODULE_KINDS.size()]
			child.modules[i] = random_part(kind, slot)
		else:
			child.modules[i] = _mutate_weight(child.modules[i], scale, slot)
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
	if randf() < Constants.EVO_GENE_MUTATION_CHANCE * scale:
		var counts: Array = ShipLaws.slot_counts(float(ship["size"]))
		var share: float = float(ship.get("tool_share", float(counts[0]) / max(1, counts[0] + counts[1])))
		ship["tool_share"] = clamp(share + _gauss() * Constants.EVO_SLOT_SHARE_SIGMA * scale, 0.0, 1.0)


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


# The size of the ship's hardpoints and bays (ShipLaws.slot_size_for): parts of that size or smaller fit.
static func slot_size(genome: Dictionary) -> String:
	return ShipLaws.slot_size_for(float(genome.ship["size"]))


# --- Templates ---

# Id of the template a part flies as: the catalogue's part of its kind and weight.
static func part_template_id(part: Dictionary) -> String:
	if part.empty():
		return ""
	return PartCatalog.id(part.kind, int(part.type))


# The catalogue part a part flies as (registered from its file if the presets are not indexed, as in
# tests); returns its id.
static func ensure_part_template(part: Dictionary) -> String:
	var template_id: String = part_template_id(part)
	if template_id == "" or TemplateDatabase.get_template(template_id) != null:
		return template_id
	var found = PartCatalog.template(part.kind, int(part.type))
	TemplateDatabase.register_evolved(found if found != null else build_part_template(part, template_id))
	return template_id


# A part's template from its genes (a laser, a missile rack or cannon, or a module).
static func build_part_template(part: Dictionary, template_id: String) -> Resource:
	if part.kind == "laser":
		return ShipLaws.build_laser_template(part.genes, int(part.type), template_id)
	if part.kind in ["missile", "cannon"]:
		return ShipLaws.build_weapon_template(part.kind, part.genes, int(part.type), template_id)
	return ShipLaws.build_module_template(part.kind, part.genes, int(part.type), template_id)


# Registers the ship and parts of a genome; returns {"ship_template_id", "fit"} (ShipFit fit).
# Play (Evolution.frozen) flies an archetype as its preset says (preset_build). Evolution builds the
# ship from the genes, on the placeholder hull of its family and weight class, whatever its faction.
static func build(genome: Dictionary, genome_id: String, faction: String) -> Dictionary:
	var model: String = str(genome.get("model", ""))  # An archetype ("fighter_light")
	if Evolution.frozen and model != "":
		var preset: Dictionary = preset_build(model, faction)
		if not preset.empty():
			return preset
	var ship_id: String = "evo_ship_%s" % genome_id
	if not TemplateDatabase.evolved.has(ship_id):
		var name: String = "%s %s" % [Constants.PART_MARK, genome_id]  # The genome shows on the HUD
		var ship = ShipLaws.build_ship_template(genome.ship, ship_id, name, faction)
		if model == "":
			model = placeholder_model(family(niche(genome)), load("res://src/core/evolution/preset_classifier.gd").ship_weight(ship))
		ship.ship_scene = load(Constants.PLACEHOLDER_HULLS_DIR.plus_file(model + ".tscn"))
		TemplateDatabase.register_evolved(ship)
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
# is fighter / raider (with a harpoon) / scavenger / drifter, after its weapons; missiles and cannons
# each prefix it ("missile-fighter", "cannon-raider"), so a new archetype grows on its own branch
# instead of competing head-on with lasers. A lance is a part, not a role (since era 67: lance ships
# did worst of all in eras 63-66 whatever their tactics): any ship may carry one, as a prospecting
# tool or a close-in weapon, and its role is that of its other parts.
# A niche whose job is fighting: fighters and raiders (not scavengers, prospectors or drifters),
# judged on the exchange (Evolution.fitness_of).
static func is_combat_role(niche_name: String) -> bool:
	var role: String = niche_name.split("|")[1] if niche_name.count("|") >= 2 else niche_name
	return role.ends_with("fighter") or role.ends_with("raider")


# A niche's family, what a spawn picks first (Evolution._pick_genome, so each gets its share of lives
# whatever its fitness): "raider", "fighter" (guns, with or without a harpoon), or the role itself
# (prospector, scavenger, drifter, and any role a new rule adds).
# An archetype's preset (database/presets/archetypes/preset_ship_archetype_<model>.tres) as the game
# flies it: that ship template, its stats, model and fit as the file has them (a hand-made model
# replaces the placeholder there). A faction with a hull of its own (its ship_scene: the xenohive)
# flies a copy on that hull. {} if there is no such preset.
static func preset_build(model: String, faction: String) -> Dictionary:
	var ship_id: String = "preset_ship_archetype_" + model
	var ship = TemplateDatabase.get_template(ship_id)
	if not ship is ShipTemplate:  # Not indexed yet: straight from its file
		var path: String = Constants.ARCHETYPES_DIR.plus_file(ship_id + ".tres")
		ship = load(path) if ResourceLoader.exists(path) else null
		if not ship is ShipTemplate:
			printerr("Genome: no preset ship ", ship_id)
			return {}
		TemplateDatabase.register_evolved(ship)  # Found by id from now on (the body looks it up)
	var spec: Dictionary = TemplateDatabase.factions.get(faction, {})
	if str(spec.get("ship_scene", "")) != "":
		var own_id: String = "%s@%s" % [ship_id, faction]
		if not TemplateDatabase.evolved.has(own_id):
			var own = ship.duplicate()
			own.template_id = own_id
			own.ship_scene = load(spec.ship_scene)
			TemplateDatabase.register_evolved(own)
		ship_id = own_id
	return {"ship_template_id": ship_id, "fit": {"tools": ship.equipped_tools.duplicate(), "modules": ship.equipped_modules.duplicate()}}


# The placeholder hull ("<family>_<weight>", scenes/prefabs/ships/placeholders/) of a family (family())
# and weight class (PresetClassifier.ship_weight); a family without its own (a drifter: unarmed, no
# lance) looks like a scavenger.
static func placeholder_model(family_name: String, weight: String) -> String:
	if not Constants.HULL_FORMS.has(family_name):
		family_name = "scavenger"
	return "%s_%s" % [family_name, weight]


# A weight class's size class in a niche's name ("s-1.0|..."): one per class, so the niche name keeps
# its form (PresetExporter.weight_class reads it back) but a class is one niche, not several.
const WEIGHT_SIZE_CLASS = {"light": -1.0, "medium": 0.0, "heavy": 1.0, "superheavy": 2.0}


static func family(niche_name: String) -> String:
	var role: String = niche_name.split("|")[1] if niche_name.count("|") >= 2 else niche_name
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
	if harpoons == 0 and float(genome.get("behavior", {}).get("trade", 0.0)) >= 0.5:
		var has_lance := false
		for part in genome.modules:
			has_lance = has_lance or (not part.empty() and part.kind == "lance")
		if not has_lance:
			role = "trader"  # Buys and sells between stations (ShipControllerAI is_trader); armed or not
	var lance := false
	for part in genome.modules:
		lance = lance or (not part.empty() and part.kind == "lance")
	if lance and lasers > 0 and harpoons > 0 and float(genome.get("behavior", {}).get("prospect", 0.0)) >= 0.5:
		role = "prospector"  # Mines (ShipControllerAI): laser, lance and harpoon, and the will to
	var range_class: String = "-"
	if lasers > 0 and role != "trader":  # A trader's guns are for its own defence: one niche per weight
		var mean_range: float = range_sum / lasers
		range_class = "short" if mean_range < 800.0 else ("mid" if mean_range < 1400.0 else "long")
	# Coarse on purpose (era 54): the role's family and the hull's weight class, not the exact mix of
	# parts and half-step size, so lives pile up on fewer genomes instead of 1,200 thin niches.
	return "s%+.1f|%s|%s" % [WEIGHT_SIZE_CLASS[ShipLaws.weight_class(float(genome.ship["size"]))], family(role), range_class]


static func describe_part(part: Dictionary) -> String:
	if part.empty():
		return "-"
	if part.kind == "harpoon":
		return "HARPOON"
	var label: String = "%s-%s" % [part.kind.to_upper(), PartCatalog.weight_name(int(part.type)).to_upper()]
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
	return "T%d s=%.2f %.0fkg hull%d thr%.0fk pwr%.0f/%.1f hold%d [st%.2f en%.2f re%.2f ca%.2f ho%.2f] tools{%s} mods{%s} beh{eng%.2f dis%.2f rng%.2f ret%.2f pur%.2f mer%.2f rf%.2f tw%.2f ca%.2f bu%.2f qu%.2f}" % [
		int(ship.type), ship["size"], stats.mass, stats.hull_integrity, stats.linear_thrust / 1000.0,
		stats.power_capacity, stats.power_regen, stats.cargo_capacity,
		sh.structure, sh.engine, sh.reactor, sh.capacitor, sh.hold,
		PoolStringArray(tools).join(" "), PoolStringArray(modules).join(" "),
		b.get("engage", 1.0), b.get("disengage", 0.8), b.get("range", 1.0), b.get("retreat_hull", 0.0),
		b.get("pursuit", Constants.AI_PURSUIT), b.get("mercy", Constants.AI_MERCY), b.get("return_fire", Constants.AI_RETURN_FIRE),
		b.get("teamwork", 1.0), b.get("caution", Constants.AI_AVOID_SHARE), b.get("burn", Constants.AI_AFTERBURNER_RESERVE),
		b.get("quiet", Constants.EVO_BEHAVIOR_RANGES.quiet[2]),
	]
