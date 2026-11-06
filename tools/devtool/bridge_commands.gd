# BridgeCommands: what the development tool (tools/dev.py) asks of Godot, one method per command,
# each taking and returning plain data (JSON-safe; values with no JSON form travel as
# {"$": type, "text": var2str(value)}, Colors and Vector3s also as "v": [...]). bridge.gd runs these
# over stdin/stdout; the tests call them directly. Godot reads and writes every file, so what the
# tool saves is what the editor would.
# Resources: ping, schema, read, write, create (fields: a script's exported variables; a
# ShaderMaterial's shader and shader parameters). Scenes: scene_nodes, scene_write, scene_add,
# scene_remove (nodes and their fields, translation included), sector_map. Views: archetypes,
# factions, parts, look. Checks: validate, models, sound_slots, check_script. user_dir.

extends Reference

const Validator = preload("res://src/core/validation/content_validator.gd")
const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")
const SoundBank = preload("res://src/core/sound/sound_bank.gd")
const TscnText = preload("res://tools/devtool/tscn_text.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const EDITABLE = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR
const SHADER_PARAM = "shader_param/"
const TRANSLATION = "translation"
const MAIN_SCENE = "res://scenes/levels/game_world/main_game_scene.tscn"
const MUSIC_NODE = "AmbientMusic"
const PART_DIRS = {"weapons": "res://database/registry/tools/", "modules": "res://database/registry/assets/modules/",
	"commodities": "res://database/registry/assets/commodities/"}
const SHADERS_DIR = "res://assets/art/shaders/"
const PATTERNS_DIR = "res://assets/art/textures/paint_patterns/"
const HINT_NAMES = {
	PROPERTY_HINT_NONE: "", PROPERTY_HINT_RANGE: "range", PROPERTY_HINT_EXP_RANGE: "range", PROPERTY_HINT_ENUM: "enum",
	PROPERTY_HINT_FLAGS: "flags", PROPERTY_HINT_FILE: "file", PROPERTY_HINT_DIR: "dir", PROPERTY_HINT_GLOBAL_FILE: "file",
	PROPERTY_HINT_RESOURCE_TYPE: "resource", PROPERTY_HINT_MULTILINE_TEXT: "multiline", PROPERTY_HINT_COLOR_NO_ALPHA: "color_no_alpha",
}
const TYPE_NAMES = {
	TYPE_NIL: "Nil", TYPE_BOOL: "bool", TYPE_INT: "int", TYPE_REAL: "float", TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2", TYPE_RECT2: "Rect2", TYPE_VECTOR3: "Vector3", TYPE_TRANSFORM2D: "Transform2D",
	TYPE_PLANE: "Plane", TYPE_QUAT: "Quat", TYPE_AABB: "AABB", TYPE_BASIS: "Basis", TYPE_TRANSFORM: "Transform",
	TYPE_COLOR: "Color", TYPE_NODE_PATH: "NodePath", TYPE_RID: "RID", TYPE_OBJECT: "Object",
	TYPE_DICTIONARY: "Dictionary", TYPE_ARRAY: "Array", TYPE_RAW_ARRAY: "PoolByteArray",
	TYPE_INT_ARRAY: "PoolIntArray", TYPE_REAL_ARRAY: "PoolRealArray", TYPE_STRING_ARRAY: "PoolStringArray",
	TYPE_VECTOR2_ARRAY: "PoolVector2Array", TYPE_VECTOR3_ARRAY: "PoolVector3Array", TYPE_COLOR_ARRAY: "PoolColorArray",
}
const BODY_PREFIXES = ["star", "planet", "moon", "station"]  # Sector scene nodes drawn on the map


# Runs `command` with `args`: {"ok": true, "result": ...} or {"ok": false, "error": text}.
func handle(command: String, args: Dictionary) -> Dictionary:
	if not has_method("cmd_" + command):
		return {"ok": false, "error": "No command '%s'" % command}
	var result = call("cmd_" + command, args)
	if result is Dictionary and result.has("error"):
		return {"ok": false, "error": result.error}
	return {"ok": true, "result": result}


func cmd_ping(_args: Dictionary) -> Dictionary:
	return {"godot": Engine.get_version_info().string}


# --- Resources ---

# The editable fields of the resource at `path` (or of the script at `script`), in order:
# [{name, type, hint, hint_name, hint_string, default, comment}].
func cmd_schema(args: Dictionary):
	var target = null
	if str(args.get("script", "")) != "":
		var script = load(str(args.script))
		target = script.new() if script is Script else null
	else:
		target = _fresh(str(args.get("path", "")))
	if target == null:
		return {"error": "Nothing to describe at %s" % args}
	var script: Script = target.get_script()
	var out := {"script": script.resource_path if script != null else "", "class": _class_of(target), "fields": fields_of(target)}
	if target is Node:
		target.free()
	return out


# The resource at `path`: its class and field values.
func cmd_read(args: Dictionary):
	var resource = _fresh(str(args.get("path", "")))
	if resource == null:
		return {"error": "Cannot load %s" % args.get("path", "")}
	var script: Script = resource.get_script()
	return {"path": str(args.path), "class": _class_of(resource), "script": script.resource_path if script != null else "",
		"values": values_of(resource)}


# Sets `values` on the resource at `path` and saves it; then its rules (ContentValidator.for_file):
# {"problems": [...], "new": [...]} (new: not there before the save).
func cmd_write(args: Dictionary):
	var path: String = str(args.get("path", ""))
	var resource = _fresh(path)
	if resource == null:
		return {"error": "Cannot load %s" % path}
	var before: Array = _texts(Validator.for_file(path))
	var error: String = set_values(resource, args.get("values", {}))
	if error != "":
		return {"error": error}
	if ResourceSaver.save(path, resource) != OK:
		return {"error": "Saving %s failed" % path}
	return _checked(path, before)


# A new resource at `path` (never over a file): of `script`, or a copy of `copy_from`; with `values`.
func cmd_create(args: Dictionary):
	var path: String = str(args.get("path", ""))
	if path == "" or File.new().file_exists(path):
		return {"error": "%s exists already (or no path)" % path}
	var resource: Resource = null
	if str(args.get("copy_from", "")) != "":
		var source = _fresh(str(args.copy_from))
		resource = source.duplicate() if source != null else null
	elif str(args.get("script", "")) != "":
		var script = load(str(args.script))
		resource = script.new() if script is Script else null
	if resource == null:
		return {"error": "Nothing to make %s from" % path}
	var error: String = set_values(resource, args.get("values", {}))
	if error != "":
		return {"error": error}
	Directory.new().make_dir_recursive(path.get_base_dir())
	if ResourceSaver.save(path, resource) != OK:
		return {"error": "Saving %s failed" % path}
	return _checked(path, [])


# --- Scenes ---

# Every node of the scene at `path` (its own, not those of scenes placed in it):
# [{node, name, parent, type, script, fields, values}]; node is its path from the root (".").
func cmd_scene_nodes(args: Dictionary):
	var root: Node = _edit_instance(str(args.get("path", "")))
	if root == null:
		return {"error": "Cannot open %s" % args.get("path", "")}
	var out: Array = []
	for node in _own_nodes(root):
		var script: Script = node.get_script()
		out.append({
			"node": str(root.get_path_to(node)), "name": node.name,
			"parent": str(root.get_path_to(node.get_parent())) if node != root else "",
			"type": node.get_class(), "script": script.resource_path if script != null else "",
			"fields": fields_of(node), "values": values_of(node),
		})
	root.free()
	return out


# Sets `values` on node `node` of the scene at `path` and saves the scene; then its rules. Only
# the lines of the values that changed change (TscnText).
func cmd_scene_write(args: Dictionary):
	var path: String = str(args.get("path", ""))
	var root: Node = _edit_instance(path)
	if root == null:
		return {"error": "Cannot open %s" % path}
	var node_path: String = str(args.get("node", ""))
	var node: Node = root.get_node_or_null(node_path)
	var old_text: String = _read_text(path)
	var doc = TscnText.new(old_text)
	if node == null or doc.find_node(node_path) == null:
		return _freed(root, {"error": "%s has no node of its own at %s" % [path, node_path]})
	var before: Array = _texts(Validator.for_file(path))
	var error: String = _set_in_text(doc, node_path, node, args.get("values", {}))
	root.free()
	if error != "":
		return {"error": error}
	return _save_text_checked(path, old_text, doc.text(), before)


# A new node `name` under `parent` of the scene at `path`: a `type` (default Position3D) with
# `script` (a res:// path, or none), its fields set to `values`. A taken name gets a number.
# Returns its path as "node".
func cmd_scene_add(args: Dictionary):
	var path: String = str(args.get("path", ""))
	var old_text: String = _read_text(path)
	if old_text == "":
		return {"error": "Cannot open %s" % path}
	var doc = TscnText.new(old_text)
	var parent: String = str(args.get("parent", "."))
	if parent != "." and doc.find_node(parent) == null:
		return {"error": "%s has no node %s" % [path, parent]}
	var type: String = str(args.get("type", "Position3D"))
	var probe = ClassDB.instance(type)
	if not probe is Node:
		return {"error": "No node type %s" % type}
	var script_path: String = str(args.get("script", ""))
	if script_path != "":
		probe.set_script(load(script_path))
	var added: String = doc.add_node(parent, str(args.get("name", "Marker")), type, doc.ext_id(script_path, "Script") if script_path != "" else -1)
	var before: Array = _texts(Validator.for_file(path))
	var error: String = _set_in_text(doc, added, probe, args.get("values", {}))
	probe.free()
	if error != "":
		return {"error": error}
	var result = _save_text_checked(path, old_text, doc.text(), before)
	if result is Dictionary and not result.has("error"):
		result["node"] = added
	return result


# Removes node `node` (and what is under it) from the scene at `path`.
func cmd_scene_remove(args: Dictionary):
	var path: String = str(args.get("path", ""))
	var old_text: String = _read_text(path)
	var doc = TscnText.new(old_text)
	var node_path: String = str(args.get("node", ""))
	if node_path in ["", "."] or not doc.remove_node(node_path):
		return {"error": "%s: no node %s to remove" % [path, node_path]}
	doc.drop_unused_resources()
	return _save_text_checked(path, old_text, doc.text(), _texts(Validator.for_file(path)))


# A sector seen from above: the bodies of its scene (stars, planets, moons, stations) and the
# markers of its layout, each {name, kind, x, z, radius, node}: x and z in m; radius a marker's
# reach (0: none set); node a marker's path in its layout.
func cmd_sector_map(args: Dictionary):
	var sector: String = str(args.get("sector", ""))
	var out: Array = []
	var scene_root: Node = _edit_instance(Constants.SECTORS_SCENES_DIR.plus_file(sector).plus_file(sector + ".tscn"))
	if scene_root != null:
		for node in _own_nodes(scene_root):
			if node is Spatial and node != scene_root:
				for prefix in BODY_PREFIXES:
					if node.name.to_lower().begins_with(prefix):
						var origin: Vector3 = _origin(node)
						out.append({"name": node.name, "kind": prefix, "x": origin.x, "z": origin.z, "radius": 0.0, "node": ""})
						break
		scene_root.free()
	var layout_root: Node = _edit_instance(Validator.layout_files().get(sector, ""))
	if layout_root != null:
		for node in _own_nodes(layout_root):
			if node is Spatial and node.get_script() != null and node != layout_root:
				var origin: Vector3 = _origin(node)
				var radius = node.get("radius")
				out.append({"name": node.name, "kind": node.get_script().resource_path.get_file().get_basename(), "x": origin.x, "z": origin.z,
					"radius": float(radius) if typeof(radius) in [TYPE_INT, TYPE_REAL] else 0.0, "node": str(layout_root.get_path_to(node))})
		layout_root.free()
	return out


# --- Views ---

# Every archetype as the game flies it: {"ranges": EVO_BEHAVIOR_RANGES, "archetypes": [{name,
# pilot, ship (paths), role, temperament, traits, lives, fitness, skill, behavior, scene, length (m),
# value, hull, cargo, slots, mass (fitted, kg), top_speed, burst_speed (afterburner), accel (m/s2),
# power, regen, signature, gun_dps (weapons as an observer counts them; ToolController), parts:
# [{id, name, kind}], flown_by: [faction ids]}]}.
func cmd_archetypes(_args: Dictionary):
	var rosters := {}
	for faction_path in Validator.faction_files().values():
		var faction = _fresh(faction_path)
		for name in faction.roster:
			if not rosters.has(name):
				rosters[name] = []
			rosters[name].append(faction.template_id)
	var out: Array = []
	for name in Validator.archetype_names():
		var pilot_path: String = Validator._archetype_agent_path(name)
		var pilot = _fresh(pilot_path)
		var ship_path: String = Constants.ARCHETYPES_DIR.plus_file(pilot.ship_template_id + ".tres")
		var ship = _fresh(ship_path)
		if ship == null:
			out.append({"name": name, "pilot": pilot_path, "ship": ship_path, "error": "no ship"})
			continue
		for part_id in Array(ship.equipped_tools) + Array(ship.equipped_modules):
			var known = TemplateDatabase.get_template(part_id)
			var part = _part(part_id)
			if part != null and (known == null or known.resource_path == part.resource_path):
				TemplateDatabase.register_evolved(part)  # As the game finds them (Genome.preset_build); fresh from the file
		var stats: Dictionary = ShipFit.compute_stats(ship, ShipFit.default_fit(ship))
		var drag: float = max(stats.mass * Constants.LINEAR_DRAG, 0.001)
		var parts: Array = []
		var gun_dps := 0.0
		for part_id in Array(ship.equipped_tools) + Array(ship.equipped_modules):
			var part = _part(part_id)
			var part_name: String = part_id
			var kind := "?"
			if part is UtilityToolTemplate:
				part_name = part.tool_name
				kind = part.tool_type
				gun_dps += _tool_dps(part)
			elif part != null:
				part_name = str(part.get("module_name")) if part.get("module_name") != null else part_id
				kind = "module"
			parts.append({"id": part_id, "name": part_name, "kind": kind})
		out.append({
			"name": name, "pilot": pilot_path, "ship": ship_path,
			"role": pilot.role, "temperament": pilot.temperament, "traits": Array(pilot.traits),
			"lives": pilot.lives, "fitness": pilot.fitness, "skill": pilot.skill, "behavior": pilot.behavior,
			"scene": ship.ship_scene.resource_path if ship.ship_scene != null else "",
			"length": float(ship.model_scale) * Constants.SHIP_MODEL_LENGTH, "value": ship.base_value,
			"hull": stats.hull, "cargo": stats.cargo_capacity,
			"slots": [ship.tool_slots_small, ship.tool_slots_medium, ship.tool_slots_large, ship.module_slots],
			"mass": stats.mass, "top_speed": stats.linear_thrust / drag,
			"burst_speed": (stats.linear_thrust + stats.afterburner_thrust) / drag, "accel": stats.linear_thrust / max(stats.mass, 0.001),
			"power": stats.power_capacity, "regen": stats.power_regen, "signature": stats.signature,
			"gun_dps": gun_dps, "parts": parts, "flown_by": rosters.get(name, []),
		})
	return {"ranges": Constants.EVO_BEHAVIOR_RANGES, "archetypes": out}


# Every faction with what the generic form cannot show: {"factions": [{id, path, name, color,
# enemies, at_war (either side's list), roster, flags..., paint (albedo of its hull material),
# havens: [{sector, layout, node, id, name, ships}]}], "archetypes": [names]}.
func cmd_factions(_args: Dictionary):
	var specs := {}
	var paths: Dictionary = Validator.faction_files()
	for id in paths:
		specs[id] = _fresh(paths[id])
	var havens := {}
	var layouts: Dictionary = Validator.layout_files()
	for sector in layouts:
		var root: Node = _edit_instance(layouts[sector])
		if root == null:
			continue
		for node in _own_nodes(root):
			if node.get_script() != null and node.get_script().resource_path.ends_with("haven_marker.gd"):
				if not havens.has(node.faction):
					havens[node.faction] = []
				havens[node.faction].append({"sector": sector, "layout": layouts[sector], "node": str(root.get_path_to(node)),
					"id": node.haven_id, "name": node.display_name, "ships": encode(node.ships)})
		root.free()
	var out: Array = []
	var ids: Array = specs.keys()
	ids.sort()
	for id in ids:
		var faction = specs[id]
		var at_war: Array = []
		for other in ids:
			if other != id and (other in faction.enemies or id in specs[other].enemies):
				at_war.append(other)
		var paint = _fresh(faction.hull_material) if faction.hull_material != "" else null
		var entry: Dictionary = values_of(faction)
		entry["id"] = id
		entry["path"] = paths[id]
		entry["at_war"] = at_war
		entry["paint"] = encode(paint.get_shader_param("albedo")) if paint is ShaderMaterial else null
		entry["havens"] = havens.get(id, [])
		out.append(entry)
	return {"factions": out, "archetypes": Validator.archetype_names(), "neutral_havens": havens.get("", [])}


# Every weapon, module and commodity (stock ones in database/registry/, archetype parts in
# database/presets/archetypes/), with its numbers and where it is used: {"weapons": [...],
# "modules": [...], "commodities": [...], "starts": [{path, id, ship, location, bank, storage}]}.
# Each item: {id, path, name, origin ("stock" or "archetype"), value, mass, used_by: [...], ...}.
func cmd_parts(_args: Dictionary):
	var used := {}
	var ship_paths: Array = []
	for path in Validator._files_in(Constants.ARCHETYPES_DIR, ".tres"):
		if path.get_file().begins_with("preset_ship_archetype_"):
			ship_paths.append(path)
	ship_paths += Validator._files_in("res://database/registry/assets/ships/", ".tres")
	for path in ship_paths:
		var ship = _fresh(path)
		if ship == null:
			continue
		var label: String = str(ship.template_id).trim_prefix("preset_ship_archetype_")
		for part_id in Array(ship.equipped_tools) + Array(ship.equipped_modules):
			_note_use(used, part_id, label)
		for commodity_id in ship.salvage_yield:
			_note_use(used, commodity_id, "salvage of " + label)
	var starts: Array = []
	for path in Validator._files_in("res://database/registry/game_starts/", ".tres"):
		var start = _fresh(path)
		for item_id in start.starting_storage:
			_note_use(used, item_id, "start " + start.template_id)
		starts.append({"path": path, "id": start.template_id, "ship": start.player_ship_template, "location": start.player_starting_location,
			"bank": start.starting_bank, "storage": encode(start.starting_storage)})
	var layouts: Dictionary = Validator.layout_files()
	for sector in layouts:
		var root: Node = _edit_instance(layouts[sector])
		if root == null:
			continue
		for node in _own_nodes(root):
			if node.get_script() != null and node.get_script().resource_path.ends_with("haven_marker.gd"):
				for commodity_id in node.buys:
					_note_use(used, commodity_id, "bought at " + node.haven_id)
		root.free()
	var out := {"weapons": [], "modules": [], "commodities": [], "starts": starts}
	var paths: Array = []
	for kind in PART_DIRS:
		for path in Validator._files_in(PART_DIRS[kind], ".tres"):
			paths.append([kind, path, "stock"])
	for path in Validator._files_in(Constants.ARCHETYPES_DIR, ".tres"):
		var name: String = path.get_file()
		if name.begins_with("preset_") and not name.begins_with("preset_ship_archetype_"):
			paths.append(["", path, "archetype"])
	for entry in paths:
		var item = _fresh(entry[1])
		if item == null:
			continue
		var row := {"id": item.template_id, "path": entry[1], "origin": entry[2], "value": item.get("base_value"),
			"used_by": used.get(item.template_id, [])}
		if item is UtilityToolTemplate:
			row.merge({"name": item.tool_name, "type": item.tool_type, "mount": item.mount_size, "mass": item.mass, "damage": item.damage,
				"cycle": item.cycle_time, "dps": _tool_dps(item), "range": item.optimal_range, "ammo": item.ammo, "power": item.power_per_cycle})
			out.weapons.append(row)
		elif item is ModuleTemplate:
			row.merge({"name": item.module_name, "kind": item.module_kind, "mass": item.mass, "effects": encode(item.stat_modifiers),
				"lance": not item.lance.empty()})
			out.modules.append(row)
		elif item is CommodityTemplate:
			row.merge({"name": item.commodity_name, "mass": item.unit_mass})
			out.commodities.append(row)
	return out


# How the game looks, as files: {"shaders": [{path, materials: [paths], scenes: [that name it]}], "paints": [{faction,
# kind ("hull"/"station"), material, albedo, pattern, strength}], "patterns": [{path, used_by}],
# "music": {scene, node, stream, fields, values}}.
func cmd_look(_args: Dictionary):
	var by_shader := {}
	var by_texture := {}
	for path in _files_under("res://assets/", ".tres"):
		var material = _fresh(path)
		if not material is ShaderMaterial or material.shader == null:
			continue
		var shader_path: String = material.shader.resource_path
		if not by_shader.has(shader_path):
			by_shader[shader_path] = []
		by_shader[shader_path].append(path)
		var texture = material.get_shader_param("detail_texture")
		if texture is Texture:
			if not by_texture.has(texture.resource_path):
				by_texture[texture.resource_path] = []
			by_texture[texture.resource_path].append(path)
	var scene_texts := {}
	for path in _files_under("res://scenes/", ".tscn") + _files_under("res://assets/", ".tscn"):
		scene_texts[path] = _read_text(path)
	var shaders: Array = []
	for path in Validator._files_in(SHADERS_DIR, ".gdshader"):
		var scenes: Array = []
		for scene in scene_texts:
			if scene_texts[scene].find('"%s"' % path) >= 0:
				scenes.append(scene)
		shaders.append({"path": path, "materials": by_shader.get(path, []), "scenes": scenes})
	var paints: Array = []
	var factions: Dictionary = Validator.faction_files()
	var ids: Array = factions.keys()
	ids.sort()
	for id in ids:
		var faction = _fresh(factions[id])
		for kind in ["hull", "station"]:
			var material_path: String = faction.get(kind + "_material")
			var material = _fresh(material_path) if material_path != "" else null
			var texture = material.get_shader_param("detail_texture") if material is ShaderMaterial else null
			paints.append({"faction": id, "kind": kind, "material": material_path,
				"albedo": encode(material.get_shader_param("albedo")) if material is ShaderMaterial else null,
				"pattern": texture.resource_path if texture is Texture else "",
				"strength": material.get_shader_param("detail_paint_strength") if material is ShaderMaterial else 0.0})
	var patterns: Array = []
	for path in Validator._files_in(PATTERNS_DIR, ".png"):
		patterns.append({"path": path, "used_by": by_texture.get(path, [])})
	var music := {"scene": MAIN_SCENE, "node": MUSIC_NODE}
	var root: Node = _edit_instance(MAIN_SCENE)
	if root != null:
		var player: Node = root.get_node_or_null(MUSIC_NODE)
		if player != null:
			music["stream"] = player.stream.resource_path if player.stream != null else ""
			music["fields"] = fields_of(player)
			music["values"] = values_of(player)
		root.free()
	return {"shaders": shaders, "paints": paints, "patterns": patterns, "music": music}


# Where Godot keeps user:// on this machine (evolution's save and logs are there).
func cmd_user_dir(_args: Dictionary):
	return {"path": OS.get_user_data_dir()}


static func _note_use(table: Dictionary, id: String, user: String) -> void:
	if not table.has(id):
		table[id] = []
	if not user in table[id]:
		table[id].append(user)


static func _files_under(dir_path: String, suffix: String) -> Array:
	var out: Array = Validator._files_in(dir_path, suffix)
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		return out
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			out += _files_under(dir_path.plus_file(name) + "/", suffix)
		name = dir.get_next()
	return out


static func _part(part_id: String) -> Resource:
	var path: String = Constants.ARCHETYPES_DIR.plus_file(part_id + ".tres")
	return _fresh(path) if ResourceLoader.exists(path) else TemplateDatabase.get_template(part_id)


# A weapon's damage per second as ToolController counts it with a full magazine.
static func _tool_dps(tool_template) -> float:
	if tool_template.cycle_time <= 0.0:
		return 0.0
	var rate: float = tool_template.damage / tool_template.cycle_time
	match tool_template.tool_type:
		"laser":
			return rate
		"missile":
			return min(rate, tool_template.damage * tool_template.ammo / Constants.AI_MISSILE_FIGHT_TIME) * Constants.AI_MISSILE_HIT_SHARE
		"cannon":
			return rate * Constants.AI_CANNON_HIT_SHARE if tool_template.ammo > 0 else 0.0
	return 0.0


# --- Checks ---

# Problems: of one `file`, one `section`, or all.
func cmd_validate(args: Dictionary):
	if args.has("file"):
		return Validator.for_file(str(args.file))
	if args.has("section"):
		return Validator.section(str(args.section))
	return Validator.all()


# Every ship and station model scene, with who uses it and its model check:
# {"ships": {scene: {"users": [...], "problems": [...]}}, "stations": {...}}.
func cmd_models(_args: Dictionary):
	var used: Dictionary = Validator.models_in_use()
	var out := {"ships": {}, "stations": {}}
	for kind in ["ships", "stations"]:
		var dirs: Array = ["res://scenes/prefabs/ships/", "res://scenes/prefabs/ships/placeholders/"] if kind == "ships" \
			else ["res://scenes/prefabs/station/", "res://scenes/prefabs/station/placeholders/"]
		var scenes := {}
		for dir_path in dirs:
			for path in Validator._files_in(dir_path, ".tscn"):
				if _is_model_scene(path, kind):
					scenes[path] = true
		for path in used[kind]:
			scenes[path] = true
		for path in scenes:
			var problems: Array = ModelCheck.ship_problems(path) if kind == "ships" else ModelCheck.station_problems(path)
			out[kind][path] = {"users": used[kind].get(path, []), "problems": problems}
	return out


# The sound bank's slots: [{slot, kind, path ("" empty), loops}].
func cmd_sound_slots(_args: Dictionary):
	var bank = _fresh(Validator.SOUND_BANK_PATH)
	var out: Array = []
	for slot in SoundBank.SLOTS:
		var stream = bank.get(slot) if bank != null else null
		out.append({"slot": slot, "kind": SoundBank.SLOTS[slot], "path": stream.resource_path if stream is AudioStream else "",
			"loops": Validator.stream_loops(stream) if stream is AudioStream else false})
	return out


# Whether `source` (GDScript text) compiles: {"ok": bool}. Godot prints the parse error itself (the
# tool shows Godot's output).
func cmd_check_script(args: Dictionary):
	var script := GDScript.new()
	script.source_code = str(args.get("source", ""))
	return {"ok": script.reload() == OK}


# --- Fields and values ---

# The editable fields of `target` (a resource or node): its script's exported variables; a
# ShaderMaterial's shader and shader parameters; a Spatial's translation first.
static func fields_of(target: Object) -> Array:
	var fields: Array = []
	if target is Spatial:
		fields.append({"name": TRANSLATION, "type": "Vector3", "hint": 0, "hint_name": "", "hint_string": "",
			"default": encode(Vector3.ZERO), "comment": "Its place, m (x, y, z; y is up)"})
	if target is AudioStreamPlayer or target is AudioStreamPlayer3D:
		fields.append({"name": "stream", "type": "Object", "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_name": "resource",
			"hint_string": "AudioStream", "default": null, "comment": "What it plays (music: an .ogg or .mp3 that loops)"})
	if target is ShaderMaterial:
		fields.append({"name": "shader", "type": "Object", "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_name": "resource",
			"hint_string": "Shader", "default": null, "comment": "The shader (assets/art/shaders/)"})
		if target.shader != null:
			var comments: Dictionary = _shader_comments(target.shader)
			for param in VisualServer.shader_get_param_list(target.shader.get_rid()):
				fields.append({"name": SHADER_PARAM + param.name, "type": TYPE_NAMES.get(param.type, str(param.type)), "hint": param.hint,
					"hint_name": HINT_NAMES.get(param.hint, ""), "hint_string": param.hint_string, "default": null,
					"comment": comments.get(param.name, "")})
		return fields
	var script: Script = target.get_script()
	if script == null:
		return fields
	var probe = script.new() if not target is Node else null
	var comments: Dictionary = _comments(script)
	for property in script.get_script_property_list():
		if property.usage & EDITABLE != EDITABLE:
			continue
		fields.append({
			"name": property.name, "type": TYPE_NAMES.get(property.type, str(property.type)),
			"hint": property.hint, "hint_name": HINT_NAMES.get(property.hint, ""), "hint_string": property.hint_string,
			"default": encode(probe.get(property.name)) if probe != null else null, "comment": comments.get(property.name, ""),
		})
	return fields


static func values_of(target: Object) -> Dictionary:
	var values := {}
	for field in fields_of(target):
		values[field.name] = encode(target.get(field.name))
	return values


# Sets `values` (encoded) on `target`; "" or what was wrong.
static func set_values(target: Object, values: Dictionary) -> String:
	var types := {}
	for field in fields_of(target):
		types[field.name] = field.type
	for name in values:
		if not types.has(name):
			return "No field '%s'" % name
		var value = match_types(decode(values[name]), target.get(name))
		match types[name]:
			"float":
				value = float(value) if typeof(value) in [TYPE_INT, TYPE_REAL] else value
			"int":
				value = int(value) if typeof(value) in [TYPE_INT, TYPE_REAL] else value
			"PoolStringArray":
				value = PoolStringArray(value) if value is Array else value
			"PoolIntArray":
				value = PoolIntArray(value) if value is Array else value
			"PoolRealArray":
				value = PoolRealArray(value) if value is Array else value
		target.set(name, value)
	return ""


# `value` as JSON text, numbers as Godot writes them into files (to_json() rounds to 6 decimals, so a
# value read and written back would change).
static func json(value) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_REAL:
			if is_nan(value) or is_inf(value):
				return "null"
			var text: String = var2str(value)
			return text if "." in text or "e" in text else text + ".0"
		TYPE_STRING:
			return to_json(value)
		TYPE_ARRAY:
			var items: PoolStringArray = []
			for item in value:
				items.append(json(item))
			return "[" + items.join(",") + "]"
		TYPE_DICTIONARY:
			var pairs: PoolStringArray = []
			for key in value:
				pairs.append(to_json(str(key)) + ":" + json(value[key]))
			return "{" + pairs.join(",") + "}"
	return json(encode(value))


static func encode(value):
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_REAL, TYPE_STRING:
			return value
		TYPE_ARRAY, TYPE_STRING_ARRAY, TYPE_INT_ARRAY, TYPE_REAL_ARRAY:
			var out: Array = []
			for item in value:
				out.append(encode(item))
			return out
		TYPE_DICTIONARY:
			var plain := true
			for key in value:
				plain = plain and typeof(key) == TYPE_STRING
			if plain:
				var out := {}
				for key in value:
					out[key] = encode(value[key])
				return out
			return {"$": "Dictionary", "text": var2str(value)}
		TYPE_COLOR:
			return {"$": "Color", "text": var2str(value), "v": [value.r, value.g, value.b, value.a]}
		TYPE_VECTOR3:
			return {"$": "Vector3", "text": var2str(value), "v": [value.x, value.y, value.z]}
		TYPE_OBJECT:
			if value is Resource:
				return {"$": "Resource", "path": value.resource_path, "class": value.get_class()}
			return {"$": "Object", "text": str(value)}
	return {"$": TYPE_NAMES.get(typeof(value), "Variant"), "text": var2str(value)}


static func decode(value):
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(decode(item))
		return out
	if value is Dictionary:
		if not value.has("$"):
			var out := {}
			for key in value:
				out[key] = decode(value[key])
			return out
		match value["$"]:
			"Color":
				if value.has("v"):
					return Color(value.v[0], value.v[1], value.v[2], value.v[3] if value.v.size() > 3 else 1.0)
			"Vector3":
				if value.has("v"):
					return Vector3(value.v[0], value.v[1], value.v[2])
			"Resource":
				return load(value.path) if str(value.get("path", "")) != "" else null
			"int":
				return int(value.get("v", 0))
		return str2var(str(value.get("text", "null")))
	return value


# `value` with its numbers given the types they had in `like` (the field's value before), all the
# way down: JSON has one number type, and Godot reads every number as a float. A new array item
# takes the type of the array's first; a new key, of any other's.
static func match_types(value, like):
	if typeof(value) == TYPE_REAL and typeof(like) == TYPE_INT and value == floor(value):
		return int(value)
	if typeof(value) == TYPE_INT and typeof(like) == TYPE_REAL:
		return float(value)
	if value is Array and (like is Array or typeof(like) in [TYPE_INT_ARRAY, TYPE_REAL_ARRAY]):
		var out: Array = []
		for index in range(value.size()):
			out.append(match_types(value[index], like[min(index, like.size() - 1)] if like.size() > 0 else null))
		return out
	if value is Dictionary and like is Dictionary:
		var out := {}
		var any = like.values()[0] if like.size() > 0 else null
		for key in value:
			out[key] = match_types(value[key], like.get(key, any))
		return out
	return value


# --- Helpers ---

func _checked(path: String, before: Array) -> Dictionary:
	TemplateDatabase._factions.clear()  # Read again on next use
	TemplateDatabase._sector_layouts.clear()
	var problems: Array = Validator.for_file(path)
	var fresh: Array = []
	for problem in problems:
		if not "%s: %s" % [problem.file, problem.problem] in before:
			fresh.append(problem)
	return {"path": path, "problems": problems, "new": fresh}


# Sets `values` (encoded) on the node at `node_path` in `doc`, as text: `node` (the node as loaded,
# or a new one) gives each field's type, current value and default. A value the file does not set
# and that equals the default stays unset, as Godot would leave it; one it sets is rewritten in place.
static func _set_in_text(doc, node_path: String, node: Node, values: Dictionary) -> String:
	var types := {}
	for field in fields_of(node):
		types[field.name] = field.type
	var defaults: Object = null
	if node.get_script() != null:
		defaults = node.get_script().new()
	var error := ""
	for name in values:
		if not types.has(name):
			error = "No field '%s'" % name
			break
		var current = node.translation if name == TRANSLATION else node.get(name)
		var value = match_types(decode(values[name]), current)
		if types[name] == "float" and typeof(value) == TYPE_INT:
			value = float(value)
		elif types[name] == "int" and typeof(value) == TYPE_REAL:
			value = int(value)
		var key: String = name
		var default = defaults.get(name) if defaults != null else null
		if name == TRANSLATION:
			var transform: Transform = node.transform
			transform.origin = value
			key = "transform"
			value = transform
			default = Transform()
		var text: String = _value_text(doc, value)
		if text == "!":
			error = "%s: only a resource saved in a file can be set (%s)" % [name, value]
			break
		var existing: String = doc.get_property(node_path, key)
		var is_default: bool = var2str(value) == var2str(default) and not (value is Resource)
		if existing == text or (existing == "" and is_default):
			continue  # As it was; or unset, and its default holds
		doc.set_property(node_path, key, "" if is_default else text)  # Back to the default: the line goes
	if defaults is Node:
		defaults.free()
	doc.drop_unused_resources()
	return error


# A value's text in a scene file ("!" when it cannot be written there).
static func _value_text(doc, value) -> String:
	if value is Resource:
		if value.resource_path == "" or value.resource_path.find("::") >= 0:
			return "!"
		var type: String = value.get_class()
		for base in ["PackedScene", "Script", "Texture", "AudioStream", "Material"]:
			if ClassDB.is_parent_class(type, base):
				type = base
				break
		return "ExtResource( %d )" % doc.ext_id(value.resource_path, type)
	return var2str(value)


# Writes `new_text` to the scene at `path` and loads it again; if it does not load, puts `old_text`
# back. Then its rules.
func _save_text_checked(path: String, old_text: String, new_text: String, before: Array):
	if new_text == old_text:
		return _checked(path, before)
	_write_text(path, new_text)
	var loaded = ResourceLoader.load(path, "", true)
	var instance: Node = loaded.instance() if loaded is PackedScene else null
	if instance == null:
		_write_text(path, old_text)
		return {"error": "The edited %s did not load; left as it was" % path}
	instance.free()
	return _checked(path, before)


static func _read_text(path: String) -> String:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _write_text(path: String, text: String) -> void:
	var file := File.new()
	file.open(path, File.WRITE)
	file.store_string(text)
	file.close()


static func _freed(root: Node, result):
	root.free()
	return result


static func _edit_instance(path: String) -> Node:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed = ResourceLoader.load(path, "", true)
	return packed.instance(PackedScene.GEN_EDIT_STATE_INSTANCE) if packed is PackedScene else null


# The scene's own nodes (the root and what it owns), parents before children.
static func _own_nodes(root: Node) -> Array:
	var out: Array = []
	var queue: Array = [root]
	while not queue.empty():
		var node: Node = queue.pop_front()
		if node == root or node.owner == root:
			out.append(node)
		for child in node.get_children():
			queue.append(child)
	return out


# A node's place in its scene's space (it is not in the tree, so no global_transform).
static func _origin(node: Spatial) -> Vector3:
	var origin: Vector3 = node.transform.origin
	var parent = node.get_parent()
	while parent is Spatial:
		origin = parent.transform.xform(origin)
		parent = parent.get_parent()
	return origin


static func _texts(problems: Array) -> Array:
	var out: Array = []
	for problem in problems:
		out.append("%s: %s" % [problem.file, problem.problem])
	return out


static func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", true) if path != "" and ResourceLoader.exists(path) else null


# Whether the scene at `path` is a model (its root a ShipModel, or a StationModel), not a scene
# models go into (FactionStation) or anything else kept beside them.
static func _is_model_scene(path: String, kind: String) -> bool:
	var scene = load(path)
	if not scene is PackedScene:
		return false
	var root: Node = scene.instance()
	var base: Script = load("res://src/scenes/game_world/models/ship_model.gd" if kind == "ships" else "res://src/scenes/game_world/models/station_model.gd")
	var script: Script = root.get_script()
	root.free()
	while script != null:
		if script == base:
			return true
		script = script.get_base_script()
	return false


# Field name -> the comment after it, through the script's base scripts.
static func _comments(script: Script) -> Dictionary:
	var out := {}
	var regex := RegEx.new()
	regex.compile("^export[^\\n]*?var\\s+(\\w+)[^#\\n]*#\\s*(.+)$")
	while script != null:
		for line in script.source_code.split("\n"):
			var found: RegExMatch = regex.search(line)
			if found != null and not out.has(found.get_string(1)):
				out[found.get_string(1)] = found.get_string(2).strip_edges()
		script = script.get_base_script()
	return out


# Uniform name -> the comment after it in the shader.
static func _shader_comments(shader: Shader) -> Dictionary:
	var out := {}
	var regex := RegEx.new()
	regex.compile("^\\s*uniform\\s+\\w+\\s+(\\w+)[^/\\n]*//\\s*(.+)$")
	for line in shader.code.split("\n"):
		var found: RegExMatch = regex.search(line)
		if found != null:
			out[found.get_string(1)] = found.get_string(2).strip_edges()
	return out


static func _class_of(target: Object) -> String:
	var script: Script = target.get_script()
	if script == null:
		return target.get_class()
	var regex := RegEx.new()
	regex.compile("(?m)^class_name\\s+(\\w+)")
	var found: RegExMatch = regex.search(script.source_code)
	return found.get_string(1) if found != null else script.resource_path.get_file().get_basename()
