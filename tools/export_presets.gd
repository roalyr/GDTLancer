# Exports each faction's best evolved designs from a save as NPC presets: for every niche whose best
# genome has flown at least --min-lives lives, its ship, parts and an AgentTemplate (faction, behaviour
# genes) as .tres files under database/presets/<faction>/. That folder is outside the registry, so
# nothing reaches the game or the station shop until you move the files you want into
# database/registry/ (parts first: ships name them by id).
#     godot --no-window -s tools/export_presets.gd -- --top=6 --min-lives=3
# Options: --save=PATH (default user://savegames/save_0.sav), --top=N per faction, --min-lives=N.
extends SceneTree

var save_path := "user://savegames/save_0.sav"
var top := 6
var min_lives := 3


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--save="):
			save_path = arg.split("=")[1]
		elif arg.begins_with("--top="):
			top = int(arg.split("=")[1])
		elif arg.begins_with("--min-lives="):
			min_lives = int(arg.split("=")[1])
	call_deferred("_run")


func _run():
	var Exporter = load("res://src/core/evolution/preset_exporter.gd")
	var file := File.new()
	if file.open(save_path, File.READ) != OK:
		print("PRESETS no save at ", save_path)
		quit()
		return
	var data = file.get_var(true)
	file.close()
	if not (data is Dictionary and data.get("evolution") is Dictionary):
		print("PRESETS the save has no evolution data")
		quit()
		return
	for line in Exporter.export_all(data.evolution, top, min_lives, "res://database/presets/"):
		print("PRESETS ", line)
	quit()
