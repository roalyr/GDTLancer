# Bakes hit surfaces: for every ship model, a trimesh of its Constants.HIT_SURFACE_LOD level saved
# as <model folder>/hit/<model>_hit.res (CollisionHull.baked_surface_path), so ships load it instead
# of building it at startup. Re-run after changing a ship model or its LODs (tools/generate_lods.py).
#     godot --no-window -s tools/bake_hit_shapes.gd [res://path/model.glb ...]
# With no models given, bakes every flown ship model (.glb in CollisionHull.HIT_SURFACE_MODELS that
# has levels of detail: the others are spare parts and stations' props).
extends SceneTree

const COLLISION_HULL = "res://src/core/agents/components/collision_hull.gd"  # Loaded when run: it needs the autoloads


func _initialize():
	call_deferred("_bake")


func _bake():
	var CollisionHull = load(COLLISION_HULL)
	var models: Array = []
	for arg in OS.get_cmdline_args():
		if arg.ends_with(".glb"):
			models.append(arg if arg.begins_with("res://") else "res://" + arg)
	if models.empty():
		models = _ship_models(CollisionHull)
	var failed := 0
	for model_path in models:
		var started: int = OS.get_ticks_usec()
		var shape: ConcavePolygonShape = CollisionHull.build_surface(model_path)
		if shape == null:
			print("SKIP %s: no faces" % model_path)
			continue
		var out: String = CollisionHull.baked_surface_path(model_path)
		Directory.new().make_dir_recursive(out.get_base_dir())
		var error: int = ResourceSaver.save(out, shape)
		if error != OK:
			failed += 1
			print("FAIL %s: error %d" % [out, error])
			continue
		print("OK   %s: %d triangles, %.1f ms" % [out, shape.get_faces().size() / 3, (OS.get_ticks_usec() - started) / 1000.0])
	quit(1 if failed > 0 else 0)


func _ship_models(CollisionHull) -> Array:
	var models: Array = []
	var folder := Directory.new()
	if folder.open(CollisionHull.HIT_SURFACE_MODELS) != OK:
		return models
	folder.list_dir_begin(true, true)
	var file: String = folder.get_next()
	while file != "":
		var path: String = CollisionHull.HIT_SURFACE_MODELS + file
		if not folder.current_is_dir() and file.ends_with(".glb") and not CollisionHull.MeshLod.lod_paths_for(path).empty():
			models.append(path)
		file = folder.get_next()
	folder.list_dir_end()
	models.sort()
	return models
