# Render preview: a scene seen from a few distances, side by side in one PNG, for before/after
# checks of shaders and materials. The camera looks at the scene's origin from +z (a little above),
# on a black background with one light from the upper left.
#     godot -s tools/render_preview.gd scene=res://path out=/abs/out.png radius=10000 distances=3,10,40
# `scene`: without .tscn (Godot would run an argument ending in .tscn as the main scene).
# `radius`: the object's size in m; `distances`: camera distances in radii; `tile`: px per view
# (default 400); `time`: s to run before capturing (default 1, so TIME-driven shaders move).
# (Monitor asleep or a compositor stalling? add an override.cfg with vsync off.)
extends SceneTree

var args := {"radius": "10", "distances": "3,10,40", "tile": "400", "time": "1"}
var camera: Camera = null
var views: Array = []
var shots: Array = []
var waited := 0.0


func _init() -> void:
	for a in OS.get_cmdline_args():
		if "=" in a:
			args[a.split("=")[0]] = a.split("=", true, 1)[1]
	for d in args.distances.split(","):
		views.append(float(d) * float(args.radius))
	var world := Spatial.new()
	get_root().add_child(world)
	world.add_child(load(args.scene + ".tscn").instance())
	camera = Camera.new()
	camera.near = 10.0  # As the game camera (orbit_camera.tscn)
	camera.far = 2.0e6
	camera.fov = 50.0
	world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	world.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.black
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	_aim()


func _aim() -> void:
	var distance: float = views[shots.size()]
	camera.look_at_from_position(Vector3(0, distance * 0.2, distance), Vector3.ZERO, Vector3.UP)


func _idle(delta: float) -> bool:
	waited += delta
	if waited < float(args.time):
		return false
	var image: Image = get_root().get_texture().get_data()
	image.flip_y()
	var side: int = int(min(image.get_width(), image.get_height()))  # The centre square, scaled to a tile
	var square: Image = image.get_rect(Rect2((image.get_size() - Vector2(side, side)) * 0.5, Vector2(side, side)))
	square.resize(int(args.tile), int(args.tile))
	shots.append(square)
	waited = float(args.time) - 0.1  # Later views: a few frames to settle
	if shots.size() < views.size():
		_aim()
		return false
	var tile: int = int(args.tile)
	var sheet := Image.new()
	sheet.create(tile * shots.size(), tile, false, Image.FORMAT_RGB8)
	for i in range(shots.size()):
		var shot: Image = shots[i]
		shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot, Rect2(Vector2.ZERO, Vector2(tile, tile)), Vector2(i * tile, 0))
	sheet.save_png(args.out)
	print("render_preview: saved ", args.out)
	quit()
	return true
