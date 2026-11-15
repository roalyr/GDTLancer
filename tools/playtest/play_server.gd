# Play server: the real game, driven from outside as a player would, for agent playtests.
# tools/playtest/play.py starts it and sends commands; .claude/agents/playtester.md plays with them.
#     godot --resolution 1920x1080 res://tools/playtest/play_server.tscn test_start=start_default port=47321 slot=l1 [fresh]
#
# Listens on 127.0.0.1:port. One connection per request: a JSON line {"cmd": name, "args": {...}},
# answered with one JSON line {"ok": ..., "result" or "error"}, then closed. Input goes in as real
# mouse events (Input.parse_input_event), so the HUD, PointerRouter and modal windows see what a
# player's clicks would. Saves go to user://playtest_saves/<slot>/ (emptied by fresh), so slots on one
# machine never share saves; the options are never written to the player's settings file. test_start
# keeps the autoloads off the player's saves before this node is up.
extends Node

const DEFAULT_PORT = 47321
const MAX_LABELS = 120  # look: readable text past this is cut (the HUD has many readouts)

var port: int = DEFAULT_PORT
var save_dir: String = "user://playtest_saves/l1/"
var _server := TCP_Server.new()
var _busy: bool = false
var _seen: Array = []  # look's ids: weakrefs to the controls it listed, by index
var _events: Array = []  # What happened since the last reply (notices, docking, loss): every reply carries them
const MAX_EVENTS = 60


func _ready() -> void:
	OS.vsync_enabled = false  # A hidden window's vsync holds the game to ~1 frame a second (tools/soak.gd)
	pause_mode = Node.PAUSE_MODE_PROCESS  # Menus pause the game; the player can still click them
	for a in OS.get_cmdline_args():
		if a.begins_with("port="):
			port = int(a.trim_prefix("port="))
		elif a.begins_with("slot="):
			save_dir = "user://playtest_saves/%s/" % a.trim_prefix("slot=")
	process_priority = -1000  # Ahead of the game each frame (_keep_save_dir)
	Directory.new().make_dir_recursive(save_dir)
	GameStateManager.save_dir = save_dir
	if "fresh" in OS.get_cmdline_args():
		GameStateManager.delete_all_saves()
	Settings.use_file = false
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	if _server.listen(port, "127.0.0.1") != OK:
		printerr("PLAY SERVER cannot listen on %d" % port)
		get_tree().quit(1)
		return
	EventBus.connect("announcement", self, "_on_event", ["notice"])
	EventBus.connect("dock_action_feedback", self, "_on_feedback", ["dock"])
	EventBus.connect("attack_action_feedback", self, "_on_feedback", ["attack"])
	EventBus.connect("player_docked", self, "_on_event", ["", "docked at"])
	EventBus.connect("player_undocked", self, "_on_bare", ["undocked"])
	EventBus.connect("player_spawned", self, "_on_bare_arg", ["ship spawned (new ship or respawn)"])
	EventBus.connect("sector_changed", self, "_on_event", ["sector"])
	EventBus.connect("threat_level_changed", self, "_on_event", ["", "threat"])
	EventBus.connect("agent_disabled", self, "_on_disabled")
	print("PLAY SERVER ready on %d" % port)


# A new game or load sets the mode, which points save_dir back at the test start's folder.
func _keep_save_dir() -> void:
	if GameStateManager.save_dir != save_dir and GameStateManager.mode == GameStateManager.MODE_PLAY:
		GameStateManager.save_dir = save_dir


func _physics_process(_delta: float) -> void:
	_keep_save_dir()


func _process(_delta: float) -> void:
	_keep_save_dir()
	if _busy or not _server.is_connection_available():
		return
	_busy = true
	var peer: StreamPeerTCP = _server.take_connection()
	var line := ""
	var waited := 0
	while not line.ends_with("\n") and waited < 200 and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var n: int = peer.get_available_bytes()
		if n > 0:
			line += peer.get_utf8_string(n)
		else:
			waited += 1
			yield(get_tree(), "idle_frame")
	var reply: Dictionary
	var parsed: JSONParseResult = JSON.parse(line.strip_edges())
	if parsed.error != OK or not parsed.result is Dictionary:
		reply = {"ok": false, "error": "Not a JSON object"}
	else:
		var state = _run(str(parsed.result.get("cmd", "")), parsed.result.get("args", {}) if parsed.result.get("args") is Dictionary else {})
		var result = (yield(state, "completed")) if state is GDScriptFunctionState else state
		if result is Dictionary and result.has("error"):
			reply = {"ok": false, "error": result.error}
		else:
			reply = {"ok": true, "result": result}
	reply["events"] = _events
	_events = []
	peer.put_data((to_json(reply) + "\n").to_utf8())
	peer.disconnect_from_host()
	_busy = false


func _log(text: String) -> void:
	_events.append("t=%.1f %s" % [GameState.world_time, text])
	if _events.size() > MAX_EVENTS:
		_events.pop_front()


func _on_event(a = null, b = null, c = null) -> void:  # (value[, value], kind[, label]): binds come last
	var parts: Array = []
	for v in [a, b, c]:
		if v != null and str(v) != "":
			parts.append(str(v))
	if parts.size() >= 2:
		parts.push_front(parts.pop_back())  # The kind first
	_log(PoolStringArray(parts).join(": "))


func _on_feedback(success, message, kind: String) -> void:
	_log("%s %s: %s" % [kind, "ok" if success else "refused", message])


func _on_bare(kind: String) -> void:
	_log(kind)


func _on_bare_arg(_body, kind: String) -> void:
	_log(kind)


func _on_disabled(body) -> void:
	if body == GlobalRefs.player_agent_body:
		_log("PLAYER SHIP DESTROYED")


func _run(cmd: String, args: Dictionary):
	if not has_method("cmd_" + cmd):
		return {"error": "No command '%s'" % cmd}
	return call("cmd_" + cmd, args)


# --- Commands ---------------------------------------------------------------------------------

func cmd_ping(_args: Dictionary):
	return "pong"


# Everything a player could read or press: buttons (id, text, centre, disabled; "world" for target
# brackets, pressed through the 3D view) and the text shown in labels.
func cmd_look(args: Dictionary):
	_seen.clear()
	var buttons: Array = []
	var texts: Array = []
	_collect(get_tree().root, buttons, texts)
	var out := {"modal": _modal_names(), "buttons": buttons, "texts": texts.slice(0, MAX_LABELS - 1) if texts.size() > MAX_LABELS else texts}
	if args.get("shot", false):
		out["shot"] = _shot(str(args.get("path", "")))
	return out


func cmd_shot(args: Dictionary):
	return _shot(str(args.get("path", "")))


# Clicks a control by look id or by its text (first match, case blind), or a point x, y.
func cmd_click(args: Dictionary):
	var point = _point_of(args)
	if point is Dictionary:
		return point
	yield(_click(point, int(args.get("count", 1))), "completed")
	return {"clicked": [point.x, point.y]}


# A press, a move in `steps` and a release: camera turns in the 3D view, sliders.
func cmd_drag(args: Dictionary):
	var from := Vector2(float(args.get("x1", 960)), float(args.get("y1", 540)))
	var to := Vector2(float(args.get("x2", 1060)), float(args.get("y2", 540)))
	var steps: int = int(max(2, args.get("steps", 10)))
	_mouse_button(from, true)
	yield(_frames(1), "completed")
	for i in range(1, steps + 1):
		var at: Vector2 = from.linear_interpolate(to, float(i) / steps)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = (to - from) / steps
		motion.button_mask = BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		yield(_frames(1), "completed")
	_mouse_button(to, false)
	yield(_frames(2), "completed")
	return {"dragged": [from.x, from.y, to.x, to.y]}


# Holds an input action (keyboard players' controls) for `seconds`, or taps it.
func cmd_key(args: Dictionary):
	var action: String = str(args.get("action", ""))
	if not InputMap.has_action(action):
		return {"error": "No action '%s'; actions: %s" % [action, _actions()]}
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	yield(_wait(float(args.get("seconds", 0.1))), "completed")
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	yield(_frames(2), "completed")
	return {"action": action}


func cmd_actions(_args: Dictionary):
	return _actions()


# Lets the game run (real time: the world is never sped up).
func cmd_wait(args: Dictionary):
	var seconds: float = clamp(float(args.get("seconds", 1.0)), 0.0, 300.0)
	yield(_wait(seconds), "completed")
	return {"waited": seconds, "fps": Engine.get_frames_per_second()}


# What the game knows of the player (the facts the HUD should be showing).
func cmd_state(_args: Dictionary):
	var out := {"sector": GameState.current_sector_id, "docked_at": GameState.player_docked_at,
		"bank": GameState.player_bank, "cargo": GameState.player_cargo, "ship": GameState.player_ship_template_id,
		"world_time": stepify(GameState.world_time, 0.1), "paused": get_tree().paused, "fps": Engine.get_frames_per_second(),
		"weapons_safe": GameState.weapons_safe, "mouse_captured": Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED}
	var body = GlobalRefs.player_agent_body
	if is_instance_valid(body):
		out["hull"] = [stepify(body.hull, 0.1), stepify(body.hull_max, 0.1)]
		out["position"] = _v(body.global_transform.origin)
		out["speed"] = stepify(body.linear_velocity.length(), 0.1)
		out["top_speed"] = stepify(body.get_top_speed(), 0.1)
	else:
		out["ship_body"] = "none"
	return out


func cmd_quit(_args: Dictionary):
	get_tree().call_deferred("quit")
	return "bye"


# --- Helpers ----------------------------------------------------------------------------------

# Buttons and texts a player sees, in draw order: a button under a control that takes the pointer
# (a menu, a window) is left out ("covered"), and an icon button is named by the labels over it.
func _collect(root: Node, buttons: Array, texts: Array) -> void:
	var drawn: Array = []  # [layer, order, control]
	_gather(root, 0, drawn, Rect2(-1e6, -1e6, 2e6, 2e6))
	drawn.sort_custom(self, "_draw_order")
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var labels: Array = []
	for k in drawn.size():
		drawn[k][2].set_meta("_order", k)  # Draw order, for _button_text
	for d in drawn:
		var c: Control = d[2]
		if (c is Label or c is RichTextLabel or c is LineEdit) and c.text.strip_edges() != "" and c.modulate.a > 0.05:
			labels.append(c)
	for i in drawn.size():
		var c: Control = drawn[i][2]
		var rect: Rect2 = c.get_global_rect()
		if not rect.intersects(screen) or rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var centre: Vector2 = rect.get_center()
		if not drawn[i][3].has_point(centre) or _covered(drawn, i, centre):
			continue
		if c is BaseButton:
			var entry := {"id": _seen.size(), "text": _button_text(c, labels), "at": [int(centre.x), int(centre.y)]}
			if c.disabled:
				entry["disabled"] = true
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				entry["world"] = true  # A target bracket: a click goes through the 3D view to it
				if "_target_label" in c and str(c._target_label) != "":
					entry["text"] = "target: " + str(c._target_label)
				if c.get("_is_selected"):
					entry["selected"] = true
			if c.toggle_mode:
				entry["on"] = c.pressed
			_seen.append(weakref(c))
			buttons.append(entry)
		elif c in labels and not _inside_button(c):
			texts.append("%s @%d,%d" % [c.text.strip_edges().replace("\n", " | ").substr(0, 160), int(centre.x), int(centre.y)])


func _inside_button(node: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null and p is Control:
		if p is BaseButton:
			return true
		p = p.get_parent()
	return false


# Every visible control, [layer, order, control, clip]: clip is what scroll containers above it
# leave in view (a row scrolled out of sight is not on screen).
func _gather(node: Node, layer: int, drawn: Array, clip: Rect2) -> void:
	if node is CanvasLayer:
		if not node.visible:
			return
		layer = node.layer
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node is Control:
		drawn.append([layer, drawn.size(), node, clip])
		if node is ScrollContainer:
			clip = clip.clip(node.get_global_rect())
	for child in node.get_children():
		_gather(child, layer, drawn, clip)


func _draw_order(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


# Whether a control drawn after drawn[i] (not its own child) takes the pointer at `point`.
func _covered(drawn: Array, i: int, point: Vector2) -> bool:
	var c: Control = drawn[i][2]
	for j in range(i + 1, drawn.size()):
		var over: Control = drawn[j][2]
		if over.mouse_filter != Control.MOUSE_FILTER_STOP or c.is_a_parent_of(over):
			continue
		if over.get_global_rect().has_point(point) and over.modulate.a > 0.05:
			return true
	return false


func _button_text(button: BaseButton, labels: Array) -> String:
	if button is Button and button.text.strip_edges() != "":
		return button.text.strip_edges().replace("\n", " ")
	var parts: Array = []
	var rect: Rect2 = button.get_global_rect()
	for label in labels:  # Its own labels, or ones drawn over it (later): never a covered window's
		var over: bool = int(label.get_meta("_order", -1)) > int(button.get_meta("_order", -1))
		if (button.is_a_parent_of(label) or (over and rect.has_point(label.get_global_rect().get_center()))) and not label.text.strip_edges() in parts:
			parts.append(label.text.strip_edges())
	if parts.empty() and button.hint_tooltip != "":
		parts.append("(" + button.hint_tooltip + ")")
	if parts.empty():
		parts.append("<icon %s>" % button.name)
	return PoolStringArray(parts).join(" ").replace("\n", " ")


func _modal_names() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("prompt_dialog"):
		if node is CanvasItem and node.is_visible_in_tree():
			out.append(node.name)
	return out


func _point_of(args: Dictionary):
	if args.has("x") and args.has("y"):
		return Vector2(float(args.x), float(args.y))
	if args.has("id"):
		var i: int = int(args.id)
		if i < 0 or i >= _seen.size() or not is_instance_valid(_seen[i].get_ref()):
			return {"error": "No control %d now: look again" % i}
		return _seen[i].get_ref().get_global_rect().get_center()
	if args.has("text"):
		var want: String = str(args.text).to_lower()
		var buttons: Array = []
		var kept: Array = _seen
		_seen = []
		_collect(get_tree().root, buttons, [])
		_seen = kept
		for exact in [true, false]:
			for b in buttons:
				var t: String = b.text.to_lower()
				if b.get("world", false) and not want.begins_with("target"):
					continue  # A bracket only by "target: <name>": "lance" means the LANCE button, not a stuck lance
				if not b.get("disabled", false) and (t == want if exact else want in t):
					return Vector2(b.at[0], b.at[1])
		return {"error": "No enabled button with text '%s'" % args.text}
	return {"error": "click needs id, text or x and y"}


func _click(point: Vector2, count: int) -> void:
	_mouse_motion(point)
	yield(_frames(1), "completed")
	for i in count:
		_mouse_button(point, true, i > 0)
		yield(_frames(1), "completed")
		_mouse_button(point, false)
		yield(_frames(2), "completed")
	yield(_frames(2), "completed")


func _mouse_motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)


func _mouse_button(point: Vector2, pressed: bool, doubleclick: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	event.doubleclick = doubleclick
	event.button_mask = BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _shot(path: String) -> String:
	if path == "":
		path = OS.get_user_data_dir().plus_file("playtest_shot.png")
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png(path)
	return path


func _actions() -> Array:
	var out: Array = []
	for a in InputMap.get_actions():
		if not str(a).begins_with("ui_"):
			out.append(a)
	return out


func _v(v: Vector3) -> Array:
	return [stepify(v.x, 0.1), stepify(v.y, 0.1), stepify(v.z, 0.1)]


func _wait(seconds: float) -> void:
	yield(get_tree().create_timer(seconds, true), "timeout")


func _frames(n: int) -> void:
	for i in n:
		yield(get_tree(), "idle_frame")
