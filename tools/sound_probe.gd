# Sound probe: starts a new game, undocks, and every second prints every playing sound (its
# stream, volume and, for the player's engine, thrust and speed). Nothing is saved.
#     godot res://tools/sound_probe.tscn [seconds=20] [near=<faction>] [plan=line|approach|docked]
extends Node

var seconds: int = 20
var plan: String = "line"  # "line": full ahead, then stop; "approach": to the nearest station, then orbit it; "docked": stays docked


func _ready() -> void:
	OS.vsync_enabled = false
	for a in OS.get_cmdline_args():
		if a.begins_with("plan="):
			plan = a.trim_prefix("plan=")
		if a.begins_with("seconds="):
			seconds = int(a.trim_prefix("seconds="))
	GameStateManager.save_dir = "user://flight_shots_saves/"
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	yield(_wait(2.0), "completed")
	_find(get_tree().root, "_on_new_game_pressed")._on_new_game_pressed()
	yield(_wait(6.0), "completed")
	if plan != "docked":
		EventBus.emit_signal("player_undocked")
	yield(_wait(1.0), "completed")
	for a in OS.get_cmdline_args():
		if a.begins_with("near="):  # Put the ship 2.5 km off the nearest ship of that faction
			var player = GlobalRefs.player_agent_body
			for body in get_tree().get_nodes_in_group("agent_body"):
				if body != player and body.get("faction") == a.trim_prefix("near=") and not body.get("is_wreck") and not body.get("is_docked"):
					player.global_transform.origin = body.global_transform.origin + Vector3(2500.0, 300.0, 0.0)
					player.linear_velocity = Vector3.ZERO
					break
	for t in range(seconds):
		yield(_wait(1.0), "completed")
		var player = GlobalRefs.player_agent_body
		if plan == "approach":
			if t == 2:
				var station = _nearest(player, "dockable_station")
				if station != null:
					player.command_approach(station)
					print("PROBE approaching ", station.name, " at ", int(station.global_transform.origin.distance_to(player.global_transform.origin)), " m")
			elif t == int(seconds * 0.5):
				player.command_orbit(_nearest(player, "dockable_station"))
				print("PROBE orbiting")
		elif plan == "docked":
			pass
		elif t == 2:
			player.command_move_direction(-player.global_transform.basis.z)  # Full ahead
		elif t == int(seconds * 0.6):
			player.command_stop()
		var lines: Array = []
		var counts: Dictionary = {}
		_collect(get_tree().root, player, lines, counts)
		var thrust = player.movement_system.get("last_thrust_fraction") if is_instance_valid(player) and is_instance_valid(player.get("movement_system")) else null
		if plan == "docked" and t == int(seconds * 0.33):
			for loop in _engine_loops(get_tree().root):
				if loop.get_parent() != player:
					loop.stop()
			print("PROBE stopped other ships' engine loops")
		elif plan == "docked" and t == int(seconds * 0.66):
			for loop in _engine_loops(get_tree().root):
				loop.stop()
			print("PROBE stopped the player's engine loop too")
		print("PROBE master peak %.1f dB" % max(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
		print("PROBE t=%d thrust=%s activity=%.2f speed=%.0f docked=%s  others' engines %s" % [t, str(thrust), player.get_engine_activity(), player.linear_velocity.length(), player.is_docked, counts])
		for line in lines:
			print("PROBE   ", line)
	get_tree().quit()


func _collect(node: Node, player, lines: Array, counts: Dictionary) -> void:
	if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node.playing and node.stream != null:
		var db: float = node.volume_db if node is AudioStreamPlayer else node.unit_db
		var path: String = node.stream.resource_path.get_file()
		if node is AudioStreamPlayer3D and node.get_parent() != player and node.name == "EngineSound":
			var d: float = node.global_transform.origin.distance_to(player.global_transform.origin)
			counts["n"] = counts.get("n", 0) + 1
			counts["nearest"] = min(counts.get("nearest", 1e9), d)
		else:
			lines.append("%s %s %.1f dB bus=%s%s" % [node.get_path(), path, db, node.bus, " (player engine)" if node.get_parent() == player else ""])
	for child in node.get_children():
		_collect(child, player, lines, counts)


func _engine_loops(node: Node) -> Array:
	var found: Array = []
	if node.name == "EngineSound":
		found.append(node)
	for child in node.get_children():
		found += _engine_loops(child)
	return found


func _nearest(player, group: String):
	var best = null
	for node in get_tree().get_nodes_in_group(group):
		if node is Spatial and (best == null or node.global_transform.origin.distance_to(player.global_transform.origin) < best.global_transform.origin.distance_to(player.global_transform.origin)):
			best = node
	return best


func _wait(s: float) -> void:
	yield(get_tree().create_timer(s), "timeout")


func _find(node: Node, method: String) -> Node:
	if node.has_method(method) and node != self:
		return node
	for child in node.get_children():
		var found = _find(child, method)
		if found != null:
			return found
	return null
