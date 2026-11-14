# Fight bench: a new game, then `n` armed archetype ships a side (verdant fighters and raiders vs
# violet raiders and fighters: lasers, cannons, missiles, lances) staged 2.5 km from the player's
# home, on screen, and kept fighting. Prints frame times (median, p95, p99, worst), rounds fired and
# ships left, then the in-game FrameProfiler's report (per frame: physics, idle, steps, sections).
# The 3D view renders at quarter scale, as perf_ablation.gd does (which measures traffic: nothing
# fights there). A throwaway save folder. Needs a display (DISPLAY=:0).
#     godot --no-window -s tools/fight_bench.gd [n=8] [secs=30]
extends SceneTree

var n := 8
var secs := 30.0
var frames := []
var last := 0
var rounds_seen := 0
var ships := []
const SIDE_A = ["fighter_light", "fighter_medium", "fighter_heavy", "raider_light"]
const SIDE_B = ["raider_light", "raider_medium", "raider_heavy", "fighter_light"]


func _initialize():
	OS.vsync_enabled = false
	for a in OS.get_cmdline_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
		elif a.begins_with("secs="):
			secs = float(a.substr(5))
	call_deferred("_run")


func _wait(sec):
	yield(create_timer(sec, true), "timeout")


func _all(node, out):
	out.append(node)
	for c in node.get_children():
		_all(c, out)
	return out


func _spawner():
	for node in _all(root, []):
		if node.has_method("spawn_npc_from_template"):
			return node


func _on_frame():
	var now = OS.get_ticks_usec()
	if last > 0:
		frames.append((now - last) / 1000.0)
	last = now


func _on_fired(_i, _p):
	rounds_seen += 1


func _run():
	var refs = root.get_node("GlobalRefs")
	root.get_node("GameStateManager").save_dir = "user://test_savegames/"
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	seed(7)
	yield(_wait(5.0), "completed")
	for node in _all(root, []):
		if node.has_method("set_downscale_factor"):
			node.set_downscale_factor(0.25)
	var genome = load("res://src/core/evolution/genome.gd")
	var C = root.get_node("Constants")
	var spawner = _spawner()
	var centre: Vector3 = refs.player_agent_body.global_transform.origin + Vector3(0, 300, -2500)
	var sides = [[], []]
	for side in range(2):
		var faction = ["verdant", "violet"][side]
		for i in range(n):
			var name = (SIDE_A if side == 0 else SIDE_B)[i % 4]
			var pilot = load(C.ARCHETYPES_DIR.plus_file("agent_archetype_%s.tres" % name))
			var build: Dictionary = genome.preset_build(name, faction).duplicate()
			var over := {"faction": faction, "ship_template_id": build.ship_template_id, "fit": build.fit, "wallet": 1e6, "skill": pilot.skill, "behavior": pilot.behavior.duplicate()}
			var at = centre + Vector3((-1 if side == 0 else 1) * 1200 + randf() * 300, randf() * 300, i * 150)
			var body = spawner.spawn_npc_from_template(C.NPC_BASE_TEMPLATE_PATH, at, over)
			sides[side].append(body)
			var tools = body.get_node_or_null("ToolController")
			if tools != null:
				tools.connect("projectile_fired", self, "_on_fired")
	yield(_wait(2.0), "completed")
	_keep_fighting(sides)
	yield(_wait(5.0), "completed")
	connect("idle_frame", self, "_on_frame")
	var t := 0.0
	while t < secs:
		yield(_wait(1.0), "completed")
		t += 1.0
		_keep_fighting(sides)
	disconnect("idle_frame", self, "_on_frame")
	frames.sort()
	var count = frames.size()
	var alive = 0
	for side in sides:
		for b in side:
			if is_instance_valid(b) and not b.is_wreck:
				alive += 1
	var hud = null
	for node in _all(root, []):
		if node.name == "MainHUD":
			hud = node
	print("FIGHT n=%d frames=%d median=%.1fms p95=%.1fms p99=%.1fms max=%.1fms rounds=%d alive=%d" % [n, count, frames[count / 2], frames[int(count * 0.95)], frames[int(count * 0.99)], frames[count - 1], rounds_seen, alive])
	print("PROFILER ", hud._frame_profiler.report)
	quit()


func _keep_fighting(sides):
	for side in range(2):
		for body in sides[side]:
			if not is_instance_valid(body) or body.is_wreck:
				continue
			var ai = body.get_node_or_null("AIController")
			if ai == null or not ai.get_state() in [1, 3]:
				continue
			for foe in sides[1 - side]:
				if is_instance_valid(foe) and not foe.is_wreck:
					ai._start_combat(foe, true)
					break
