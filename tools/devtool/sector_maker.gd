# SectorMaker: makes, copies and removes sectors and their bodies as files, named by SectorNames, so
# what the tool makes keeps the sector rules (ContentValidator.sector_folders). BridgeCommands runs
# these (sector_new, sector_clone, body_new, body_remove, layout_new) and checks the rules after.
# Each takes `dir`, the sectors folder, and `locations`, the locations folder (others only for tests),
# and returns {"error": text} or what it made: {"scene", "files" (every file written), ...}.

extends Reference

const SectorNames = preload("res://src/core/validation/sector_names.gd")
const TscnText = preload("res://tools/devtool/tscn_text.gd")
const SECTOR_LAYOUT_SCRIPT = "res://src/scenes/game_world/sector_layout/sector_layout.gd"
const SCENE_ASSETS = "SceneAssets"
const ENTRY_REACH = 20000.0  # m: a new sector's entry, as far out as Elace's, when its location has none

const SCENE_TEMPLATE = """[gd_scene load_steps=3 format=2]

[ext_resource path="res://src/scenes/game_world/starsphere_slot.gd" type="Script" id=1]
[ext_resource path="res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn" type="PackedScene" id=2]

[node name="%s" type="Spatial"]

[node name="AgentContainer" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}

[node name="StarsphereSlot" type="Spatial" parent="."]
script = ExtResource( 1 )
__meta__ = {
"_edit_lock_": true
}

[node name="Globalnebulas" parent="StarsphereSlot" instance=ExtResource( 2 )]
visible = false

[node name="SceneAssets" type="Spatial" parent="."]
__meta__ = {
"_edit_lock_": true
}
"""

const LAYOUT_TEMPLATE = """[gd_scene load_steps=3 format=2]

[ext_resource path="res://src/scenes/game_world/sector_layout/markers/sector_layout_markers.gd" type="Script" id=1]
[ext_resource path="res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd" type="Script" id=2]

[node name="Layout" type="Spatial"]
script = ExtResource( 1 )
sector_id = "%s"

[node name="Hazards" type="Spatial" parent="."]

[node name="Havens" type="Spatial" parent="."]

[node name="Beacons" type="Spatial" parent="."]

[node name="Entry" type="Position3D" parent="Beacons"]
transform = %s
script = ExtResource( 2 )
kind = "entry"
beacon_name = "%s"
radius = %s
"""


static func scene_of(dir: String, sector: String) -> String:
	return dir.plus_file(sector).plus_file(sector + ".tscn")


static func layout_of(dir: String, sector: String) -> String:
	return dir.plus_file(sector).plus_file(sector + "_layout.tscn")


static func location_of(locations: String, sector: String) -> String:
	return locations.plus_file(sector + ".tres")


# A new sector `sector`: its folder, an empty sector scene, its layout (an entry beacon at the
# middle) and its location (made, or the one there pointed at the scene). Returns {"scene", "files"}.
static func new_sector(dir: String, locations: String, sector: String) -> Dictionary:
	var problem: String = SectorNames.sector_problem(sector)
	if problem != "":
		return {"error": problem}
	if Directory.new().dir_exists(dir.plus_file(sector)):
		return {"error": "%s is there already" % sector}
	Directory.new().make_dir_recursive(dir.plus_file(sector))
	var scene: String = scene_of(dir, sector)
	_write(scene, SCENE_TEMPLATE % SectorNames.title(sector))
	var made: Dictionary = new_layout(dir, locations, sector)
	if made.has("error"):
		_remove_files([scene])
		Directory.new().remove(dir.plus_file(sector))
		return made
	var location_path: String = location_of(locations, sector)
	var location = ResourceLoader.load(location_path, "", true) if ResourceLoader.exists(location_path) else null
	var files: Array = [scene, layout_of(dir, sector)]
	if location == null:
		location = LocationTemplate.new()
		location.template_id = sector
		location.location_name = SectorNames.title(SectorNames.word_of(sector))
		location.jump_in_distance = ENTRY_REACH
		files.append(location_path)
	location.sector_scene_path = scene
	location.is_procedural = false
	ResourceSaver.save(location_path, location)
	return {"scene": scene, "files": files, "location": location_path}


# A layout for `sector`, which has a scene and no layout: its groups and an entry beacon (where
# the scene's EntryPoint is, else the middle; as far out as the location's jump_in_distance),
# placed in the sector scene under SceneAssets/SectorLayout. Returns {"scene", "layout", "files"}.
static func new_layout(dir: String, locations: String, sector: String) -> Dictionary:
	var scene_path: String = scene_of(dir, sector)
	var layout_path: String = layout_of(dir, sector)
	var scene_text: String = _read(scene_path)
	if sector == "" or scene_text == "":
		return {"error": "No sector scene %s" % scene_path}
	if File.new().file_exists(layout_path):
		return {"error": "%s has a layout already" % sector}
	var doc = TscnText.new(scene_text)
	if doc.find_node(SCENE_ASSETS) == null:
		return {"error": "%s has no %s node" % [scene_path, SCENE_ASSETS]}
	var entry := Vector3.ZERO
	var packed = ResourceLoader.load(scene_path, "", true)
	var root: Node = packed.instance(PackedScene.GEN_EDIT_STATE_INSTANCE) if packed is PackedScene else null
	if root != null:
		var entry_node: Node = root.find_node("EntryPoint", true, false)
		if entry_node is Spatial:
			var place: Transform = entry_node.transform
			var parent: Node = entry_node.get_parent()
			while parent != root and parent is Spatial:
				place = parent.transform * place
				parent = parent.get_parent()
			entry = place.origin
		root.free()
	var location_path: String = location_of(locations, sector)
	var location = ResourceLoader.load(location_path, "", true) if ResourceLoader.exists(location_path) else null
	var reach: float = float(location.jump_in_distance) if location != null and location.jump_in_distance > 0.0 else ENTRY_REACH
	var name: String = (location.location_name if location != null and location.location_name != "" else SectorNames.title(SectorNames.word_of(sector))) + " Entry"
	_write(layout_path, LAYOUT_TEMPLATE % [sector, var2str(Transform(Basis(), entry)), name.c_escape(), var2str(reach)])
	var holder: String = doc.add_node(SCENE_ASSETS, "SectorLayout", "Spatial", doc.ext_id(SECTOR_LAYOUT_SCRIPT, "Script"))
	doc.add_instance(holder, "Layout", layout_path)
	_write(scene_path, doc.text())
	if not _loads(scene_path):
		_write(scene_path, scene_text)
		_remove_files([layout_path])
		return {"error": "The sector scene with its layout did not load; left as it was"}
	return {"scene": scene_path, "layout": layout_path, "files": [layout_path]}


# The bodies' folders of `sector`: stem -> its scene's path.
static func bodies_of(dir: String, sector: String) -> Dictionary:
	var out := {}
	var folder: String = dir.plus_file(sector)
	var listing := Directory.new()
	if listing.open(folder) != OK:
		return out
	listing.list_dir_begin(true, true)
	var name: String = listing.get_next()
	while name != "":
		if listing.current_is_dir():
			out[name] = folder.plus_file(name).plus_file(name + ".tscn")
		name = listing.get_next()
	return out


# A new body of `kind` in `sector`, a copy of the body scene `from` (its folder's files, renamed),
# named by SectorNames.next_name (a moon of planet `of`; a belt's `word`), placed in the sector scene
# at `at`. Returns {"scene", "node" (its path in the sector scene), "body" (its scene), "files"}.
static func new_body(dir: String, sector: String, kind: String, from: String, at: Vector3, of: String = "", word: String = "") -> Dictionary:
	if not kind in SectorNames.KINDS:
		return {"error": "No kind of body '%s' (%s)" % [kind, PoolStringArray(SectorNames.KINDS).join(", ")]}
	var scene_path: String = scene_of(dir, sector)
	var scene_text: String = _read(scene_path)
	if scene_text == "":
		return {"error": "No sector scene %s" % scene_path}
	var from_text: String = _read(from)
	if from_text == "":
		return {"error": "No body scene %s to copy" % from}
	if (kind == "star") != (from_text.find("is_star = true") >= 0):
		return {"error": "A %s is made from a %s scene; %s is %s" % [kind, "star" if kind == "star" else "body that is no star", from.get_file(), "a star" if kind != "star" else "no star"]}
	var taken: Array = bodies_of(dir, sector).keys()
	var stem: String = SectorNames.next_name(sector, kind, taken, of, word)
	if stem == "":
		return {"error": "No name for a new %s%s" % [kind, " (a moon needs its planet's letter; a belt, a word in lower_snake_case not taken)" if kind in ["moon", "belt"] else ""]}
	if kind == "moon" and not "planet_%s_%s" % [SectorNames.word_of(sector), of] in taken:
		return {"error": "%s has no planet %s" % [sector, of.to_upper()]}
	var copied: Dictionary = copy_body(from, dir.plus_file(sector).plus_file(stem))
	if copied.has("error"):
		return copied
	var doc = TscnText.new(scene_text)
	var added: String = doc.add_instance(SCENE_ASSETS, SectorNames.title(stem), copied.scene)
	if at != Vector3.ZERO:
		doc.set_property(added, "transform", var2str(Transform(Basis(), at)))
	_write(scene_path, doc.text())
	if not _loads(scene_path):
		_write(scene_path, scene_text)
		_remove_files(copied.files)
		Directory.new().remove(dir.plus_file(sector).plus_file(stem))
		return {"error": "The sector scene with %s did not load; left as it was" % stem}
	return {"scene": scene_path, "node": added, "body": copied.scene, "files": copied.files}


# Copies the body folder of the scene `from` to `folder` (a new body's), renaming its files and
# the paths between them after the new body, each file's root named after its file. Returns
# {"scene", "files"}.
static func copy_body(from: String, folder: String) -> Dictionary:
	var from_folder: String = from.get_base_dir()
	var from_stem: String = from.get_file().get_basename()
	var stem: String = folder.get_file()
	if Directory.new().dir_exists(folder):
		return {"error": "%s is there already" % folder}
	var own_folder: bool = from_folder.get_file() == from_stem  # A body's folder; else a prefab, copied alone
	var names: Array = [from.get_file()]
	var listing := Directory.new()
	if own_folder and listing.open(from_folder) == OK:
		listing.list_dir_begin(true, true)
		var name: String = listing.get_next()
		while name != "":
			if not listing.current_is_dir() and name.ends_with(".tscn") and name.begins_with(from_stem + "_"):
				names.append(name)  # Its parts
			name = listing.get_next()
	Directory.new().make_dir_recursive(folder)
	var files: Array = []
	for file_name in names:
		var new_name: String = stem + file_name.get_basename().trim_prefix(from_stem) + ".tscn"
		var text: String = _read(from_folder.plus_file(file_name))
		if own_folder:
			text = text.replace(from_folder.plus_file(from_stem), folder.plus_file(stem))
		text = _with_root_name(text, SectorNames.title(new_name.get_basename()))
		_write(folder.plus_file(new_name), text)
		files.append(folder.plus_file(new_name))
	return {"scene": folder.plus_file(stem + ".tscn"), "files": files}


# Removes the body `node` from the sector scene; if it was one of the sector's own bodies, its
# folder goes too. Returns {"scene", "deleted": [files]}.
static func remove_body(dir: String, sector: String, node: String) -> Dictionary:
	var scene_path: String = scene_of(dir, sector)
	var scene_text: String = _read(scene_path)
	var doc = TscnText.new(scene_text)
	var section = doc.find_node(node)
	if section == null or node == ".":
		return {"error": "%s has no %s" % [scene_path, node]}
	var scene: String = ""
	var regex := RegEx.new()
	regex.compile("instance=ExtResource\\( ([0-9]+) \\)")
	var found = regex.search(section.head)
	if found != null:
		scene = SectorNames.ext_resources(scene_text).get(int(found.get_string(1)), "")
	doc.remove_node(node)
	doc.drop_unused_resources()
	_write(scene_path, doc.text())
	if not _loads(scene_path):
		_write(scene_path, scene_text)
		return {"error": "The sector scene without %s did not load; left as it was" % node}
	var deleted: Array = []
	var folder: String = scene.get_base_dir()
	if scene != "" and folder.get_base_dir() == dir.plus_file(sector) and doc.text().find('path="%s"' % scene) < 0:
		var listing := Directory.new()
		if listing.open(folder) == OK:
			listing.list_dir_begin(true, true)
			var name: String = listing.get_next()
			while name != "":
				if not listing.current_is_dir():
					deleted.append(folder.plus_file(name))
				name = listing.get_next()
		_remove_files(deleted)
		Directory.new().remove(folder)
	return {"scene": scene_path, "deleted": deleted}


# A copy of the sector `from` as `to`: every body (renamed for `to`), its scene and layout (the
# havens' ids made its own, names "From" -> "To") and its location, with no connections (no one
# jumps there: a sector apart, as evolution's). Returns {"scene", "files"}.
static func clone_sector(dir: String, locations: String, from: String, to: String) -> Dictionary:
	var problem: String = SectorNames.sector_problem(to)
	if problem != "":
		return {"error": problem}
	if Directory.new().dir_exists(dir.plus_file(to)):
		return {"error": "%s is there already" % to}
	if _read(scene_of(dir, from)) == "":
		return {"error": "No sector %s to copy" % from}
	var from_word: String = SectorNames.word_of(from)
	var to_word: String = SectorNames.word_of(to)
	var paths := {}  # Old path -> new, for every file
	var titles := {}  # Old body title -> new
	var files: Array = []
	Directory.new().make_dir_recursive(dir.plus_file(to))
	var bodies: Dictionary = bodies_of(dir, from)
	for stem in bodies:
		var parts: Dictionary = SectorNames.body_parts(from, stem)
		if parts.has("problem"):
			_remove_files(files)
			return {"error": "%s keeps not the rules: %s" % [from, parts.problem]}
		var new_stem: String = "%s_%s%s" % [parts.kind, to_word, "_" + parts.suffix if parts.suffix != "" else ""]
		var copied: Dictionary = copy_body(bodies[stem], dir.plus_file(to).plus_file(new_stem))
		if copied.has("error"):
			_remove_files(files)
			return copied
		files += copied.files
		paths[bodies[stem]] = copied.scene
		titles[SectorNames.title(stem)] = SectorNames.title(new_stem)
	paths[layout_of(dir, from)] = layout_of(dir, to)
	var scene_text: String = _read(scene_of(dir, from))
	for old in paths:
		scene_text = scene_text.replace('path="%s"' % old, 'path="%s"' % paths[old])
	for old in titles:
		scene_text = scene_text.replace('name="%s"' % old, 'name="%s"' % titles[old])
	scene_text = _with_root_name(scene_text, SectorNames.title(to))
	_write(scene_of(dir, to), scene_text)
	files.append(scene_of(dir, to))
	var layout_text: String = _read(layout_of(dir, from))
	if layout_text != "":
		for old in titles:
			layout_text = layout_text.replace('"SceneAssets/%s"' % old, '"SceneAssets/%s"' % titles[old])
		layout_text = layout_text.replace('sector_id = "%s"' % from, 'sector_id = "%s"' % to)
		layout_text = _renamed_lines(layout_text, ["display_name", "beacon_name", "[node name"], SectorNames.title(from_word), SectorNames.title(to_word))
		layout_text = _own_haven_ids(layout_text, from_word, to_word)
		_write(layout_of(dir, to), layout_text)
		files.append(layout_of(dir, to))
	var from_location = ResourceLoader.load(location_of(locations, from), "", true) if ResourceLoader.exists(location_of(locations, from)) else null
	var location = from_location.duplicate() if from_location != null else LocationTemplate.new()
	location.template_id = to
	location.location_name = SectorNames.title(to_word)
	location.sector_scene_path = scene_of(dir, to)
	location.connections = PoolStringArray()
	ResourceSaver.save(location_of(locations, to), location)
	files.append(location_of(locations, to))
	if not _loads(scene_of(dir, to)):
		_remove_files(files)
		return {"error": "The copied sector scene did not load"}
	return {"scene": scene_of(dir, to), "files": files, "location": location_of(locations, to)}


# Haven ids are the game's own everywhere (a sector's apart): an id with the old word gets the
# new one; another gets the new word in front.
static func _own_haven_ids(text: String, from_word: String, to_word: String) -> String:
	var lines: Array = text.split("\n")
	for i in range(lines.size()):
		var line: String = lines[i]
		if line.begins_with('haven_id = "'):
			var id: String = line.trim_prefix('haven_id = "').trim_suffix('"')
			id = id.replace(from_word, to_word) if id.find(from_word) >= 0 else to_word + "_" + id
			lines[i] = 'haven_id = "%s"' % id
	return PoolStringArray(lines).join("\n")


static func _renamed_lines(text: String, keys: Array, old: String, new: String) -> String:
	var lines: Array = text.split("\n")
	for i in range(lines.size()):
		for key in keys:
			if lines[i].begins_with(key + ' = "') or (key.begins_with("[") and lines[i].begins_with(key + '="')):
				lines[i] = lines[i].replace(old, new)
	return PoolStringArray(lines).join("\n")


static func _with_root_name(text: String, name: String) -> String:
	var regex := RegEx.new()
	regex.compile('\\[node name="[^"]+" type="([^"]+)"\\]')
	var found = regex.search(text)
	if found == null:
		return text
	return text.substr(0, found.get_start()) + '[node name="%s" type="%s"]' % [name, found.get_string(1)] + text.substr(found.get_end())


static func _loads(path: String) -> bool:
	var packed = ResourceLoader.load(path, "", true)
	if not packed is PackedScene:
		return false
	var root: Node = packed.instance()
	if root == null:
		return false
	root.free()
	return true


static func _remove_files(paths: Array) -> void:
	for path in paths:
		Directory.new().remove(path)
	var folders := {}
	for path in paths:
		folders[path.get_base_dir()] = true
	for folder in folders:
		Directory.new().remove(folder)  # Only if empty


static func _read(path: String) -> String:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _write(path: String, text: String) -> void:
	var file := File.new()
	file.open(path, File.WRITE)
	file.store_string(text)
	file.close()
