# New model scene: wraps a model file (.glb) in the scene the game flies (a ShipModel) or places (a
# StationModel), so pointing a preset's ship_scene or a HavenMarker's model at it is all that is left.
# Leaves a scene that already exists alone (it may have been edited since).
#     godot --no-window -s tools/new_model_scene.gd -- res://assets/models/ships/<name>/<name>.glb [--station] [--out=res://scenes/...tscn]
# Default out: scenes/prefabs/ships/<name>.tscn, or scenes/prefabs/station/<name>.tscn with --station.
extends SceneTree

const SHIP_SCRIPT = "res://src/scenes/game_world/models/ship_model.gd"
const STATION_SCRIPT = "res://src/scenes/game_world/models/station_model.gd"


func _initialize():
	call_deferred("_make")


func _make():
	var model_path := ""
	var station := false
	var out := ""
	for arg in OS.get_cmdline_args():
		if arg.ends_with(".glb"):
			model_path = arg if arg.begins_with("res://") else "res://" + arg
		elif arg == "--station":
			station = true
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if model_path == "" or not ResourceLoader.exists(model_path):
		print("FAIL no model file %s (import it first: tools/import_model.sh)" % model_path)
		quit(1)
		return
	var name: String = model_path.get_file().get_basename()
	if out == "":
		out = "res://scenes/prefabs/%s/%s.tscn" % ["station" if station else "ships", name]
	if ResourceLoader.exists(out):
		print("KEEP %s: it exists" % out)
		quit(0)
		return
	var root := Spatial.new()
	root.name = name
	root.set_script(load(STATION_SCRIPT if station else SHIP_SCRIPT))
	var model: Node = load(model_path).instance()
	root.add_child(model)
	model.owner = root
	var scene := PackedScene.new()
	var error: int = scene.pack(root)
	if error == OK:
		Directory.new().make_dir_recursive(out.get_base_dir())
		error = ResourceSaver.save(out, scene)
	root.free()
	print(("OK   %s" if error == OK else "FAIL %s: error %d") % ([out] if error == OK else [out, error]))
	quit(0 if error == OK else 1)
