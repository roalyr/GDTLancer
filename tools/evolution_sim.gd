# Headless evolution run: plays the game with the player docked at home, the sector's havens populated (SectorLayout) and running sped
# up, and saves to the real save slot as it goes, so the game can load and carry on from it (and
# this can carry on from the game's save). The console gets Evolution's EVO lines and reports.
#     godot --no-window -s tools/evolution_sim.gd -- --hours=4 --speed=8
# Options (after --):
#   --hours=H      simulated hours to run (default 1)
#   --speed=X      time scale; physics steps per second scale with it, so the physics is unchanged (default 6)
#   --new          start a new evolution even if a save exists (otherwise the save is loaded)
#   --save-every=M simulated minutes between saves (default 15)
#   --save-dir=D   save folder (default the game's); use another to keep a run apart
#   --new-era      the rules changed: every genome's record starts over (Evolution.new_era)
#   --backup-every=H simulated hours between copies of the save into user://save_backups/ (with
#                  --save-dir, its backups/ folder), and at the end (default 2; the newest
#                  EVOSIM_BACKUPS_KEPT are kept): a blackout loses at most that much
#   --frozen       fly the frozen world (the archetypes, as the game does) instead of evolving:
#                  for watching how the game's world plays out; use with --save-dir and --new
#   --probe        every 10 simulated minutes, list NPCs stuck in one activity for 30 minutes or more
#                  (state, target, throttle, speed): for finding ships that never finish a life
# Vsync is switched off: with it, a monitor gone to sleep (DPMS) stalls every frame and the run with it.
extends SceneTree

var hours := 1.0
var speed := 6.0
var fresh := false
var save_every := 15.0
var save_dir := ""
var new_era := false
var probe := false
var frozen := false
var backup_every := 2.0
const EVOSIM_BACKUPS_KEPT = 3
var _since: Dictionary = {}  # Probe: evo uid -> [activity, game time it began]


func _initialize():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--hours="):
			hours = float(arg.split("=")[1])
		elif arg.begins_with("--speed="):
			speed = max(1.0, float(arg.split("=")[1]))
		elif arg == "--new":
			fresh = true
		elif arg.begins_with("--save-every="):
			save_every = max(1.0, float(arg.split("=")[1]))
		elif arg.begins_with("--save-dir="):
			save_dir = arg.split("=")[1]
		elif arg == "--new-era":
			new_era = true
		elif arg == "--probe":
			probe = true
		elif arg == "--frozen":
			frozen = true
		elif arg.begins_with("--backup-every="):
			backup_every = max(0.25, float(arg.split("=")[1]))
	OS.vsync_enabled = false
	call_deferred("_run")


func _wait(sec):
	yield(create_timer(sec, true), "timeout")


func _run():
	var refs = root.get_node("GlobalRefs")
	var manager = root.get_node("GameStateManager")
	var evolution = root.get_node("Evolution")
	evolution.frozen = frozen  # The game's world is frozen; the arena evolves
	if save_dir != "":
		manager.save_dir = save_dir
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	refs.agent_spawner.run_traffic = false  # No travellers among the evolving NPCs
	refs.agent_spawner.offscreen.enabled = false  # Every NPC flown: fitness from real fights only
	if not fresh and manager.has_save_file(0):
		print("EVOSIM loading the saved game")
		manager.load_game(0)
	else:
		print("EVOSIM new game, new evolution")
		root.get_node("EventBus").emit_signal("new_game_requested")
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
	if new_era:
		evolution.new_era()
	var menu = _find_menu()
	if menu != null:
		menu.visible = false
	paused = false
	Engine.iterations_per_second = int(60 * speed)
	Engine.time_scale = speed
	var start_time: float = evolution.game_time
	var end_time: float = start_time + hours * 3600.0
	var next_save: float = start_time + save_every * 60.0
	var next_probe: float = start_time + 600.0
	var next_backup: float = start_time + backup_every * 3600.0
	var t0 = OS.get_ticks_msec()
	print("EVOSIM running %.1f h of evolution time at x%.0f, from t=%.0fs" % [hours, speed, start_time])
	while evolution.game_time < end_time:
		yield(_wait(5.0), "completed")
		if paused:
			paused = false  # Nothing here should pause the run (a menu opened by a stray event)
		if probe and evolution.game_time >= next_probe:
			next_probe = evolution.game_time + 600.0
			_probe(evolution.game_time)
		if evolution.game_time >= next_save:
			next_save = evolution.game_time + save_every * 60.0
			print("EVOSIM saved=%s t=%.0fs wall=%.0fs pace x%.1f nodes=%d orphans=%d objects=%d bodies=%d templates=%d genomes=%d mem=%.0fMB" % [
				manager.save_game(0), evolution.game_time, (OS.get_ticks_msec() - t0) / 1000.0,
				(evolution.game_time - start_time) / max(0.001, (OS.get_ticks_msec() - t0) / 1000.0),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT), get_nodes_in_group("agent_body").size(),
				root.get_node("TemplateDatabase").evolved.size(), evolution.genomes.size(), OS.get_static_memory_usage() / 1048576.0])
			if evolution.game_time >= next_backup:
				next_backup = evolution.game_time + backup_every * 3600.0
				_backup(manager, evolution.game_time)
	Engine.time_scale = 1.0
	Engine.iterations_per_second = 60
	evolution.print_report()
	print("EVOSIM done, saved=%s" % manager.save_game(0))
	_backup(manager, evolution.game_time)
	quit()


# Copies the save just written to user://save_backups/auto_t<simulated hour>.sav and keeps the newest
# EVOSIM_BACKUPS_KEPT of those.
func _backup(manager, now: float) -> void:
	var folder: String = "user://save_backups/" if save_dir == "" else save_dir.plus_file("backups/")  # A run of its own keeps its own
	var dir := Directory.new()
	dir.make_dir_recursive(folder)
	var target: String = folder + "auto_t%06.2fh.sav" % (now / 3600.0)
	var err: int = dir.copy(manager._get_save_path(0), target)
	print("EVOSIM backup %s -> %s" % ["ok" if err == OK else "FAILED %d" % err, target])
	var autos: Array = []
	if dir.open(folder) == OK:
		dir.list_dir_begin(true, true)
		var name: String = dir.get_next()
		while name != "":
			if name.begins_with("auto_t") and name.ends_with(".sav"):
				autos.append(name)
			name = dir.get_next()
	autos.sort()  # Zero-padded hours: oldest first
	while autos.size() > EVOSIM_BACKUPS_KEPT:
		dir.remove(folder + autos.pop_front())


func _probe(now: float) -> void:
	var stuck := 0
	for body in get_nodes_in_group("agent_body"):
		var ai = body.get_node_or_null("AIController")
		if ai == null or str(body.get("evo_uid")) == "" or body.get("is_wreck"):
			continue
		var activity: String = "%s/%s" % [ai.get_activity_label(), "docked" if body.get("is_docked") else "flying"]
		var uid: String = str(body.evo_uid)
		if not _since.has(uid) or _since[uid][0] != activity:
			_since[uid] = [activity, now]
		elif now - _since[uid][1] >= 1800.0:
			stuck += 1
			var target = ai.get_focus()
			var movement = body.get("movement_system")
			print("EVOSIM PROBE %s %s for %.0f min: target=%s pending=%s throttle=%.2f speed=%.1f quiet=%s station=%s at %s" % [
				uid, activity, (now - _since[uid][1]) / 60.0, target.get("evo_uid") if target != null else "-",
				ai.get("_pending"), movement.thrust_throttle if movement != null else -1.0, body.linear_velocity.length(),
				ai.get("_quiet_now"), ai.get("_station").name if is_instance_valid(ai.get("_station")) else "-", body.global_transform.origin.round()])
	print("EVOSIM PROBE t=%.0fs: %d stuck" % [now, stuck])


func _find_menu():
	var stack: Array = [root]
	while not stack.empty():
		var node = stack.pop_back()
		if node.get_script() != null and str(node.get_script().resource_path).ends_with("main_menu.gd"):
			return node
		stack += node.get_children()
	return null
