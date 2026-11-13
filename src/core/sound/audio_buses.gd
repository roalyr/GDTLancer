# AudioBuses: the game's audio buses (default_bus_layout.tres): "Music" (AmbientMusic) and
# "Effects" (every SoundEffects player), both into Master. apply() sets each from its volume option
# (Settings "music", "effects": a share of full, 0 mutes it); SoundEffects calls it on its start and
# whenever an option changes.

extends Reference

const MUSIC = "Music"
const EFFECTS = "Effects"
const OPTIONS = {MUSIC: "music", EFFECTS: "effects"}


static func apply() -> void:
	for bus in OPTIONS:
		set_volume(bus, float(Settings.get_option(OPTIONS[bus])))


# The bus at `share` of full loudness (linear); 0 or less mutes it. A missing bus is skipped.
static func set_volume(bus: String, share: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, share <= 0.0)
	AudioServer.set_bus_volume_db(index, linear2db(max(share, 0.0001)))
