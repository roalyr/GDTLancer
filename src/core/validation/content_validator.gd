# ContentValidator: the rules every content file keeps (CONTENT.md), as lists of problems, each
# {"file": res:// path, "problem": text}. One set of rules for both checkers: the content tests
# (src/tests/database/test_content.gd) want every list empty, and the development tool
# (tools/dev.py) checks each file it saves and shows the lists. A new rule goes here, nowhere else.
# Sections: factions, sectors (layouts, havens, beacons), archetypes, models (every ship and station
# model in use, ModelCheck: the slow one), sounds (the sound bank). all() runs them all.
# Files are read afresh (not from TemplateDatabase's caches), so a just-saved edit counts.

extends Reference

const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")
const SoundBank = preload("res://src/core/sound/sound_bank.gd")
const SOUND_BANK_PATH = "res://database/sounds/sound_bank.tres"
const SECTIONS = ["factions", "sectors", "archetypes", "starts", "models", "materials", "sounds"]
const STARTS_DIR = "res://database/registry/game_starts/"
const COMMODITIES_DIR = "res://database/registry/assets/commodities/"
const PART_DIRS = ["res://database/registry/tools/", "res://database/registry/assets/modules/"]
const SHIPS_DIR = "res://database/registry/assets/ships/"
const ANY_COMMODITY = "*"
const MATERIALS_DIR = "res://assets/art/materials_generic/"
const MATERIAL_SHADERS = ["res://assets/art/shaders/solid.gdshader", "res://assets/art/shaders/glow.gdshader"]
const BEACON_KINDS = ["patrol", "field", "landmark"]


static func all() -> Array:
	var out: Array = []
	for section in SECTIONS:
		out += section(section)
	return out


static func section(name: String) -> Array:
	match name:
		"factions":
			return factions()
		"sectors":
			return sectors()
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
	return [_problem("", "No validator section '%s'" % name)]


# The section a file's rules are in ("" when no rule covers it).
static func section_for(path: String) -> String:
	if path.begins_with(Constants.FACTIONS_DIR):
		return "factions"
	if path.begins_with(Constants.SECTORS_SCENES_DIR):
		return "sectors"
	if path.begins_with(Constants.ARCHETYPES_DIR):
		return "archetypes"
	if path == SOUND_BANK_PATH:
		return "sounds"
	if path.begins_with(MATERIALS_DIR):
		return "materials"
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
		for name in faction.roster:
			if not _exists(_archetype_agent_path(name)):
				out.append(_problem(path, "Roster archetype '%s' does not exist" % name))
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
	var seen := {}
	for sector_id in layouts:
		var path: String = layouts[sector_id]
		var scene_path: String = Constants.SECTORS_SCENES_DIR.plus_file(sector_id).plus_file(sector_id + ".tscn")
		var file := File.new()
		if file.open(scene_path, File.READ) != OK:
			out.append(_problem(path, "No sector scene %s" % scene_path))
		else:
			if file.get_as_text().find(sector_id + Constants.SECTOR_LAYOUT_SUFFIX) < 0:
				out.append(_problem(path, "The sector scene %s does not place this layout" % scene_path))
			file.close()
		var layout: Node = _fresh(path).instance()
		var spec: Dictionary = layout.to_spec() if layout.has_method("to_spec") else {"havens": [], "beacons": []}
		layout.free()
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
				elif factions[faction].roster.empty():
					out.append(_problem(path, "Haven '%s': %s has no roster to fly" % [haven.id, faction]))
			var commodities: Array = commodity_ids()
			var buys: Dictionary = haven.get("services", {}).get("buys", {})
			for commodity in buys:
				if commodity != ANY_COMMODITY and not commodity in commodities:
					out.append(_problem(path, "Haven '%s' buys '%s', which is not a commodity" % [haven.id, commodity]))
				if not typeof(buys[commodity]) in [TYPE_INT, TYPE_REAL] or float(buys[commodity]) <= 0.0:
					out.append(_problem(path, "Haven '%s': its price factor for '%s' should be a number above 0" % [haven.id, commodity]))
			if haven.has("model") and not _exists(haven.model):
				out.append(_problem(path, "Haven '%s': model '%s' does not exist" % [haven.id, haven.model]))
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


static func archetypes() -> Array:
	var out: Array = []
	for archetype in archetype_names():
		var path: String = _archetype_agent_path(archetype)
		var agent = _fresh(path)
		if agent.genome.empty():
			out.append(_problem(path, "No genome"))
		var ship_path: String = Constants.ARCHETYPES_DIR.plus_file(agent.ship_template_id + ".tres")
		if not _exists(ship_path):
			out.append(_problem(path, "Its ship %s does not exist" % ship_path))
		else:
			var ship = _fresh(ship_path)
			if ship.ship_scene == null:
				out.append(_problem(ship_path, "No hull scene (ship_scene)"))
			for part in ship.equipped_tools + ship.equipped_modules:
				if not (_exists(Constants.ARCHETYPES_DIR.plus_file(part + ".tres")) or TemplateDatabase.get_template(part) != null or part == Constants.HARPOON_TEMPLATE_ID):
					out.append(_problem(ship_path, "Part '%s' does not exist" % part))
		if not _exists(Constants.PLACEHOLDER_HULLS_DIR.plus_file(archetype + ".tscn")):
			out.append(_problem(path, "No placeholder hull %s" % Constants.PLACEHOLDER_HULLS_DIR.plus_file(archetype + ".tscn")))
	return out


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


# --- Game starts ---

# Each start: its ship is a ship template, it starts docked at a haven, its kit holds parts.
static func starts(dir_path: String = STARTS_DIR) -> Array:
	var out: Array = []
	var havens := {}
	for path in layout_files().values():
		var layout: Node = _fresh(path).instance()
		if layout.has_method("to_spec"):
			for haven in layout.to_spec().havens:
				havens[haven.id] = true
		layout.free()
	var parts: Array = part_ids()
	for path in _files_in(dir_path, ".tres"):
		var start = _fresh(path)
		var ship: String = start.player_ship_template
		if not (_exists(SHIPS_DIR.plus_file(ship + ".tres")) or _exists(Constants.ARCHETYPES_DIR.plus_file(ship + ".tres"))):
			out.append(_problem(path, "Its ship '%s' is not a ship template" % ship))
		if not havens.has(start.player_starting_location):
			out.append(_problem(path, "It starts at '%s', which is not a haven" % start.player_starting_location))
		if start.starting_bank < 0:
			out.append(_problem(path, "Its bank is below 0"))
		for part in start.starting_storage:
			if not part in parts:
				out.append(_problem(path, "Its kit holds '%s', which is not a weapon, tool or module" % part))
			var count = start.starting_storage[part]
			if typeof(count) != TYPE_INT or count < 1:
				out.append(_problem(path, "Its kit's count of '%s' should be a whole number from 1" % part))
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
		if looped != (SoundBank.SLOTS[slot] == "loop"):
			out.append(_problem(SOUND_BANK_PATH, "Slot %s: %s should %s (Import dock: Loop)" % [slot, stream.resource_path, "loop" if SoundBank.SLOTS[slot] == "loop" else "not loop"]))
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


static func _use(table: Dictionary, path: String, user: String) -> void:
	if not table.has(path):
		table[path] = []
	if not user in table[path]:
		table[path].append(user)


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
