# A placeholder hull (scenes/prefabs/ships/placeholders/): a ShipModel built from primitives
# (PrimitiveForm, Constants HULL_FORMS), one silhouette per preset family, its girth by weight class,
# so ships can be told apart until real models land. Built when the scene sets `form`
# ("<family>_<weight>"), as it instances, so the collision hull, made as the ship instances it,
# already has its meshes; its engine markers (a set facing each way) get their exhausts then too,
# and its weapon and module hardpoints take the fitted parts later (ShipModel). A tool script: the
# editor shows the hull and its markers.

tool
extends "res://src/scenes/game_world/models/ship_model.gd"


export var form: String = "" setget set_form


func set_form(value: String) -> void:
	form = value
	for old in get_children():
		if old.name in ["Model", "Engines", MOUNTS] or is_engine_marker(old) or _is_marker(old, WEAPON_PREFIX) or _is_marker(old, MODULE_PREFIX):
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
	var engines: Dictionary = spec.get("engines", {})
	for direction in ["rear", "front", "top", "bottom", "sides"]:
		for at in engines.get(direction, []):
			var sides: Array = [[1.0, direction]]
			if direction == "sides":
				sides = [[1.0, "right"], [-1.0, "left"]]
			elif at.x != 0.0:
				sides = [[1.0, direction], [-1.0, direction]]
			for side in sides:
				_add_marker("%s%s%d" % [ENGINE_PREFIX, side[1].capitalize(), count], Vector3(at.x * side[0], at.y, at.z), Defaults.HULL_FORM_EXHAUST_SCALE * girth, girth, length)
				count += 1
	for group in [[WEAPON_PREFIX, "weapons"], [MODULE_PREFIX, "modules"]]:
		var index := 0
		for at in spec.get(group[1], []):
			for side in ([1.0, -1.0] if at.x != 0.0 else [1.0]):
				_add_marker("%s%d" % [group[0], index], Vector3(at.x * side, at.y, at.z), Defaults.HULL_FORM_HARDPOINT_SCALE * girth, girth, length)
				index += 1


# A marker (Position3D) named `marker_name` at `at` (shares of the length, the girth across), scaled `size`.
func _add_marker(marker_name: String, at: Vector3, size: float, girth: float, length: float) -> void:
	var marker := Position3D.new()
	marker.name = marker_name
	marker.transform = Transform(Basis().scaled(Vector3.ONE * size), Vector3(at.x * girth, at.y * girth, at.z) * length)
	add_child(marker)
