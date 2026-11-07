# Tests for AmbientMusic: the "music" option (off by default) silences every track.

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


func test_off_by_default_nothing_plays():
	assert_false(Settings.get_option("music"), "Off by default")
	var music = _music()
	music._process(2.0)
	assert_false(music.playing)
	assert_eq(music._gain["calm"], 0.0)


func test_on_it_plays_and_off_again_it_fades_out():
	Settings._values["music"] = true
	var music = _music()
	music._process(2.0)
	assert_eq(music._gain["calm"], 1.0, "On: the calm track")
	Settings._values["music"] = false
	music._process(2.0)
	assert_eq(music._gain["calm"], 0.0, "Off: faded out")
	assert_false(music.playing)
