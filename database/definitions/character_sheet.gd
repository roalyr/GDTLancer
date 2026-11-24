# CharacterSheet: who one archetype is, and how it is made (database/characters/character_<archetype>.tres).
# It starts from an evolved design (base_genome, as evolution flew it) and takes hand tweaks: pilot genes,
# hull shares and parts. genome() is the result; refit_archetypes builds the archetype's two files from it
# (the catalogue's parts, the laws' stats), so the sheet is what is edited and the archetype files are
# derived (the content rules say when they are out of date). pick_archetypes sets a new base and keeps
# the character and its tweaks. The game does not read it.

extends Template
class_name CharacterSheet

const PartCatalog = preload("res://src/core/systems/part_catalog.gd")

export var display_name: String = ""  # Its name as players would know it ("Smuggler")
export(String, MULTILINE) var summary: String = ""  # What it is like, in a sentence
export var strengths: String = ""
export var weakness: String = ""
export var quirk: String = ""  # What it does that others don't
export var looks: String = ""  # How it shows: its weapons, their tracers and beams
export var genes: Dictionary = {}  # Pilot gene -> its value instead of the base's (Constants EVO_BEHAVIOR_RANGES)
export var shares: Dictionary = {}  # Hull share ("structure", "engine", "reactor", "capacitor", "hold") -> its value instead of the base's (relative: the laws take each against their sum)
export var add_parts: Array = []  # Catalogue part ids it fits on top of the base's ("preset_damper_medium")
export var remove_parts: Array = []  # Catalogue part ids taken off the base (one each)
export var base_genome: Dictionary = {}  # The evolved design it starts from (Genome)
export var base_origin: String = ""  # Its design and era ("trader_medium_21949i2 (era 68)")
export var base_lives: int = 0  # Lives it flew in evolution
export var base_fitness: float = 0.0  # Its ranked fitness there (PresetExporter.ranked)


# The archetype it makes: its id without "character_" ("trader_medium").
func archetype() -> String:
	return template_id.trim_prefix("character_")


func tweaked() -> bool:
	return not (genes.empty() and shares.empty() and add_parts.empty() and remove_parts.empty())


# The base genome with the tweaks.
func genome() -> Dictionary:
	var out: Dictionary = base_genome.duplicate(true)
	if out.empty():
		return out
	if not out.has("behavior"):
		out["behavior"] = {}
	for gene in genes:
		out.behavior[gene] = float(genes[gene])
	if not out.ship.has("shares"):
		out.ship["shares"] = {}
	for share in shares:
		out.ship.shares[share] = float(shares[share])
	for template_id in remove_parts:
		for group in ["tools", "modules"]:
			var index: int = _index_of(out.get(group, []), str(template_id))
			if index >= 0:
				out[group][index] = {}
				break
	for template_id in add_parts:
		var part: Dictionary = part_of(str(template_id))
		if not part.empty():
			var group: String = "tools" if part.kind == "harpoon" or part.kind in PartCatalog.TOOL_KINDS else "modules"
			if not out.has(group):
				out[group] = []
			out[group].append(part)
	return out


# genome() as the archetype flies it: every part the catalogue's (Genome.retire_parts: its genes, a
# lighter weight where it does not fit the hull's slots). What refit_archetypes writes.
func built_genome() -> Dictionary:
	var out: Dictionary = genome()
	if not out.empty():
		load("res://src/core/evolution/genome.gd").retire_parts(out)
	return out


# A catalogue part as a genome holds it ({kind, type, genes}); {} if `template_id` is not one.
static func part_of(template_id: String) -> Dictionary:
	if template_id == Constants.HARPOON_TEMPLATE_ID:
		return {"kind": "harpoon", "type": 0, "genes": {}}
	for kind in PartCatalog.weighted_kinds():
		for part_type in PartCatalog.WEIGHTS:
			if PartCatalog.id(kind, part_type) == template_id:
				return {"kind": kind, "type": part_type, "genes": PartCatalog.genes(kind, part_type)}
	return {}


# Index of the first part in `parts` that is catalogue part `template_id` (-1 if none).
static func _index_of(parts: Array, template_id: String) -> int:
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		if not part.empty() and PartCatalog.id(str(part.kind), int(part.get("type", 0))) == template_id:
			return index
	return -1


# Whether `template_id` is among the base's parts (what remove_parts may name).
func base_has(template_id: String) -> bool:
	return _index_of(base_genome.get("tools", []), template_id) >= 0 or _index_of(base_genome.get("modules", []), template_id) >= 0
