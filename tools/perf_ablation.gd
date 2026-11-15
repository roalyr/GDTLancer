# Performance ablation: the sector's traffic by the home station (player docked; no fight is staged:
# tools/fight_bench.gd measures fights), measured
# with one system switched off, to see what each costs. The 3D view renders at quarter scale so the
# GPU's fill rate is out of the picture (as on phones, where render scale did not change the frame
# rate); mode=base_full renders at full scale. Prints frame times, the split into physics steps and
# the rest of the frame, engine monitors, and the in-game FrameProfiler's sections.
# Modes: base, base_full, no_3d, no_hud, no_lights, no_particles, no_rocks, no_ships_3d, lod_low,
# physics_30, no_ai; for the rendering draft: no_starsphere, sky_color (environment background a
# plain colour), no_exhausts, no_preview (the fitting window's hull preview viewport not updated),
# no_star (the star's shells and sprite hidden; its light stays). Any mode ending in _full renders at
# full scale. Vsync is off (a sleeping monitor otherwise blocks the swap a second a frame). Uses a
# throwaway save folder. Run one mode per process:
#     godot --no-window -s tools/perf_ablation.gd mode=no_hud
# ab=1 measures A/B in one process instead: the mode switches on and off every 2 s for the 30 s
# (the first 0.3 s after each switch not counted) and one `AB` line gives each half's median frame
# and median idle part (process + render, the physics steps left out) with the monitors. Fairer
# than two processes when the machine warms up over a series. Reversible modes only: no_starsphere,
# sky_color, no_exhausts, no_preview, no_star, no_lights, no_particles, no_rocks, no_ships_3d,
# no_hud (hidden only), no_3d.
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
var ab = false
var ab_on = false  # The mode is on now (A/B)
var ab_since = 0  # usec of the last switch
var ab_frames = [[], []]  # [off, on]
var ab_idle = [[], []]
var ab_mon = [{}, {}]
var ab_saved = {}  # What a switch changed, to put back: node -> visible, and the like
const MONS = {
	"process": Performance.TIME_PROCESS, "physics": Performance.TIME_PHYSICS_PROCESS,
	"draws": Performance.RENDER_DRAW_CALLS_IN_FRAME, "objects": Performance.RENDER_OBJECTS_IN_FRAME,
	"materials": Performance.RENDER_MATERIAL_CHANGES_IN_FRAME, "shaders": Performance.RENDER_SHADER_CHANGES_IN_FRAME,
	"surfaces": Performance.RENDER_SURFACE_CHANGES_IN_FRAME, "2d_items": Performance.RENDER_2D_ITEMS_IN_FRAME,
	"2d_draws": Performance.RENDER_2D_DRAW_CALLS_IN_FRAME, "nodes": Performance.OBJECT_NODE_COUNT,
	"vertices": Performance.RENDER_VERTICES_IN_FRAME,
}
func _initialize():
	OS.vsync_enabled = false
	for a in OS.get_cmdline_args():
		if a.begins_with("mode="):
			mode = a.substr(5)
		elif a == "ab=1":
			ab = true
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
			_ab_idle(now)
		t_phys_start = now
		in_frame_phys = true
func _on_frame():
	var now = OS.get_ticks_usec()
	if in_frame_phys:
		phys_ms += (now - t_phys_start) / 1000.0
		in_frame_phys = false
	elif t_idle > 0:
		idle_ms += (now - t_idle) / 1000.0
		_ab_idle(now)
	if ab and last > 0 and t_idle - ab_since > 300000:
		var side = 1 if ab_on else 0
		ab_frames[side].append((now - last) / 1000.0)
		for k in MONS:
			ab_mon[side][k] = ab_mon[side].get(k, 0.0) + Performance.get_monitor(MONS[k])
	t_idle = now
	if last > 0:
		frames.append((now - last) / 1000.0)
		for k in MONS:
			mon[k] = mon.get(k, 0.0) + Performance.get_monitor(MONS[k])
	last = now
# The idle part of the frame that began at t_idle, to the half it ran in.
func _ab_idle(now):
	if ab and t_idle - ab_since > 300000:
		ab_idle[1 if ab_on else 0].append((now - t_idle) / 1000.0)


# Switches mode `m` on or off, putting back what it changed.
func _switch(m, on):
	var nodes = []
	if m == "no_starsphere":
		nodes = _find(root, "StarsphereSlot").get_children()
	elif m == "no_star":
		for n in _all(root, []):
			if (n.name == "Model" or n.name == "ModelAdditional") and n.get_parent() != null and n.get_parent().name.begins_with("Star "):
				nodes.append(n)
	elif m == "no_lights":
		for n in _all(root, []):
			if n is Light and not (n.get_viewport() != null and n.get_viewport().get_parent() != null and n.get_viewport().get_parent().name == "HullPreview"):
				nodes.append(n)
	elif m == "no_particles":
		for n in _all(root, []):
			if n is CPUParticles:
				nodes.append(n)
	elif m == "no_rocks":
		for n in get_nodes_in_group("asteroid"):
			nodes.append(n.get_node("Model"))
	elif m == "no_ships_3d":
		for n in get_nodes_in_group("agent_body"):
			nodes.append(n.get_node("Model"))
	elif m == "no_hud":
		nodes = [_find(root, "MainHUD")]
	elif m == "no_exhausts":
		root.get_node("Settings").set_option("engine_exhausts", not on)
	elif m == "sky_color":
		for n in _all(root, []):
			if n is WorldEnvironment:
				if on:
					ab_saved[n] = n.environment.background_mode
					n.environment.background_mode = Environment.BG_COLOR
				elif ab_saved.has(n):
					n.environment.background_mode = ab_saved[n]
	elif m == "no_preview" or m == "no_3d":
		for n in _all(root, []):
			if n is Viewport and n.get_parent() != null and n.get_parent().name == ("HullPreview" if m == "no_preview" else "WorldViewportContainer") or (m == "no_3d" and n.name == "WorldViewport"):
				if on:
					ab_saved[n] = n.render_target_update_mode
					n.render_target_update_mode = Viewport.UPDATE_DISABLED
				elif ab_saved.has(n):
					n.render_target_update_mode = ab_saved[n]
	for n in nodes:
		if on:
			ab_saved[n] = n.visible
			n.visible = false
		elif ab_saved.has(n) and is_instance_valid(n):
			n.visible = ab_saved[n]
	if not on:
		ab_saved.clear()
	ab_on = on
	ab_since = OS.get_ticks_usec()


func _median(list):
	if list.empty():
		return 0.0
	list.sort()
	return list[list.size() / 2]


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
	var m = mode.trim_suffix("_full")
	if m == "base":
		pass
	elif m == "no_starsphere":
		var slot = _find(root, "StarsphereSlot")
		for c in slot.get_children():
			c.visible = false
	elif m == "sky_color":
		for n in _all(root, []):
			if n is WorldEnvironment:
				n.environment.background_mode = Environment.BG_COLOR
	elif m == "no_exhausts":
		root.get_node("Settings").set_option("engine_exhausts", false)
	elif m == "no_preview":
		for n in _all(root, []):
			if n is Viewport and n.get_parent() != null and n.get_parent().name == "HullPreview":
				n.render_target_update_mode = Viewport.UPDATE_DISABLED
	elif m == "no_star":
		for n in _all(root, []):
			if n.name == "Model" or n.name == "ModelAdditional":
				if n.get_parent() != null and n.get_parent().name.begins_with("Star "):
					n.visible = false
	elif m == "no_hud":
		var hud = _find(root, "MainHUD")
		for n in _all(hud, []):
			n.set_process(false)
			n.set_physics_process(false)
		hud.visible = false
	elif m == "no_lights":
		for n in _all(root, []):
			if n is Light:
				n.visible = false
	elif m == "no_particles":
		for n in _all(root, []):
			if n is CPUParticles:
				n.emitting = false
				n.visible = false
	elif m == "no_3d":
		vp.render_target_update_mode = Viewport.UPDATE_DISABLED
	elif m == "no_rocks":
		for n in get_nodes_in_group("asteroid"):
			n.get_node("Model").visible = false
	elif m == "lod_low":
		for n in _all(root, []):
			if n.get_script() != null and n.get_script().resource_path.ends_with("mesh_lod.gd"):
				n.set_process(false)
				n.show_level(n.levels.size() - 1)
	elif m == "physics_30":
		Engine.iterations_per_second = 30
	elif m == "no_ships_3d":
		for n in get_nodes_in_group("agent_body"):
			n.get_node("Model").visible = false
	elif m == "no_ai":
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
	if ab:
		yield(_run_ab(), "completed")
		quit()
		return
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



func _run_ab():
	var m = mode.trim_suffix("_full")
	for n in _all(root, []):
		if n.has_method("set_downscale_factor"):
			n.set_downscale_factor(0.25 if not mode.ends_with("_full") else 1.0)
	yield(_wait(1.0), "completed")
	connect("idle_frame", self, "_on_frame")
	connect("physics_frame", self, "_on_physics")
	for i in range(15):
		_switch(m, i % 2 == 1)
		yield(_wait(2.0), "completed")
	_switch(m, false)
	disconnect("idle_frame", self, "_on_frame")
	disconnect("physics_frame", self, "_on_physics")
	var s = "AB %-14s" % mode
	for side in [0, 1]:
		var n = max(ab_frames[side].size(), 1)
		s += " | %s: frames=%d frame=%.2fms idle=%.2fms" % [["off", "on"][side], ab_frames[side].size(), _median(ab_frames[side]), _median(ab_idle[side])]
		for k in ["draws", "materials", "shaders", "surfaces", "vertices", "objects"]:
			s += " %s=%d" % [k, ab_mon[side].get(k, 0.0) / n]
	print(s)
