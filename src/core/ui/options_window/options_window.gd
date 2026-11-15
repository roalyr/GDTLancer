# OptionsWindow (scenes/ui/menus/options_window.tscn): the player's options (Settings), one button
# each, tapped to step through its values. Open, it pauses the game; closing puts the pause back as
# it was (the main menu keeps its own). Each button reads its option's value; OPTIONS lists them.
# To add an option: a key in Settings.DEFAULTS, who applies it (Settings' header), a button in the
# scene and a row here.

extends Control

# Button node -> [option key, values stepped through (null: on/off), label]
# Volumes (PERCENT) read as a percentage, 0 as OFF.
const PERCENT = ["music", "effects"]
const OPTIONS = {
	"ButtonParticles": ["particles", null, "PARTICLES"],
	"ButtonRenderScale": ["render_scale", "RENDER_SCALE_STEPS", "RENDER SCALE"],
	"ButtonHitEffects": ["hit_effects", null, "HIT EFFECTS"],
	"ButtonHudLook": ["hud_preset", "HUD_PRESET_ORDER", "HUD LOOK"],
	"ButtonMusic": ["music", "VOLUME_STEPS", "MUSIC"],
	"ButtonEffects": ["effects", "VOLUME_STEPS", "SOUND EFFECTS"],
	"ButtonSlowDown": ["slow_down_on_lag", null, "SLOW DOWN ON LAG"],
	"ButtonShowFps": ["show_fps", null, "SHOW FPS"],
	"ButtonAutosave": ["autosave_on_dock", null, "SAVE ON DOCKING"],
	"ButtonExhausts": ["engine_exhausts", null, "ENGINE EXHAUSTS"],
	"ButtonDynamicLights": ["dynamic_lights", "DYNAMIC_LIGHTS_LEVELS", "DYNAMIC LIGHTS"],
	"ButtonTetherRope": ["tether_rope", "TETHER_ROPE_STYLES", "TETHER ROPE"],
	"ButtonDynamicCamera": ["camera_dynamic", null, "DYNAMIC CAMERA (UNFINISHED, JITTERS)"],
}

var _was_paused: bool = false


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Panel/Layout/Header/ButtonClose.connect("pressed", self, "close")
	for name in OPTIONS:
		get_node("Panel/Layout/" + name).connect("pressed", self, "step", [OPTIONS[name][0]])
	Settings.connect("changed", self, "_on_settings_changed")
	_refresh()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


# The option's next value: on and off in turn, or the next of its steps.
func step(key: String) -> void:
	var value = Settings.get_option(key)
	for name in OPTIONS:
		if OPTIONS[name][0] != key:
			continue
		if OPTIONS[name][1] == null:
			Settings.set_option(key, not bool(value))
		else:
			var steps: Array = Constants.get(OPTIONS[name][1])
			Settings.set_option(key, steps[(steps.find(value) + 1) % steps.size()])


func _on_settings_changed(_key, _value) -> void:
	_refresh()


func _refresh() -> void:
	for name in OPTIONS:
		var button: Button = get_node_or_null("Panel/Layout/" + name)
		if button != null:
			var key: String = OPTIONS[name][0]
			button.text = "%s: %s" % [OPTIONS[name][2], percent_text(Settings.get_option(key)) if key in PERCENT else value_text(Settings.get_option(key))]


static func percent_text(value) -> String:
	return "%d%%" % int(round(float(value) * 100.0)) if float(value) > 0.0 else "OFF"


static func value_text(value) -> String:
	if typeof(value) == TYPE_BOOL:
		return "ON" if value else "OFF"
	if typeof(value) == TYPE_REAL or typeof(value) == TYPE_INT:
		return "X%.2f" % float(value) if fmod(float(value) * 10.0, 1.0) != 0.0 else "X%.1f" % float(value)
	return str(value).to_upper()
