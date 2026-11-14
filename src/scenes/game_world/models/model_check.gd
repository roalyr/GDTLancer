# ModelCheck: what is wrong with a ship or station model scene, by the rules in CONTENT.md
# ("Models"). The content test runs it on every scene the game flies or places;
# tools/check_model.gd (and tools/import_model.sh) on one. Each check returns a list of problems,
# empty when the scene is fine.

extends Reference

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")
const ShipModel = preload("res://src/scenes/game_world/models/ship_model.gd")
const PartCatalog = preload("res://src/core/systems/part_catalog.gd")
const FX_MODELS_DIR = "res://assets/models/fx/"


# A hull that never moves (the weapon platform's): it needs no engines.
static func is_stationary(scene_path: String, root: Node) -> bool:
	return scene_path == Constants.PLATFORM_HULL_SCENE or str(root.get("form")).begins_with("platform")


static func ship_problems(scene_path: String) -> Array:
	var problems: Array = []
	var root: Spatial = _instance(scene_path, problems)
	if root == null:
		return problems
	var length: float = ModelLooks.bounds(root).size.z
	if abs(length - Constants.SHIP_MODEL_LENGTH) > Constants.SHIP_MODEL_LENGTH * Constants.SHIP_MODEL_LENGTH_TOLERANCE:
		problems.append("%.1f m nose to tail: ship models are %.0f m (re-run tools/import_model.sh, which fits them; the preset's model_scale sizes the ship)" % [length, Constants.SHIP_MODEL_LENGTH])
	var engines: Array = []
	var own: Node = root.get_node_or_null("Engines")
	if own != null:
		for exhaust in own.get_children():
			if exhaust is Spatial:
				engines.append(own.transform * exhaust.transform)
	if engines.empty():
		if not is_stationary(scene_path, root):
			problems.append("no engines: put an empty (or Position3D) named Engine at each nozzle")
	else:
		problems += nozzle_problems(engines, is_stationary(scene_path, root))
	problems += _material_problems(root)
	for model_path in _model_files(root):
		if load("res://src/core/agents/components/mesh_lod.gd").lod_paths_for(model_path).empty():
			problems.append("%s has no levels of detail (tools/import_model.sh)" % model_path)
		if not ResourceLoader.exists(load("res://src/core/agents/components/collision_hull.gd").baked_surface_path(model_path)):
			problems.append("%s has no baked hit surface (tools/import_model.sh)" % model_path)
	root.free()
	return problems


# What is wrong with a ship's exhausts (`engines`: their Transforms in model space, +Z where each
# exhaust points): a moving ship needs a nozzle facing each way (ShipModel.NOZZLE_DIRECTIONS), and its
# rear ones aft.
static func nozzle_problems(engines: Array, stationary: bool = false) -> Array:
	var problems: Array = []
	var aft := 0.0
	var facing := {}
	for placed in engines:
		var exhaust: Vector3 = placed.basis.z.normalized()
		for direction in ShipModel.NOZZLE_DIRECTIONS:
			if exhaust.dot(ShipModel.NOZZLE_DIRECTIONS[direction]) > 0.9:
				facing[direction] = true
				if direction == "rear":
					aft += placed.origin.z
	if facing.has("rear") and aft <= 0.0:
		problems.append("its rear engines sit forward: the nose faces -Z in Godot (+Y in Blender)")
	if not stationary:
		for direction in ShipModel.NOZZLE_DIRECTIONS:
			if not facing.has(direction):
				problems.append("no %s nozzle: ships fly at top speed in any direction; add an empty named %s%s" % [direction, ShipModel.ENGINE_PREFIX, "" if direction == "rear" else direction.capitalize()])
	return problems


# What is wrong with `ship`'s default fit on the model at `scene_path`: more parts that are not
# internal than the model has hardpoints for (the rest would not show).
static func hardpoint_problems(scene_path: String, ship: Resource) -> Array:
	var problems: Array = []
	var root: Spatial = _instance(scene_path, problems)
	if root == null:
		return problems
	var points: Dictionary = ShipModel.hardpoints(root)
	root.free()
	var wanted := {"tools": 0, "modules": 0}
	for group in [["tools", ship.equipped_tools], ["modules", ship.equipped_modules]]:
		for part_id in group[1]:
			var part = PartCatalog.get_part(str(part_id))
			if part != null and not part.internal:
				wanted[group[0]] += 1
	for group in [["tools", "Weapon"], ["modules", "Module"]]:
		if wanted[group[0]] > points[group[0]].size():
			problems.append("%d %s outside the hull, but its model has %d %s hardpoints (empties named %s)" % [
				wanted[group[0]], group[0], points[group[0]].size(), group[1].to_lower(), group[1]])
	return problems


# What a ship model carries, for the dev tool's Models tab: {"nozzles": {direction: count},
# "weapons": count, "modules": count} (ShipModel); empty when the scene does not instance.
static func ship_summary(scene_path: String) -> Dictionary:
	var root: Spatial = _instance(scene_path, [])
	if root == null:
		return {}
	var nozzles := {}
	var own: Node = root.get_node_or_null("Engines")
	for exhaust in (own.get_children() if own != null else []):
		if exhaust is Spatial:
			var z: Vector3 = (own.transform * exhaust.transform).basis.z.normalized()
			for direction in ShipModel.NOZZLE_DIRECTIONS:
				if z.dot(ShipModel.NOZZLE_DIRECTIONS[direction]) > 0.9:
					nozzles[direction] = int(nozzles.get(direction, 0)) + 1
	var points: Dictionary = ShipModel.hardpoints(root)
	root.free()
	return {"nozzles": nozzles, "weapons": points.tools.size(), "modules": points.modules.size()}


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
