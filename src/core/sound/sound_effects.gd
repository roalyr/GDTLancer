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
const LASER_HUM_NAME = "LaserHum"
const REEL_NAME = "HarpoonReel"
const WEAPON_HIT_WINDOW = 150  # ms: damage this soon after a weapon's own hit sound plays no hull_hit
const ONE_SHOT_FALLBACK = 10.0  # s a one-shot of unknown length is kept before it is freed

export(Resource) var bank = null

var _listener: Listener = null
var _voices: Array = []  # [player, free at (ms)]
var _last_played: Dictionary = {}  # "slot:source id" -> ms
var _ships: Array = []  # [agent body, engine loop or null]
var _weapon_hits: Dictionary = {}  # body instance id -> ms its last weapon hit sound played


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
	if player is AudioStreamPlayer:
		player.volume_db = Constants.SOUND_EFFECTS_VOLUME_DB
	else:
		set_volume_3d(player, Constants.SOUND_EFFECTS_VOLUME_DB)
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


func _process(delta: float) -> void:
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
			_drive_engine(ship[1], body, delta)
		var live: bool = not body.get("is_wreck")
		_drive_loop(body, "laser_hum", LASER_HUM_NAME, live and laser_on(body), Constants.SOUND_LASER_HUM_GAIN, delta)
		_drive_loop(body, "harpoon_reel", REEL_NAME, live and winching(body), Constants.SOUND_REEL_GAIN, delta)


# --- Hooking onto what enters the tree ---

func _on_node_added(node: Node) -> void:
	if node is AgentScript:
		if bank.stream("engine") != null or bank.stream("laser_hum") != null or bank.stream("harpoon_reel") != null:
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
	_ships.append([body, loop])


# A looping `slot` carried by `body` (freed with it), or null when the slot is empty.
func _attach_loop(slot: String, body: Spatial, node_name: String = LOOP_NAME) -> AudioStreamPlayer3D:
	var stream: AudioStream = bank.stream(slot)
	if stream == null:
		return null
	var loop := AudioStreamPlayer3D.new()
	loop.name = node_name
	loop.stream = stream
	_shape_3d(loop)
	set_volume_3d(loop, Constants.SOUND_EFFECTS_VOLUME_DB)
	body.add_child(loop)
	loop.play()
	return loop


func _drive_engine(loop: AudioStreamPlayer3D, body: Spatial, delta: float = 0.0) -> void:
	if body.get("is_wreck"):
		if loop.playing:
			loop.stop()
		return
	set_volume_3d(loop, Constants.SOUND_EFFECTS_VOLUME_DB + linear2db(max(engine_gain(body), 0.0001)))
	# The afterburner pitches the engine up (over SOUND_AFTERBURNER_PITCH_TIME s, and back down).
	var pitch: float = Constants.SOUND_AFTERBURNER_PITCH if body.get("afterburner_lit") else 1.0
	var step: float = delta / Constants.SOUND_AFTERBURNER_PITCH_TIME if delta > 0.0 else 1.0
	loop.pitch_scale = move_toward(loop.pitch_scale, pitch, (Constants.SOUND_AFTERBURNER_PITCH - 1.0) * step)


# A loop the ship carries while `on` (a laser's hum, the harpoon winch): the `slot` loop, made the
# first time as the child `node_name`, fades in over SOUND_LOOP_FADE s to `level` (linear, of the
# file's own) and out again; silent, it stops.
func _drive_loop(body: Spatial, slot: String, node_name: String, on: bool, level: float, delta: float) -> void:
	if bank.stream(slot) == null:
		return
	var loop = body.get_node_or_null(node_name)
	if loop == null:
		if not on:
			return
		loop = _attach_loop(slot, body, node_name)
		loop.set_meta("gain", 0.0)
	var gain: float = move_toward(float(loop.get_meta("gain", 0.0)), 1.0 if on else 0.0, delta / Constants.SOUND_LOOP_FADE)
	loop.set_meta("gain", gain)
	set_volume_3d(loop, Constants.SOUND_EFFECTS_VOLUME_DB + linear2db(max(gain * level, 0.0001)))
	if gain > 0.0 and not loop.playing:
		loop.play()
	elif gain <= 0.0 and loop.playing:
		loop.stop()


# Whether the ship's harpoon winch is turning: reeling a hooked body in, or a loose cable back.
static func winching(body: Node) -> bool:
	var tools = body.get_node_or_null("ToolController")
	if tools == null or not tools.has_method("get_tether"):
		return false
	for index in range(tools.get_tool_count()):
		if tools.is_retracting(index):
			return true
		var tether = tools.get_tether(index)
		if tether != null and tether.is_valid() and tether.length > tether.min_length + 0.01:
			return true
	return false


# Whether any of the ship's lasers is on.
static func laser_on(body: Node) -> bool:
	var tools = body.get_node_or_null("ToolController")
	if tools == null or not tools.has_method("get_tool_count"):
		return false
	for index in range(tools.get_tool_count()):
		var tool_template = tools.get_tool(index)
		if tool_template != null and tool_template.tool_type == "laser" and tools.is_active(index):
			return true
	return false


# A 3D sound's loudness: `db` at most, quieter with distance. Both unit_db and max_db: the listener
# sits on the player's ship, and at no distance Godot's inverse-distance gain (unit_size / distance)
# is endless, so the sound plays at max_db (+3 dB unless set) whatever unit_db says.
static func set_volume_3d(player: AudioStreamPlayer3D, db: float) -> void:
	player.unit_db = db
	player.max_db = db


# The engine loop (baked, engine.ogg) changes only in volume, and only with speed: 0 standing
# still, SOUND_ENGINE_MAX_GAIN at top speed, in proportion between; other ships' at
# SOUND_ENGINE_OTHERS_SHARE of that.
static func engine_gain(body: Spatial) -> float:
	var velocity = body.get("linear_velocity")
	var speed: float = velocity.length() if velocity is Vector3 else 0.0
	var top: float = body.get_top_speed() if body.has_method("get_top_speed") else 0.0
	var share: float = 1.0 if body == GlobalRefs.player_agent_body else Constants.SOUND_ENGINE_OTHERS_SHARE
	return Constants.SOUND_ENGINE_MAX_GAIN * share * clamp(speed / top, 0.0, 1.0) if top > 0.0 else 0.0


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

func _on_tool_cycled(index: int, target, _quality, damage, tools: Node) -> void:
	var tool_template = tools.get_tool(index)
	if tool_template == null:
		return
	var body: Node = _owner_of(tools)
	match tool_template.tool_type:
		"laser":
			if float(damage) > 0.0 and is_instance_valid(target) and target is Spatial:
				_weapon_hit("laser_hit", target)  # Only the hit is heard; the shooter hums
		"harpoon":
			if tools.get_tether(index) != null and target == tools.get_target(index):
				play("harpoon_launch", body, tools)
				var tether: Node = tools.get_tether(index)
				if not tether.is_connected("hooked", self, "_on_hooked"):
					tether.connect("hooked", self, "_on_hooked", [target], CONNECT_ONESHOT)


func _on_tool_blocked(index: int, _target, blocker, tools: Node) -> void:
	var tool_template = tools.get_tool(index)
	if tool_template != null and tool_template.tool_type == "laser" and is_instance_valid(blocker) and blocker is Spatial:
		_weapon_hit("laser_hit", blocker)  # The beam lands on what is in the way


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
		_mark_weapon_hit(body)
	elif body is AgentScript:
		play("cannon_hit", projectile)
		_mark_weapon_hit(body)
	elif body != null:
		play("rock_hit", projectile)


func _on_missile_intercepted(_index: int, missile: Node, destroyed: bool, _tools: Node) -> void:
	if not is_instance_valid(missile):
		return
	play("laser_hit", missile)
	if destroyed:
		play("missile_burst", missile)


# A weapon's own hit sound at `body`, which then plays no hull_hit for the same damage.
func _weapon_hit(slot: String, body: Spatial) -> void:
	play(slot, body, body)
	_mark_weapon_hit(body)


func _mark_weapon_hit(body) -> void:
	if is_instance_valid(body) and body is Object:
		_weapon_hits[body.get_instance_id()] = OS.get_ticks_msec()


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
		_weapon_hit("lance_strike", target)


func _on_lance_glanced(target, _reason) -> void:
	if is_instance_valid(target):
		play("lance_glance", target, target)


# Deferred: a weapon's hit sound comes in the same frame as its damage, before or after it.
func _on_agent_damaged(body, _amount, _source) -> void:
	if is_instance_valid(body) and body is Spatial and body.is_inside_tree():
		call_deferred("_hull_hit", weakref(body))


func _hull_hit(ref: WeakRef) -> void:
	var body = ref.get_ref()
	if body == null or not body.is_inside_tree():
		return
	if OS.get_ticks_msec() - int(_weapon_hits.get(body.get_instance_id(), -100000)) < WEAPON_HIT_WINDOW:
		return  # Its weapon's own hit sound covers it
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
