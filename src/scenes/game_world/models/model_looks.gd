# ModelLooks: gives a model's surfaces the game's materials by the names they had in Blender, so a
# model needs no material work in Godot (CONTENT.md, "Models"). A surface's material name (the
# imported material's name; Blender's ".001" suffixes, case and spaces aside) picks:
#   "paint"   the owner's paint (FactionTemplate.hull_material for ships, station_material for
#             stations), given at spawn;
#   "<name>"  the library material LIBRARY_DIR/mat_<name>.tres, when there is one ("hull_dark_metal",
#             "radiator_graphite", ...; ALIASES lists short names);
#   anything else keeps its imported material, which lacks the game's shader (unknown_tags lists
#   those, and the content test fails on them).
# Placeholder primitives (PrimitiveForm) mark painted parts by node name ("Paint...") instead.

tool
extends Reference

const LIBRARY_DIR = "res://assets/art/materials_generic/"
const PAINT_TAG = "paint"
const PAINT_PREFIX = "Paint"  # Placeholder parts named so take the paint too
const ALIASES = {"glow": "hull_glow", "metal": "hull_dark_metal", "dark": "hull_panel_dark", "light": "hull_panel_offwhite"}
const _LIBRARY := {}  # Tag -> library Material (null: none by that name)


# Gives every surface under `root` its material by name, and the painted ones `paint` (null: leaves
# them as they are). Before MeshLod.attach: lower levels copy the original's materials.
static func dress(root: Node, paint: Material) -> void:
	for node in _mesh_instances(root):
		if paint != null and node.name.begins_with(PAINT_PREFIX):
			node.material_override = paint
			continue
		for surface in range(node.mesh.get_surface_count()):
			var tag: String = tag_of(node.mesh.surface_get_material(surface))
			if tag == "":
				continue
			if tag == PAINT_TAG:
				if paint != null:
					node.set_surface_material(surface, paint)
				continue
			var material: Material = library_material(tag)
			if material != null:
				node.set_surface_material(surface, material)


# The material names under `root` that are neither "paint" nor in the library (sorted).
static func unknown_tags(root: Node) -> Array:
	var found := {}
	for node in _mesh_instances(root):
		for surface in range(node.mesh.get_surface_count()):
			var tag: String = tag_of(node.mesh.surface_get_material(surface))
			if tag != "" and tag != PAINT_TAG and library_material(tag) == null:
				found[tag] = true
	var tags: Array = found.keys()
	tags.sort()
	return tags


# Whether anything under `root` takes the owner's paint.
static func has_paint(root: Node) -> bool:
	for node in _mesh_instances(root):
		if node.name.begins_with(PAINT_PREFIX):
			return true
		for surface in range(node.mesh.get_surface_count()):
			if tag_of(node.mesh.surface_get_material(surface)) == PAINT_TAG:
				return true
	return false


# A material's name as a tag: lower case, spaces as underscores, without Blender's duplicate suffix
# ("Hull Dark Metal.001" -> "hull_dark_metal"); "" if it has none.
static func tag_of(material: Material) -> String:
	if material == null:
		return ""
	var key: String = material.resource_name
	var dot: int = key.find_last(".")
	if dot > 0 and key.substr(dot + 1).is_valid_integer():
		key = key.substr(0, dot)
	return key.strip_edges().to_lower().replace(" ", "_")


static func library_material(tag: String) -> Material:
	tag = ALIASES.get(tag, tag)
	if not _LIBRARY.has(tag):
		var path: String = LIBRARY_DIR.plus_file("mat_%s.tres" % tag)
		_LIBRARY[tag] = load(path) if ResourceLoader.exists(path) else null
	return _LIBRARY[tag]


# The bounds of the meshes under `root`, in root space (effects under an "Engines" node left out).
static func bounds(root: Spatial) -> AABB:
	var box := AABB()
	var found := false
	var stack: Array = [[root, Transform.IDENTITY]]
	while not stack.empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		if node != root and node.name == "Engines":
			continue
		if node is MeshInstance and node.mesh != null:
			var placed: AABB = item[1].xform(node.get_aabb())
			box = placed if not found else box.merge(placed)
			found = true
		for child in node.get_children():
			if child is Spatial:
				stack.append([child, item[1] * child.transform])
	return box


# The far corner of the meshes under `root` from its origin, and their top, in root space: [radius, top].
static func extent(root: Spatial) -> Array:
	var box: AABB = bounds(root)
	var radius := 0.0
	for index in range(8):
		radius = max(radius, box.get_endpoint(index).length())
	return [radius, box.end.y]


static func _mesh_instances(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.empty():
		var node: Node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance and node.mesh != null:
			out.append(node)
	return out
