# Rewrites the hand-made ships and parts in database/registry/ from their law_genes (ShipLaws), so
# what the stations sell obeys the same laws as what evolution makes. Run after changing a law:
#     godot --no-window -s tools/apply_laws.gd
# Only templates with law_genes are touched (modules also need module_kind, tools tool_type "laser").
extends SceneTree

var ShipLaws = null  # Loaded once the autoloads are in (the laws read Constants)
const FOLDERS = ["res://database/registry/assets/ships/", "res://database/registry/assets/modules/", "res://database/registry/tools/"]


func _initialize():
	call_deferred("_run")


func _run():
	ShipLaws = load("res://src/core/systems/ship_laws.gd")
	for folder in FOLDERS:
		var dir := Directory.new()
		if dir.open(folder) != OK:
			continue
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_apply(folder + file_name)
			file_name = dir.get_next()
	quit()


func _apply(path: String) -> void:
	var template = ResourceLoader.load(path, "", true)
	if template == null or template.get("law_genes") == null or template.law_genes.empty():
		return
	var stats: Dictionary = ShipLaws.reapply(template)
	var err: int = ResourceSaver.save(path, template)
	print("LAWS %s %s: %s" % ["saved" if err == OK else "FAILED", path, stats])
