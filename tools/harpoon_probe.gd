# Harpoon probe: starts a new game, undocks, sets a target next to the player (a wreck of the nearest
# other ship, a bared ore chunk, or the chunks a lance strike breaks off a rock) and fires the
# player's harpoon at it, then prints the tether, every release (with its reason) and the HUD
# messages each second. Nothing is saved.
#     godot res://tools/harpoon_probe.tscn [seconds=30] [dist=150] [target=chunk] [lance=<damage>] [approach] [full]
extends Node

var seconds: int = 30
var chunk_target := false  # target=chunk: a bared, cooled ore chunk in place of a wreck
var start_distance := 150.0  # dist=<m>
var approach := false  # approach: APPROACH the target (as from the HUD) before the harpoon
var lance_damage := 0.0  # lance=<damage>: chunks a lance strike of that damage breaks off a rock (the biggest is the target)
var cargo_full := false  # full: the hold full from the start


func _ready() -> void:
	OS.vsync_enabled = false
	for a in OS.get_cmdline_args():
		if a.begins_with("seconds="):
			seconds = int(a.trim_prefix("seconds="))
		chunk_target = chunk_target or a == "target=chunk"
		cargo_full = cargo_full or a == "full"
		approach = approach or a == "approach"
		if a.begins_with("lance="):
			lance_damage = float(a.trim_prefix("lance="))
			chunk_target = true
		if a.begins_with("dist="):
			start_distance = float(a.trim_prefix("dist="))
	GameStateManager.save_dir = "user://flight_shots_saves/"
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	yield(_wait(2.0), "completed")
	_find(get_tree().root, "_on_new_game_pressed")._on_new_game_pressed()
	yield(_wait(6.0), "completed")
	EventBus.emit_signal("player_undocked")
	yield(_wait(2.0), "completed")
	var player = GlobalRefs.player_agent_body
	var tools = player.get_node("ToolController")
	tools.connect("tool_deactivated", self, "_on_released")
	tools.connect("tool_cycled", self, "_on_cycled")
	var harpoon := -1
	for index in range(tools.get_tool_count()):
		if tools.get_tool(index).tool_type == "harpoon":
			harpoon = index
	var wreck = null
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body != player and not body.get("is_docked") and not body.get("is_wreck"):
			wreck = body
			break
	if chunk_target:
		var rock = get_tree().get_nodes_in_group("asteroid")[0]
		var chunk
		if lance_damage > 0.0:
			var pieces: Array = rock.break_chunks(rock.global_transform.origin + Vector3.UP * 50.0, Vector3.DOWN, lance_damage)
			print("HARPOON a %.0f strike broke off %s units" % [lance_damage, str(_all_units(pieces))])
			chunk = pieces[0]
		else:
			chunk = preload("res://src/scenes/game_world/celestial/ore_chunk.gd").new()
			chunk.setup({rock.deposit_id: 12}, load(Constants.MINING_CHUNK_MODELS[0]), Constants.MINING_CHUNK_RADIUS * 2.0)
			rock.get_parent().add_child(chunk)
		chunk.linear_velocity = Vector3.ZERO
		chunk.global_transform.origin = player.global_transform.origin - player.global_transform.basis.z * start_distance
		chunk.crust = 0.0
		chunk.heat = 0.0
		wreck = chunk
	else:
		wreck.global_transform.origin = player.global_transform.origin - player.global_transform.basis.z * start_distance
		wreck.linear_velocity = Vector3.ZERO
		wreck.become_wreck()
		var boom := -200.0
		for f in range(10):
			yield(_wait(0.05), "completed")
			boom = max(boom, AudioServer.get_bus_peak_volume_left_db(0, 0))
		print("HARPOON wrecked at %.0f m: %s peak %.0f dB" % [start_distance, PoolStringArray(_playing(get_tree().root)).join(" "), boom])
	if cargo_full:
		player.add_cargo(wreck.salvage.keys()[0] if chunk_target else "commodity_ore_iron", player.cargo_capacity - player.get_cargo_units())
	yield(_wait(0.5), "completed")
	print("HARPOON max range %.0f, reach %.0f, detects %s" % [tools.get_tool(harpoon).get_max_range(), tools.reach_on(harpoon, wreck), player.detects(wreck)])
	print("HARPOON probe: harpoon slot %d, wreck %s salvage %d" % [harpoon, wreck.name, wreck.get_salvage_units()])
	EventBus.connect("attack_action_feedback", self, "_on_feedback")
	EventBus.connect("player_target_deselected", self, "_on_deselected")
	EventBus.connect("player_target_selected", self, "_on_selected")
	EventBus.emit_signal("player_target_selection_requested", wreck)
	if approach:
		EventBus.emit_signal("player_approach_pressed")
	yield(_wait(1.0), "completed")
	print("HARPOON pressing the harpoon button")
	GlobalRefs.main_hud._on_tool_button_pressed(harpoon)
	for t in range(seconds):
		var heard := {}
		var peak := -200.0
		for f in range(10):
			yield(_wait(0.1), "completed")
			peak = max(peak, AudioServer.get_bus_peak_volume_left_db(0, 0))
			for node in _playing(get_tree().root):
				heard[node] = true
		print("HARPOON sounds %s peak %.0f dB" % [PoolStringArray(heard.keys()).join(" "), peak])
		var tether = tools.get_tether(harpoon)
		var nav = player.get_node("NavigationSystem")
		var state := "none"
		if tether != null:
			state = "launching" if tether.launching else ("retracting" if tether.retracting else ("reeled in" if tether.is_reeled_in() else "reeling"))
		print("HARPOON t=%d active=%s tether=%s cmd=%s speed=%.0f strain=%.2f dist=%.0f salvage=%d cargo=%d/%d" % [t, tools.is_active(harpoon), state,
			nav._current_command.get("type", -1), player.linear_velocity.length(), tether.strain if tether != null else 0.0,
			wreck.global_transform.origin.distance_to(player.global_transform.origin) if is_instance_valid(wreck) else -1.0,
			wreck.get_salvage_units() if is_instance_valid(wreck) else -1, player.get_cargo_units(), player.cargo_capacity])
	get_tree().quit()


# What plays near the player (within 300 m): 3D players' stream files or node names.
func _playing(node: Node) -> Array:
	var out: Array = []
	if node is AudioStreamPlayer3D and node.playing and node.global_transform.origin.distance_to(GlobalRefs.player_agent_body.global_transform.origin) < 300.0:
		out.append(node.stream.resource_path.get_file().get_basename() if node.stream != null else node.name)
	for child in node.get_children():
		out += _playing(child)
	return out


func _all_units(pieces: Array) -> Array:
	var out: Array = []
	for piece in pieces:
		out.append(piece.get_salvage_units())
	return out


func _on_feedback(ok, text) -> void:
	print("HARPOON feedback %s: %s" % [ok, text])


func _on_deselected() -> void:
	print("HARPOON target deselected")
	print_stack()


func _on_selected(target) -> void:
	print("HARPOON target selected: %s" % (target.name if is_instance_valid(target) else str(target)))


func _on_released(index: int, reason: String) -> void:
	print("HARPOON released tool %d: %s" % [index, reason])
	print_stack()


func _on_cycled(index: int, target, _q, _d) -> void:
	print("HARPOON cycled tool %d" % index)


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
