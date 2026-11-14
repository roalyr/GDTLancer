# Exports a save's best evolved designs as presets (PresetExporter), whatever their faction: the
# fittest of each archetype (role and weight class: up to three per role) whose genome has flown at least --min-lives lives, its ship, parts
# and a faction-free AgentTemplate (behaviour genes) as .tres files, drafts under database/drafts/
# (never among the game's presets: the game flies only database/presets/archetypes/, picked from
# drafts by tools/pick_archetypes.gd).
#     godot --no-window -s tools/export_presets.gd -- --top=60 --min-lives=10 --clean
# Options: --save=PATH (default user://evolution/save_0.sav: evolution mode's save), --top=N archetypes, --min-lives=N,
# --out=PATH (default res://database/drafts/export/), --clean (remove the drafts there first; never
# a folder outside database/drafts/).
extends SceneTree

var save_path := "user://evolution/save_0.sav"
var out_dir := "res://database/drafts/export/"
var top := 60
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
		quit(1)
		return
	var data = file.get_var(true)
	file.close()
	if not (data is Dictionary and data.get("evolution") is Dictionary):
		print("PRESETS the save has no evolution data")
		quit(1)
		return
	if clean:
		if not out_dir.begins_with("res://database/drafts/") or out_dir.trim_suffix("/") == "res://database/drafts":
			print("PRESETS --clean only empties a folder inside res://database/drafts/ (not %s): nothing exported" % out_dir)
			quit(1)
			return
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
