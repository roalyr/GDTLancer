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


# A sector's Location may name its own tracks; one left empty takes the game's. Changing to a sector
# with other tracks fades the playing ones out before the new ones come in.
func test_a_sector_plays_its_own_music_and_fades_over_to_it():
	Settings._values["music"] = 1.0
	var music = _music()
	var game_calm = music.stream
	var own := AudioStreamSample.new()
	own.loop_mode = AudioStreamSample.LOOP_FORWARD
	var location = LocationTemplate.new()
	location.music_calm = own
	var saved = TemplateDatabase.locations
	TemplateDatabase.locations = {"sector_own": location, "sector_plain": LocationTemplate.new()}
	var tracks: Dictionary = music.tracks_for("sector_own")
	assert_eq(tracks.calm, own, "Its own calm track")
	assert_eq(tracks.danger, music._defaults.danger, "The game's danger track where it names none")
	assert_eq(music.tracks_for("sector_plain").calm, game_calm, "A sector with none: the game's")
	music._process(2.0)
	assert_eq(music._gain["calm"], 1.0, "The game's calm track on")
	music.follow_sector("sector_own")
	assert_eq(music.stream, game_calm, "Not cut off: it fades out first")
	music._process(0.5)
	assert_lt(music._gain["calm"], 1.0, "Fading out")
	for i in range(20):
		music._process(0.5)
	assert_eq(music.stream, own, "Then the sector's own comes in")
	assert_eq(music._gain["calm"], 1.0)
	music.follow_sector("sector_own")
	assert_true(music._pending.empty(), "The same tracks: nothing to change")
	TemplateDatabase.locations = saved
