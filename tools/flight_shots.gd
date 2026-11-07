# Flight shots: starts a new game, undocks and flies on for a while, then screenshots the HUD in
# flight (and with the nearest ship selected), for before/after checks of HUD changes. As a scene:
#     godot res://tools/flight_shots.tscn out=/abs/dir [wait=12] [near=raiders]
# near=<faction>: `wait` s after undocking, the ship is put NEAR_DISTANCE m off the nearest ship of that faction.
# Writes flight.png and flight_selected.png there, then quits. Nothing is saved.
extends Node

var out: String = "user://flight_shots"
var wait: float = 12.0
var near: String = ""
const NEAR_DISTANCE = 2500.0


func _ready() -> void:
	OS.vsync_enabled = false  # With the monitor asleep, vsync holds a frame a second
	for a in OS.get_cmdline_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a.begins_with("wait="):
			wait = float(a.trim_prefix("wait="))
		elif a.begins_with("near="):
			near = a.trim_prefix("near=")
	Directory.new().make_dir_recursive(out)
	GameStateManager.save_dir = "user://flight_shots_saves/"  # A respawn saves: never into the player's saves
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	yield(_wait(2.0), "completed")
	_find(get_tree().root, "_on_new_game_pressed")._on_new_game_pressed()
	yield(_wait(6.0), "completed")
	print("FLIGHT SHOT docked at '%s', paused %s" % [GameState.player_docked_at, get_tree().paused])
	EventBus.emit_signal("player_undocked")
	yield(_wait(wait), "completed")
	print("FLIGHT SHOT ships: ", _factions())
	if near != "":
		var player = GlobalRefs.player_agent_body
		for body in get_tree().get_nodes_in_group("agent_body"):
			if body != player and body.get("faction") == near and not body.get("is_wreck") and not body.get("is_docked"):
				var at: Vector3 = body.global_transform.origin + Vector3(NEAR_DISTANCE, 300.0, 0.0)
				player.global_transform.origin = at
				player.look_at(body.global_transform.origin, Vector3.UP)
				player.linear_velocity = Vector3.ZERO
				break
	yield(_wait(1.0), "completed")
	_shot("flight")
	var player = GlobalRefs.player_agent_body
	var best = null
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body != player and body.has_method("get_faction_color") and not body.get("is_wreck") and (best == null or body.global_transform.origin.distance_to(player.global_transform.origin) < best.global_transform.origin.distance_to(player.global_transform.origin)):
			best = body
	if best != null:
		EventBus.emit_signal("player_target_selected", best)
		var hud = GlobalRefs.main_hud
		if is_instance_valid(hud) and not hud._is_camera_target_follow_active():
			hud._on_ButtonCamera_pressed()  # Turn to it
	yield(_wait(3.0), "completed")
	_shot("flight_selected")
	get_tree().quit()


func _wait(seconds: float) -> void:
	yield(get_tree().create_timer(seconds), "timeout")


func _shot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png(out.plus_file(name + ".png"))
	print("FLIGHT SHOT ", out.plus_file(name + ".png"))


func _find(node: Node, method: String) -> Node:
	if node.has_method(method) and node != self:
		return node
	for child in node.get_children():
		var found = _find(child, method)
		if found != null:
			return found
	return null


func _factions() -> Dictionary:
	var counts := {}
	for body in get_tree().get_nodes_in_group("agent_body"):
		var key: String = "%s%s" % [body.get("faction"), " docked" if body.get("is_docked") else ""]
		counts[key] = counts.get(key, 0) + 1
	return counts
