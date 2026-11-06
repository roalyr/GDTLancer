# BridgeCommands: what the development tool (tools/dev.py) asks of Godot, one method per command,
# each taking and returning plain data (JSON-safe; values with no JSON form travel as
# {"$": type, "text": var2str(value)}). bridge.gd runs these over stdin/stdout; the tests call them
# directly. Godot reads and writes every file, so what the tool saves is what the editor would.
# Commands: ping, schema, read, write, create, validate, models.

extends Reference

const Validator = preload("res://src/core/validation/content_validator.gd")
const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")
const EDITABLE = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR
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


# The editable fields of the resource at `path` (or of the script at `script`), in script order:
# [{name, type, hint, hint_string, default, comment}]: comment is the text after the field's `#`.
func cmd_schema(args: Dictionary):
	var script: Script = _script_for(args)
	if script == null:
		return {"error": "No script for %s" % args}
	var probe = script.new()
	var comments: Dictionary = _comments(script)
	var fields: Array = []
	for property in script.get_script_property_list():
		if property.usage & EDITABLE != EDITABLE:
			continue
		fields.append({
			"name": property.name, "type": TYPE_NAMES.get(property.type, str(property.type)),
			"hint": property.hint, "hint_name": HINT_NAMES.get(property.hint, ""), "hint_string": property.hint_string,
			"default": encode(probe.get(property.name)), "comment": comments.get(property.name, ""),
		})
	return {"script": script.resource_path, "class": _class_name(script), "fields": fields}


# The resource at `path`: its script, class and field values.
func cmd_read(args: Dictionary):
	var resource = _fresh(str(args.get("path", "")))
	if resource == null:
		return {"error": "Cannot load %s" % args.get("path", "")}
	var script: Script = resource.get_script()
	var values := {}
	if script != null:
		for property in script.get_script_property_list():
			if property.usage & EDITABLE == EDITABLE:
				values[property.name] = encode(resource.get(property.name))
	return {"path": str(args.path), "class": _class_name(script) if script != null else resource.get_class(),
		"script": script.resource_path if script != null else "", "values": values}


# Sets `values` on the resource at `path` and saves it; then its rules (ContentValidator.for_file):
# {"problems": [...], "new": [...]} (new: not there before the save).
func cmd_write(args: Dictionary):
	var path: String = str(args.get("path", ""))
	var resource = _fresh(path)
	if resource == null:
		return {"error": "Cannot load %s" % path}
	return _save_checked(path, resource, args.get("values", {}))


# A new resource of `script` at `path` (not over an existing file), with `values`.
func cmd_create(args: Dictionary):
	var path: String = str(args.get("path", ""))
	if path == "" or ResourceLoader.exists(path) or File.new().file_exists(path):
		return {"error": "%s exists already (or no path)" % path}
	var script: Script = _script_for(args)
	if script == null:
		return {"error": "No script %s" % args.get("script", "")}
	var dir := Directory.new()
	dir.make_dir_recursive(path.get_base_dir())
	return _save_checked(path, script.new(), args.get("values", {}))


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


# --- Values ---

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
			"Resource":
				return load(value.path) if str(value.get("path", "")) != "" else null
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

func _save_checked(path: String, resource: Resource, values: Dictionary):
	var before: Array = _texts(Validator.for_file(path)) if ResourceLoader.exists(path) else []
	var field_types := {}
	for property in resource.get_script().get_script_property_list():
		field_types[property.name] = property.type
	for name in values:
		if not field_types.has(name):
			return {"error": "%s has no field '%s'" % [path, name]}
		var value = match_types(decode(values[name]), resource.get(name))
		if field_types[name] == TYPE_REAL and typeof(value) == TYPE_INT:
			value = float(value)
		elif field_types[name] == TYPE_INT and typeof(value) == TYPE_REAL:
			value = int(value)
		elif field_types[name] in [TYPE_STRING_ARRAY, TYPE_INT_ARRAY, TYPE_REAL_ARRAY] and value is Array:
			value = convert(value, field_types[name])
		resource.set(name, value)
	var error: int = ResourceSaver.save(path, resource)
	if error != OK:
		return {"error": "Saving %s failed (%d)" % [path, error]}
	TemplateDatabase._factions.clear()  # Read again on next use
	TemplateDatabase._sector_layouts.clear()
	var problems: Array = Validator.for_file(path)
	var fresh: Array = []
	for problem in problems:
		if not "%s: %s" % [problem.file, problem.problem] in before:
			fresh.append(problem)
	return {"path": path, "problems": problems, "new": fresh}


static func _texts(problems: Array) -> Array:
	var out: Array = []
	for problem in problems:
		out.append("%s: %s" % [problem.file, problem.problem])
	return out


static func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", true) if path != "" and ResourceLoader.exists(path) else null


func _script_for(args: Dictionary) -> Script:
	if str(args.get("script", "")) != "":
		return load(str(args.script)) as Script
	var resource = _fresh(str(args.get("path", "")))
	return resource.get_script() if resource != null else null


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


static func _class_name(script: Script) -> String:
	if script == null:
		return ""
	var regex := RegEx.new()
	regex.compile("(?m)^class_name\\s+(\\w+)")
	var found: RegExMatch = regex.search(script.source_code)
	return found.get_string(1) if found != null else script.resource_path.get_file().get_basename()
