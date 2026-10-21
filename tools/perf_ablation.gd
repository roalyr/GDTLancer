# Performance ablation: a headless battle by the home station (player docked, out of it), measured
# with one system switched off, to see what each costs. The 3D view renders at quarter scale so the
# GPU's fill rate is out of the picture (as on phones, where render scale did not change the frame
# rate); mode=base_full renders at full scale. Prints frame times, the split into physics steps and
# the rest of the frame, engine monitors, and the in-game FrameProfiler's sections.
# Modes: base, base_full, no_3d, no_hud, no_lights, no_particles, no_rocks, no_ships_3d, lod_low,
# physics_30, no_ai. Uses a throwaway save folder. Run one mode per process:
#     godot --no-window -s tools/perf_ablation.gd mode=no_hud
# (Monitor asleep or a compositor stalling? add an override.cfg with vsync off.)
extends SceneTree
var frames = []
var phys_ms = 0.0
var idle_ms = 0.0
var steps = 0
var t_phys_start = 0
var t_idle = 0
var in_frame_phys = false
var last = 0
var mon = {}
var mode = "base"
const MONS = {
	"process": Performance.TIME_PROCESS, "physics": Performance.TIME_PHYSICS_PROCESS,
	"draws": Performance.RENDER_DRAW_CALLS_IN_FRAME, "objects": Performance.RENDER_OBJECTS_IN_FRAME,
	"materials": Performance.RENDER_MATERIAL_CHANGES_IN_FRAME, "shaders": Performance.RENDER_SHADER_CHANGES_IN_FRAME,
	"surfaces": Performance.RENDER_SURFACE_CHANGES_IN_FRAME, "2d_items": Performance.RENDER_2D_ITEMS_IN_FRAME,
	"2d_draws": Performance.RENDER_2D_DRAW_CALLS_IN_FRAME, "nodes": Performance.OBJECT_NODE_COUNT,
	"vertices": Performance.RENDER_VERTICES_IN_FRAME,
}
func _initialize():
	for a in OS.get_cmdline_args():
		if a.begins_with("mode="):
			mode = a.substr(5)
	call_deferred("_run")
func _wait(sec):
	yield(create_timer(sec, true), "timeout")
# physics_frame fires before each physics step, idle_frame before the idle (process + render) part.
func _on_physics():
	var now = OS.get_ticks_usec()
	steps += 1
	if not in_frame_phys:
		if t_idle > 0:
			idle_ms += (now - t_idle) / 1000.0
		t_phys_start = now
		in_frame_phys = true
func _on_frame():
	var now = OS.get_ticks_usec()
	if in_frame_phys:
		phys_ms += (now - t_phys_start) / 1000.0
		in_frame_phys = false
	elif t_idle > 0:
		idle_ms += (now - t_idle) / 1000.0
	t_idle = now
	if last > 0:
		frames.append((now - last) / 1000.0)
		for k in MONS:
			mon[k] = mon.get(k, 0.0) + Performance.get_monitor(MONS[k])
	last = now
func _all(n, out):
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out
func _apply_mode():
	var vp = _find(root, "WorldViewport")
	var wr = null
	for n in _all(root, []):
		if n.has_method("set_downscale_factor"):
			wr = n
	wr.set_downscale_factor(0.25 if not mode.ends_with("_full") else 1.0)
	if mode.begins_with("base"):
		pass
	elif mode == "no_hud":
		var hud = _find(root, "MainHUD")
		for n in _all(hud, []):
			n.set_process(false)
			n.set_physics_process(false)
		hud.visible = false
	elif mode == "no_lights":
		for n in _all(root, []):
			if n is Light:
				n.visible = false
	elif mode == "no_particles":
		for n in _all(root, []):
			if n is CPUParticles:
				n.emitting = false
				n.visible = false
	elif mode == "no_3d":
		vp.render_target_update_mode = Viewport.UPDATE_DISABLED
	elif mode == "no_rocks":
		for n in get_nodes_in_group("asteroid"):
			n.get_node("Model").visible = false
	elif mode == "lod_low":
		for n in _all(root, []):
			if n.get_script() != null and n.get_script().resource_path.ends_with("mesh_lod.gd"):
				n.set_process(false)
				n.show_level(n.levels.size() - 1)
	elif mode == "physics_30":
		Engine.iterations_per_second = 30
	elif mode == "no_ships_3d":
		for n in get_nodes_in_group("agent_body"):
			n.get_node("Model").visible = false
	elif mode == "no_ai":
		for n in _all(root, []):
			if n.name == "AIController":
				n.set_physics_process(false)
				n.set_process(false)
func _find(n, name):
	if n.name == name:
		return n
	for c in n.get_children():
		var r = _find(c, name)
		if r:
			return r
	return null
func _run():
	var refs = root.get_node("GlobalRefs")
	root.get_node("GameStateManager").save_dir = "user://test_savegames/"
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	seed(7)
	yield(_wait(25.0), "completed")
	_apply_mode()
	yield(_wait(1.0), "completed")
	connect("idle_frame", self, "_on_frame")
	connect("physics_frame", self, "_on_physics")
	yield(_wait(30.0), "completed")
	disconnect("idle_frame", self, "_on_frame")
	disconnect("physics_frame", self, "_on_physics")
	frames.sort()
	var n = frames.size()
	var s = "ABLATE %-12s frames=%d median=%.1fms p95=%.1fms | per frame: physics %.2fms (%.2f steps, %.2fms/step) idle+render %.2fms |" % [mode, n, frames[n / 2], frames[int(n * 0.95)], phys_ms / n, float(steps) / n, phys_ms / max(steps, 1), idle_ms / n]
	for k in MONS:
		var v = mon[k] / n
		s += " %s=%s" % [k, ("%.1fms" % (v * 1000.0)) if k in ["process", "physics"] else ("%d" % v)]
	print(s)
	var hud = _find(root, "MainHUD")
	print("PROFILER ", hud._frame_profiler.report)
	quit()
