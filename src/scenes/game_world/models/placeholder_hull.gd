# A placeholder hull (scenes/prefabs/ships/placeholders/): a ShipModel built from primitives
# (PrimitiveForm, Constants HULL_FORMS), one silhouette per preset family, its girth by weight class,
# so ships can be told apart until real models land. Built when the scene sets `form`
# ("<family>_<weight>"), as it instances, so the collision hull, made as the ship instances it,
# already has its meshes; its engine markers get their exhausts then too (ShipModel). A tool
# script: the editor shows the hull and its engine markers.

tool
extends "res://src/scenes/game_world/models/ship_model.gd"

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const PrimitiveForm = preload("res://src/scenes/game_world/models/primitive_form.gd")

export var form: String = "" setget set_form


func set_form(value: String) -> void:
	form = value
	for old in get_children():
		if old.name == "Model" or old.name == "Engines" or is_engine_marker(old):
			remove_child(old)
			old.free()
	var parts: PoolStringArray = value.split("_")
	if parts.size() != 2 or not (Defaults.HULL_FORMS.has(parts[0]) or parts[0] == "platform"):
		printerr("PlaceholderHull: no hull form ", value)
		return
	var spec: Dictionary = Defaults.PLATFORM_FORM if parts[0] == "platform" else Defaults.HULL_FORMS[parts[0]]  # A weapon platform: its own form
	var girth: float = float(Defaults.HULL_FORM_GIRTH.get(parts[1], 1.0))
	var length: float = Defaults.SHIP_MODEL_LENGTH
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(PrimitiveForm.build(spec.parts, length, girth, parts[1]))
	add_child(model)
	var count := 0
	for at in spec.engines:
		for side in ([1.0, -1.0] if at.x != 0.0 else [1.0]):
			var marker := Position3D.new()
			marker.name = "%s%d" % [ENGINE_PREFIX, count]
			marker.transform = Transform(Basis().scaled(Vector3.ONE * Defaults.HULL_FORM_EXHAUST_SCALE * girth), Vector3(at.x * side * girth, at.y * girth, at.z) * length)
			add_child(marker)
			count += 1
