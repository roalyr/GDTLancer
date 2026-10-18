# AmbientMusic: the space ambient soundtrack (stream set in the main scene). Fades in when the
# first sector loads and keeps playing (looped) across jumps.

extends AudioStreamPlayer

var _fade_left := 0.0


func _ready() -> void:
	EventBus.connect("zone_loaded", self, "_on_zone_loaded")


func _on_zone_loaded(_zone, _path, _agent_container) -> void:
	if playing or stream == null:
		return
	volume_db = Constants.MUSIC_SILENT_DB
	_fade_left = Constants.MUSIC_AMBIENT_FADE_IN
	play()


func _process(delta: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left = max(0.0, _fade_left - delta)
	var t: float = 1.0 - _fade_left / Constants.MUSIC_AMBIENT_FADE_IN
	volume_db = lerp(Constants.MUSIC_SILENT_DB, Constants.MUSIC_AMBIENT_VOLUME_DB, t)
