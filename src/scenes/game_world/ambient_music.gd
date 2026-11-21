# AmbientMusic: the sector's music, three tracks by how dangerous things are (ThreatWatch's level):
# `stream` (calm, the space ambient), `danger_stream` (hostiles seen, none has seen the player) and
# `combat_stream` (one has, or the player is under fire). Those set in the main scene are the
# game's own; a sector's Location may name its own (music_calm, music_danger, music_combat), each
# left empty taking the game's. Each loops; the one for the level fades in over MUSIC_CROSSFADE s as
# the others fade out, all at MUSIC_AMBIENT_VOLUME_DB. An empty track stays with the one playing. The
# music starts (fading in) when the first sector loads and plays on through jumps (it runs while the
# jump pauses the game); a sector with other tracks fades the old ones out as the jump leaves
# (sector_changed) and its own in after. It plays on the "Music" bus, whose loudness is the "music"
# option (Settings, AudioBuses); at 0 every track fades out and none plays.

extends AudioStreamPlayer

const AudioBuses = preload("res://src/core/sound/audio_buses.gd")

export(AudioStream) var danger_stream = null  # Hostiles seen, none has seen you (an .ogg or .mp3 that loops; empty: the calm one plays on)
export(AudioStream) var combat_stream = null  # A hostile sees you, or you are under fire (empty: the danger one)

const LEVELS = ["calm", "danger", "combat"]
const LOCATION_FIELDS = {"calm": "music_calm", "danger": "music_danger", "combat": "music_combat"}

var level: String = "calm"
var _players: Dictionary = {}  # Level -> AudioStreamPlayer ("calm" is this one)
var _gain: Dictionary = {"calm": 0.0, "danger": 0.0, "combat": 0.0}  # 0..1 each, toward the level's
var _started: bool = false
var _fade_time: float = 0.0  # s a fade takes: MUSIC_AMBIENT_FADE_IN at the start, MUSIC_CROSSFADE after
var _defaults: Dictionary = {}  # Level -> the game's own track (the main scene's), or null
var _pending: Dictionary = {}  # Level -> track: another sector's, put in once the playing ones are faded out


func _ready() -> void:
	bus = AudioBuses.MUSIC
	pause_mode = Node.PAUSE_MODE_PROCESS  # Plays on while a jump pauses the game
	_defaults = {"calm": stream, "danger": danger_stream, "combat": combat_stream}
	_players["calm"] = self
	_set_tracks(_defaults)
	EventBus.connect("zone_loaded", self, "_on_zone_loaded")
	EventBus.connect("sector_changed", self, "_on_sector_changed")
	EventBus.connect("threat_level_changed", self, "_on_threat_level_changed")


# The tracks `sector_id` plays: its Location's, the game's where it names none.
func tracks_for(sector_id: String) -> Dictionary:
	var location = TemplateDatabase.locations.get(sector_id) if sector_id != "" else null
	var out := {}
	for key in LEVELS:
		var own = location.get(LOCATION_FIELDS[key]) if location != null else null
		out[key] = own if own is AudioStream else _defaults[key]
	return out


# The tracks playing now, by level (null: none).
func current_tracks() -> Dictionary:
	var out := {}
	for key in LEVELS:
		out[key] = _players[key].stream if _players.has(key) else null
	return out


# Puts `tracks` in the players, making one for a level that had none.
func _set_tracks(tracks: Dictionary) -> void:
	for key in LEVELS:
		var track = tracks.get(key)
		if key == "calm":
			if stream != track:
				stop()
				stream = track
				_gain[key] = 0.0
			continue
		if not _players.has(key):
			if track == null:
				continue
			var player := AudioStreamPlayer.new()
			player.name = key.capitalize() + "Music"
			player.bus = bus
			player.volume_db = Constants.MUSIC_SILENT_DB
			add_child(player)
			_players[key] = player
		if _players[key].stream != track:
			_players[key].stop()
			_players[key].stream = track
			_gain[key] = 0.0


# Follows `sector_id`'s music: before the music has started, at once; after, the playing tracks fade
# out first (_process) and the new ones come in.
func follow_sector(sector_id: String) -> void:
	var wanted: Dictionary = tracks_for(sector_id)
	if same_tracks(wanted, current_tracks()):
		_pending = {}
		return
	if not _started:
		_set_tracks(wanted)
		return
	_pending = wanted
	_fade_time = Constants.MUSIC_CROSSFADE


func _on_sector_changed(new_sector_id, _old_sector_id) -> void:
	follow_sector(str(new_sector_id))


func _on_zone_loaded(_zone, _path, _agent_container) -> void:
	follow_sector(GameState.current_sector_id)
	if _started:
		return
	_started = true
	_fade_time = Constants.MUSIC_AMBIENT_FADE_IN


func _on_threat_level_changed(new_level: String) -> void:
	level = new_level
	_fade_time = Constants.MUSIC_CROSSFADE


# The track the level plays: its own, else the nearest calmer one there is.
func track_for(wanted: String) -> String:
	var order: Array = ["calm", "danger", "combat"]
	for index in range(order.find(wanted), -1, -1):
		if _players.has(order[index]) and _players[order[index]].stream != null:
			return order[index]
	return "calm"


# A track plays only while it is heard: one fading out stops once silent (and starts over next time).
func _process(delta: float) -> void:
	if not _started:
		return
	if not _pending.empty() and _silent():
		_set_tracks(_pending)  # The old sector's tracks are out: the new ones come in
		_pending = {}
	var current: String = track_for(level) if float(Settings.get_option("music")) > 0.0 and _pending.empty() else ""  # Off, or changing sectors: all fade out
	var step: float = delta / max(_fade_time, 0.01)
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		if player.stream == null:
			continue
		_gain[key] = clamp(_gain[key] + (step if key == current else -step), 0.0, 1.0)
		player.volume_db = lerp(Constants.MUSIC_SILENT_DB, Constants.MUSIC_AMBIENT_VOLUME_DB, sqrt(_gain[key]))
		if _gain[key] > 0.0 and not player.playing:
			player.play()
		elif _gain[key] <= 0.0 and player.playing:
			player.stop()


static func same_tracks(a: Dictionary, b: Dictionary) -> bool:
	for key in LEVELS:
		if a.get(key) != b.get(key):
			return false
	return true


func _silent() -> bool:
	for key in _players:
		if _gain.get(key, 0.0) > 0.0:
			return false
	return true
