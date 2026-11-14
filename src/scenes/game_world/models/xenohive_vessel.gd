# A xenohive ship's model (scenes/prefabs/ships/xenohive_vessel.tscn): a ShipModel grown as a
# XenoForm, the length of the other ship models (the ship's model_scale stretches it like theirs).
# Built on creation, so the collision hull, made as the ship instances it, already has its meshes.
# Its nozzles, one facing each way (ShipModel), sit on the faces of its bounds
# (Constants.XENO_VESSEL_NOZZLE_DEPTH of the way out from its middle).

extends "res://src/scenes/game_world/models/ship_model.gd"

const XenoForm = preload("res://src/scenes/game_world/models/xeno_form.gd")


func _init() -> void:
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(XenoForm.build(Constants.XENO_FORMS.vessel, Constants.SHIP_MODEL_LENGTH, Constants.XENO_VESSEL_SEED))
	add_child(model)
	var box: AABB = ModelLooks.bounds(model)
	var middle: Vector3 = box.position + box.size * 0.5
	for direction in NOZZLE_DIRECTIONS:
		var out: Vector3 = NOZZLE_DIRECTIONS[direction]
		var marker := Position3D.new()
		marker.name = ENGINE_PREFIX + direction.capitalize()
		marker.scale = Vector3.ONE * Constants.XENO_VESSEL_NOZZLE_SCALE
		marker.transform.origin = middle + out * box.size * 0.5 * Constants.XENO_VESSEL_NOZZLE_DEPTH
		add_child(marker)
