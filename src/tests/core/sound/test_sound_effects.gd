# Tests for SoundBank (slots) and SoundEffects (playing them): empty slots stay silent, filled ones
# play where they should, and the game's bank keeps the rules.

extends GutTest

const SoundBank = preload("res://src/core/sound/sound_bank.gd")
const SoundEffects = preload("res://src/core/sound/sound_effects.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const GAME_BANK = "res://database/sounds/sound_bank.tres"


class FakeShip:
	extends Spatial
	var is_wreck := false
	var afterburner_lit := false
	var activity := 0.0
	var linear_velocity := Vector3.ZERO

	func get_engine_activity() -> float:
		return activity

	func get_top_speed() -> float:
		return 100.0


func _sample(looped: bool = false) -> AudioStreamSample:
	var sample := AudioStreamSample.new()
	sample.format = AudioStreamSample.FORMAT_8_BITS
	sample.mix_rate = 8000
	var data := PoolByteArray()
	data.resize(800)  # 0.1 s
	sample.data = data
	if looped:
		sample.loop_mode = AudioStreamSample.LOOP_FORWARD
		sample.loop_end = 800
	return sample


func _effects(filled: Array) -> Node:
	var bank = SoundBank.new()
	for slot in filled:
		bank.set(slot, _sample(SoundBank.SLOTS[slot] == "loop"))
	var fx = SoundEffects.new()
	fx.bank = bank
	add_child_autofree(fx)
	return fx


func _exported_streams(bank: Resource) -> Array:
	var out: Array = []
	for property in bank.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.hint_string == "AudioStream":
			out.append(property.name)
	return out


func test_every_slot_is_an_exported_stream_and_back():
	var exported: Array = _exported_streams(SoundBank.new())
	for slot in SoundBank.SLOTS:
		assert_has(exported, slot, "Slot %s has its export" % slot)
	for name in exported:
		assert_true(SoundBank.SLOTS.has(name), "Export %s is a listed slot" % name)
	for kind in SoundBank.SLOTS.values():
		assert_has(["world", "loop", "ui"], kind)


func test_the_game_bank_keeps_the_rules():
	var bank = load(GAME_BANK)
	assert_true(bank is SoundBank, "The main scene's bank is a SoundBank")
	for slot in SoundBank.SLOTS:
		var stream = bank.get(slot)
		if stream == null:
			continue
		assert_true(stream is AudioStream, "%s holds a sound" % slot)
		var loops: bool = (stream is AudioStreamSample and stream.loop_mode != AudioStreamSample.LOOP_DISABLED) \
			or (stream is AudioStreamOGGVorbis and stream.loop) or (stream is AudioStreamMP3 and stream.loop)
		assert_eq(loops, SoundBank.SLOTS[slot] == "loop", "%s: loop slots loop, the rest play once (Import dock: Loop)" % slot)


func test_the_main_scene_plays_the_game_bank():
	var text: String = _read("res://scenes/levels/game_world/main_game_scene.tscn")
	assert_true(text.find(GAME_BANK) >= 0 and text.find("sound_effects.gd") >= 0, "SoundEffects with the game bank in the main scene")
	assert_true(text.find("audio_listener_enable_3d = true") >= 0, "The world's viewport hears 3D sound")


func _read(path: String) -> String:
	var file := File.new()
	file.open(path, File.READ)
	var text: String = file.get_as_text()
	file.close()
	return text


func test_an_empty_slot_is_silent():
	var fx = _effects([])
	assert_null(fx.play("cannon_fire", Vector3.ZERO))
	assert_null(fx.play("ui_press"))


func test_a_ui_slot_plays_as_it_is():
	var fx = _effects(["ui_press"])
	var player = fx.play("ui_press")
	assert_true(player is AudioStreamPlayer, "Not positional")
	assert_almost_eq(player.volume_db, Constants.SOUND_EFFECTS_VOLUME_DB, 0.001)


func test_a_world_slot_plays_where_it_happens_unless_too_far():
	var fx = _effects(["cannon_fire"])
	var near = fx.play("cannon_fire", Vector3(100, 0, 0))
	assert_true(near is AudioStreamPlayer3D)
	assert_eq(near.translation, Vector3(100, 0, 0))
	assert_eq(near.max_distance, Constants.SOUND_MAX_DISTANCE)
	assert_null(fx.play("cannon_fire", Vector3(Constants.SOUND_MAX_DISTANCE + 10.0, 0, 0)), "Beyond hearing")


func test_one_source_does_not_repeat_a_slot_too_fast():
	var fx = _effects(["hull_hit"])
	var a := Node.new()
	var b := Node.new()
	autofree(a)
	autofree(b)
	assert_not_null(fx.play("hull_hit", Vector3.ZERO, a))
	assert_null(fx.play("hull_hit", Vector3.ZERO, a), "Same source, too soon")
	assert_not_null(fx.play("hull_hit", Vector3.ZERO, b), "Another source plays")


func test_voices_are_capped():
	var fx = _effects(["laser_hit"])
	var played := 0
	for i in range(Constants.SOUND_MAX_VOICES + 5):
		var source := Node.new()
		autofree(source)
		if fx.play("laser_hit", Vector3.ZERO, source) != null:
			played += 1
	assert_eq(played, Constants.SOUND_MAX_VOICES)


func test_announcements_play_by_level():
	var fx = _effects(["notice_danger"])
	var before: int = fx.get_child_count()
	EventBus.emit_signal("announcement", "Missile inbound!", "info")
	assert_eq(fx.get_child_count(), before, "Info's slot is empty: silent")
	EventBus.emit_signal("announcement", "Missile inbound!", "danger")
	assert_eq(fx.get_child_count(), before + 1, "Danger's plays")


func test_tool_controllers_are_heard_as_they_enter():
	var fx = _effects([])
	var ship := RigidBody.new()
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	ship.add_child(tools)
	add_child_autofree(ship)
	assert_true(tools.is_connected("projectile_fired", fx, "_on_projectile_fired"))
	assert_true(tools.is_connected("tool_cycled", fx, "_on_tool_cycled"))


func test_the_engine_loop_follows_speed():
	var fx = _effects(["engine"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var loop = fx._attach_loop("engine", ship)
	assert_eq(loop.get_parent(), ship, "Carried by the ship")
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = ship
	var gain = funcref(self, "_gain_of")
	ship.activity = 1.0
	fx._drive_engine(loop, ship)
	assert_lt(loop.unit_db, -60.0, "Standing still, whatever the thrust: mute")
	ship.linear_velocity = Vector3(0, 0, -50)
	fx._drive_engine(loop, ship)
	assert_almost_eq(gain.call_func(loop), Constants.SOUND_ENGINE_MAX_GAIN * 0.5, 0.001, "Half speed: half as loud")
	ship.linear_velocity = Vector3(0, 0, -300)
	fx._drive_engine(loop, ship)
	assert_almost_eq(gain.call_func(loop), Constants.SOUND_ENGINE_MAX_GAIN, 0.001, "Past top speed: the cap")
	GlobalRefs.player_agent_body = null
	fx._drive_engine(loop, ship)
	assert_almost_eq(gain.call_func(loop), Constants.SOUND_ENGINE_MAX_GAIN * Constants.SOUND_ENGINE_OTHERS_SHARE, 0.001, "Another ship's: quieter")
	GlobalRefs.player_agent_body = saved_player
	ship.is_wreck = true
	fx._drive_engine(loop, ship)
	assert_false(loop.playing, "A wreck's engine is silent")


func _gain_of(loop) -> float:
	return db2linear(loop.unit_db - Constants.SOUND_EFFECTS_VOLUME_DB)


func test_the_afterburner_pitches_the_engine_up():
	var fx = _effects(["engine"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var loop = fx._attach_loop("engine", ship)
	fx._drive_engine(loop, ship, 0.0)
	assert_almost_eq(loop.pitch_scale, 1.0, 0.001, "Not lit: as baked")
	ship.afterburner_lit = true
	fx._drive_engine(loop, ship, Constants.SOUND_AFTERBURNER_PITCH_TIME * 0.5)
	assert_almost_eq(loop.pitch_scale, lerp(1.0, Constants.SOUND_AFTERBURNER_PITCH, 0.5), 0.001, "Pitching up")
	fx._drive_engine(loop, ship, Constants.SOUND_AFTERBURNER_PITCH_TIME)
	assert_almost_eq(loop.pitch_scale, Constants.SOUND_AFTERBURNER_PITCH, 0.001, "Lit: up")
	ship.afterburner_lit = false
	fx._drive_engine(loop, ship, Constants.SOUND_AFTERBURNER_PITCH_TIME)
	assert_almost_eq(loop.pitch_scale, 1.0, 0.001, "Out: back down")


class FakeTools extends Node:
	var on := false
	func get_tool_count() -> int:
		return 1
	func get_tool(_index: int):
		var tool_template = UtilityToolTemplate.new()
		tool_template.tool_type = "laser"
		return tool_template
	func is_active(_index: int) -> bool:
		return on


func test_a_laser_hums_while_on():
	var fx = _effects(["laser_hum"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var tools := FakeTools.new()
	tools.name = "ToolController"
	ship.add_child(tools)
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, fx.laser_on(ship), Constants.SOUND_LASER_HUM_GAIN, 0.1)
	assert_null(ship.get_node_or_null(fx.LASER_HUM_NAME), "Off: no hum")
	tools.on = true
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, fx.laser_on(ship), Constants.SOUND_LASER_HUM_GAIN, Constants.SOUND_LOOP_FADE)
	var hum = ship.get_node(fx.LASER_HUM_NAME)
	assert_true(hum.playing)
	assert_almost_eq(db2linear(hum.unit_db - Constants.SOUND_EFFECTS_VOLUME_DB), Constants.SOUND_LASER_HUM_GAIN, 0.001, "Low")
	tools.on = false
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, fx.laser_on(ship), Constants.SOUND_LASER_HUM_GAIN, Constants.SOUND_LOOP_FADE)
	assert_false(hum.playing, "Off again: dies away")


func test_a_weapon_hit_takes_the_place_of_the_hull_hit():
	var fx = _effects(["laser_hit", "hull_hit"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var before: int = fx.get_child_count()
	fx._weapon_hit("laser_hit", ship)
	fx._hull_hit(weakref(ship))
	assert_eq(fx.get_child_count(), before + 1, "The spark only")
	fx._weapon_hits.clear()
	fx._hull_hit(weakref(ship))
	assert_eq(fx.get_child_count(), before + 2, "Other damage: the hull hit")


class FakeTether extends Node:
	var length := 50.0
	var min_length := 10.0
	func is_valid() -> bool:
		return true


class FakeHarpoonTools extends Node:
	var tether = null
	var retracting := false
	func get_tool_count() -> int:
		return 1
	func get_tether(_index: int):
		return tether
	func is_retracting(_index: int) -> bool:
		return retracting


func test_the_winch_turns_while_a_harpoon_reels_in_or_pulls_its_cable_back():
	var fx = _effects(["harpoon_reel"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var tools := FakeHarpoonTools.new()
	tools.name = "ToolController"
	ship.add_child(tools)
	assert_false(fx.winching(ship), "No harpoon out")
	var tether := FakeTether.new()
	autofree(tether)
	tools.tether = tether
	assert_true(fx.winching(ship), "Reeling in")
	tether.length = tether.min_length
	assert_false(fx.winching(ship), "Reeled in: the winch stops")
	tools.tether = null
	tools.retracting = true
	assert_true(fx.winching(ship), "Pulling a loose cable back")
