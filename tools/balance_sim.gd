# Combat balance sim: a headless faction battle by the home station (the player stays docked, out
# of it), sped up. Prints kills by ship class with how long each fight took from the first hit, and
# damage dealt and hit ranges per class. Uses a throwaway save folder, never real saves.
# Run (monitor asleep or a compositor stalling? add an override.cfg with vsync off):
#     godot --no-window -s tools/balance_sim.gd
extends SceneTree

const TIME_SCALE = 3.0
const GAME_SECONDS = 300.0

var first_hit = {}  # victim id -> game time of first damage
var last_source = {}
var kills = []  # [victim class, killer class, seconds from first hit]
var dmg_by = {}  # class -> damage dealt
var ranges = {}  # class -> [hit distances]
var game_time = 0.0
func _initialize():
	call_deferred("_run")
func _wait(sec):
	yield(create_timer(sec, true), "timeout")
func _cls(a):
	if not is_instance_valid(a):
		return "?"
	if a.has_method("is_player") and a.is_player():
		return "player"
	return a.ship_template.template_id.replace("ship_", "") if a.ship_template else "?"
func _on_damaged(victim, amount, source):
	var id = victim.get_instance_id()
	if not first_hit.has(id):
		first_hit[id] = game_time
	last_source[id] = _cls(source)
	var c = _cls(source)
	dmg_by[c] = dmg_by.get(c, 0.0) + amount
	if is_instance_valid(source):
		if not ranges.has(c):
			ranges[c] = []
		ranges[c].append(victim.global_transform.origin.distance_to(source.global_transform.origin))
func _on_disabled(victim):
	var id = victim.get_instance_id()
	kills.append([_cls(victim), last_source.get(id, "?"), game_time - first_hit.get(id, game_time)])
func _idle(delta):
	game_time += delta
func _run():
	var refs = root.get_node("GlobalRefs")
	root.get_node("GameStateManager").save_dir = "user://test_savegames/"
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	var bus = root.get_node("EventBus")
	bus.connect("agent_damaged", self, "_on_damaged")
	bus.connect("agent_disabled", self, "_on_disabled")
	Engine.time_scale = TIME_SCALE
	var t0 = OS.get_ticks_msec()
	while game_time < GAME_SECONDS:
		yield(self, "idle_frame")
	Engine.time_scale = 1.0
	print("SIM game_s=%d real_s=%.0f" % [game_time, (OS.get_ticks_msec() - t0) / 1000.0])
	var tally = {}
	for k in kills:
		var key = "%s killed by %s" % [k[0], k[1]]
		if not tally.has(key):
			tally[key] = []
		tally[key].append(k[2])
	for key in tally:
		var s = 0.0
		for v in tally[key]:
			s += v
		print("SIM %s: %d, mean fight %.1fs" % [key, tally[key].size(), s / tally[key].size()])
	for c in dmg_by:
		var r = ranges.get(c, [0])
		r.sort()
		print("SIM %s dealt %.0f dmg, hit range median %.0f m (p90 %.0f)" % [c, dmg_by[c], r[r.size() / 2], r[int(r.size() * 0.9)]])
	quit()
