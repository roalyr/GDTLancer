# Duels: ships of two designs fight one on one, well away from the havens, sped up; prints
# who won, how long it took and what the lance did (strikes, glances, damage, closing speeds).
# A throwaway save folder; never the real save. DUEL_TRACE=1 in the environment prints the first
# ship's state every second (distance, speed, activity, lance, run-up).
#     godot --no-window -s tools/lance_duel.gd -- --duels=8 --speed=6 [--weapons: missile and cannon designs]
#         [--match=lancer,laser: that one match only]
#         [--archetypes=fighter_light,raider_light: two archetypes as the game flies them; several
#          matches split by ";": --archetypes="raider_light,trader_light;raider_medium,trader_medium"]
#         [--free: the first ship is set on the second once and then both pilots do as their genes say:
#          no fight is forced again; prints how each spent its time (activity labels) and how duels ended]
# Designs (Genome genomes, see DESIGNS): "lancer" (small and fast: lance and harpoon), "lance_laser"
# (reference ship sized, engine-heavy: lance and a laser), "laser" (the reference ship, two lasers),
# "laser_heavy" (a big slow three-laser ship), "hauler" (an unarmed reference ship), "lancer_fast"
# (engine-heavy, a 200 kg lance and a light laser), "lance_twin" (lance_laser with a second launcher
# beside the first). See MATCHES.
# Archetypes (database/presets/archetypes/) fly their preset ship and fit with their pilot's skill and
# behaviour genes, as their havens fly them; the first for Verdant, the second for Violet.
extends SceneTree

const DESIGNS = {
	"lancer": {"ship": {"type": 1, "size": 0.5, "shares": {"structure": 0.4, "engine": 0.38, "reactor": 0.08, "capacitor": 0.04, "hold": 0.1}},
		"tools": [{"kind": "harpoon", "type": 0, "genes": {}}], "modules": [{"kind": "lance", "type": 1, "genes": {"nail_mass": 100.0, "count": 3.0}}]},
	"lancer_fast": {"ship": {"type": 1, "size": 0.6, "shares": {"structure": 0.3, "engine": 0.5, "reactor": 0.08, "capacitor": 0.04, "hold": 0.08}},
		"tools": [{"kind": "laser", "type": 1, "genes": {"mass": 100.0, "energy": 1.5}}], "modules": [{"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}]},
	"lance_laser": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.45, "engine": 0.32, "reactor": 0.1, "capacitor": 0.05, "hold": 0.08}},
		"tools": [{"kind": "laser", "type": 1, "genes": {"mass": 150.0, "energy": 2.5}}, {}], "modules": [{"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}, {}]},
	"lance_twin": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.45, "engine": 0.32, "reactor": 0.1, "capacitor": 0.05, "hold": 0.08}},
		"tools": [{"kind": "laser", "type": 1, "genes": {"mass": 150.0, "energy": 2.5}}, {}], "modules": [{"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}, {"kind": "lance", "type": 2, "genes": {"nail_mass": 200.0, "count": 3.0}}]},
	"laser": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}], "modules": [{}, {}]},
	"laser_heavy": {"ship": {"type": 3, "size": 2.5, "shares": {"structure": 0.65, "engine": 0.15, "reactor": 0.1, "capacitor": 0.04, "hold": 0.06}},
		"tools": [{"kind": "laser", "type": 3, "genes": {"mass": 600.0, "energy": 12.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}, {"kind": "laser", "type": 2, "genes": {"mass": 300.0, "energy": 5.0}}],
		"modules": [{"kind": "plating", "type": 2, "genes": {"mass": 1000.0}}, {}, {}]},
	"hauler": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{}, {}], "modules": [{}, {}]},
	"missileer": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{"kind": "missile", "type": 2, "genes": {"round_mass": 100.0, "count": 4.0}}, {"kind": "laser", "type": 1, "genes": {"mass": 150.0, "energy": 2.5}}], "modules": [{}, {}]},
	"gunner": {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.5, "engine": 0.25, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
		"tools": [{"kind": "cannon", "type": 2, "genes": {"mass": 300.0, "round_mass": 5.0, "count": 60.0}}, {"kind": "cannon", "type": 2, "genes": {"mass": 300.0, "round_mass": 5.0, "count": 60.0}}], "modules": [{}, {}]},
}
const MATCHES_WEAPONS = [["missileer", "laser"], ["gunner", "laser"], ["missileer", "gunner"], ["gunner", "lancer_fast"], ["missileer", "lancer_fast"], ["missileer", "laser_heavy"]]
const MATCHES = [["lancer", "hauler"], ["lancer", "laser"], ["lancer_fast", "laser"], ["lancer_fast", "laser_heavy"], ["lance_laser", "laser"], ["lance_laser", "laser_heavy"]]
const DUEL_TIME = 180.0  # s of game time before a duel is called a draw
const FREE_APART = 8000.0  # --free: m apart that ends a duel as parted (one got away)
const FREE_CALM = 15.0  # --free: s with neither fighting nor fleeing that ends a duel as let go
const ARENA_OFFSET = Vector3(0, 15000, 0)  # From the home station : well above the sector's plane

var duels := 6
var matches: Array = MATCHES
var speed := 6.0
var archetypes := false  # --archetypes=: the match is two archetypes, not DESIGNS
var free := false  # --free: no fight forced after the first attack
var rate := 0  # --rate=: physics steps per game second (0: the project's, Interp.physics_rate())
var _shown: Dictionary = {}


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--duels="):
			duels = int(arg.split("=")[1])
		elif arg == "--weapons":
			matches = MATCHES_WEAPONS
		elif arg.begins_with("--match="):
			matches = [arg.split("=")[1].split(",")]
		elif arg.begins_with("--archetypes="):
			matches = []
			for pairing in arg.split("=")[1].split(";"):
				matches.append(pairing.split(","))
			archetypes = true
		elif arg == "--free":
			free = true
		elif arg.begins_with("--rate="):
			rate = int(arg.split("=")[1])
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
	refs.agent_spawner.offscreen.enabled = false  # The fights are staged far from the player: fly them all
	root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	paused = false
	if rate <= 0:
		rate = load("res://src/core/utils/interp.gd").physics_rate()
	print("RATE %d steps a game second" % rate)
	Engine.iterations_per_second = int(rate * speed)  # A step stays 1/rate s of game time
	Engine.time_scale = speed
	var genome_script = load("res://src/core/evolution/genome.gd")
	var built := {}
	if archetypes:
		for index in range(matches.size() * 2):
			var name: String = matches[index / 2][index % 2]
			var faction: String = ["verdant", "violet"][index % 2]
			if built.has(name):
				continue
			var pilot = load(Constants_path("ARCHETYPES_DIR").plus_file("agent_archetype_%s.tres" % name))
			var preset: Dictionary = genome_script.preset_build(name, faction)
			if pilot == null or preset.empty():
				print("DUEL no archetype ", name)
				quit(1)
				return
			built[name] = preset.duplicate()
			built[name]["skill"] = pilot.skill
			built[name]["behavior"] = pilot.behavior.duplicate()
	else:
		for design in DESIGNS:
			built[design] = genome_script.build(_fitted(genome_script, DESIGNS[design]), "duel_" + design, "verdant")
	var centre: Vector3 = refs.player_agent_body.global_transform.origin + ARENA_OFFSET
	for pairing in matches:
		print("DESIGNS %s vs %s" % [pairing[0], pairing[1]])
		var tally := {"wins": {}, "draws": 0, "ends": {}, "labels": [{}, {}], "times": [], "strikes": 0, "glances": 0, "damage": 0.0, "speeds": [], "rounds": {}, "hull_left": [[], []]}
		for i in range(duels):
			var result = yield(_duel(built[pairing[0]], built[pairing[1]], centre), "completed")
			if result.winner == "":
				tally.draws += 1
			else:
				var side: String = pairing[0] if result.winner == "a" else pairing[1]
				tally.wins[side + (" (a)" if result.winner == "a" else " (b)")] = int(tally.wins.get(side + (" (a)" if result.winner == "a" else " (b)"), 0)) + 1
				tally.times.append(result.time)
			_count(tally.ends, result.end)
			for index in range(2):
				for label in result.labels[index]:
					tally.labels[index][label] = int(tally.labels[index].get(label, 0)) + int(result.labels[index][label])
			tally.hull_left[0].append(result.hull_left[0])
			tally.hull_left[1].append(result.hull_left[1])
			tally.strikes += result.strikes
			tally.glances += result.glances
			tally.damage += result.damage
			tally.speeds += result.speeds
			for key in result.rounds:
				tally.rounds[key] = int(tally.rounds.get(key, 0)) + int(result.rounds[key])
		print("DUEL %s vs %s: wins %s, draws %d, mean time %.0fs, hull left %.0f%% vs %.0f%%, lance strikes %d (%.0f damage), glances %d, closing speeds at contact %s, rounds %s" % [
			pairing[0], pairing[1], tally.wins, tally.draws, _mean(tally.times), 100.0 * _mean(tally.hull_left[0]), 100.0 * _mean(tally.hull_left[1]), tally.strikes, tally.damage, tally.glances, _summary(tally.speeds), tally.rounds])
		if free:
			print("FREE %s vs %s: ends %s" % [pairing[0], pairing[1], tally.ends])
			for index in range(2):
				print("  %s spent its time: %s" % [pairing[index], _shares(tally.labels[index])])
	quit()


# A design as the arena would fly it: every part the catalogue's of its kind and weight, the next
# lighter one where it is too big for the hull's slots (Genome._fitted; parts never fitting a slot are
# dropped by the fit, so a medium lance on a light hull flew without one).
func _fitted(genome_script, design: Dictionary) -> Dictionary:
	var genome: Dictionary = design.duplicate(true)
	var slot: String = genome_script.slot_size(genome)
	for group in ["tools", "modules"]:
		for i in range(genome[group].size()):
			genome[group][i] = genome_script._fitted(genome[group][i], slot)
	return genome


# One duel: two fresh ships 3 km apart, each told to fight the other. Returns {"winner": "a"/"b"/"",
# "time", "strikes", "glances", "damage", "speeds"}.
func _duel(a_build: Dictionary, b_build: Dictionary, centre: Vector3):
	var spawner = _find_agent_system()
	var a = spawner.spawn_npc_from_template(Constants_path("NPC_BASE_TEMPLATE_PATH"), centre + Vector3(-1500, 0, 0), _overrides(a_build, "verdant"))
	var b = spawner.spawn_npc_from_template(Constants_path("NPC_BASE_TEMPLATE_PATH"), centre + Vector3(1500, 0, 0), _overrides(b_build, "violet"))
	if not _shown.has(a_build.ship_template_id + b_build.ship_template_id):
		_shown[a_build.ship_template_id + b_build.ship_template_id] = true
		for body in [a, b]:
			print("  %s: top speed %.0f m/s, hull %.0f, %.0f kg" % [body.ship_template.template_id, body.get_top_speed(), body.hull_max, body.mass])
	var result := {"end": "timeout", "labels": [{}, {}], "winner": "", "time": 0.0, "strikes": 0, "glances": 0, "damage": 0.0, "speeds": [], "rounds": {}, "hull_left": [0.0, 0.0]}
	for pair in [[a, b], [b, a]]:
		var lance = pair[0].get_lance()
		if lance != null:
			lance.connect("struck", self, "_on_struck", [result, pair[0]])
			lance.connect("glanced", self, "_on_glanced", [result, pair[0]])
		var ai = pair[0].get_node_or_null("AIController")
		if ai != null and not (free and pair[0] == b):
			ai._start_combat(pair[1], true)  # --free: the first ship only; the other answers as its genes say
		var tools = pair[0].get_node_or_null("ToolController")
		if tools != null:
			tools.connect("projectile_fired", self, "_on_fired", [result])
			tools.connect("missile_intercepted", self, "_on_intercepted", [result])
	var t := 0.0
	var calm := 0.0
	while t < DUEL_TIME:
		yield(_wait(1.0), "completed")
		t += 1.0
		var a_out: bool = not is_instance_valid(a) or a.is_wreck
		var b_out: bool = not is_instance_valid(b) or b.is_wreck
		if a_out or b_out:
			result.winner = "" if a_out and b_out else ("b" if a_out else "a")
			result.end = "both lost" if a_out and b_out else ("b won" if a_out else "a won")
			result.time = t
			break
		if free:
			var busy := false
			for index in range(2):
				var ai = [a, b][index].get_node_or_null("AIController")
				var label: String = ai.get_activity_label() if ai != null else ""
				_count(result.labels[index], label)
				busy = busy or (ai != null and ai.get_state() in [2, 3])  # COMBAT, FLEE
			calm = 0.0 if busy else calm + 1.0
			if a.global_transform.origin.distance_to(b.global_transform.origin) > FREE_APART:
				result.end = "parted"
				break
			if calm >= FREE_CALM:
				result.end = "let go"
				break
			continue
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
	for index in range(2):
		var body = [a, b][index]
		if is_instance_valid(body) and not body.is_wreck:
			result.hull_left[index] = float(body.hull) / max(float(body.hull_max), 1.0)
	for body in [a, b]:
		if is_instance_valid(body):
			body.despawn()
	yield(_wait(1.0), "completed")
	return result


# How a built design spawns: an archetype brings its pilot's skill and behaviour genes.
static func _overrides(build: Dictionary, faction: String) -> Dictionary:
	var out := {"faction": faction, "ship_template_id": build.ship_template_id, "fit": build.fit, "wallet": 1e6, "skill": build.get("skill", 0.8)}
	if build.has("behavior"):
		out["behavior"] = build.behavior
	return out


# Rounds fired and hits, by kind ("missile", "shell"), and missiles shot down.
func _on_fired(_index, projectile, result):
	var kind: String = projectile.get_script().resource_path.get_file().get_basename()
	_count(result.rounds, kind + " fired")
	projectile.connect("hit", self, "_on_round_hit", [kind, result])


func _on_round_hit(_projectile, _body, damage, kind, result):
	_count(result.rounds, kind + (" hit" if damage > 0.0 else " rock"))


func _on_intercepted(_index, _missile, destroyed, result):
	_count(result.rounds, "missile shot down" if destroyed else "missile scorched")


static func _count(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _on_struck(_target, damage, result, thrower):
	result.strikes += 1
	result.damage += damage
	var lance = thrower.get_lance()
	result.speeds.append(int(damage / float(lance.lance.damage) * root.get_node("Constants").LAW_LANCE_REF_SPEED))  # Damage is linear in speed


func _on_glanced(target, _reason, result, thrower):
	result.glances += 1
	var lance = thrower.get_lance()
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


# Each label's share of the counted seconds, most first ("FIGHTING 61%, FLEEING 30%, ...").
static func _shares(counts: Dictionary) -> String:
	var total := 0
	var rows: Array = []
	for label in counts:
		total += int(counts[label])
		rows.append([int(counts[label]), label])
	rows.sort()
	rows.invert()
	var parts: PoolStringArray = []
	for row in rows:
		parts.append("%s %.0f%%" % [row[1] if row[1] != "" else "-", 100.0 * row[0] / max(1, total)])
	return parts.join(", ")


static func _summary(values: Array) -> String:
	if values.empty():
		return "-"
	var sorted: Array = values.duplicate()
	sorted.sort()
	return "%s (negative: glances)" % str(sorted)
