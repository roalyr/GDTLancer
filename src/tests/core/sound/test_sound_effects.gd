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
	var fx = _effects(["laser_fire"])
	var played := 0
	for i in range(Constants.SOUND_MAX_VOICES + 5):
		var source := Node.new()
		autofree(source)
		if fx.play("laser_fire", Vector3.ZERO, source) != null:
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


func test_the_engine_loop_follows_thrust():
	var fx = _effects(["engine"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var loop = fx._attach_loop("engine", ship)
	assert_eq(loop.get_parent(), ship, "Carried by the ship")
	fx._drive_engine(loop, ship)
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = ship
	ship.linear_velocity = Vector3(0, 0, -50)
	fx._drive_engine(loop, ship)
	assert_lt(loop.unit_db, -60.0, "Coasting, engine off: silent")
	ship.activity = 0.5
	fx._drive_engine(loop, ship)
	assert_almost_eq(db2linear(loop.unit_db - Constants.SOUND_EFFECTS_VOLUME_DB), Constants.SOUND_ENGINE_MAX_GAIN * 0.5, 0.001, "Half thrust: half as loud")
	ship.activity = 1.0
	fx._drive_engine(loop, ship)
	assert_almost_eq(db2linear(loop.unit_db - Constants.SOUND_EFFECTS_VOLUME_DB), Constants.SOUND_ENGINE_MAX_GAIN, 0.001, "Full thrust: the cap")
	assert_almost_eq(loop.pitch_scale, Constants.SOUND_ENGINE_PITCH[1], 0.001)
	GlobalRefs.player_agent_body = null
	fx._drive_engine(loop, ship)
	assert_almost_eq(db2linear(loop.unit_db - Constants.SOUND_EFFECTS_VOLUME_DB), Constants.SOUND_ENGINE_MAX_GAIN * Constants.SOUND_ENGINE_OTHERS_SHARE, 0.001, "Another ship's: quieter")
	GlobalRefs.player_agent_body = saved_player
	ship.is_wreck = true
	fx._drive_engine(loop, ship)
	assert_false(loop.playing, "A wreck's engine is silent")


func test_the_afterburner_plays_as_it_lights():
	var fx = _effects(["afterburner"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	fx._track_ship(ship)
	var before: int = fx.get_child_count()
	fx._process(0.0)
	assert_eq(fx.get_child_count(), before, "Not lit")
	ship.afterburner_lit = true
	fx._process(0.0)
	assert_eq(fx.get_child_count(), before + 1, "Lit: plays once")
	fx._process(0.0)
	assert_eq(fx.get_child_count(), before + 1, "Stays lit: no repeat")
