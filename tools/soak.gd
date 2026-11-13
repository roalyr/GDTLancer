# Soak: the real game left running, sampled. A new game (start_default: Elace, the player docked
# at home, saves in user://test_savegames/) runs `minutes` of real time at 1x while the sector lives
# round it: haven ships, travellers, fights, mining, wrecks. Every `every` s it prints one line
#   SOAK {json}: t (min), game (s), fps, nodes, orphans, objects, resources, mem (MB), bodies,
#                wrecks, lances (and their caps), over (caps broken) and tables (bookkeeping sizes)
# then "SOAK done". tools/devtool/soak.py runs it and judges the lines (errors, orphans and memory
# growing, caps broken, tables growing); `tools/dev.py soak`, and the release before it builds.
#
#   godot --no-window -s tools/soak.gd [minutes=5] [every=30]
#
# Runs need a display (DISPLAY=:0; the server build crashes). vsync is switched off: a hidden
# window's vsync holds the game to ~1 frame a second. Time is never sped up: Engine.time_scale
# stretches each physics step, so ships would not fly as they do in play.
extends SceneTree

var minutes := 5.0
var every := 30.0


func _initialize():
	OS.vsync_enabled = false
	for arg in OS.get_cmdline_args():
		if arg.begins_with("minutes="):
			minutes = float(arg.substr(8))
		elif arg.begins_with("every="):
			every = max(1.0, float(arg.substr(6)))
	call_deferred("_run")


func _wait(seconds):
	yield(create_timer(seconds, true), "timeout")


func _find_script(node, path):
	if node.get_script() != null and node.get_script().resource_path == path:
		return node
	for child in node.get_children():
		var found = _find_script(child, path)
		if found != null:
			return found
	return null


func _run():
	var refs = root.get_node("GlobalRefs")
	root.get_node("GameStateManager").save_dir = "user://test_savegames/"
	change_scene("res://scenes/levels/game_world/main_game_scene.tscn")
	yield(_wait(1.0), "completed")
	root.get_node("EventBus").emit_signal("new_game_requested")
	var waited := 0.0
	while not is_instance_valid(refs.player_agent_body):
		yield(_wait(0.25), "completed")
		waited += 0.25
		if waited > 120.0:
			print("SOAK failed: no player after 120 s")
			quit(1)
			return
	yield(_wait(5.0), "completed")
	root.get_node("EventBus").connect("agent_disabled", self, "_on_disabled")
	var start := OS.get_ticks_msec()
	var samples := int(ceil(minutes * 60.0 / every))
	for index in range(samples + 1):
		print("SOAK " + to_json(sample((OS.get_ticks_msec() - start) / 60000.0)))
		if index < samples:
			yield(_wait(every), "completed")
	print("SOAK done")
	quit()


func sample(t: float) -> Dictionary:
	var constants = root.get_node("Constants")
	var bodies = get_nodes_in_group("agent_body")
	var wrecks := 0
	var lances := 0
	var held := {}
	for body in bodies:
		var tools = body.get_node_or_null("ToolController")
		if tools != null and not body.get("is_wreck"):
			for index in range(tools.get_tool_count()):
				if is_instance_valid(tools.get_target(index)):
					held[tools.get_target(index)] = true
	for body in bodies:
		if body.get("is_wreck") and not held.has(body) and not (body.has_method("is_player") and body.is_player()):
			if body.is_in_group("loose_lance"):
				lances += 1
			else:
				wrecks += 1
	var over := []
	# Wrecks are cleared as new ones come, so one over between clears is allowed.
	if wrecks > constants.WRECK_MAX + 1:
		over.append("wrecks %d > %d" % [wrecks, constants.WRECK_MAX])
	if lances > constants.LANCE_LOOSE_MAX + 1:
		over.append("loose lances %d > %d" % [lances, constants.LANCE_LOOSE_MAX])
	return {
		"t": stepify(t, 0.01), "game": int(root.get_node("GameState").world_time), "fps": Engine.get_frames_per_second(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"mem": stepify(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"bodies": bodies.size(), "wrecks": wrecks, "lances": lances, "over": over, "tables": tables()}


# The sizes of the bookkeeping that lives as long as the game: none may keep growing.
func tables() -> Dictionary:
	var out := {}
	var state = root.get_node("GameState")
	out["travellers"] = state.travelers.size()
	out["markups"] = state.station_markups.size()
	out["evolution_live"] = root.get_node("Evolution").live.size()
	var fx = _find_script(root, "res://src/core/sound/sound_effects.gd")
	if fx != null:
		for name in ["_last_played", "_weapon_hits", "_ships", "_voices", "_missiles"]:
			if fx.get(name) != null:
				out["sound" + name] = fx.get(name).size()
	var watch = _find_script(root, "res://src/core/systems/threat_watch.gd")
	if watch != null:
		out["threat_noticed"] = watch._noticed.size()
	return out


func _on_disabled(body):
	var by = body._last_hit_by.get_ref() if body.get("_last_hit_by") != null else null
	var who = "%s %s" % [body.faction, "traveller" if body.has_meta("traveler") else ("player" if body.is_player() else "haven ship")]
	var killer = "nothing (collision, radiation)"
	if is_instance_valid(by):
		killer = "%s %s" % [by.faction, "traveller" if by.has_meta("traveler") else ("player" if by.is_player() else "haven ship")]
	print("DEATH %s (%s) <- %s" % [who, body.ship_template.template_id if body.ship_template else "", killer])
