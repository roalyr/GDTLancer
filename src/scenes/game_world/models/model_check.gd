# ModelCheck: what is wrong with a ship or station model scene, by the rules in CONTENT.md
# ("Models"). The content test runs it on every scene the game flies or places;
# tools/check_model.gd (and tools/import_model.sh) on one. Each check returns a list of problems,
# empty when the scene is fine.

extends Reference

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")
const ShipModel = preload("res://src/scenes/game_world/models/ship_model.gd")
const FX_MODELS_DIR = "res://assets/models/fx/"


static func ship_problems(scene_path: String) -> Array:
	var problems: Array = []
	var root: Spatial = _instance(scene_path, problems)
	if root == null:
		return problems
	var length: float = ModelLooks.bounds(root).size.z
	if abs(length - Constants.SHIP_MODEL_LENGTH) > Constants.SHIP_MODEL_LENGTH * Constants.SHIP_MODEL_LENGTH_TOLERANCE:
		problems.append("%.1f m nose to tail: ship models are %.0f m (the preset's model_scale sizes the ship)" % [length, Constants.SHIP_MODEL_LENGTH])
	var engines: Array = []
	var own: Node = root.get_node_or_null("Engines")
	if own != null:
		for exhaust in own.get_children():
			if exhaust is Spatial:
				engines.append(exhaust.transform)
	if engines.empty():
		problems.append("no engines: put an empty (or Position3D) named Engine at each nozzle")
	else:
		var aft := 0.0
		for placed in engines:
			aft += placed.origin.z
		if aft <= 0.0:
			problems.append("its engines sit forward: the nose faces -Z in Godot (+Y in Blender)")
	problems += _material_problems(root)
	for model_path in _model_files(root):
		if load("res://src/core/agents/components/mesh_lod.gd").lod_paths_for(model_path).empty():
			problems.append("%s has no levels of detail (tools/import_model.sh)" % model_path)
		if not ResourceLoader.exists(load("res://src/core/agents/components/collision_hull.gd").baked_surface_path(model_path)):
			problems.append("%s has no baked hit surface (tools/import_model.sh)" % model_path)
	root.free()
	return problems


static func station_problems(scene_path: String) -> Array:
	var problems: Array = []
	var root: Spatial = _instance(scene_path, problems)
	if root == null:
		return problems
	if ModelLooks.bounds(root).size == Vector3.ZERO:
		problems.append("no meshes")
	problems += _material_problems(root)
	root.free()
	return problems


static func _instance(scene_path: String, problems: Array) -> Spatial:
	var scene = load(scene_path) if ResourceLoader.exists(scene_path) else null
	if not scene is PackedScene:
		problems.append("no scene at %s" % scene_path)
		return null
	var root = scene.instance()
	if not root is Spatial:
		problems.append("its root is not a Spatial")
		if root != null:
			root.free()
		return null
	return root


static func _material_problems(root: Node) -> Array:
	var problems: Array = []
	for tag in ModelLooks.unknown_tags(root):
		problems.append("material \"%s\" is neither paint nor in %s (name it after a mat_<name>.tres there)" % [tag, ModelLooks.LIBRARY_DIR])
	return problems


# The model files (.glb) under `root`: not effects, not lower levels of detail.
static func _model_files(root: Node) -> Array:
	var found := {}
	var stack: Array = [root]
	while not stack.empty():
		var node: Node = stack.pop_back()
		stack += node.get_children()
		if node.filename.ends_with(".glb") and node.filename.find("/lod/") < 0 and not node.filename.begins_with(FX_MODELS_DIR):
			found[node.filename] = true
	return found.keys()
