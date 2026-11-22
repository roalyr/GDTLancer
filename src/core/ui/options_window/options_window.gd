# OptionsWindow (scenes/ui/menus/options_window.tscn): the player's options (Settings) in tabs, a
# category each (CATEGORIES: game, display, performance, sound, interface); each tab a table that
# scrolls, a row each (its name, its value), tapped to step through its values. Open, it pauses
# the game; closing puts the pause back as it was (the main menu keeps its own). To add an option:
# a key in Settings.DEFAULTS, who applies it (Settings' header), a row in OPTIONS and its name in
# its category.

extends Control

# Row node -> [option key, values stepped through (null: on/off), label]
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
	"ButtonAutolevel": ["autolevel", null, "AUTOLEVEL"],
	"ButtonDynamicLights": ["dynamic_lights", "DYNAMIC_LIGHTS_LEVELS", "DYNAMIC LIGHTS"],
	"ButtonTetherRope": ["tether_rope", "TETHER_ROPE_STYLES", "TETHER ROPE"],
	"ButtonDynamicCamera": ["camera_dynamic", null, "DYNAMIC CAMERA (UNFINISHED, JITTERS)"],
}

# Tabs, in order: [id, name, rows (OPTIONS keys) in order]. Every option is in one.
const CATEGORIES = [
	["game", "GAME", ["ButtonAutosave", "ButtonAutolevel", "ButtonDynamicCamera"]],
	["display", "DISPLAY", ["ButtonParticles", "ButtonHitEffects", "ButtonExhausts", "ButtonTetherRope", "ButtonDynamicLights"]],
	["performance", "PERFORMANCE", ["ButtonRenderScale", "ButtonSlowDown", "ButtonShowFps"]],
	["sound", "SOUND", ["ButtonMusic", "ButtonEffects"]],
	["interface", "INTERFACE", ["ButtonHudLook"]],
]
const TAB_HEIGHT = 64.0
const ROW_HEIGHT = 80.0
const ROW_MARGIN = 24.0  # px from the row's ends to its words
const ODD_ROW_SHADE = 0.35  # Every other row's own fill this strong, so rows read apart (as the store's)

var tab: String = CATEGORIES[0][0]
var _was_paused: bool = false


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Panel/Layout/Header/ButtonClose.connect("pressed", self, "close")
	for category in CATEGORIES:
		var button := Button.new()
		button.name = "Tab_" + category[0]
		button.focus_mode = Control.FOCUS_NONE
		button.rect_min_size = Vector2(0, TAB_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, "show_tab", [category[0]])
		$Panel/Layout/Tabs.add_child(button)
		for index in range(category[2].size()):
			_add_row(category[2][index], index)
	show_tab(tab)
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


# Shows one category's rows, its tab marked.
func show_tab(which: String) -> void:
	tab = which
	for category in CATEGORIES:
		var here: bool = category[0] == tab
		$Panel/Layout/Tabs.get_node("Tab_" + category[0]).text = ("[%s]" if here else "%s") % category[1]
		for name in category[2]:
			$Panel/Layout/Scroll/List.get_node(name).visible = here
	$Panel/Layout/Scroll.scroll_vertical = 0


# The category an option's row is in ("" for none).
static func category_of(name: String) -> String:
	for category in CATEGORIES:
		if name in category[2]:
			return category[0]
	return ""


# A row: a button the width of the table, its option's name to the left, its value to the right.
func _add_row(name: String, index: int) -> void:
	var button := Button.new()
	button.name = name
	button.focus_mode = Control.FOCUS_NONE
	button.rect_min_size = Vector2(0, ROW_HEIGHT)
	if index % 2 != 0:
		button.self_modulate = Color(1, 1, 1, ODD_ROW_SHADE)  # Its fill only: not its words
	button.connect("pressed", self, "step", [OPTIONS[name][0]])
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.margin_left = ROW_MARGIN
	row.margin_right = -ROW_MARGIN
	for part in [["Name", "LargeLabel", OPTIONS[name][2]], ["Value", "LargeValueLabel", ""]]:
		var label := Label.new()
		label.name = part[0]
		label.theme_type_variation = part[1]
		label.text = part[2]
		label.valign = Label.VALIGN_CENTER
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if part[0] == "Name":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
		else:
			label.align = Label.ALIGN_RIGHT
		row.add_child(label)
	button.add_child(row)
	$Panel/Layout/Scroll/List.add_child(button)


func _refresh() -> void:
	for name in OPTIONS:
		var label: Label = get_node_or_null("Panel/Layout/Scroll/List/%s/Row/Value" % name)
		if label != null:
			var key: String = OPTIONS[name][0]
			if key == "hud_preset":
				label.text = Constants.hud_preset_label(Settings.get_option(key))
			else:
				label.text = percent_text(Settings.get_option(key)) if key in PERCENT else value_text(Settings.get_option(key))
			label.theme_type_variation = "LargeOffLabel" if label.text == "OFF" else "LargeValueLabel"  # Off: grey


# "NAME: VALUE" of a row, as shown.
func row_text(name: String) -> String:
	var row: Node = get_node("Panel/Layout/Scroll/List/%s/Row" % name)
	return "%s: %s" % [row.get_node("Name").text, row.get_node("Value").text]


static func percent_text(value) -> String:
	return "%d%%" % int(round(float(value) * 100.0)) if float(value) > 0.0 else "OFF"


static func value_text(value) -> String:
	if typeof(value) == TYPE_BOOL:
		return "ON" if value else "OFF"
	if typeof(value) == TYPE_REAL or typeof(value) == TYPE_INT:
		return "X%.2f" % float(value) if fmod(float(value) * 10.0, 1.0) != 0.0 else "X%.1f" % float(value)
	return str(value).to_upper()
