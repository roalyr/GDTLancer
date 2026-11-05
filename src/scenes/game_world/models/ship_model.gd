# ShipModel: the root of a ship's model scene (an archetype's or hull's `ship_scene`). What the game
# needs from a ship model (CONTENT.md, "Models"):
# - Size: Constants.SHIP_MODEL_LENGTH (17 m) nose to tail at scale 1 (tools/import_model.sh fits a
#   model made at any size to it), nose to -Z, top to +Y. The ship's model_scale (its preset's)
#   stretches it to the ship's size.
# - Materials by their names in Blender (ModelLooks): "paint" takes the faction's paint.
# - Engines: an empty in Blender (a Position3D in Godot) named "Engine..." at each nozzle, unrotated
#   (the exhaust trails aft, +Z); its scale sizes the exhaust. Exhausts are added as the scene
#   instances.
#   A scene with an "Engines" node of its own (EngineExhaustSet) keeps that instead.
# - Nothing else: the collision hull, hit surface and levels of detail come from the model's .glb
#   files (CollisionHull, MeshLod; tools/import_model.sh makes the LODs and hit surfaces).

tool
extends Spatial

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")
const ExhaustScene = preload("res://scenes/prefabs/effects/engine_exhaust.tscn")
const ExhaustSet = preload("res://src/core/agents/effects/engine_exhaust_set.gd")
const ENGINE_PREFIX = "Engine"


func _notification(what: int) -> void:
	if what == NOTIFICATION_INSTANCED:
		ModelLooks.dress(self, null)
		if not Engine.editor_hint:
			add_exhausts(self)


# Takes `material` on the painted surfaces (FactionTemplate.hull_material).
func paint(material: Material) -> void:
	ModelLooks.dress(self, material)


# The engine markers under `root`, in root space: empties (Spatials that draw nothing) named
# "Engine...", outside an "Engines" node.
static func engine_markers(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [[root, Transform.IDENTITY]]
	while not stack.empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		if node.name == "Engines":
			continue
		if is_engine_marker(node):
			out.append(item[1])
		for child in node.get_children():
			if child is Spatial:
				stack.append([child, item[1] * child.transform])
	return out


static func is_engine_marker(node: Node) -> bool:
	return node is Spatial and not node is VisualInstance and node.name.begins_with(ENGINE_PREFIX) and node.name != "Engines"


# An exhaust at each engine marker, under an "Engines" node (EngineExhaustSet) of `root`.
static func add_exhausts(root: Spatial) -> void:
	if root.has_node("Engines"):
		return
	var markers: Array = engine_markers(root)
	if markers.empty():
		return
	var engines := Spatial.new()
	engines.name = "Engines"
	engines.set_script(ExhaustSet)
	for placed in markers:
		var exhaust: Spatial = ExhaustScene.instance()
		exhaust.transform = placed
		engines.add_child(exhaust)
	root.add_child(engines)
