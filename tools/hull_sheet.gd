# Hull sheet: every placeholder hull (scenes/prefabs/ships/placeholders/) in one PNG, families across
# and weight classes down, in a faction's paint, seen from above and ahead at three quarters.
#     godot res://tools/hull_sheet.tscn out=/abs/hulls.png faction=verdant
extends Spatial

const FAMILIES = ["fighter", "lance", "prospector", "raider", "scavenger"]
const WEIGHTS = ["light", "medium", "heavy"]
const SPACING = 30.0  # m between hulls

var out: String = "user://hull_sheet.png"
var faction: String = "verdant"


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a.begins_with("faction="):
			faction = a.trim_prefix("faction=")
	var material = load(TemplateDatabase.factions[faction].hull_material)
	for column in FAMILIES.size():
		for row in WEIGHTS.size():
			var hull: Spatial = load("res://scenes/prefabs/ships/placeholders/%s_%s.tscn" % [FAMILIES[column], WEIGHTS[row]]).instance()
			hull.transform.origin = Vector3((column - 2) * SPACING, 0, (row - 1) * SPACING)
			hull.rotation_degrees.y = -35.0
			add_child(hull)
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
	camera.look_at_from_position(Vector3(0, 78, 62), Vector3(0, 0, 3), Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	for i in range(10):
		yield(get_tree(), "idle_frame")
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png(out)
	print("HULL SHEET ", out)
	get_tree().quit()
