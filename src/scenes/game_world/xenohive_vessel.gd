# A xenohive ship's model (scenes/prefabs/ships/xenohive_vessel.tscn): a XenoForm the size of the
# other hulls' models (the ship's model_scale stretches it like theirs). Built on creation, so the
# collision hull, made as the ship instances it, already has its meshes.

extends Spatial

const XenoForm = preload("res://src/scenes/game_world/xeno_form.gd")


func _init() -> void:
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(XenoForm.build(Constants.XENO_FORMS.vessel, Constants.XENO_VESSEL_LENGTH, Constants.XENO_VESSEL_SEED))
	add_child(model)
