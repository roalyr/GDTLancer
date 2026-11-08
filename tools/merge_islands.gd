# Makes island runs one save again (IslandMerge): the save they all started from, and each island's
# save after its segment. The merged save is the first island's world with the merged evolution.
#     godot --no-window -s tools/merge_islands.gd -- --base=/abs/base.sav --out=/abs/save_0.sav /abs/i1.sav /abs/i2.sav
# The out file is written beside itself and swapped in, the old one kept as .bak (as the game saves).
# Prints "MERGE ok ..." with the merged lives and genomes, or "MERGE FAILED ..." and exits 1.
extends SceneTree

var IslandMerge = null  # Loaded once the autoloads are in (the ranking reads Constants)


func _initialize():
	call_deferred("_run")


func _run() -> void:
	IslandMerge = load("res://src/core/evolution/island_merge.gd")
	var base_path := ""
	var out_path := ""
	var island_paths: Array = []
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--base="):
			base_path = arg.split("=", true, 1)[1]
		elif arg.begins_with("--out="):
			out_path = arg.split("=", true, 1)[1]
		elif arg.ends_with(".sav"):
			island_paths.append(arg)
	if base_path == "" or out_path == "" or island_paths.empty():
		_fail("give --base=, --out= and the islands' saves")
		return
	var base = _read(base_path)
	if base == null:
		return
	var datas: Array = []
	var evolutions: Array = []
	for path in island_paths:
		var data = _read(path)
		if data == null:
			return
		datas.append(data)
		evolutions.append(data.evolution)
	var merged: Dictionary = datas[0].duplicate(true)
	merged.evolution = IslandMerge.merge(base.evolution, evolutions)
	var file := File.new()
	if file.open(out_path + ".tmp", File.WRITE) != OK:
		_fail("cannot write " + out_path + ".tmp")
		return
	file.store_var(merged, true)
	file.close()
	var dir := Directory.new()
	if dir.file_exists(out_path):
		dir.remove(out_path + ".bak")
		dir.rename(out_path, out_path + ".bak")
	if dir.rename(out_path + ".tmp", out_path) != OK:
		_fail("cannot move the merged save into " + out_path)
		return
	var lives: int = int(merged.evolution.totals.get("deaths", 0)) + int(merged.evolution.totals.get("retired", 0))
	print("MERGE ok %d islands -> %s: %d lives ended (base %d), %d genomes, t=%.0fs" % [
		island_paths.size(), out_path, lives, int(base.evolution.totals.get("deaths", 0)) + int(base.evolution.totals.get("retired", 0)),
		merged.evolution.genomes.size(), float(merged.evolution.get("game_time", 0.0))])
	quit()


func _read(path: String):
	var file := File.new()
	if file.open(path, File.READ) != OK:
		_fail("no save at " + path)
		return null
	var data = file.get_var(true)
	file.close()
	if not (data is Dictionary and data.get("evolution") is Dictionary and data.evolution.has("genomes")):
		_fail(path + " has no evolution data")
		return null
	return data


func _fail(why: String) -> void:
	print("MERGE FAILED ", why)
	quit(1)
