# OptionsWindow (scenes/ui/menus/options_window.tscn): the player's options (Settings) in tabs, a
# category each (CATEGORIES: game, graphics, sound, interface). Each tab is a list down the left
# half, a row per option (its name, its value), tapped to step through its values; the right half
# tells what the last row tapped does and the values it takes. Open, it pauses the game; closing
# puts the pause back as it was (the main menu keeps its own). Every word is a Strings key, redone
# when the language changes. To add an option: a key in Settings.DEFAULTS, who applies it
# (Settings' header), a row in OPTIONS, its place in CATEGORIES, and its strings
# (options.<key>.name, options.<key>.about).

extends Control

# Row node -> [option key, values stepped through (a Constants array; null: on/off)].
# Volumes (PERCENT) read as a percentage, 0 as OFF.
const PERCENT = ["music", "effects"]
const OPTIONS = {
	"ButtonAutosave": ["autosave_on_dock", null],
	"ButtonAutolevel": ["autolevel", null],
	"ButtonSlowDown": ["slow_down_on_lag", null],
	"ButtonDynamicCamera": ["dynamic_camera", null],
	"ButtonRenderScale": ["render_scale", "RENDER_SCALE_STEPS"],
	"ButtonPixelSmoothing": ["pixel_smoothing", null],
	"ButtonMsaa": ["msaa", "MSAA_LEVELS"],
	"ButtonFxaa": ["fxaa", null],
	"ButtonSmoothMotion": ["smooth_motion", null],
	"ButtonVsync": ["vsync", null],
	"ButtonFrameCap": ["frame_cap", "FRAME_CAP_STEPS"],
	"ButtonFullscreen": ["fullscreen", null],
	"ButtonParticles": ["particles", null],
	"ButtonHitEffects": ["hit_effects", null],
	"ButtonExhausts": ["engine_exhausts", null],
	"ButtonDynamicLights": ["dynamic_lights", "DYNAMIC_LIGHTS_LEVELS"],
	"ButtonTetherRope": ["tether_rope", "TETHER_ROPE_STYLES"],
	"ButtonJumpAnimation": ["jump_animation", null],
	"ButtonShowFps": ["show_fps", null],
	"ButtonMusic": ["music", "VOLUME_STEPS"],
	"ButtonEffects": ["effects", "VOLUME_STEPS"],
	"ButtonLanguage": ["language", "LANGUAGES"],
	"ButtonUiScale": ["ui_scale", "UI_SCALE_STEPS"],
	"ButtonHudLook": ["hud_preset", "HUD_PRESET_ORDER"],
	"ButtonBracketFade": ["bracket_fade", null],
}

# Tabs, in order: [id, rows (OPTIONS keys) in order]. Every option is in one. Graphics runs from
# the picture (resolution, smoothing, frame rate) to the effects that cost the most.
const CATEGORIES = [
	["game", ["ButtonAutosave", "ButtonAutolevel", "ButtonSlowDown", "ButtonDynamicCamera"]],
	["graphics", ["ButtonRenderScale", "ButtonPixelSmoothing", "ButtonMsaa", "ButtonFxaa", "ButtonSmoothMotion",
		"ButtonVsync", "ButtonFrameCap", "ButtonFullscreen", "ButtonParticles", "ButtonHitEffects", "ButtonExhausts",
		"ButtonDynamicLights", "ButtonTetherRope", "ButtonJumpAnimation", "ButtonShowFps"]],
	["sound", ["ButtonMusic", "ButtonEffects"]],
	["interface", ["ButtonLanguage", "ButtonUiScale", "ButtonHudLook", "ButtonBracketFade"]],
]
const TAB_HEIGHT = 64.0
const ROW_HEIGHT = 72.0
const ROW_MARGIN = 20.0  # px from the row's ends to its words
const ODD_ROW_SHADE = 0.35  # Every other row's own fill this strong, so rows read apart (as the store's)

var tab: String = CATEGORIES[0][0]
var about: String = ""  # The row the right half tells of ("": the tab's own words)
var _was_paused: bool = false

onready var _layout: Control = $Panel/Overflow/Layout
onready var _list: Control = $Panel/Overflow/Layout/Body/Scroll/List
onready var _info: Control = $Panel/Overflow/Layout/Body/Info


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Panel/Overflow/Layout/Header/ButtonClose.connect("pressed", self, "close")
	for category in CATEGORIES:
		var button := Button.new()
		button.name = "Tab_" + category[0]
		button.theme_type_variation = "TabButton"
		button.focus_mode = Control.FOCUS_NONE
		button.rect_min_size = Vector2(0, TAB_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, "show_tab", [category[0]])
		$Panel/Overflow/Layout/Tabs.add_child(button)
		for index in range(category[1].size()):
			_add_row(category[1][index], index)
	show_tab(tab)
	Settings.connect("changed", self, "_on_settings_changed")
	Strings.connect("changed", self, "_on_language_changed")
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


# The option's next value: on and off in turn, or the next of its steps. The right half tells of it.
func step(key: String) -> void:
	var value = Settings.get_option(key)
	for name in OPTIONS:
		if OPTIONS[name][0] != key:
			continue
		about = name
		var steps: Array = steps_of(name)
		if steps.empty():
			Settings.set_option(key, not bool(value))
		else:
			Settings.set_option(key, steps[(steps.find(value) + 1) % steps.size()])
	_show_about()


# The values a row steps through ([] for on/off).
static func steps_of(name: String) -> Array:
	var source = OPTIONS[name][1]
	if source == null:
		return []
	if source == "LANGUAGES":
		return Strings.LANGUAGES
	return Constants.get(source)


func _on_settings_changed(_key, _value) -> void:
	_refresh()


func _on_language_changed(_language) -> void:
	_refresh()


# Shows one category's rows, its tab marked; the right half tells of the tab until a row is tapped.
func show_tab(which: String) -> void:
	tab = which
	about = ""
	for category in CATEGORIES:
		for name in category[1]:
			_list.get_node(name).visible = category[0] == tab
	$Panel/Overflow/Layout/Body/Scroll.scroll_vertical = 0
	_refresh()


# The category an option's row is in ("" for none).
static func category_of(name: String) -> String:
	for category in CATEGORIES:
		if name in category[1]:
			return category[0]
	return ""


# A row: a button the width of the list, its option's name to the left, its value to the right.
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
	for part in ["Name", "Value"]:
		var label := Label.new()
		label.name = part
		label.theme_type_variation = "LargeLabel" if part == "Name" else "LargeValueLabel"
		label.valign = Label.VALIGN_CENTER
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if part == "Name":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
		else:
			label.align = Label.ALIGN_RIGHT
		row.add_child(label)
	button.add_child(row)
	_list.add_child(button)


# Every word as the options and the language are now.
func _refresh() -> void:
	if not is_inside_tree():
		return
	$Panel/Overflow/Layout/Header/Title.text = Strings.t("options.title")
	$Panel/Overflow/Layout/Header/ButtonClose.text = Strings.t("common.close")
	$Panel/Overflow/Layout/Note.text = Strings.t("options.note")
	for category in CATEGORIES:
		var title: String = Strings.t("options.tab." + category[0])
		$Panel/Overflow/Layout/Tabs.get_node("Tab_" + category[0]).text = ("[%s]" if category[0] == tab else "%s") % title
	for name in OPTIONS:
		var row: Node = _list.get_node_or_null(name + "/Row")
		if row == null:
			continue
		row.get_node("Name").text = Strings.t("options.%s.name" % OPTIONS[name][0])
		var value: Label = row.get_node("Value")
		value.text = shown_value(OPTIONS[name][0], Settings.get_option(OPTIONS[name][0]))
		value.theme_type_variation = "LargeOffLabel" if value.text == Strings.t("options.value.off") else "LargeValueLabel"  # Off: grey
	_show_about()


# The right half: the row last tapped (its name, value, what it does and the values it takes), or
# the tab's own words.
func _show_about() -> void:
	var title: Label = _info.get_node("Title")
	var value: Label = _info.get_node("Value")
	var text: Label = _info.get_node("Text")
	var values: Label = _info.get_node("Values")
	if about == "" or not OPTIONS.has(about):
		title.text = Strings.t("options.tab." + tab)
		value.text = ""
		text.text = Strings.t("options.tab.%s.about" % tab)
		values.text = Strings.t("options.hint")
		return
	var key: String = OPTIONS[about][0]
	title.text = Strings.t("options.%s.name" % key)
	value.text = shown_value(key, Settings.get_option(key))
	text.text = Strings.t("options.%s.about" % key)
	var shown := []
	var steps: Array = steps_of(about)
	for each in steps if not steps.empty() else [true, false]:
		shown.append(shown_value(key, each))
	values.text = Strings.t("options.values", [PoolStringArray(shown).join(" · ")])


# "NAME: VALUE" of a row, as shown.
func row_text(name: String) -> String:
	var row: Node = _list.get_node("%s/Row" % name)
	return "%s: %s" % [row.get_node("Name").text, row.get_node("Value").text]


# An option's value as the player reads it, in the current language.
static func shown_value(key: String, value) -> String:
	match key:
		"hud_preset":
			return Strings.t("hud.look." + str(value))
		"language":
			return Strings.LANGUAGE_NAMES.get(str(value), str(value).to_upper())
		"frame_cap":
			return Strings.t("options.value.no_cap") if int(value) == 0 else Strings.t("options.value.fps", [int(value)])
	if key in PERCENT:
		return percent_text(value)
	return value_text(value)


static func percent_text(value) -> String:
	return "%d%%" % int(round(float(value) * 100.0)) if float(value) > 0.0 else Strings.t("options.value.off")


static func value_text(value) -> String:
	if typeof(value) == TYPE_BOOL:
		return Strings.t("options.value.on") if value else Strings.t("options.value.off")
	if typeof(value) == TYPE_REAL or typeof(value) == TYPE_INT:
		return "X%.2f" % float(value) if fmod(float(value) * 10.0, 1.0) != 0.0 else "X%.1f" % float(value)
	var key: String = "options.value." + str(value)
	return Strings.t(key) if Strings.has(key) else str(value).to_upper()
