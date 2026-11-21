# ShipModel: the root of a ship's model scene (an archetype's or hull's `ship_scene`). What the game
# needs from a ship model (CONTENT.md, "Models"):
# - Size: Constants.SHIP_MODEL_LENGTH (17 m) nose to tail at scale 1 (tools/import_model.sh fits a
#   model made at any size to it), nose to -Z, top to +Y. The ship's model_scale (its preset's)
#   stretches it to the ship's size.
# - Materials by their names in Blender (ModelLooks): "paint" takes the faction's paint.
# - Engines: a main nozzle facing each way, since a ship flies at top speed in any direction. An
#   empty in Blender (a Position3D in Godot) named "Engine..." at each nozzle; the word after
#   "Engine" says which way its exhaust points: Rear (or none), Front, Top, Bottom, Left, Right
#   (NOZZLE_DIRECTIONS; "EngineTop.001" is a top nozzle). Its rotation is ignored, its scale sizes
#   the exhaust. Exhausts are added as the scene instances, each turned its way; a nozzle burns as
#   the ship's thrust pushes away from its exhaust (EngineExhaustSet).
#   A scene with an "Engines" node of its own (EngineExhaustSet) keeps that instead: its exhausts'
#   own +Z is their direction.
# - Hardpoints: empties named "Weapon..." (tools) and "Module..." (modules), fixed, facing forward.
#   Each fitted part that is not internal (its template's `internal`) takes the next free hardpoint
#   of its kind, in the scene's order, and shows there (mount_parts; Constants.PART_FORMS); internal
#   parts take none. A part with no hardpoint left is not drawn. Hardpoints only show the fit: tools
#   still fire from the ship's centre.
# - Nothing else: the collision hull, hit surface and levels of detail come from the model's .glb
#   files (CollisionHull, MeshLod; tools/import_model.sh makes the LODs and hit surfaces).

tool
extends Spatial

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")
const ExhaustScene = preload("res://scenes/prefabs/effects/engine_exhaust.tscn")
const ExhaustSet = preload("res://src/core/agents/effects/engine_exhaust_set.gd")
const PrimitiveForm = preload("res://src/scenes/game_world/models/primitive_form.gd")
const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const ENGINE_PREFIX = "Engine"
const WEAPON_PREFIX = "Weapon"
const MODULE_PREFIX = "Module"
const MOUNTS = "Mounts"  # The node mount_parts builds the fitted parts under
# Which way a nozzle's exhaust points, in model space (nose -Z, top +Y), by the word after "Engine".
const NOZZLE_DIRECTIONS = {
	"rear": Vector3(0, 0, 1),
	"front": Vector3(0, 0, -1),
	"top": Vector3(0, 1, 0),
	"bottom": Vector3(0, -1, 0),
	"right": Vector3(1, 0, 0),
	"left": Vector3(-1, 0, 0),
}


func _notification(what: int) -> void:
	if what == NOTIFICATION_INSTANCED:
		ModelLooks.dress(self, null)
		if not Engine.editor_hint:
			add_exhausts(self)


# Takes `material` on the painted surfaces (FactionTemplate.hull_material).
func paint(material: Material) -> void:
	ModelLooks.dress(self, material)


static func is_engine_marker(node: Node) -> bool:
	return _is_marker(node, ENGINE_PREFIX)


# Which way the exhaust of an engine marker named `marker_name` points ("rear" unless the word after
# "Engine" says otherwise).
static func nozzle_direction(marker_name: String) -> String:
	var word: String = ""
	for character in marker_name.substr(ENGINE_PREFIX.length()).to_lower():
		if character >= "a" and character <= "z":
			word += character
	for direction in NOZZLE_DIRECTIONS:
		if word.begins_with(direction):
			return direction
	return "rear"


# A basis that turns +Z (an exhaust's own direction) to `direction`, scaled by `scale`.
static func exhaust_basis(direction: Vector3, scale: Vector3) -> Basis:
	var z: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP if abs(z.y) < 0.9 else Vector3.BACK
	var x: Vector3 = up.cross(z).normalized()
	return Basis(x * scale.x, z.cross(x) * scale.y, z * scale.z)


# An exhaust at each engine marker, turned the way its name says, under an "Engines" node
# (EngineExhaustSet) of `root`.
static func add_exhausts(root: Spatial) -> void:
	if root.has_node("Engines"):
		return
	var markers: Array = _markers(root, ENGINE_PREFIX, true)
	if markers.empty():
		return
	var engines := Spatial.new()
	engines.name = "Engines"
	engines.set_script(ExhaustSet)
	for marker in markers:
		var placed: Transform = marker[1]
		var exhaust: Spatial = ExhaustScene.instance()
		exhaust.transform = Transform(exhaust_basis(NOZZLE_DIRECTIONS[nozzle_direction(marker[0])], placed.basis.get_scale()), placed.origin)
		engines.add_child(exhaust)
	root.add_child(engines)


# The weapon ("Weapon...") and module ("Module...") hardpoints under `root`, in root space, in the
# scene's order: {"tools": [Transform], "modules": [Transform]}.
static func hardpoints(root: Node) -> Dictionary:
	return {"tools": _markers(root, WEAPON_PREFIX), "modules": _markers(root, MODULE_PREFIX)}


# Shows each fitted part that is not internal (ShipFit fit: {"tools": [id], "modules": [id]}) at
# the next free hardpoint of its kind, under a "Mounts" node of `root` (rebuilt on every call), its
# paint parts in `paint` (null: the library's). Returns how many parts found no hardpoint.
static func mount_parts(root: Spatial, fit: Dictionary, paint: Material = null) -> int:
	var old: Node = root.get_node_or_null(MOUNTS)
	if old != null:
		root.remove_child(old)
		old.queue_free()
	var points: Dictionary = hardpoints(root)
	var mounts := Spatial.new()
	mounts.name = MOUNTS
	var missing := 0
	for group in ["tools", "modules"]:
		var free: Array = points[group]
		var used := 0
		for part_id in fit.get(group, []):
			var part = _template(str(part_id))
			if part == null or bool(part.get("internal")):
				continue
			if used >= free.size():
				missing += 1
				continue
			var form: Spatial = part_form(part)
			form.transform = free[used] * form.transform
			mounts.add_child(form)
			used += 1
	if mounts.get_child_count() == 0:
		mounts.free()
		return missing
	ModelLooks.dress(mounts, paint)
	root.add_child(mounts)
	return missing


# A part's look at a hardpoint (Constants.PART_FORMS by its kind, PART_FORM_LENGTH by its own mount
# size), facing forward (-Z).
static func part_form(part: Resource) -> Spatial:
	var kind: String = part_kind(part)
	var parts: Array = Defaults.PART_FORMS.get(kind, Defaults.PART_FORMS.get("default", []))
	var form: Spatial = PrimitiveForm.build(parts, float(Defaults.PART_FORM_LENGTH.get(part_size(part), 1.0)))
	form.name = kind.capitalize().replace(" ", "") if kind != "" else "Part"
	return form


# A part's mount size: a tool's own, a module's by its weight (ShipFit.module_mount_size).
static func part_size(part: Resource) -> String:
	if "mount_size" in part:
		return str(part.mount_size)
	return ["small", "medium", "large"][int(clamp(int(part.get("variant_type")) - 1, 0, 2))]


# A tool's tool_type or a module's module_kind ("" for a hand-made module without one).
static func part_kind(part: Resource) -> String:
	if "tool_type" in part:
		return str(part.tool_type)
	return str(part.get("module_kind"))


static func _template(part_id: String) -> Resource:
	var tree = Engine.get_main_loop()
	if part_id == "" or Engine.editor_hint or not tree is SceneTree:
		return null
	var database: Node = tree.root.get_node_or_null("TemplateDatabase")
	var found = database.get_template(part_id) if database != null else null
	var path: String = Defaults.PARTS_DIR.plus_file(part_id + ".tres")
	if found == null and ResourceLoader.exists(path):  # A catalogue part not indexed (tests, tools)
		found = load(path)
	return found


# The markers named `prefix`... under `root`, in root space and the scene's order: their
# Transforms, or with `named` [name, Transform] pairs. "Engines" and "Mounts" nodes are skipped.
static func _markers(root: Node, prefix: String, named: bool = false) -> Array:
	var out: Array = []
	_collect(root, Transform.IDENTITY, prefix, named, out)
	return out


static func _collect(node: Node, to_root: Transform, prefix: String, named: bool, out: Array) -> void:
	if node.name == "Engines" or node.name == MOUNTS:
		return
	if _is_marker(node, prefix):
		out.append([str(node.name), to_root] if named else to_root)
	for child in node.get_children():
		if child is Spatial:
			_collect(child, to_root * child.transform, prefix, named, out)


static func _is_marker(node: Node, prefix: String) -> bool:
	return node is Spatial and not node is VisualInstance and node.name.begins_with(prefix) and node.name != "Engines"
