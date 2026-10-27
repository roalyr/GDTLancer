# Headless evolution run: plays the game with the player docked at home, the arenas running sped
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
# Vsync is switched off: with it, a monitor gone to sleep (DPMS) stalls every frame and the run with it.
extends SceneTree

var hours := 1.0
var speed := 6.0
var fresh := false
var save_every := 15.0
var save_dir := ""
var new_era := false


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
	OS.vsync_enabled = false
	call_deferred("_run")


func _wait(sec):
	yield(create_timer(sec, true), "timeout")


func _run():
	var refs = root.get_node("GlobalRefs")
	var manager = root.get_node("GameStateManager")
	var evolution = root.get_node("Evolution")
	if save_dir != "":
		manager.save_dir = save_dir
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
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
	var t0 = OS.get_ticks_msec()
	print("EVOSIM running %.1f h of arena time at x%.0f, from t=%.0fs" % [hours, speed, start_time])
	while evolution.game_time < end_time:
		yield(_wait(5.0), "completed")
		if paused:
			paused = false  # Nothing here should pause the run (a menu opened by a stray event)
		if evolution.game_time >= next_save:
			next_save = evolution.game_time + save_every * 60.0
			print("EVOSIM saved=%s t=%.0fs wall=%.0fs pace x%.1f nodes=%d orphans=%d objects=%d bodies=%d templates=%d genomes=%d mem=%.0fMB" % [
				manager.save_game(0), evolution.game_time, (OS.get_ticks_msec() - t0) / 1000.0,
				(evolution.game_time - start_time) / max(0.001, (OS.get_ticks_msec() - t0) / 1000.0),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT), get_nodes_in_group("agent_body").size(),
				root.get_node("TemplateDatabase").evolved.size(), evolution.genomes.size(), OS.get_static_memory_usage() / 1048576.0])
	Engine.time_scale = 1.0
	Engine.iterations_per_second = 60
	evolution.print_report()
	print("EVOSIM done, saved=%s" % manager.save_game(0))
	quit()


func _find_menu():
	var stack: Array = [root]
	while not stack.empty():
		var node = stack.pop_back()
		if node.get_script() != null and str(node.get_script().resource_path).ends_with("main_menu.gd"):
			return node
		stack += node.get_children()
	return null
