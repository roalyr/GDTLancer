# PresetClassifier: names what a preset is, for picking archetypes when building factions. A preset
# stays whole (hull, fit and behaviour genes evolved together); this only labels it:
# - role ("lance-raider", "prospector": Genome.niche's names, read off the ship's fit), family
#   (Genome.family) and weight class (light / medium / heavy: Constants PRESET_WEIGHT_CLASSES);
# - temperament: "aggressive", "measured" or "cautious", from how readily the genes start, keep up
#   and chase fights against how soon they run, next to the default genes (PRESET_TEMPERAMENT_GENES);
# - traits: the genes gone most of the way from their default to an end of their range (Constants
#   EVO_BEHAVIOR_RANGES), in words (PRESET_TRAITS).

extends Reference

const Genome = preload("res://src/core/evolution/genome.gd")

# Gene -> [word when low, word when high]: a gene PRESET_TRAIT_SHARE of the way from its default to
# the bottom or top of its range.
const PRESET_TRAITS = {
	"engage": ["quick to fight", "picks its fights"],
	"disengage": ["stubborn", "quick to break off"],
	"range": ["close-in", "standoff"],
	"retreat_hull": ["fights to the end", "skittish"],
	"pursuit": ["lets runners go", "relentless"],
	"mercy": ["ruthless", "merciful"],
	"return_fire": ["runs silent", "shoots back"],
	"teamwork": ["loner", "team player"],
	"caution": ["bold", "wary"],
	"haul": ["sells often", "hoards"],
	"quiet": ["loud", "sneaky"],
}
const PRESET_TRAIT_SHARE = 0.6
# Gene -> sign: + makes it more aggressive as the gene rises, - less.
const PRESET_TEMPERAMENT_GENES = {"engage": -1.0, "disengage": -1.0, "pursuit": 1.0, "retreat_hull": -1.0, "caution": -1.0, "mercy": -1.0}
const PRESET_TEMPERAMENT_EDGE = 0.1  # Mean signed lean from the default genes (-1 .. 1) past which it is aggressive or cautious


# {"role", "family", "weight_class", "archetype", "temperament", "traits"} for a preset's ship and genes;
# `role` if known (the exporter has the genome's niche), else read off the ship's fit.
static func classify(ship, behavior: Dictionary, role: String = "") -> Dictionary:
	if role == "":
		role = ship_role(ship, behavior)
	var weight: String = ship_weight(ship)
	return {
		"role": role, "family": Genome.family(role), "weight_class": weight, "archetype": "%s %s" % [role, weight],
		"temperament": temperament(behavior), "traits": traits(behavior),
	}


# What a fitted design fights with, named as the evolution names it (Genome.niche).
static func ship_role(ship, behavior: Dictionary = {}) -> String:
	var kinds := {}
	for tool_id in ship.equipped_tools:
		var part = TemplateDatabase.get_template(str(tool_id))
		if part is UtilityToolTemplate:
			kinds[part.tool_type] = true
	var lance := false
	for module_id in ship.equipped_modules:
		var part = TemplateDatabase.get_template(str(module_id))
		if part is ModuleTemplate and (part.module_kind == "lance" or not part.lance.empty()):
			lance = true
	var armed: bool = kinds.has("laser") or kinds.has("missile") or kinds.has("cannon")
	var role: String = "drifter"
	if armed:
		role = "raider" if kinds.has("harpoon") else "fighter"
	elif kinds.has("harpoon"):
		role = "scavenger"
	for kind in ["cannon", "missile"]:
		if kinds.has(kind):
			role = kind + "-" + role
	if lance:
		role = "lancer" if not armed else "lance-" + role
		if kinds.has("laser") and kinds.has("harpoon") and float(behavior.get("prospect", 0.0)) >= 0.5:
			role = "prospector"
	return role


# Light, medium or heavy, from the hull's size gene; a hull without one by its mass against the
# reference hull's.
static func ship_weight(ship) -> String:
	var size: float = float(ship.law_genes.get("size", 0.0)) if ship.law_genes is Dictionary else 0.0
	if size <= 0.0:
		size = float(ship.mass) / Constants.LAW_SHIP_REF_MASS
	var size_class: float = round(log(max(size, 0.001)) / log(2.0) * 2.0) / 2.0
	for weight in Constants.PRESET_WEIGHT_CLASSES:
		if size_class <= weight[1]:
			return weight[0]
	return Constants.PRESET_WEIGHT_CLASSES.back()[0]


static func temperament(behavior: Dictionary) -> String:
	var lean := 0.0
	for gene in PRESET_TEMPERAMENT_GENES:
		lean += PRESET_TEMPERAMENT_GENES[gene] * (_position(gene, behavior) - _position(gene, {}))  # From where evolution started
	lean /= PRESET_TEMPERAMENT_GENES.size()
	if lean > PRESET_TEMPERAMENT_EDGE:
		return "aggressive"
	if lean < -PRESET_TEMPERAMENT_EDGE:
		return "cautious"
	return "measured"


static func traits(behavior: Dictionary) -> Array:
	var words: Array = []
	for gene in PRESET_TRAITS:
		var position: float = _position(gene, behavior)
		var start: float = _position(gene, {})
		if position < start and (start - position) / start >= PRESET_TRAIT_SHARE:
			words.append(PRESET_TRAITS[gene][0])
		elif position > start and (position - start) / (1.0 - start) >= PRESET_TRAIT_SHARE:
			words.append(PRESET_TRAITS[gene][1])
	return words


# Where a gene sits in its range, 0 .. 1 (its default if the genes lack it).
static func _position(gene: String, behavior: Dictionary) -> float:
	var span: Array = Constants.EVO_BEHAVIOR_RANGES[gene]
	var value: float = float(behavior.get(gene, span[2]))
	return clamp((value - span[0]) / max(span[1] - span[0], 0.0001), 0.0, 1.0)
