# Exports a save's best evolved designs as presets (PresetExporter), whatever their faction: the
# fittest of each archetype (role) whose genome has flown at least --min-lives lives, its ship, parts
# and a faction-free AgentTemplate (behaviour genes) as .tres files under database/presets/. That
# folder is outside the registry, so nothing reaches the game or the station shop until you move the
# files you want into database/registry/ (parts first: ships name them by id).
#     godot --no-window -s tools/export_presets.gd -- --top=12 --min-lives=10 --clean
# Options: --save=PATH (default user://savegames/save_0.sav), --top=N archetypes, --min-lives=N,
# --out=PATH (default res://database/presets/), --clean (remove the presets there first).
extends SceneTree

var save_path := "user://savegames/save_0.sav"
var out_dir := "res://database/presets/"
var top := 12
var min_lives := 10
var clean := false


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--save="):
			save_path = arg.split("=")[1]
		elif arg.begins_with("--top="):
			top = int(arg.split("=")[1])
		elif arg.begins_with("--min-lives="):
			min_lives = int(arg.split("=")[1])
		elif arg.begins_with("--out="):
			out_dir = arg.split("=")[1]
		elif arg == "--clean":
			clean = true
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
	if clean:
		_remove_presets(out_dir)
	for line in Exporter.export_all(data.evolution, top, min_lives, out_dir):
		print("PRESETS ", line)
	quit()


# Every .tres under `path` (old presets), and the folders left empty.
func _remove_presets(path: String) -> void:
	var dir := Directory.new()
	if dir.open(path) != OK:
		return
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		var full: String = path.plus_file(name)
		if dir.current_is_dir():
			_remove_presets(full)
			dir.remove(full)  # Only if empty
		elif name.ends_with(".tres"):
			dir.remove(full)
		name = dir.get_next()
	dir.list_dir_end()
