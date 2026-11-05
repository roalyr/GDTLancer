# Check model: lists what is wrong with a ship or station model scene (ModelCheck; the rules are in
# CONTENT.md, "Models"). Exits 1 if anything is.
#     godot --no-window -s tools/check_model.gd -- res://scenes/prefabs/ships/<name>.tscn [--station]
extends SceneTree


func _initialize():
	call_deferred("_check")


func _check():
	var ModelCheck = load("res://src/scenes/game_world/models/model_check.gd")  # Loaded when run: it needs the autoloads
	var scene_path := ""
	var station := false
	for arg in OS.get_cmdline_args():
		if arg.ends_with(".tscn"):
			scene_path = arg if arg.begins_with("res://") else "res://" + arg
		elif arg == "--station":
			station = true
	var problems: Array = ModelCheck.station_problems(scene_path) if station else ModelCheck.ship_problems(scene_path)
	for problem in problems:
		print("PROBLEM %s: %s" % [scene_path, problem])
	if problems.empty():
		print("OK   %s" % scene_path)
	quit(1 if not problems.empty() else 0)
