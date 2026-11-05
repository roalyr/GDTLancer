# A placeholder station (scenes/prefabs/station/placeholders/): a StationModel built from primitives
# (PrimitiveForm, Constants STATION_FORMS: haven, post, refinery, den) until real models land. Built
# when the scene sets `form`, as it instances. A tool script: the editor shows it too.

tool
extends "res://src/scenes/game_world/models/station_model.gd"

const Defaults = preload("res://src/autoload/Constants.gd")  # Read in the editor too, where autoloads are not
const PrimitiveForm = preload("res://src/scenes/game_world/models/primitive_form.gd")

export var form: String = "" setget set_form


func set_form(value: String) -> void:
	form = value
	var old: Node = get_node_or_null("PrimitiveForm")
	if old != null:
		remove_child(old)
		old.free()
	if not Defaults.STATION_FORMS.has(value):
		printerr("PlaceholderStation: no station form ", value)
		return
	var spec: Dictionary = Defaults.STATION_FORMS[value]
	add_child(PrimitiveForm.build(spec.parts, float(spec.length)))
