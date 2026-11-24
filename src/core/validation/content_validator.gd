# ContentValidator: the rules every content file keeps (docs/CONTENT.md), as lists of problems, each
# {"file": res:// path, "problem": text}. One set of rules for both checkers: the content tests
# (src/tests/database/test_content.gd) want every list empty, and the development tool
# (tools/dev.py) checks each file it saves and shows the lists. A new rule goes here, nowhere else.
# Sections: factions, locations (the sector graph), sectors (layouts, havens and their market (SectorEconomy), beacons), archetypes, models (every ship and station
# model in use, ModelCheck: the slow one), sounds (the sound bank), theme (the UI theme and its looks). all() runs them all.
# Files are read afresh (not from TemplateDatabase's caches), so a just-saved edit counts.

extends Reference

const PartCatalog = preload("res://src/core/systems/part_catalog.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")
const SectorNames = preload("res://src/core/validation/sector_names.gd")
const SoundBank = preload("res://src/core/sound/sound_bank.gd")
const SectorEconomy = preload("res://src/core/validation/sector_economy.gd")
const FactionRoster = preload("res://src/core/systems/faction_roster.gd")
const SOUND_BANK_PATH = "res://database/sounds/sound_bank.tres"
const SECTIONS = ["factions", "locations", "sectors", "parts", "archetypes", "starts", "models", "materials", "sounds", "theme"]
const STARTS_DIR = "res://database/registry/game_starts/"
const LOCATIONS_DIR = "res://database/registry/locations/"
const COMMODITIES_DIR = "res://database/registry/assets/commodities/"
const PART_DIRS = [Constants.PARTS_DIR]  # The part catalogue (PartCatalog): the only parts there are
const SHIPS_DIR = "res://database/registry/assets/ships/"
const ANY_COMMODITY = "*"
const MATERIALS_DIR = "res://assets/art/materials_generic/"
const MATERIAL_SHADERS = ["res://assets/art/shaders/solid.gdshader", "res://assets/art/shaders/solid_fading.gdshader", "res://assets/art/shaders/glow.gdshader"]
const BEACON_KINDS = ["patrol", "field", "landmark", "entry"]
const THEMES_DIR = "res://assets/themes/"
const MAIN_THEME = "res://assets/themes/main_theme.tres"
const LOOK_PATTERN = "theme_type_variation = \"([A-Za-z_][A-Za-z0-9_]*)\""  # How a scene (or a script) names a look
const LOOK_SKIPPED = ["res://src/tests/"]  # Tests name made-up looks
# A part whose stats are not what its law_genes give (ShipLaws.stale_fields).
const LAWS_STALE = "%s not what its law_genes give: change law_genes, not the stats, then run apply_laws (Tools)"


static func all() -> Array:
	var out: Array = []
	for section in SECTIONS:
		out += section(section)
	return out


static func section(name: String) -> Array:
	match name:
		"factions":
			return factions()
		"locations":
			return locations()
		"sectors":
			return sectors()
		"parts":
			return parts()
		"archetypes":
			return archetypes()
		"models":
			return models()
		"materials":
			return materials()
		"starts":
			return starts()
		"sounds":
			return sounds()
		"theme":
			return theme()
	return [_problem("", "No validator section '%s'" % name)]


# The section a file's rules are in ("" when no rule covers it).
static func section_for(path: String) -> String:
	if path.begins_with(Constants.FACTIONS_DIR):
		return "factions"
	if path.begins_with(LOCATIONS_DIR):
		return "locations"
	if path.begins_with(Constants.SECTORS_SCENES_DIR):
		return "sectors"
	if path.begins_with(Constants.PARTS_DIR):
		return "parts"
	if path.begins_with(Constants.ARCHETYPES_DIR) or path.begins_with(Constants.CHARACTERS_DIR):
		return "archetypes"
	if path == SOUND_BANK_PATH:
		return "sounds"
	if path.begins_with(MATERIALS_DIR):
		return "materials"
	if path.begins_with(THEMES_DIR):
		return "theme"
	if path.begins_with(STARTS_DIR):
		return "starts"
	if path.begins_with("res://scenes/prefabs/ships/") or path.begins_with("res://scenes/prefabs/station/"):
		return "models"
	return ""


# The problems of one file: its section's, those in that file (and those its section cannot pin on a file).
static func for_file(path: String) -> Array:
	var name: String = section_for(path)
	if name == "":
		return []
	var out: Array = []
	for problem in section(name):
		if problem.file == path or problem.file == "":
			out.append(problem)
	return out


# --- Factions ---

static func faction_files(dir_path: String = Constants.FACTIONS_DIR) -> Dictionary:
	var out := {}  # id -> path
	for path in _files_in(dir_path, ".tres"):
		var faction = _fresh(path)
		if faction is FactionTemplate and faction.template_id != "":
			out[faction.template_id] = path
	return out


# `dir_path`: the faction folder (another only for tests).
static func factions(dir_path: String = Constants.FACTIONS_DIR) -> Array:
	var out: Array = []
	var files: Dictionary = faction_files(dir_path)
	if files.empty():
		out.append(_problem(dir_path, "No factions"))
	for id in files:
		var path: String = files[id]
		var faction: Dictionary = _fresh(path).to_spec()
		if faction.name == "":
			out.append(_problem(path, "No name"))
		for enemy in faction.enemies:
			if not files.has(enemy):
				out.append(_problem(path, "Enemy '%s' is not a faction" % enemy))
		for key in ["hull_material", "station_material"]:
			if not _exists(faction[key]):
				out.append(_problem(path, "%s '%s' does not exist" % [key, faction[key]]))
		if faction.ship_scene != "" and not _exists(faction.ship_scene):
			out.append(_problem(path, "Own hull '%s' does not exist" % faction.ship_scene))
		for level in faction.pilot_shares:
			if not str(level).to_upper() in Constants.PILOT_LEVELS:
				out.append(_problem(path, "Pilot level '%s' is not one of %s" % [level, PoolStringArray(Constants.PILOT_LEVELS).join(", ").to_lower()]))
			elif float(faction.pilot_shares[level]) < 0.0:
				out.append(_problem(path, "Pilot level '%s': a share below 0" % level))
		if not faction.pilot_shares.empty() and _sum(faction.pilot_shares) <= 0.0:
			out.append(_problem(path, "Pilot shares add up to 0: no pilots"))
		var families := {}  # The families it flies an archetype of
		for name in faction.archetype_shares:
			if not FactionRoster.archetype_exists(str(name)):
				out.append(_problem(path, "Archetype '%s' does not exist" % name))
			elif float(faction.archetype_shares[name]) < 0.0:
				out.append(_problem(path, "Archetype '%s': a share below 0" % name))
			elif float(faction.archetype_shares[name]) > 0.0:
				families[FactionRoster.split(str(name))[0]] = true
		for family in faction.traffic:
			if int(faction.traffic[family]) < 0:
				out.append(_problem(path, "Traffic '%s': a count below 0" % family))
			elif family != "" and not families.has(family):
				out.append(_problem(path, "Traffic family '%s': it flies none of its archetypes (its travellers would fly any)" % family))
	return out


static func _sum(table: Dictionary) -> float:
	var total := 0.0
	for key in table:
		total += max(float(table[key]), 0.0)
	return total


# --- Locations: the sector graph ---

# `dir_path`: the locations folder (another only for tests). Each location has an id; each
# connection names another location that connects back (a jump goes both ways); a scene path names
# a scene (else the sector would be an empty stand-in); a sector with a layout has a location.
static func locations(dir_path: String = LOCATIONS_DIR) -> Array:
	var out: Array = []
	var graph := {}  # id -> [path, connections]
	for path in _files_in(dir_path, ".tres"):
		var location = _fresh(path)
		if not location is LocationTemplate:
			continue
		if location.template_id == "":
			out.append(_problem(path, "No template_id"))
		elif graph.has(location.template_id):
			out.append(_problem(path, "template_id '%s' is used twice" % location.template_id))
		else:
			graph[location.template_id] = [path, Array(location.connections)]
		if location.sector_scene_path != "" and not ResourceLoader.exists(location.sector_scene_path):
			out.append(_problem(path, "Sector scene '%s' does not exist" % location.sector_scene_path))
		var expected: String = Constants.SECTORS_SCENES_DIR.plus_file(location.template_id).plus_file(location.template_id + ".tscn")
		if location.sector_scene_path != "" and location.sector_scene_path != expected and dir_path == LOCATIONS_DIR:
			out.append(_problem(path, "Its sector scene is '%s': a sector's is %s" % [location.sector_scene_path, expected]))
		if path.get_file().get_basename() != location.template_id and location.template_id != "":
			out.append(_problem(path, "Its file is named after its template_id: %s.tres" % location.template_id))
	for id in graph:
		var path: String = graph[id][0]
		for other in graph[id][1]:
			if other == id:
				out.append(_problem(path, "It connects to itself"))
			elif not graph.has(other):
				out.append(_problem(path, "Connection '%s' is not a location" % other))
			elif not id in graph[other][1]:
				out.append(_problem(path, "It connects to '%s', which does not connect back" % other))
	if dir_path == LOCATIONS_DIR:
		for id in graph:
			if graph[id][1].empty() and id != Constants.EVO_SECTOR_ID:
				out.append(_problem(graph[id][0], "It connects to no sector, so no one gets there (only evolution's, %s, stands apart)" % Constants.EVO_SECTOR_ID))
			elif id == Constants.EVO_SECTOR_ID and not graph[id][1].empty():
				out.append(_problem(graph[id][0], "Evolution's sector stands apart: it connects to no sector (the game never goes there)"))
		for sector_id in layout_files():
			if not graph.has(sector_id):
				out.append(_problem(layout_files()[sector_id], "No location '%s' for this sector (%s)" % [sector_id, LOCATIONS_DIR]))
	return out


# --- Sectors: layouts, havens, beacons ---

static func layout_files() -> Dictionary:
	var out := {}  # sector id -> layout scene path
	var dir := Directory.new()
	if dir.open(Constants.SECTORS_SCENES_DIR) != OK:
		return out
	dir.list_dir_begin(true, true)
	var sector_id: String = dir.get_next()
	while sector_id != "":
		var path: String = Constants.SECTORS_SCENES_DIR.plus_file(sector_id).plus_file(sector_id + Constants.SECTOR_LAYOUT_SUFFIX)
		if dir.current_is_dir() and ResourceLoader.exists(path):
			out[sector_id] = path
		sector_id = dir.get_next()
	return out


static func sectors() -> Array:
	var out: Array = []
	var factions: Dictionary = {}
	var files: Dictionary = faction_files()
	for id in files:
		factions[id] = _fresh(files[id]).to_spec()
	var layouts: Dictionary = layout_files()
	if layouts.empty():
		out.append(_problem(Constants.SECTORS_SCENES_DIR, "No sector layouts"))
	out += sector_folders()
	var seen := {}
	var goods: Dictionary = commodities()
	for sector_id in layouts:
		var path: String = layouts[sector_id]
		var spec: Dictionary = _spec_of(path)
		var scene_path: String = Constants.SECTORS_SCENES_DIR.plus_file(sector_id).plus_file(sector_id + ".tscn")
		var file := File.new()
		if file.open(scene_path, File.READ) != OK:
			out.append(_problem(path, "No sector scene %s" % scene_path))
		else:
			var scene_text: String = file.get_as_text()
			file.close()
			var entries := 0
			var points: Array = []
			for haven in spec.havens:
				points.append([haven.get("id", ""), haven])
			for list in ["beacons", "hazards"]:
				for point in spec[list]:
					points.append([point.get("name", point.get("kind", "")), point])
					if point.get("kind", "") == "entry" and list == "beacons":
						entries += 1
			if entries != 1:
				out.append(_problem(path, "%d entry beacons: a sector has one (where ships arrive)" % entries))
			for point in points:
				var body: String = str(point[1].get("attached_to", ""))
				if body != "" and not has_node_path(scene_text, body):
					out.append(_problem(path, "'%s' is attached to %s, which the sector scene does not have" % [point[0], body]))
			if scene_text.find(sector_id + Constants.SECTOR_LAYOUT_SUFFIX) < 0:
				out.append(_problem(path, "The sector scene %s does not place this layout" % scene_path))
			for station in stations_placed_in(scene_text):
				out.append(_problem(scene_path, "It places a station (%s): stations come with their haven, so place a haven marker in the layout instead" % station))
		for haven in spec.havens:
			if seen.has(haven.id):
				out.append(_problem(path, "Haven id '%s' is used twice" % haven.id))
			seen[haven.id] = true
			if haven.name == "":
				out.append(_problem(path, "Haven '%s': no name" % haven.id))
			if haven.faction != "" and not factions.has(haven.faction):
				out.append(_problem(path, "Haven '%s': owner '%s' is not a faction" % [haven.id, haven.faction]))
			for faction in haven.ships:
				if not factions.has(faction):
					out.append(_problem(path, "Haven '%s': ships' faction '%s' is not a faction" % [haven.id, faction]))
				elif FactionRoster.mix(factions[faction]).empty():
					out.append(_problem(path, "Haven '%s': %s flies no ships (no archetypes)" % [haven.id, faction]))
			var commodities: Array = commodity_ids()
			var buys: Dictionary = haven.get("services", {}).get("buys", {})
			for commodity in buys:
				if commodity != ANY_COMMODITY and not commodity in commodities:
					out.append(_problem(path, "Haven '%s' buys '%s', which is not a commodity" % [haven.id, commodity]))
				if not typeof(buys[commodity]) in [TYPE_INT, TYPE_REAL] or float(buys[commodity]) <= 0.0:
					out.append(_problem(path, "Haven '%s': its price factor for '%s' should be a number above 0" % [haven.id, commodity]))
			if not haven.has("model"):
				out.append(_problem(path, "Haven '%s': no station (model): a haven and its station are one" % haven.id))
			elif not _exists(haven.model):
				out.append(_problem(path, "Haven '%s': model '%s' does not exist" % [haven.id, haven.model]))
		for problem in SectorEconomy.problems(spec.havens, goods, sector_id == Constants.EVO_SECTOR_ID):
			if problem.hard:
				out.append(_problem(path, problem.text))
		for beacon in spec.beacons:
			if not beacon.kind in BEACON_KINDS:
				out.append(_problem(path, "Beacon '%s': kind '%s' is not one of %s" % [beacon.name, beacon.kind, BEACON_KINDS]))
			elif beacon.kind == "patrol" and not factions.has(beacon.get("owner", "")):
				out.append(_problem(path, "Beacon '%s': owner '%s' is not a faction" % [beacon.name, beacon.get("owner", "")]))
	return out


# --- Archetypes ---

static func archetype_names() -> Array:
	var out: Array = []
	for path in _files_in(Constants.ARCHETYPES_DIR, ".tres"):
		var name: String = path.get_file()
		if name.begins_with("agent_archetype_"):
			out.append(name.trim_prefix("agent_archetype_").trim_suffix(".tres"))
	out.sort()
	return out


# The part catalogue (PartCatalog): three of every kind, light, medium and heavy, and one harpoon;
# each preset_<kind>_<weight>.tres with its kind, weight and plain name, and nothing else there. The
# archetypes folder holds the archetypes alone (their parts are the catalogue's).
static func parts(dir_path: String = Constants.PARTS_DIR) -> Array:
	var out: Array = []
	var expected: Array = PartCatalog.ids()
	for path in _files_in(dir_path, ".tres"):
		var template_id: String = path.get_file().get_basename()
		if not template_id in expected:
			out.append(_problem(path, "Not a catalogue part: the catalogue is preset_<kind>_<light|medium|heavy> and %s" % Constants.HARPOON_TEMPLATE_ID))
			continue
		expected.erase(template_id)
		var part = _fresh(path)
		if part == null or part.template_id != template_id:
			out.append(_problem(path, "Its template_id should be '%s'" % template_id))
			continue
		var kind: String = str(part.get("tool_type")) if part is UtilityToolTemplate else str(part.get("module_kind"))
		var part_type: int = 0 if kind == "harpoon" else int(part.variant_type)
		if PartCatalog.id(kind, part_type) != template_id:
			out.append(_problem(path, "It is a %s %s, so its id is '%s'" % [PartCatalog.weight_name(part_type), kind, PartCatalog.id(kind, part_type)]))
		var name: String = str(part.get("tool_name")) if part is UtilityToolTemplate else str(part.get("module_name"))
		if name != PartCatalog.name(kind, part_type):
			out.append(_problem(path, "Its name is '%s', not '%s'" % [name, PartCatalog.name(kind, part_type)]))
		if kind != "harpoon" and (part.get("law_genes") == null or part.law_genes.empty()):
			out.append(_problem(path, "No law_genes: the part's genes, which evolution and apply_laws read"))
		var stale: Array = ShipLaws.stale_fields(part)
		if not stale.empty():
			out.append(_problem(path, LAWS_STALE % PoolStringArray(stale).join(", ")))
	for template_id in expected:
		out.append(_problem(dir_path.plus_file(template_id + ".tres"), "Missing: every kind comes light, medium and heavy"))
	if dir_path == Constants.PARTS_DIR:
		for path in _files_in(Constants.ARCHETYPES_DIR, ".tres"):
			var name: String = path.get_file()
			if not (name.begins_with("agent_archetype_") or name.begins_with("preset_ship_archetype_")):
				out.append(_problem(path, "Not an archetype: archetypes fit the catalogue's parts, kept in %s" % Constants.PARTS_DIR))
	return out


static func archetypes() -> Array:
	var out: Array = characters()
	for archetype in archetype_names():
		var path: String = _archetype_agent_path(archetype)
		var agent = _fresh(path)
		if agent.genome.empty():
			out.append(_problem(path, "No genome"))
		var character_path: String = character_path(archetype)
		if not _exists(character_path):
			out.append(_problem(path, "No character (%s): what the archetype is built from" % character_path))
		elif not ShipLaws.same_value(agent.genome, _fresh(character_path).built_genome()):
			out.append(_problem(path, "Its genome is not its character's (the base with its tweaks): run refit_archetypes (Overview f)"))
		var ship_path: String = Constants.ARCHETYPES_DIR.plus_file(agent.ship_template_id + ".tres")
		if not _exists(ship_path):
			out.append(_problem(path, "Its ship %s does not exist" % ship_path))
		else:
			var ship = _fresh(ship_path)
			if ship.ship_scene == null:
				out.append(_problem(ship_path, "No hull scene (ship_scene)"))
			else:
				for problem in ModelCheck.hardpoint_problems(ship.ship_scene.resource_path, ship):
					out.append(_problem(ship_path, problem))
			for part in ship.equipped_tools + ship.equipped_modules:
				if not PartCatalog.has(part):
					out.append(_problem(ship_path, "Part '%s' is not the catalogue's (%s)" % [part, Constants.PARTS_DIR]))
			out += archetype_stale(ship, agent, ship_path)
			var ship_name: String = archetype_ship_name(archetype)
			if ship.ship_model_name != ship_name:
				out.append(_problem(ship_path, "Its name is '%s', not its character's '%s': run refit_archetypes (Overview f)" % [ship.ship_model_name, ship_name]))
			elif not Strings.has(Strings.name_key(ship_name)):
				out.append(_problem(ship_path, "Its name '%s' has no string %s (Strings tab): the players' other language has no name for it" % [ship_name, Strings.name_key(ship_name)]))
		for group in ["tools", "modules"]:
			for part in agent.genome.get(group, []):
				if part.empty() or part.kind == "harpoon":
					continue
				if PartCatalog.genes(part.kind, int(part.type)).hash() != part.genes.hash():
					out.append(_problem(path, "Its genome's %s %s is not the catalogue's (its genes differ): run refit_archetypes (Tools)" % [PartCatalog.weight_name(int(part.type)), part.kind]))
		if not _exists(Constants.PLACEHOLDER_HULLS_DIR.plus_file(archetype + ".tscn")):
			out.append(_problem(path, "No placeholder hull %s" % Constants.PLACEHOLDER_HULLS_DIR.plus_file(archetype + ".tscn")))
	return out


# The name an archetype's hull goes by in the game: its character's (display_name), or while it has none
# its family, mark and weight ("Trader Mk I-medium"). refit_archetypes writes it.
static func archetype_ship_name(archetype: String) -> String:
	var path: String = character_path(archetype)
	if _exists(path):
		var sheet = _fresh(path)
		if sheet.display_name != "":
			return sheet.display_name
	var words: Array = archetype.split("_")
	return PartCatalog.hull_name(words[0], words[1]) if words.size() == 2 else archetype


# An archetype's ship against its pilot's genome, as refit_archetypes writes it: the hull genes are
# the genome's and the stats are what they give (ShipLaws.ship_stats).
static func archetype_stale(ship: Resource, agent: Resource, ship_path: String) -> Array:
	var genes: Dictionary = agent.genome.get("ship", {})
	if genes.empty():
		return []
	if not ShipLaws.same_value(ship.law_genes, genes):
		return [_problem(ship_path, "Its law_genes are not its pilot's genome's hull genes: run refit_archetypes (Tools)")]
	var stale: Array = []
	var stats: Dictionary = ShipLaws.ship_stats(genes)
	for field in stats:
		if not ShipLaws.same_value(ship.get(field), stats[field]):
			stale.append(field)
	if stale.empty():
		return []
	return [_problem(ship_path, "%s differ%s from what its genome's hull genes give: change the genome, not the stats, then run refit_archetypes (Tools)" % [
		PoolStringArray(stale).join(", "), "s" if stale.size() == 1 else ""])]


# --- Models in use ---

# {"ships": {scene path: [users]}, "stations": {scene path: [users]}}: what flies or places each model.
static func models_in_use() -> Dictionary:
	var ships := {}
	for path in _files_in(Constants.ARCHETYPES_DIR, ".tres") + _files_in("res://database/registry/assets/ships", ".tres"):
		if path.get_file().begins_with("agent_"):
			continue
		var ship = _fresh(path)
		if "ship_scene" in ship and ship.ship_scene != null:
			_use(ships, ship.ship_scene.resource_path, path)
	var files: Dictionary = faction_files()
	for id in files:
		var scene: String = _fresh(files[id]).to_spec().ship_scene
		if scene != "":
			_use(ships, scene, files[id])
	_use(ships, Constants.SHIP_DEFAULT_SCENE, "Constants.SHIP_DEFAULT_SCENE")
	var stations := {}
	_use(stations, Constants.STATION_DEFAULT_MODEL, "Constants.STATION_DEFAULT_MODEL")
	var layouts: Dictionary = layout_files()
	for sector_id in layouts:
		var layout: Node = _fresh(layouts[sector_id]).instance()
		if layout.has_method("to_spec"):
			for haven in layout.to_spec().havens:
				if haven.has("model"):
					_use(stations, haven.model, layouts[sector_id])
		layout.free()
	return {"ships": ships, "stations": stations}


static func models() -> Array:
	var out: Array = []
	var used: Dictionary = models_in_use()
	for scene_path in used.ships:
		for problem in ModelCheck.ship_problems(scene_path):
			out.append(_problem(scene_path, problem))
	for scene_path in used.stations:
		for problem in ModelCheck.station_problems(scene_path):
			out.append(_problem(scene_path, problem))
	return out


# Whether a scene's text has a node at `node_path` (from its root, e.g. "SceneAssets/Star Elace").
static func has_node_path(scene_text: String, node_path: String) -> bool:
	var parent: String = node_path.get_base_dir() if node_path.find("/") >= 0 else "."
	var head: String = '[node name="%s" ' % node_path.get_file()
	var at: int = scene_text.find(head)
	while at >= 0:
		if scene_text.substr(at, scene_text.find("\n", at) - at).find('parent="%s"' % parent) >= 0:
			return true
		at = scene_text.find(head, at + 1)
	return false


# The folder rules (SectorNames): every sector folder, its files, its bodies and what its scene
# places. `dir_path`: the sectors folder (another only for tests).
static func sector_folders(dir_path: String = Constants.SECTORS_SCENES_DIR) -> Array:
	var out: Array = []
	for sector_id in _dirs_in(dir_path):
		var folder: String = dir_path.plus_file(sector_id)
		var problem: String = SectorNames.sector_problem(sector_id)
		if problem != "":
			out.append(_problem(folder, "Sector folder %s" % problem))
			continue
		var scene_path: String = folder.plus_file(sector_id + ".tscn")
		var layout_path: String = folder.plus_file(sector_id + Constants.SECTOR_LAYOUT_SUFFIX)
		for path in _files_in(folder, ""):
			if not path in [scene_path, layout_path]:
				out.append(_problem(path, "A sector folder holds only %s.tscn, its layout and its bodies' folders" % sector_id))
		var scene_text: String = _text_of(scene_path)
		if scene_text == "":
			out.append(_problem(folder, "No sector scene %s" % scene_path))
			continue
		if SectorNames.root_name(scene_text) != SectorNames.title(sector_id):
			out.append(_problem(scene_path, "Its root is '%s', not '%s'" % [SectorNames.root_name(scene_text), SectorNames.title(sector_id)]))
		if dir_path == Constants.SECTORS_SCENES_DIR:
			var location = _fresh(LOCATIONS_DIR.plus_file(sector_id + ".tres")) if ResourceLoader.exists(LOCATIONS_DIR.plus_file(sector_id + ".tres")) else null
			if location == null:
				out.append(_problem(scene_path, "No location %s%s.tres for this sector" % [LOCATIONS_DIR, sector_id]))
			elif location.sector_scene_path != scene_path:
				out.append(_problem(scene_path, "Its location's sector_scene_path is '%s', not this scene" % location.sector_scene_path))
		var bodies := {}  # body scene path -> [kind, suffix]
		var planets := []
		for body in _dirs_in(folder):
			var parts: Dictionary = SectorNames.body_parts(sector_id, body)
			var body_folder: String = folder.plus_file(body)
			if parts.has("problem"):
				out.append(_problem(body_folder, "Body folder %s" % parts.problem))
				continue
			var body_path: String = body_folder.plus_file(body + ".tscn")
			for path in _files_in(body_folder, ""):
				if path != body_path and not path.get_file().begins_with(body + "_"):
					out.append(_problem(path, "A body's folder holds %s.tscn and its parts, named %s_<part>" % [body, body]))
			if not _dirs_in(body_folder).empty():
				out.append(_problem(body_folder, "A body's folder has no folders in it"))
			var body_text: String = _text_of(body_path)
			if body_text == "":
				out.append(_problem(body_folder, "No body scene %s" % body_path))
				continue
			bodies[body_path] = [parts.kind, parts.suffix]
			if parts.kind == "planet":
				planets.append(parts.suffix)
			if SectorNames.root_name(body_text) != SectorNames.title(body):
				out.append(_problem(body_path, "Its root is '%s', not '%s'" % [SectorNames.root_name(body_text), SectorNames.title(body)]))
			if (parts.kind == "star") != (body_text.find("is_star = true") >= 0):
				out.append(_problem(body_path, "A %s's scene should %sbe a star (is_star)" % [parts.kind, "" if parts.kind == "star" else "not "]))
		for path in bodies:
			if bodies[path][0] == "moon" and not bodies[path][1].substr(0, 1) in planets:
				out.append(_problem(path, "A moon of planet %s, which the sector does not have" % bodies[path][1].substr(0, 1).to_upper()))
		var placed := {}
		for thing in SectorNames.instances_under(scene_text, "SceneAssets"):
			if thing.name == "SectorLayout":
				continue
			if bodies.has(thing.scene):
				placed[thing.scene] = int(placed.get(thing.scene, 0)) + 1
				if thing.name != SectorNames.title(thing.scene):
					out.append(_problem(scene_path, "'%s' places %s: name it '%s'" % [thing.name, thing.scene.get_file(), SectorNames.title(thing.scene)]))
			elif thing.scene.begins_with(SectorNames.PREFABS_DIR):
				if not thing.name.begins_with(SectorNames.title(thing.scene)):
					out.append(_problem(scene_path, "'%s' places %s: name it '%s' (and a number)" % [thing.name, thing.scene.get_file(), SectorNames.title(thing.scene)]))
			elif thing.scene.begins_with(dir_path):
				out.append(_problem(scene_path, "'%s' places %s, which is not one of this sector's bodies: copy it into the sector as a body of its own" % [thing.name, thing.scene]))
		for path in bodies:
			if int(placed.get(path, 0)) > 1:
				out.append(_problem(scene_path, "It places %s %d times: a body is placed once (a copy is a body of its own)" % [path.get_file(), placed[path]]))
			elif not placed.has(path):
				out.append(_problem(path, "The sector scene does not place this body: place it, or remove its folder"))
		var layout_text: String = _text_of(layout_path)
		if layout_text != "":
			var regex := RegEx.new()
			regex.compile('\nsector_id = "([^"]*)"')
			var found = regex.search(layout_text)
			if found != null and found.get_string(1) != sector_id:
				out.append(_problem(layout_path, "Its sector_id is '%s', not '%s'" % [found.get_string(1), sector_id]))
	return out


static func _dirs_in(dir_path: String) -> Array:
	var out: Array = []
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		return out
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			out.append(name)
		name = dir.get_next()
	out.sort()
	return out


static func _text_of(path: String) -> String:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _spec_of(layout_path: String) -> Dictionary:
	var layout: Node = _fresh(layout_path).instance()
	var spec: Dictionary = layout.to_spec() if layout.has_method("to_spec") else {"havens": [], "beacons": [], "hazards": []}
	layout.free()
	return spec


# The station scenes a sector scene's text places itself (by their ext_resources): a station
# script, or a scene whose own text uses one.
static func stations_placed_in(scene_text: String) -> Array:
	var out: Array = []
	var regex := RegEx.new()
	regex.compile('\\[ext_resource path="([^"]+)" type="(Script|PackedScene)"')
	for found in regex.search_all(scene_text):
		var used: String = found.get_string(1)
		var text: String = used
		if found.get_string(2) == "PackedScene":
			var file := File.new()
			if file.open(used, File.READ) != OK:
				continue
			text = file.get_as_text()
			file.close()
		if text.find("station/dockable_station.gd") >= 0 or text.find("station/faction_station.gd") >= 0:
			out.append(used)
	return out


# --- Game starts ---

# Each start: its ship is a ship template, it starts docked at a haven, its kit holds parts, its
# standings name factions that have standing, from -1 to 1.
static func starts(dir_path: String = STARTS_DIR) -> Array:
	var out: Array = []
	var havens := {}  # Haven id -> its sector
	var layouts: Dictionary = layout_files()
	for sector_id in layouts:
		var layout: Node = _fresh(layouts[sector_id]).instance()
		if layout.has_method("to_spec"):
			for haven in layout.to_spec().havens:
				havens[haven.id] = sector_id
		layout.free()
	var parts: Array = part_ids()
	for path in _files_in(dir_path, ".tres"):
		var start = _fresh(path)
		var ship: String = start.player_ship_template
		if not (_exists(SHIPS_DIR.plus_file(ship + ".tres")) or _exists(Constants.ARCHETYPES_DIR.plus_file(ship + ".tres"))):
			out.append(_problem(path, "Its ship '%s' is not a ship template" % ship))
		if not havens.has(start.player_starting_location):
			out.append(_problem(path, "It starts at '%s', which is not a haven" % start.player_starting_location))
		elif dir_path == STARTS_DIR:  # Each mode's start docks in its sector: the game's home, evolution's arena
			var home: String = Constants.EVO_SECTOR_ID if start.template_id == Constants.EVO_GAME_START_ID else Constants.INITIAL_SECTOR_ID
			if havens[start.player_starting_location] != home:
				out.append(_problem(path, "It starts in %s; a%s start docks in %s" % [havens[start.player_starting_location],
					"n evolution" if home == Constants.EVO_SECTOR_ID else " game", home]))
		if start.starting_bank < 0:
			out.append(_problem(path, "Its bank is below 0"))
		for part in start.starting_storage:
			if not part in parts:
				out.append(_problem(path, "Its kit holds '%s', which is not a weapon, tool or module" % part))
			var count = start.starting_storage[part]
			if typeof(count) != TYPE_INT or count < 1:
				out.append(_problem(path, "Its kit's count of '%s' should be a whole number from 1" % part))
		var factions: Dictionary = faction_files()
		for faction in start.starting_standing:
			if not factions.has(faction):
				out.append(_problem(path, "Its standing with '%s', which is not a faction" % faction))
			elif _fresh(factions[faction]).no_standing:
				out.append(_problem(path, "Its standing with '%s', which has none (no_standing)" % faction))
			var standing = start.starting_standing[faction]
			if not typeof(standing) in [TYPE_INT, TYPE_REAL] or abs(float(standing)) > 1.0:
				out.append(_problem(path, "Its standing with '%s' should be a number from -1 to 1" % faction))
	return out


# Every commodity as SectorEconomy takes them: {id: {"name", "value", "mass"}}.
static func commodities() -> Dictionary:
	var out := {}
	for path in _files_in(COMMODITIES_DIR, ".tres"):
		var item = _fresh(path)
		if item is CommodityTemplate:
			out[item.template_id] = {"name": item.commodity_name, "value": float(item.base_value), "mass": float(item.unit_mass)}
	return out


static func commodity_ids() -> Array:
	var out: Array = []
	for path in _files_in(COMMODITIES_DIR, ".tres"):
		out.append(path.get_file().get_basename())
	return out


# Stock weapons, tools and modules (what the store sells and storage holds).
static func part_ids() -> Array:
	var out: Array = []
	for dir_path in PART_DIRS:
		for path in _files_in(dir_path, ".tres"):
			out.append(path.get_file().get_basename())
	return out


# --- Materials ---

# The material library: models take their materials from it by name (mat_<what>.tres; the model's
# material of that name is swapped for it), so each is a ShaderMaterial on a model shader, named so.
static func materials() -> Array:
	var out: Array = []
	var name_regex := RegEx.new()
	name_regex.compile("^mat_[a-z0-9_]+\\.tres$")
	for path in _files_in(MATERIALS_DIR, ".tres"):
		if name_regex.search(path.get_file()) == null:
			out.append(_problem(path, "Name it mat_<lower_case>.tres (models find it by that name)"))
		var material = _fresh(path)
		if not material is ShaderMaterial:
			out.append(_problem(path, "Not a ShaderMaterial"))
		elif material.shader == null or not material.shader.resource_path in MATERIAL_SHADERS:
			out.append(_problem(path, "Its shader should be one of %s" % [MATERIAL_SHADERS]))
	return out


# --- Theme ---

# The UI theme (MAIN_THEME): every UI scene takes it, and its named looks (type variations: a
# look's base_type, the plain control it changes, and what it sets) stand in for local overrides.
# Every look a scene or a script names is in the theme (else that control quietly falls back to the
# plain look), each look is built on a control or another look, and the folder holds only themes,
# fonts and styles. `scenes_dirs`: where looks are named (others only for tests).
static func theme(theme_path: String = MAIN_THEME, scenes_dirs: Array = ["res://scenes/", "res://src/"]) -> Array:
	var out: Array = []
	var main = _fresh(theme_path)
	if not main is Theme:
		return [_problem(theme_path, "Not a Theme")]
	for property in main.get_property_list():  # Every look, those that set nothing yet too
		if not property.name.ends_with("/base_type"):
			continue
		var look: String = property.name.get_slice("/", 0)
		var base: String = main.get_type_variation_base(look)
		if not ClassDB.is_parent_class(base, "Control") and main.get_type_variation_base(base) == "":
			out.append(_problem(theme_path, "The look %s is built on %s: name a control (Label, Button, Panel...) or another look" % [look, base]))
	var used: Dictionary = looks_in_use(scenes_dirs)
	for look in used:
		if main.get_type_variation_base(look) == "":
			out.append(_problem(theme_path, "%s name the look %s, which the theme does not have (they show the plain look)" % [
				PoolStringArray(used[look]).join(", "), look]))
	for path in _files_in(theme_path.get_base_dir(), ".tres"):
		var resource = _fresh(path)
		if not (resource is Theme or resource is Font or resource is StyleBox):
			out.append(_problem(path, "Not a theme, font or style (this folder holds the UI theme's files)"))
	return out


# {look: [file names]}: the looks (theme_type_variation) the .tscn and .gd files under `dirs` name.
static func looks_in_use(dirs: Array = ["res://scenes/", "res://src/"]) -> Dictionary:
	var out := {}
	var pattern := RegEx.new()
	pattern.compile(LOOK_PATTERN)
	for dir_path in dirs:
		for path in _files_under(dir_path, [".tscn", ".gd"]):
			if _skipped(path):
				continue
			var file := File.new()
			if file.open(path, File.READ) != OK:
				continue
			var text: String = file.get_as_text()
			file.close()
			for found in pattern.search_all(text):
				_use(out, found.get_string(1), path.get_file())
	return out


# --- Sounds ---

static func sounds() -> Array:
	var out: Array = []
	var bank = _fresh(SOUND_BANK_PATH)
	if not bank is SoundBank:
		return [_problem(SOUND_BANK_PATH, "Not a SoundBank")]
	for slot in SoundBank.SLOTS:
		var stream = bank.get(slot)
		if stream == null:
			continue
		if not stream is AudioStream:
			out.append(_problem(SOUND_BANK_PATH, "Slot %s holds no sound" % slot))
			continue
		var looped: bool = stream_loops(stream)
		if looped != SoundBank.loops(slot):
			out.append(_problem(SOUND_BANK_PATH, "Slot %s: %s should %s (Import dock: Loop)" % [slot, stream.resource_path, "loop" if SoundBank.loops(slot) else "not loop"]))
	return out


static func stream_loops(stream: AudioStream) -> bool:
	return (stream is AudioStreamSample and stream.loop_mode != AudioStreamSample.LOOP_DISABLED) \
		or (stream is AudioStreamOGGVorbis and stream.loop) or (stream is AudioStreamMP3 and stream.loop)


# --- Helpers ---

static func _problem(file: String, text: String) -> Dictionary:
	return {"file": file, "problem": text}


static func _exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


static func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", true)  # Not from the cache: a file just saved counts


static func _archetype_agent_path(name: String) -> String:
	return Constants.ARCHETYPES_DIR.plus_file("agent_archetype_%s.tres" % name)


static func character_path(archetype: String) -> String:
	return Constants.CHARACTERS_DIR.plus_file("character_%s.tres" % archetype)


# The characters (CharacterSheet): one per archetype, named, with a base genome, and tweaks the
# genome can take (genes in range, hull shares the laws know, catalogue parts, removed ones there).
static func characters(dir_path: String = Constants.CHARACTERS_DIR) -> Array:
	var out: Array = []
	var archetypes: Array = archetype_names()
	for path in _files_in(dir_path, ".tres"):
		var sheet = _fresh(path)
		if not sheet is CharacterSheet:
			out.append(_problem(path, "Not a CharacterSheet"))
			continue
		if path.get_file() != sheet.template_id + ".tres" or not sheet.template_id.begins_with("character_"):
			out.append(_problem(path, "Its template_id must be its file name, character_<archetype>"))
		elif dir_path == Constants.CHARACTERS_DIR and not sheet.archetype() in archetypes:
			out.append(_problem(path, "No archetype %s" % sheet.archetype()))
		if sheet.display_name == "":
			out.append(_problem(path, "No name"))
		if sheet.base_genome.empty() or not sheet.base_genome.has("ship"):
			out.append(_problem(path, "No base genome: pick_archetypes sets it from evolution's drafts"))
		for gene in sheet.genes:
			var range_of = Constants.EVO_BEHAVIOR_RANGES.get(gene)
			if range_of == null:
				out.append(_problem(path, "Gene '%s' is not a pilot gene (%s)" % [gene, PoolStringArray(Constants.EVO_BEHAVIOR_RANGES.keys()).join(", ")]))
			elif not typeof(sheet.genes[gene]) in [TYPE_INT, TYPE_REAL] or float(sheet.genes[gene]) < range_of[0] or float(sheet.genes[gene]) > range_of[1]:
				out.append(_problem(path, "Gene '%s': %s is outside %s..%s" % [gene, sheet.genes[gene], range_of[0], range_of[1]]))
		for share in sheet.shares:
			if not Constants.LAW_SHIP_SHARES.has(share):
				out.append(_problem(path, "Share '%s' is not a hull share (%s)" % [share, PoolStringArray(Constants.LAW_SHIP_SHARES.keys()).join(", ")]))
			elif not typeof(sheet.shares[share]) in [TYPE_INT, TYPE_REAL] or float(sheet.shares[share]) < Constants.LAW_SHIP_SHARE_MIN[share]:
				out.append(_problem(path, "Share '%s': below its least, %s" % [share, Constants.LAW_SHIP_SHARE_MIN[share]]))
		for template_id in sheet.add_parts:
			if not PartCatalog.has(str(template_id)):
				out.append(_problem(path, "add_parts: '%s' is not a catalogue part" % template_id))
		for template_id in sheet.remove_parts:
			if not PartCatalog.has(str(template_id)):
				out.append(_problem(path, "remove_parts: '%s' is not a catalogue part" % template_id))
			elif not sheet.base_has(str(template_id)):
				out.append(_problem(path, "remove_parts: its base has no %s" % template_id))
	return out


static func _use(table: Dictionary, path: String, user: String) -> void:
	if not table.has(path):
		table[path] = []
	if not user in table[path]:
		table[path].append(user)


static func _skipped(path: String) -> bool:
	for prefix in LOOK_SKIPPED:
		if path.begins_with(prefix):
			return true
	return false


# Files under `dir_path`, any depth, ending in one of `suffixes`; sorted.
static func _files_under(dir_path: String, suffixes: Array) -> Array:
	var out: Array = []
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		return out
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		var path: String = dir_path.plus_file(name)
		if dir.current_is_dir():
			out += _files_under(path, suffixes)
		else:
			for suffix in suffixes:
				if name.ends_with(suffix):
					out.append(path)
		name = dir.get_next()
	out.sort()
	return out


static func _files_in(dir_path: String, suffix: String) -> Array:
	var out: Array = []
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		return out
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(suffix):
			out.append(dir_path.plus_file(name))
		name = dir.get_next()
	out.sort()
	return out
