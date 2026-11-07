# SoundEffects: plays the game's sound effects from a SoundBank (`bank`; the main scene gives it
# database/sounds/sound_bank.tres). It sits in the world's viewport and listens to what the game
# already signals: EventBus (damage, wrecks, notices, radio, threats, docking), each ship's ToolController and
# LanceController and every button, picked up as they enter the tree. An empty slot costs nothing.
# World sounds are heard from the player's ship (the camera's position when there is none), turned
# the camera's way; Constants "SOUND" sets distances, the voice cap and the engine loop's range.
# To add an event: a slot in SoundBank.SLOTS (and its export there), then a play() where it happens.

extends Spatial

const SoundBank = preload("res://src/core/sound/sound_bank.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const LanceScript = preload("res://src/core/agents/components/lance_controller.gd")
const MissileScript = preload("res://src/core/agents/components/missile.gd")
const LOOP_NAME = "EngineSound"
const ONE_SHOT_FALLBACK = 10.0  # s a one-shot of unknown length is kept before it is freed

export(Resource) var bank = null

var _listener: Listener = null
var _voices: Array = []  # [player, free at (ms)]
var _last_played: Dictionary = {}  # "slot:source id" -> ms
var _ships: Array = []  # [agent body, engine loop or null, afterburner was lit]


func _ready() -> void:
	if bank == null:
		bank = SoundBank.new()
	_listener = Listener.new()
	_listener.name = "Listener"
	add_child(_listener)
	_listener.make_current()
	_connect(EventBus, "agent_damaged", "_on_agent_damaged")
	_connect(EventBus, "agent_disabled", "_on_agent_disabled")
	_connect(EventBus, "announcement", "_on_announcement")
	_connect(EventBus, "radio_message", "_on_radio_message")
	_connect(EventBus, "hostile_detected", "_on_hostile_detected")
	_connect(EventBus, "hostile_aware", "_on_hostile_aware")
	_connect(EventBus, "dock_available", "_on_dock_available")
	_connect(EventBus, "player_docked", "_on_player_docked")
	_connect(EventBus, "player_undocked", "_on_player_undocked")
	_connect(get_tree(), "node_added", "_on_node_added")


func _exit_tree() -> void:
	if get_tree().is_connected("node_added", self, "_on_node_added"):
		get_tree().disconnect("node_added", self, "_on_node_added")


# Plays `slot` once: a "world" slot at `at` (a Spatial or a Vector3), a "ui" slot as it is. `source`
# (a node) keeps one source from repeating a slot faster than SOUND_REPEAT_GAP. Returns the player,
# or null when nothing plays (an empty slot, too far, too soon, too many voices).
func play(slot: String, at = null, source: Object = null) -> Node:
	var stream: AudioStream = bank.stream(slot)
	if stream == null:
		return null
	var now: int = OS.get_ticks_msec()
	var key: String = "%s:%d" % [slot, source.get_instance_id() if source != null else 0]
	if now - int(_last_played.get(key, -100000)) < int(Constants.SOUND_REPEAT_GAP * 1000.0):
		return null
	var player: Node
	if SoundBank.SLOTS[slot] == "ui":
		player = AudioStreamPlayer.new()
	else:
		var position: Vector3 = at.global_transform.origin if at is Spatial else (at if at is Vector3 else hearing_point())
		if position.distance_to(hearing_point()) > Constants.SOUND_MAX_DISTANCE or _voices.size() >= Constants.SOUND_MAX_VOICES:
			return null
		player = AudioStreamPlayer3D.new()
		_shape_3d(player)
		player.translation = position
	_last_played[key] = now
	player.stream = stream
	player.set("volume_db" if player is AudioStreamPlayer else "unit_db", Constants.SOUND_EFFECTS_VOLUME_DB)
	add_child(player)
	player.play()
	var length: float = stream.get_length()
	_voices.append([player, now + int((length if length > 0.0 else ONE_SHOT_FALLBACK) * 1000.0) + 200])
	return player


# Where world sounds are heard from: the player's ship, else the camera.
func hearing_point() -> Vector3:
	if is_instance_valid(GlobalRefs.player_agent_body) and GlobalRefs.player_agent_body.is_inside_tree():
		return GlobalRefs.player_agent_body.global_transform.origin
	var camera: Camera = get_viewport().get_camera() if is_inside_tree() else null
	return camera.global_transform.origin if camera != null else Vector3.ZERO


func _process(_delta: float) -> void:
	var camera: Camera = get_viewport().get_camera()
	_listener.global_transform = Transform(camera.global_transform.basis if camera != null else Basis(), hearing_point())
	var now: int = OS.get_ticks_msec()
	for voice in _voices.duplicate():
		if not is_instance_valid(voice[0]) or now >= voice[1]:
			if is_instance_valid(voice[0]):
				voice[0].queue_free()
			_voices.erase(voice)
	for ship in _ships.duplicate():
		if not is_instance_valid(ship[0]):
			_ships.erase(ship)
			continue
		var body: Spatial = ship[0]
		if ship[1] != null and is_instance_valid(ship[1]):
			_drive_engine(ship[1], body)
		var lit: bool = bool(body.get("afterburner_lit"))
		if lit and not ship[2]:
			play("afterburner", body, body)
		ship[2] = lit


# --- Hooking onto what enters the tree ---

func _on_node_added(node: Node) -> void:
	if node is AgentScript:
		if bank.stream("engine") != null or bank.stream("afterburner") != null:
			call_deferred("_track_ship", node)
	elif node is ToolControllerScript:
		_connect(node, "tool_cycled", "_on_tool_cycled", [node])
		_connect(node, "tool_blocked", "_on_tool_blocked", [node])
		_connect(node, "projectile_fired", "_on_projectile_fired", [node])
		_connect(node, "missile_intercepted", "_on_missile_intercepted", [node])
		_connect(node, "salvage_stripped", "_on_salvage", [node])
		_connect(node, "ammo_recovered", "_on_salvage", [node])
		_connect(node, "lance_recovered", "_on_salvage_lance", [node])
	elif node is LanceScript:
		_connect(node, "launched", "_on_lance_launched", [node])
		_connect(node, "struck", "_on_lance_struck")
		_connect(node, "glanced", "_on_lance_glanced")
	elif node is BaseButton and bank.stream("ui_press") != null:
		_connect(node, "pressed", "_on_button_pressed")


func _track_ship(body: Spatial) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	var loop: AudioStreamPlayer3D = null
	if bank.stream("engine") != null and not body.has_node(LOOP_NAME):
		loop = _attach_loop("engine", body)
	_ships.append([body, loop, bool(body.get("afterburner_lit"))])


# A looping `slot` carried by `body` (freed with it), or null when the slot is empty.
func _attach_loop(slot: String, body: Spatial) -> AudioStreamPlayer3D:
	var stream: AudioStream = bank.stream(slot)
	if stream == null:
		return null
	var loop := AudioStreamPlayer3D.new()
	loop.name = LOOP_NAME
	loop.stream = stream
	_shape_3d(loop)
	loop.unit_db = Constants.SOUND_EFFECTS_VOLUME_DB
	body.add_child(loop)
	loop.play()
	return loop


func _drive_engine(loop: AudioStreamPlayer3D, body: Spatial) -> void:
	if body.get("is_wreck"):
		if loop.playing:
			loop.stop()
		return
	var activity: float = clamp(body.get_engine_activity(), 0.0, 1.0) if body.has_method("get_engine_activity") else 0.0
	loop.unit_db = Constants.SOUND_EFFECTS_VOLUME_DB + linear2db(max(engine_gain(body, activity), 0.0001))
	loop.pitch_scale = lerp(Constants.SOUND_ENGINE_PITCH[0], Constants.SOUND_ENGINE_PITCH[1], activity)


# The engine loop's loudness (linear): in proportion to thrust (`activity`, 0..1), up to
# SOUND_ENGINE_MAX_GAIN; other ships' at SOUND_ENGINE_OTHERS_SHARE of that. Coasting is silent.
# The sound itself is baked (engine.ogg): only its volume and, a little, its pitch change.
static func engine_gain(body: Spatial, activity: float) -> float:
	var share: float = 1.0 if body == GlobalRefs.player_agent_body else Constants.SOUND_ENGINE_OTHERS_SHARE
	return Constants.SOUND_ENGINE_MAX_GAIN * share * clamp(activity, 0.0, 1.0)


func _shape_3d(player: AudioStreamPlayer3D) -> void:
	player.unit_size = Constants.SOUND_UNIT_SIZE
	player.max_distance = Constants.SOUND_MAX_DISTANCE
	player.attenuation_filter_cutoff_hz = 20500.0  # No muffling with distance: there is no air


func _connect(emitter: Object, signal_name: String, method: String, binds: Array = []) -> void:
	if not emitter.is_connected(signal_name, self, method):
		emitter.connect(signal_name, self, method, binds)


static func _owner_of(component: Node) -> Node:
	return component.get_parent()


# --- Events ---

func _on_tool_cycled(index: int, target, _quality, _damage, tools: Node) -> void:
	var tool_template = tools.get_tool(index)
	if tool_template == null:
		return
	var body: Node = _owner_of(tools)
	match tool_template.tool_type:
		"laser":
			play("laser_fire", body, tools)
		"harpoon":
			if tools.get_tether(index) != null and target == tools.get_target(index):
				play("harpoon_launch", body, tools)
				var tether: Node = tools.get_tether(index)
				if not tether.is_connected("hooked", self, "_on_hooked"):
					tether.connect("hooked", self, "_on_hooked", [target], CONNECT_ONESHOT)


func _on_tool_blocked(index: int, _target, _blocker, tools: Node) -> void:
	var tool_template = tools.get_tool(index)
	if tool_template != null and tool_template.tool_type == "laser":
		play("laser_fire", _owner_of(tools), tools)


func _on_projectile_fired(_index: int, projectile: Node, tools: Node) -> void:
	var missile: bool = projectile is MissileScript
	play("missile_launch" if missile else "cannon_fire", _owner_of(tools), tools)
	_connect(projectile, "hit", "_on_projectile_hit")
	if missile and bank.stream("missile_engine") != null:
		call_deferred("_attach_missile_loop", projectile)


func _attach_missile_loop(missile: Spatial) -> void:
	if is_instance_valid(missile) and missile.is_inside_tree():
		_attach_loop("missile_engine", missile)


func _on_projectile_hit(projectile: Node, body, _damage) -> void:
	if projectile is MissileScript:
		play("missile_burst", projectile)
	elif body != null and not body is AgentScript:
		play("rock_hit", projectile)


func _on_missile_intercepted(_index: int, missile: Node, destroyed: bool, tools: Node) -> void:
	play("laser_fire", _owner_of(tools), tools)
	if destroyed and is_instance_valid(missile):
		play("missile_burst", missile)


func _on_hooked(target) -> void:
	if is_instance_valid(target):
		play("harpoon_hook", target, target)


func _on_salvage(_index: int, _what, tools: Node) -> void:
	play("salvage", _owner_of(tools), tools)


func _on_salvage_lance(_index: int, tools: Node) -> void:
	play("salvage", _owner_of(tools), tools)


func _on_lance_launched(_target, lance: Node) -> void:
	play("lance_launch", _owner_of(lance), lance)


func _on_lance_struck(target, _damage) -> void:
	if is_instance_valid(target):
		play("lance_strike", target, target)


func _on_lance_glanced(target, _reason) -> void:
	if is_instance_valid(target):
		play("lance_glance", target, target)


func _on_agent_damaged(body, _amount, _source) -> void:
	if is_instance_valid(body) and body is Spatial and body.is_inside_tree():
		play("hull_hit", body, body)


func _on_agent_disabled(body) -> void:
	if is_instance_valid(body) and body is Spatial and body.is_inside_tree():
		play("ship_wrecked", body, body)


func _on_announcement(_message, level) -> void:
	play("notice_" + str(level) if SoundBank.SLOTS.has("notice_" + str(level)) else "notice_info")


func _on_radio_message(_speaker, _text) -> void:
	play("radio")


func _on_hostile_detected(_ship) -> void:
	play("hostile_detected")


func _on_hostile_aware(_ship) -> void:
	play("hostile_aware")


func _on_dock_available(_location_id) -> void:
	play("dock_ready")


func _on_player_docked(_location_id) -> void:
	play("docked")


func _on_player_undocked() -> void:
	play("undocked")


func _on_button_pressed() -> void:
	play("ui_press")
