# Tests for AmbientMusic: the "music" volume (full by default) silences every track at 0; it plays on the Music bus.

extends GutTest

const AmbientMusic = preload("res://src/scenes/game_world/ambient_music.gd")


func after_each():
	Settings.reset_to_defaults()


func _music() -> AudioStreamPlayer:
	var music = AudioStreamPlayer.new()
	music.set_script(AmbientMusic)
	var sample := AudioStreamSample.new()
	sample.loop_mode = AudioStreamSample.LOOP_FORWARD
	music.stream = sample
	music.danger_stream = sample
	add_child_autofree(music)
	music._started = true
	music._fade_time = 1.0
	return music


func test_switched_off_nothing_plays():
	assert_eq(Settings.get_option("music"), 1.0, "Full by default")
	Settings._values["music"] = 0.0
	var music = _music()
	music._process(2.0)
	assert_false(music.playing)
	assert_eq(music._gain["calm"], 0.0)


func test_on_it_plays_and_off_again_it_fades_out():
	Settings._values["music"] = 1.0
	var music = _music()
	assert_eq(music.bus, "Music")
	assert_eq(music.get_node("DangerMusic").bus, "Music", "Every track on the Music bus")
	music._process(2.0)
	assert_eq(music._gain["calm"], 1.0, "On: the calm track")
	Settings._values["music"] = 0.0
	music._process(2.0)
	assert_eq(music._gain["calm"], 0.0, "Off: faded out")
	assert_false(music.playing)
