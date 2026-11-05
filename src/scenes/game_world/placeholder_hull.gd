# A placeholder hull (scenes/prefabs/ships/placeholders/): a PrimitiveForm from Constants
# HULL_FORMS, one silhouette per preset family, its girth by weight class, so ships can be told apart
# until real models land. 17 m nose to tail like the other hull models (the ship's model_scale
# stretches it). Built when the scene sets `form` ("<family>_<weight>"), as it instances, so the
# collision hull, made as the ship instances it, already has its meshes. Painted in the faction's
# colour at spawn (paint()). A tool script: the editor shows the hull too (unpainted, no exhausts).

tool
extends Spatial

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const PrimitiveForm = preload("res://src/scenes/game_world/primitive_form.gd")
const ExhaustScene = preload("res://scenes/prefabs/effects/engine_exhaust.tscn")
const ExhaustSet = preload("res://src/core/agents/effects/engine_exhaust_set.gd")

export var form: String = "" setget set_form


func set_form(value: String) -> void:
	form = value
	for old in [get_node_or_null("Model"), get_node_or_null("Engines")]:
		if old != null:
			remove_child(old)
			old.free()
	var parts: PoolStringArray = value.split("_")
	if parts.size() != 2 or not Defaults.HULL_FORMS.has(parts[0]):
		printerr("PlaceholderHull: no hull form ", value)
		return
	var spec: Dictionary = Defaults.HULL_FORMS[parts[0]]
	var girth: float = float(Defaults.HULL_FORM_GIRTH.get(parts[1], 1.0))
	var length: float = Defaults.HULL_FORM_LENGTH
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(PrimitiveForm.build(spec.parts, length, girth, parts[1]))
	add_child(model)
	if Engine.editor_hint:
		return  # The look only
	var engines := Spatial.new()
	engines.name = "Engines"
	engines.set_script(ExhaustSet)
	for at in spec.engines:
		for side in ([1.0, -1.0] if at.x != 0.0 else [1.0]):
			var exhaust: Spatial = ExhaustScene.instance()
			exhaust.transform = Transform(Basis().scaled(Vector3.ONE * Defaults.HULL_FORM_EXHAUST_SCALE * girth), Vector3(at.x * side * girth, at.y * girth, at.z) * length)
			engines.add_child(exhaust)
	add_child(engines)


# Takes `material` on the painted parts (FactionTemplate.hull_material).
func paint(material: Material) -> void:
	PrimitiveForm.paint(self, material)
