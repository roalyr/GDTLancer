# AmbientMusic: the sector's music, three tracks by how dangerous things are (ThreatWatch's level):
# `stream` (this player's own: calm, the space ambient), `danger_stream` (hostiles seen, none has
# seen the player) and `combat_stream` (one has, or the player is under fire). Set in the main
# scene. Each loops; the one for the level fades in over MUSIC_CROSSFADE s as the others fade out,
# all at MUSIC_AMBIENT_VOLUME_DB. An empty track stays with the one playing. The music starts
# (fading in) when the first sector loads and plays on across jumps. With the "music" option off
# (Settings; the default) nothing plays.

extends AudioStreamPlayer

export(AudioStream) var danger_stream = null  # Hostiles seen, none has seen you (an .ogg or .mp3 that loops; empty: the calm one plays on)
export(AudioStream) var combat_stream = null  # A hostile sees you, or you are under fire (empty: the danger one)

var level: String = "calm"
var _players: Dictionary = {}  # Level -> AudioStreamPlayer ("calm" is this one)
var _gain: Dictionary = {"calm": 0.0, "danger": 0.0, "combat": 0.0}  # 0..1 each, toward the level's
var _started: bool = false
var _fade_time: float = 0.0  # s a fade takes: MUSIC_AMBIENT_FADE_IN at the start, MUSIC_CROSSFADE after


func _ready() -> void:
	_players["calm"] = self
	for pair in [["danger", danger_stream], ["combat", combat_stream]]:
		if pair[1] == null:
			continue
		var player := AudioStreamPlayer.new()
		player.name = pair[0].capitalize() + "Music"
		player.stream = pair[1]
		player.bus = bus
		player.volume_db = Constants.MUSIC_SILENT_DB
		add_child(player)
		_players[pair[0]] = player
	EventBus.connect("zone_loaded", self, "_on_zone_loaded")
	EventBus.connect("threat_level_changed", self, "_on_threat_level_changed")


func _on_zone_loaded(_zone, _path, _agent_container) -> void:
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
	var current: String = track_for(level) if Settings.get_option("music") else ""  # Off: all fade out
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
