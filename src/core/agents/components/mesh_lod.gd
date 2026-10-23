# MeshLod: swaps a model for its lower-detail versions with distance from the camera.
# Godot 3's own GeometryInstance LOD distances do nothing, so this does it by visibility.
# LOD files come from tools/generate_lods.py: <model folder>/lod/<model>_LOD<n>.glb, with the
# same node names as the original. attach() finds every such model under a visual root.
# Levels switch at a number of object radii from the camera (a big rock keeps its detail further
# out than a small ship): Constants.LOD_DISTANCE_RADII for low-poly models,
# LOD_DISTANCE_RADII_DENSE for dense ones; with Constants.LOD_HYSTERESIS so they do not flicker.
# Distances are view distances (ScreenSpace.view_distance): zooming in on a far model shows it in detail.
# Lower levels take the original's materials and join group "lod_mesh".

extends Node

const ScreenSpace = preload("res://src/core/ui/screen_space.gd")

var levels: Array = []  # Spatial roots, LOD0 (the original) first
var radius: float = 10.0  # World radius of the object
var distance_radii: Array = Constants.LOD_DISTANCE_RADII
var level: int = 0

var _timer := 0.0



# Adds a MeshLod for every model under `visual_root` that has LOD files. Returns the MeshLod nodes.
static func attach(visual_root: Node, object_radius: float, thresholds: Array = Constants.LOD_DISTANCE_RADII) -> Array:
	var created: Array = []
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		var paths: Array = lod_paths_for(node.filename) if node is Spatial and node.filename != "" else []
		if paths.empty():
			stack += node.get_children()
			continue
		var lod = load("res://src/core/agents/components/mesh_lod.gd").new()
		lod.name = "MeshLod"
		node.get_parent().add_child(lod)
		lod.distance_radii = thresholds
		lod.setup(node, paths, object_radius)
		created.append(lod)
	return created


# res:// paths of the LOD files for a model scene path, in order; empty if there are none.
static func lod_paths_for(model_path: String) -> Array:
	var paths: Array = []
	if not model_path.ends_with(".glb"):
		return paths
	var base: String = model_path.get_file().get_basename()
	var folder: String = model_path.get_base_dir() + "/lod/"
	var index := 1
	while ResourceLoader.exists(folder + "%s_LOD%d.glb" % [base, index]):
		paths.append(folder + "%s_LOD%d.glb" % [base, index])
		index += 1
	return paths


func setup(original: Spatial, paths: Array, object_radius: float) -> void:
	radius = max(object_radius, 0.1)
	levels = [original]
	for path in paths:
		var copy: Spatial = load(path).instance()
		copy.transform = original.transform
		copy.visible = false
		original.get_parent().add_child(copy)
		_match_materials(original, copy)
		levels.append(copy)
	_timer = randf() * Constants.LOD_CHECK_INTERVAL  # Spread the checks over frames


# Each LOD mesh takes the materials of the original node of the same name.
# Surfaces are matched by their imported material's name (Blender's ".001" suffixes aside):
# decimation can drop a material from a level, which shifts the surfaces after it.
func _match_materials(original: Node, copy: Node) -> void:
	for node in _all_nodes(copy):
		if not node is MeshInstance:
			continue
		node.add_to_group("lod_mesh")
		var source = original.get_node_or_null(copy.get_path_to(node))
		if not source is MeshInstance:
			continue
		if source.material_override != null:
			node.material_override = source.material_override
		var by_name := {}
		for surface in range(source.mesh.get_surface_count()):
			by_name[material_key(source.mesh.surface_get_material(surface))] = surface
		for surface in range(node.mesh.get_surface_count()):
			var key: String = material_key(node.mesh.surface_get_material(surface))
			var source_surface: int = by_name.get(key, surface) if key != "" else surface
			if source_surface < source.get_surface_material_count() and source.get_surface_material(source_surface) != null:
				node.set_surface_material(surface, source.get_surface_material(source_surface))


# A material's name without Blender's duplicate suffix ("metal.001" -> "metal"); "" if unnamed.
static func material_key(material: Material) -> String:
	if material == null:
		return ""
	var key: String = material.resource_name
	var dot: int = key.find_last(".")
	if dot > 0 and key.substr(dot + 1).is_valid_integer():
		key = key.substr(0, dot)
	return key


# Level for a camera `distance` away, given the level shown now (hysteresis keeps it from
# flickering at a threshold).
static func level_for(distance: float, object_radius: float, current: int, count: int, thresholds: Array = Constants.LOD_DISTANCE_RADII) -> int:
	var result := 0
	for i in range(min(thresholds.size(), count - 1)):
		var threshold: float = thresholds[i] * object_radius
		threshold *= (1.0 - Constants.LOD_HYSTERESIS) if current > i else (1.0 + Constants.LOD_HYSTERESIS)
		if distance > threshold:
			result = i + 1
	return result


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or levels.empty():
		return
	_timer = Constants.LOD_CHECK_INTERVAL
	var camera = get_viewport().get_camera()
	if camera == null or not is_instance_valid(levels[0]):
		return
	show_level(level_for(ScreenSpace.view_distance(camera, levels[0].global_transform.origin), radius, level, levels.size(), distance_radii))


func show_level(new_level: int) -> void:
	level = int(clamp(new_level, 0, levels.size() - 1))
	for i in range(levels.size()):
		if is_instance_valid(levels[i]):
			levels[i].visible = i == level


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out
