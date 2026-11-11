# Hull sheet: every placeholder hull (scenes/prefabs/ships/placeholders/) in one PNG, families across
# and weight classes down, in a faction's paint, seen from above and ahead at three quarters.
#     godot res://tools/hull_sheet.tscn out=/abs/hulls.png faction=verdant
# With scene=, one ship model for review instead: every faction's paint across, its levels of
# detail down (LOD0 on top), its exhausts lit:
#     godot res://tools/hull_sheet.tscn out=/abs/model.png scene=res://scenes/prefabs/ships/<name>
# (`scene` without .tscn: Godot would run an argument ending in .tscn as the main scene.)
extends Spatial

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")

const FAMILIES = ["fighter", "lance", "prospector", "raider", "scavenger", "trader"]
const WEIGHTS = ["light", "medium", "heavy", "superheavy"]
const SPACING = 30.0  # m between placeholder hulls; a model sheet spaces by the model's size
const MODEL_GAP = 1.3  # A model sheet's spacing, times the model's widest span (stations are big)

var out: String = "user://hull_sheet.png"
var faction: String = "verdant"
var scene_path: String = ""
var spacing: float = SPACING


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a.begins_with("faction="):
			faction = a.trim_prefix("faction=")
		elif a.begins_with("scene="):
			scene_path = a.trim_prefix("scene=") + ".tscn"
	var columns: int = FAMILIES.size()
	var rows: int = WEIGHTS.size()
	if scene_path != "":
		var size: Array = _model_sheet()
		columns = size[0]
		rows = size[1]
	else:
		var material = load(TemplateDatabase.factions[faction].hull_material)
		for column in FAMILIES.size():
			for row in WEIGHTS.size():
				var hull: Spatial = load("res://scenes/prefabs/ships/placeholders/%s_%s.tscn" % [FAMILIES[column], WEIGHTS[row]]).instance()
				_place(hull, column, row, columns, rows)
				hull.paint(material)
	var light := DirectionalLight.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.1)
	environment.ambient_light_color = Color(0.35, 0.35, 0.4)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var camera := Camera.new()
	camera.far = 10000.0
	add_child(camera)
	var reach: float = max(columns / 5.0, rows / 3.0) * spacing / SPACING  # The placeholder sheet's framing, grown to fit
	camera.look_at_from_position(Vector3(0, 78, 62) * reach, Vector3(0, 0, 3), Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	for i in range(10):
		yield(get_tree(), "idle_frame")
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png(out)
	print("HULL SHEET ", out)
	get_tree().quit()


func _place(hull: Spatial, column: int, row: int, columns: int, rows: int) -> void:
	hull.transform.origin = Vector3((column - (columns - 1) / 2.0) * spacing, 0, (row - (rows - 1) / 2.0) * spacing)
	hull.rotation_degrees.y = -35.0
	add_child(hull)


# `scene_path` in each faction's paint (columns) at each of its levels of detail (rows): [columns, rows].
func _model_sheet() -> Array:
	var paints: Array = []
	for id in TemplateDatabase.factions:
		var path: String = TemplateDatabase.factions[id].hull_material
		if path != "" and not paints.has(path):
			paints.append(path)
	var levels: int = 1
	var probe: Spatial = load(scene_path).instance()
	add_child(probe)
	var box: AABB = ModelLooks.bounds(probe)
	spacing = max(SPACING, max(box.size.x, box.size.z) * MODEL_GAP)
	for lod in MeshLod.attach(probe, null):
		levels = max(levels, lod.levels.size())
	probe.free()
	for column in paints.size():
		for row in levels:
			var hull: Spatial = load(scene_path).instance()
			if hull.has_method("paint"):
				hull.paint(load(paints[column]))
			_place(hull, column, row, paints.size(), levels)
			for lod in MeshLod.attach(hull, null):
				lod.show_level(row)
	return [paints.size(), levels]
