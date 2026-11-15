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


func test_the_mixer_keeps_each_ships_loops_and_leaves_silent_ones_be():
	var fx = _effects(["laser_hum"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var tools := FakeTools.new()
	tools.name = "ToolController"
	ship.add_child(tools)
	var loops := {}
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, false, Constants.SOUND_LASER_HUM_GAIN, 0.1, loops)
	assert_true(loops.empty(), "Off and never on: nothing made")
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, true, Constants.SOUND_LASER_HUM_GAIN, Constants.SOUND_LOOP_FADE, loops)
	var hum = ship.get_node(fx.LASER_HUM_NAME)
	assert_eq(loops.get(fx.LASER_HUM_NAME), hum, "Kept in the ship's own record")
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, false, Constants.SOUND_LASER_HUM_GAIN, Constants.SOUND_LOOP_FADE, loops)
	assert_false(hum.playing, "Faded out and stopped")
	hum.unit_db = 3.0
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, false, Constants.SOUND_LASER_HUM_GAIN, 0.1, loops)
	assert_eq(hum.unit_db, 3.0, "Off and silent: left alone")
	hum.free()
	fx._drive_loop(ship, "laser_hum", fx.LASER_HUM_NAME, true, Constants.SOUND_LASER_HUM_GAIN, 0.1, loops)
	assert_true(is_instance_valid(loops.get(fx.LASER_HUM_NAME)), "A loop gone is made again")


func test_loop_carriers_are_reranked_on_their_interval():
	var fx = _effects(["engine"])
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = null
	fx._process(0.1)
	var ship := FakeShip.new()
	add_child_autofree(ship)
	fx._track_ship(ship)
	fx._process(0.1)
	assert_false(fx._heard.has(ship.get_instance_id()), "Not yet re-ranked")
	fx._next_carriers = 0
	fx._process(0.1)
	assert_true(fx._heard.has(ship.get_instance_id()), "On the next re-rank")
	GlobalRefs.player_agent_body = saved_player


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


class FakePlayerShip:
	extends Spatial
	var is_wreck := false
	var hull := 100.0
	var hull_max := 100.0
	var power := 50.0
	var power_max := 50.0


func _ui_plays(fx: Node, slot: String) -> int:
	var count := 0
	for child in fx.get_children():
		if child is AudioStreamPlayer and child.stream == fx.bank.stream(slot):
			count += 1
	return count


func test_only_the_nearest_ships_play_their_loops():
	var fx = _effects(["engine"])
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = null
	var ships: Array = []
	for index in range(Constants.SOUND_LOOP_CARRIERS + 2):
		var ship := FakeShip.new()
		add_child_autofree(ship)
		ship.translation = Vector3(100.0 * (index + 1), 0, 0)
		fx._track_ship(ship)
		ships.append(ship)
	var far := FakeShip.new()
	add_child_autofree(far)
	far.translation = Vector3(Constants.SOUND_MAX_DISTANCE + 100.0, 0, 0)
	fx._track_ship(far)
	var heard: Dictionary = fx.loop_carriers()
	assert_eq(heard.size(), Constants.SOUND_LOOP_CARRIERS, "A budget of loops")
	assert_true(heard.has(ships[0].get_instance_id()), "The nearest")
	assert_false(heard.has(ships[ships.size() - 1].get_instance_id()), "Past the budget: none")
	assert_false(heard.has(far.get_instance_id()), "Out of hearing: none")
	var loop = ships[ships.size() - 1].get_node(fx.LOOP_NAME)
	ships[ships.size() - 1].linear_velocity = Vector3(0, 0, -100)
	fx._drive_engine(loop, ships[ships.size() - 1], 0.1, false)
	assert_false(loop.playing, "Not among them: stopped, whatever its speed")
	fx._drive_engine(loop, ships[ships.size() - 1], 0.1, true)
	assert_true(loop.playing, "Among them again: plays")
	ships[ships.size() - 1].linear_velocity = Vector3.ZERO
	fx._drive_engine(loop, ships[ships.size() - 1], 0.1, true)
	assert_false(loop.playing, "Standing still: silent, so stopped")
	assert_eq(loop.bus, "Effects")
	GlobalRefs.player_agent_body = saved_player


func test_old_bookkeeping_is_forgotten():
	var fx = _effects(["hull_hit"])
	var source := Node.new()
	autofree(source)
	fx.play("hull_hit", Vector3.ZERO, source)
	fx._weapon_hits[12345] = OS.get_ticks_msec()
	assert_eq(fx._last_played.size(), 1)
	fx.prune(OS.get_ticks_msec() + fx.PRUNE_AGE + 1)
	assert_eq(fx._last_played.size(), 0, "Played long ago: forgotten")
	assert_eq(fx._weapon_hits.size(), 0, "Hit long ago: forgotten")


func test_a_pack_of_hostiles_is_one_notice():
	var fx = _effects(["hostile_detected"])
	for i in range(5):
		EventBus.emit_signal("hostile_detected", null)
	assert_eq(_ui_plays(fx, "hostile_detected"), 1, "Within SOUND_ALERT_GAP: once")


func test_tools_click_on_and_off_and_run_dry():
	var fx = _effects(["tool_on", "tool_off", "out_of_ammo"])
	var ship := RigidBody.new()
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	ship.add_child(tools)
	add_child_autofree(ship)
	var before: int = fx.get_child_count()
	tools.emit_signal("tool_activated", 0, null)
	assert_eq(fx.get_child_count(), before + 1, "On")
	tools.emit_signal("tool_deactivated", 0, "retarget")
	assert_eq(fx.get_child_count(), before + 1, "A new target is no switch")
	tools.emit_signal("tool_deactivated", 0, "empty")
	var last = fx.get_child(fx.get_child_count() - 1)
	assert_eq(last.stream, fx.bank.out_of_ammo, "Out of rounds: the dry click")


func test_the_players_alarms_sound_once_each_time():
	var fx = _effects(["hull_critical", "power_empty", "lance_warning"])
	var ship := FakePlayerShip.new()
	add_child_autofree(ship)
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = ship
	fx._watch_player()
	assert_eq(_ui_plays(fx, "hull_critical") + _ui_plays(fx, "power_empty"), 0, "All well: quiet")
	ship.hull = 20.0
	ship.power = 0.0
	fx._watch_player()
	fx._watch_player()
	assert_eq(_ui_plays(fx, "hull_critical"), 1, "Hull critical, once")
	assert_eq(_ui_plays(fx, "power_empty"), 1, "Power out, once")
	EventBus.emit_signal("agent_charged", Spatial.new(), null)
	assert_eq(_ui_plays(fx, "lance_warning"), 0, "Another ship charged: not the player's warning")
	EventBus.emit_signal("agent_charged", ship, null)
	assert_eq(_ui_plays(fx, "lance_warning"), 1, "A lance charging the player")
	GlobalRefs.player_agent_body = saved_player


func test_the_afterburner_lighting_roars_once():
	var fx = _effects(["afterburner_ignite"])
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var saved_player = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = null
	fx._track_ship(ship)
	ship.afterburner_lit = true
	fx._process(0.1)
	fx._process(0.1)
	var roars := 0
	for child in fx.get_children():
		if child is AudioStreamPlayer3D and child.stream == fx.bank.afterburner_ignite:
			roars += 1
	assert_eq(roars, 1, "Lit: one roar, not one a frame")
	GlobalRefs.player_agent_body = saved_player


func test_trading_and_targeting_are_heard():
	var fx = _effects(["trade", "target_selected"])
	EventBus.emit_signal("player_traded", "cargo")
	EventBus.emit_signal("player_target_selected", null)
	assert_eq(_ui_plays(fx, "trade"), 1)
	assert_eq(_ui_plays(fx, "target_selected"), 1)
	assert_eq(fx.get_child(fx.get_child_count() - 1).bus, "Effects", "On the Effects bus")


func test_effects_pause_with_the_game():
	var fx = _effects(["ui_press"])
	var player = fx.play("ui_press")
	get_tree().paused = true
	var paused: bool = player.stream_paused
	get_tree().paused = false
	assert_true(paused, "The pause menu holds the sounds")
	assert_false(player.stream_paused, "And lets them go")
