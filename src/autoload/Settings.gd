# Settings: the player's options (the Options window), kept in user://settings.cfg between runs.
# Each option is a key of DEFAULTS; set_option() keeps it, saves the file and emits "changed".
# Whoever an option concerns applies it on "changed" and on its own start:
#   "particles"    (bool)  WorldRendering.set_particles_enabled
#   "render_scale" (float) WorldRendering.set_downscale_factor (one of Constants.RENDER_SCALE_STEPS)
#   "hit_effects"  (bool)  Agent: hull scars and slag, and the hit surface shots land on (off: the
#                          convex hull, cheaper); ships made after a change take it in full
#   "hud_preset"   (String) MainHUD.apply_hud_preset (Constants.HUD_PRESETS)
#   "music"        (float) AudioBuses: the Music bus's loudness, one of Constants.VOLUME_STEPS
#                          (0: off, AmbientMusic fades every track out and none plays)
#   "effects"      (float) AudioBuses: the Effects bus's loudness (0: no sound effects)
#   "slow_down_on_lag" (bool) FrameGovernor: the game slows down rather than its frame rate falling
#   "show_fps"     (bool)  MainHUD: frames a second in the top left corner
#   "dynamic_camera" (bool) OrbitCamera: a springy leash the ship's acceleration stretches; off,
#                          fixed to the ship
#   "autosave_on_dock" (bool) PlayerControllerShip: the game saves each time the player docks
#   "engine_exhausts" (bool) EngineExhaustSet: ships' plumes and nozzle glow (off: hidden and not
#                          worked out, nor the agents' per-nozzle thrust); missiles keep theirs
#   "dynamic_lights" (String) LaserHitEffect, WreckExplosionEffect: how many hits and explosions
#                          light their surroundings at once (Constants.DYNAMIC_LIGHTS_LEVELS, _CAPS)
#   "autolevel"    (bool)  MovementSystem: the player's ship slowly rolls about its nose until its up is
#                          as near the world's up as the heading allows
#   "ui_scale"     (float) UiScale: lettering, buttons and the HUD this many times their size
#                          (Constants.UI_SCALE_STEPS, x0.5-x1.5; 1.0 for a 12" 1366x768, more for
#                          denser screens, less for large monitors)
#   "language"     (String) Strings: the language every text is in (Strings.LANGUAGES)
#   "pixel_smoothing" (bool) WorldRendering: smooths the 3D picture when a render scale below 1.0
#                          stretches it (off: crisp pixels)
#   "msaa"         (String) WorldRendering: the 3D picture's multisampling (Constants.MSAA_LEVELS)
#   "fxaa"         (bool)  WorldRendering: FXAA on the 3D picture (cheap, softens edges)
#   "vsync"        (bool)  WorldRendering: OS.vsync_enabled
#   "frame_cap"    (int)   WorldRendering: Engine.target_fps (0: no cap; Constants.FRAME_CAP_STEPS)
#   "fullscreen"   (bool)  WorldRendering: OS.window_fullscreen (desktop; a phone is always full)
#   "smooth_motion" (bool) WorldRendering: physics interpolation (off: things move in 30 Hz steps,
#                          a little cheaper)
#   "jump_animation" (bool) JumpOrchestrator (WorldRendering.jump_transition_enabled): the jump's
#                          flight through the tunnel; off, a jump is a cut
#   "bracket_fade" (bool)  MainHUD (WorldRendering.projected_target_center_fade_enabled): brackets
#                          fade toward the screen's edges, so the eye stays near its centre
#   "tether_rope"  (String) Tether: "complex" simulates near cables, "simple" draws a straight line
#                          (Constants.TETHER_ROPE_STYLES)
# The file is read only by load_file() (the main scene's start), and written only after it: tests
# and tools run on the defaults, whatever the player chose, and never touch the file.

extends Node

signal changed(key, value)
signal loaded  # load_file() read the player's options (UiScale takes its factor from them)

const PATH = "user://settings.cfg"
const SECTION = "options"
const DEFAULTS = {
	"particles": true,
	"render_scale": 1.0,
	"hit_effects": true,
	"hud_preset": "standard",
	"music": 1.0,  # Was on/off: a saved bool is not kept
	"effects": 1.0,
	"slow_down_on_lag": false,
	"show_fps": false,
	"dynamic_camera": true,  # Was "camera_dynamic", off while it jittered: its saved "off" is not kept
	"autosave_on_dock": true,
	"engine_exhausts": true,
	"tether_rope": "complex",
	"dynamic_lights": "all",
	"autolevel": true,
	"ui_scale": 1.0,
	"language": "en",
	"pixel_smoothing": false,
	"msaa": "off",
	"fxaa": false,
	"vsync": true,
	"frame_cap": 0,
	"fullscreen": false,
	"smooth_motion": true,
	"jump_animation": true,
	"bracket_fade": true,
}


# [hits, explosions] that may light their surroundings at once (Settings "dynamic_lights").
func light_caps() -> Array:
	return Constants.DYNAMIC_LIGHTS_CAPS.get(get_option("dynamic_lights"), Constants.DYNAMIC_LIGHTS_CAPS.all)

var _values: Dictionary = DEFAULTS.duplicate()
var _persist: bool = false  # Set by load_file()
var _saved: Dictionary = {}  # Keys the file had when load_file() read it
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
	if config.load(PATH) == OK:
		for key in DEFAULTS:
			var value = config.get_value(SECTION, key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]) or (typeof(DEFAULTS[key]) == TYPE_REAL and typeof(value) == TYPE_INT):
				_values[key] = value
				_saved[key] = true
	emit_signal("loaded")


# Whether the player's file had this option (else it is at its default, never chosen).
func is_saved(key: String) -> bool:
	return _saved.has(key)


func save_file() -> void:
	if not _persist:
		return
	var config := ConfigFile.new()
	for key in _values:
		config.set_value(SECTION, key, _values[key])
	config.save(PATH)


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
