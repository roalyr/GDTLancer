# Settings: the player's options (the Options window), kept in user://settings.cfg between runs.
# Each option is a key of DEFAULTS; set_option() keeps it, saves the file and emits "changed".
# Whoever an option concerns applies it on "changed" and on its own start:
#   "particles"    (bool)  WorldRendering.set_particles_enabled
#   "render_scale" (float) WorldRendering.set_downscale_factor (one of Constants.RENDER_SCALE_STEPS)
#   "hit_effects"  (bool)  Agent: hull scars and slag, and the hit surface shots land on (off: the
#                          convex hull, cheaper); ships made after a change take it in full
#   "hud_preset"   (String) MainHUD.apply_hud_preset (Constants.HUD_PRESETS)
#   "music"        (bool)  AmbientMusic: off, every track fades out and none plays
# The file is read only by load_file() (the main scene's start), and written only after it: tests
# and tools run on the defaults, whatever the player chose, and never touch the file.

extends Node

signal changed(key, value)

const PATH = "user://settings.cfg"
const SECTION = "options"
const DEFAULTS = {
	"particles": true,
	"render_scale": 1.0,
	"hit_effects": true,
	"hud_preset": "standard",
	"music": true,
}

var _values: Dictionary = DEFAULTS.duplicate()
var _persist: bool = false  # Set by load_file()
var use_file: bool = true  # False (the tests): load_file() reads and keeps nothing


func get_option(key: String):
	return _values.get(key, DEFAULTS.get(key))


func set_option(key: String, value) -> void:
	if not DEFAULTS.has(key):
		push_error("Settings: no option '%s'" % key)
		return
	if typeof(value) != typeof(DEFAULTS[key]):
		value = float(value) if typeof(DEFAULTS[key]) == TYPE_REAL else value
	_values[key] = value
	save_file()
	emit_signal("changed", key, value)


func load_file() -> void:
	if not use_file:
		return
	_persist = true
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key in DEFAULTS:
		var value = config.get_value(SECTION, key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]) or (typeof(DEFAULTS[key]) == TYPE_REAL and typeof(value) == TYPE_INT):
			_values[key] = value


func save_file() -> void:
	if not _persist:
		return
	var config := ConfigFile.new()
	for key in _values:
		config.set_value(SECTION, key, _values[key])
	config.save(PATH)


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
