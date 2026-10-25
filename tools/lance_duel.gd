# Lance duels: ships of two designs fight one on one, well away from the arenas, sped up; prints
# who won, how long it took and what the lance did (strikes, glances, damage, closing speeds).
# A throwaway save folder; never the real save. DUEL_TRACE=1 in the environment prints the first
# ship's state every second (distance, speed, activity, lance, run-up).
#     godot --no-window -s tools/lance_duel.gd -- --duels=8 --speed=6
# Designs (Genome genomes, see DESIGNS): "lancer" (small and fast: lance and harpoon), "lance_laser"
# (Phoenix Light sized, engine-heavy: lance and a laser), "laser" (the Phoenix Light, two lasers),
# "laser_heavy" (a big slow three-laser ship), "hauler" (an unarmed Phoenix Light), "lancer_fast"
# (engine-heavy, a 200 kg lance and a light laser). See MATCHES.
extends SceneTree

const DESIGNS = {
	"lancer": {"ship": {"type": 1, "size": 0.5, "shares": {"structure": 0.4, "engine": 0.38, "reactor": 0.08, "capacitor": 0.04, "hold": 0.1}},
		"tools": [{"kind": "harpoon", "type": 0, "genes": {}}], "modules": [{"kind": "lance", "type": 1, "genes": {"nail_mass": 100.0, "count": 3.0}}]},
	"lancer_fast": {"ship": {"type": 1, "size": 0.6, "shares": {"structure": 0.3, "engine": 0.5, "reactor": 0.08, "capacitor": 0.04, "hold": 0.08}},
		"tools": [{"kind": "laser", "type": 1, "genes": {"mass": 100.0, "energy": 1.5}}], "modules": [{"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}]},
	"lance_laser": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.45, "engine": 0.32, "reactor": 0.1, "capacitor": 0.05, "hold": 0.08}},
		"tools": [{"kind": "laser", "type": 1, "genes": {"mass": 150.0, "energy": 2.5}}, {}], "modules": [{"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}, {}]},
	"laser": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}], "modules": [{}, {}]},
	"laser_heavy": {"ship": {"type": 3, "size": 2.5, "shares": {"structure": 0.65, "engine": 0.15, "reactor": 0.1, "capacitor": 0.04, "hold": 0.06}},
		"tools": [{"kind": "laser", "type": 3, "genes": {"mass": 600.0, "energy": 12.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}],
		"modules": [{"kind": "plating", "type": 2, "genes": {"mass": 1000.0}}, {}, {}]},
	"hauler": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{}, {}], "modules": [{}, {}]},
}
const MATCHES = [["lancer", "hauler"], ["lancer", "laser"], ["lancer_fast", "laser"], ["lancer_fast", "laser_heavy"], ["lance_laser", "laser"], ["lance_laser", "laser_heavy"]]
const DUEL_TIME = 180.0  # s of game time before a duel is called a draw
const ARENA_OFFSET = Vector3(0, 6000, 0)  # From the home station: far from the arenas' zones

var duels := 6
var speed := 6.0
var _shown: Dictionary = {}


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--duels="):
			duels = int(arg.split("=")[1])
		elif arg.begins_with("--speed="):
			speed = max(1.0, float(arg.split("=")[1]))
	OS.vsync_enabled = false
	call_deferred("_run")


func _wait(sec):
	yield(create_timer(sec, true), "timeout")


func _run():
	var refs = root.get_node("GlobalRefs")
	root.get_node("GameStateManager").save_dir = "user://test_savegames/"
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	paused = false
	Engine.iterations_per_second = int(60 * speed)
	Engine.time_scale = speed
	var genome_script = load("res://src/core/evolution/genome.gd")
	var built := {}
	for design in DESIGNS:
		built[design] = genome_script.build(DESIGNS[design], "duel_" + design, "verdant")
	var centre: Vector3 = refs.player_agent_body.global_transform.origin + ARENA_OFFSET
	for pairing in MATCHES:
		print("DESIGNS %s vs %s" % [pairing[0], pairing[1]])
		var tally := {"wins": {}, "draws": 0, "times": [], "strikes": 0, "glances": 0, "damage": 0.0, "speeds": []}
		for i in range(duels):
			var result = yield(_duel(built[pairing[0]], built[pairing[1]], centre), "completed")
			if result.winner == "":
				tally.draws += 1
			else:
				var side: String = pairing[0] if result.winner == "a" else pairing[1]
				tally.wins[side + (" (a)" if result.winner == "a" else " (b)")] = int(tally.wins.get(side + (" (a)" if result.winner == "a" else " (b)"), 0)) + 1
				tally.times.append(result.time)
			tally.strikes += result.strikes
			tally.glances += result.glances
			tally.damage += result.damage
			tally.speeds += result.speeds
		print("DUEL %s vs %s: wins %s, draws %d, mean time %.0fs, lance strikes %d (%.0f damage), glances %d, closing speeds at contact %s" % [
			pairing[0], pairing[1], tally.wins, tally.draws, _mean(tally.times), tally.strikes, tally.damage, tally.glances, _summary(tally.speeds)])
	quit()


# One duel: two fresh ships 3 km apart, each told to fight the other. Returns {"winner": "a"/"b"/"",
# "time", "strikes", "glances", "damage", "speeds"}.
func _duel(a_build: Dictionary, b_build: Dictionary, centre: Vector3):
	var spawner = _find_agent_system()
	var a = spawner.spawn_npc_from_template(Constants_path("NPC_BASE_TEMPLATE_PATH"), centre + Vector3(-1500, 0, 0), {
		"faction": "verdant", "ship_template_id": a_build.ship_template_id, "fit": a_build.fit, "wallet": 1e6, "skill": 0.8})
	var b = spawner.spawn_npc_from_template(Constants_path("NPC_BASE_TEMPLATE_PATH"), centre + Vector3(1500, 0, 0), {
		"faction": "violet", "ship_template_id": b_build.ship_template_id, "fit": b_build.fit, "wallet": 1e6, "skill": 0.8})
	if not _shown.has(a_build.ship_template_id + b_build.ship_template_id):
		_shown[a_build.ship_template_id + b_build.ship_template_id] = true
		for body in [a, b]:
			print("  %s: top speed %.0f m/s, hull %.0f, %.0f kg" % [body.ship_template.template_id, body.get_top_speed(), body.hull_max, body.mass])
	var result := {"winner": "", "time": 0.0, "strikes": 0, "glances": 0, "damage": 0.0, "speeds": []}
	for pair in [[a, b], [b, a]]:
		var lance = pair[0].get_lance()
		if lance != null:
			lance.connect("struck", self, "_on_struck", [result, pair[0]])
			lance.connect("glanced", self, "_on_glanced", [result, pair[0]])
		var ai = pair[0].get_node_or_null("AIController")
		if ai != null:
			ai._start_combat(pair[1], true)
	var t := 0.0
	while t < DUEL_TIME:
		yield(_wait(1.0), "completed")
		t += 1.0
		var a_out: bool = not is_instance_valid(a) or a.is_wreck
		var b_out: bool = not is_instance_valid(b) or b.is_wreck
		if a_out or b_out:
			result.winner = "" if a_out and b_out else ("b" if a_out else "a")
			result.time = t
			break
		if OS.get_environment("DUEL_TRACE") != "":
			var lance = a.get_lance()
			var nav = a.navigation_system._current_command
			print("TRACE t=%d dist=%.0f a_speed=%.0f top=%.0f a=%s armed=%s nails=%s run_up=%s b=%s a_hull=%.0f b_hull=%.0f" % [t,
				a.global_transform.origin.distance_to(b.global_transform.origin), a.linear_velocity.length(), a.get_top_speed(),
				a.get_node("AIController").get_activity_label(), lance.armed if lance else "-", lance.nails if lance else "-",
				nav.get("running_up", "-"), b.get_node("AIController").get_activity_label(), a.hull, b.hull])
		for pair in [[a, b], [b, a]]:  # Keep them at it (a broken-off fight starts again)
			var ai = pair[0].get_node_or_null("AIController")
			if ai != null and ai.get_state() in [1, 3]:  # PATROL, FLEE
				ai._start_combat(pair[1], true)
	for body in [a, b]:
		if is_instance_valid(body):
			body.despawn()
	yield(_wait(1.0), "completed")
	return result


func _on_struck(_target, damage, result, rammer):
	result.strikes += 1
	result.damage += damage
	var lance = rammer.get_lance()
	result.speeds.append(int(damage / float(lance.lance.damage) * root.get_node("Constants").LAW_LANCE_REF_SPEED))  # Damage is linear in speed


func _on_glanced(target, result, rammer):
	result.glances += 1
	var lance = rammer.get_lance()
	result.speeds.append(-int(lance.closing_speed_on(target)) if lance != null else 0)


func _find_agent_system():
	for node in get_nodes_in_group("agent_system"):
		return node
	var stack: Array = [root]
	while not stack.empty():
		var node = stack.pop_back()
		if node.has_method("spawn_npc_from_template"):
			return node
		stack += node.get_children()
	return null


func Constants_path(name: String) -> String:
	return root.get_node("Constants").get(name)


static func _mean(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / max(1, values.size())


static func _summary(values: Array) -> String:
	if values.empty():
		return "-"
	var sorted: Array = values.duplicate()
	sorted.sort()
	return "%s (negative: glances)" % str(sorted)
