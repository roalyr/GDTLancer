# A xenohive ship's model (scenes/prefabs/ships/xenohive_vessel.tscn): a ShipModel grown as a
# XenoForm, the length of the other ship models (the ship's model_scale stretches it like theirs).
# Built on creation, so the collision hull, made as the ship instances it, already has its meshes.
# Its scene has its own Engines.

extends "res://src/scenes/game_world/models/ship_model.gd"

const XenoForm = preload("res://src/scenes/game_world/models/xeno_form.gd")


func _init() -> void:
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(XenoForm.build(Constants.XENO_FORMS.vessel, Constants.SHIP_MODEL_LENGTH, Constants.XENO_VESSEL_SEED))
	add_child(model)
