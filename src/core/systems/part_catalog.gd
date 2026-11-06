# PartCatalog: the parts there are. Three of every kind, one per weight (light, medium, heavy), as
# there are three hulls of every family; the one harpoon besides. Each is a preset in
# Constants.PARTS_DIR (preset_<kind>_<weight>.tres; preset_harpoon.tres), its law_genes the part's
# genes (tools/apply_laws.gd rebuilds its stats from them). Archetypes, starting kits and the store
# use these and nothing else, and evolution picks among them: a genome's part is a kind and a
# weight, its genes always the catalogue's (Genome), so balance is tuned in these files.
# Names are plain and the same for all: "<Name> <Mark>-<weight>" ("Laser Mk I-light"), hulls too
# ("Lance Mk I-heavy"). The mark (Constants.PART_MARK) is the generation, the same for every part.

extends Reference

const WEIGHTS = {1: "light", 2: "medium", 3: "heavy"}
const TOOL_KINDS = ["laser", "missile", "cannon"]  # Evolved tools; the harpoon is one of its own


static func kinds() -> Array:
	return Constants.PART_NAMES.keys()


# Every kind but the harpoon comes in the three weights.
static func weighted_kinds() -> Array:
	var out: Array = []
	for kind in Constants.PART_NAMES:
		if kind != "harpoon":
			out.append(kind)
	return out


static func id(kind: String, part_type: int) -> String:
	if kind == "harpoon":
		return Constants.HARPOON_TEMPLATE_ID
	return "preset_%s_%s" % [kind, WEIGHTS.get(part_type, "?")]


static func path(kind: String, part_type: int) -> String:
	return Constants.PARTS_DIR.plus_file(id(kind, part_type) + ".tres")


# Every catalogue id, the harpoon's last.
static func ids() -> Array:
	var out: Array = []
	for kind in weighted_kinds():
		for part_type in WEIGHTS:
			out.append(id(kind, part_type))
	out.append(Constants.HARPOON_TEMPLATE_ID)
	return out


static func has(template_id: String) -> bool:
	return template_id in ids()


# The catalogue's tools (weapons and the harpoon) and modules, by id.
static func tool_ids() -> Array:
	var out: Array = []
	for kind in TOOL_KINDS:
		for part_type in WEIGHTS:
			out.append(id(kind, part_type))
	out.append(Constants.HARPOON_TEMPLATE_ID)
	return out


static func module_ids() -> Array:
	var out: Array = []
	for template_id in ids():
		if not template_id in tool_ids():
			out.append(template_id)
	return out


# A catalogue part by id: as indexed, or read from its file; null if none.
static func get_part(template_id: String) -> Resource:
	var found = TemplateDatabase.get_template(template_id)
	if found == null and ResourceLoader.exists(Constants.PARTS_DIR.plus_file(template_id + ".tres")):
		found = load(Constants.PARTS_DIR.plus_file(template_id + ".tres"))
	return found


static func weight_name(part_type: int) -> String:
	return WEIGHTS.get(part_type, "")


static func name(kind: String, part_type: int) -> String:
	if kind == "harpoon":
		return "%s %s" % [Constants.PART_NAMES.harpoon, Constants.PART_MARK]
	return "%s %s-%s" % [Constants.PART_NAMES.get(kind, kind.capitalize()), Constants.PART_MARK, weight_name(part_type)]


# Short, for the HUD's tool buttons: "LASER I-L".
static func hud_label(kind: String, part_type: int) -> String:
	var word: String = Constants.PART_NAMES.get(kind, kind).to_upper()
	if kind == "harpoon":
		return word
	return "%s %s-%s" % [word, Constants.PART_MARK.trim_prefix("Mk "), weight_name(part_type).substr(0, 1).to_upper()]


# A hull's name: its family, the mark and its weight ("Lance Mk I-heavy").
static func hull_name(family: String, weight: String) -> String:
	return "%s %s-%s" % [family.capitalize(), Constants.PART_MARK, weight]


# The catalogue part (the template), indexed or read from its file; null if there is none.
static func template(kind: String, part_type: int) -> Resource:
	var template_id: String = id(kind, part_type)
	var found = TemplateDatabase.presets.get(template_id) if TemplateDatabase.presets.has(template_id) else null
	if found == null and ResourceLoader.exists(path(kind, part_type)):
		found = load(path(kind, part_type))
	return found


# The part's genes, as the catalogue has them ({} for the harpoon, or none there).
static func genes(kind: String, part_type: int) -> Dictionary:
	if kind == "harpoon":
		return {}
	var found = template(kind, part_type)
	return found.law_genes.duplicate() if found != null and found.get("law_genes") != null else {}


# kg a part takes on its hardpoint, from its genes (a missile rack with its rounds, a cannon with its
# magazine); modules take no hardpoint (0).
static func mount_mass(kind: String, part_genes: Dictionary) -> float:
	match kind:
		"laser":
			return float(part_genes.get("mass", 0.0))
		"missile":
			return float(part_genes.get("round_mass", 0.0)) * (round(float(part_genes.get("count", 0.0))) + Constants.LAW_MISSILE_RACK_ROUNDS)
		"cannon":
			return float(part_genes.get("mass", 0.0)) + float(part_genes.get("round_mass", 0.0)) * round(float(part_genes.get("count", 0.0)))
	return 0.0
