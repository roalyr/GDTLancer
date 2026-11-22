# UiScale: the UI's size (Settings "ui_scale", Options > INTERFACE > UI SCALE, x0.5 to x1.5): more
# for screens denser than the 12" 1366x768 the UI is drawn for (1.0), less for large monitors.
# Everything follows one factor, down as well as up, in three places:
#   - Lettering: every DynamicFont of main_theme.tres takes its size times the factor, so every label
#     and button, made now or later, follows; the named looks (SmallLabel, TitleLabel...) keep their
#     proportions.
#   - Buttons (any BaseButton, icon-only ones too): their rect_min_size times the factor, and, laid
#     out by hand (not in a container), their size grows from their anchor (an anchored corner stays
#     put, a centred one stays centred).
#   - Layouts (a control with the meta LAYOUT, the HUD's ScreenControls): everything under it scales
#     as one about its anchors: offsets, min sizes and box separations. A HUD element anchored to a
#     corner of the screen grows from that corner. A layout takes layout_factor: the factor, but no
#     more than the screen's width holds (Constants.HUD_SCALE_WIDTH at 1.0); its lettering still
#     takes the full factor. Under a layout, a control with the meta AXES = "x" grows only across
#     and shrinks both ways (the HUD's sliders keep their length above 1.0), and one given its own factor (set_subtree_factor, the
#     HUD's flight row fitted between the corners) takes that, with all under it.
# Controls are scaled as they enter the tree (just after: code that sets a size right after add_child
# is scaled too), and again from their own sizes when the factor changes. Code that sets a scaled
# control's size or offsets later writes them at 1.0 (base_of() reads one back; set_base() sets and
# applies at once); otherwise they are taken up at the next change of the factor. A control with
# the meta SKIP (and all under it) is left alone: the target brackets, placed and sized by their
# own code.
# Words never spill out of a button, whatever the language (clamp_words()): a label laid on a button
# wraps within it and is cut where it still does not fit; a button's own text is cut to the button
# when the button has a set width or stretches to share a row (else it grows with its text).

extends Node

signal changed(factor)

const MainTheme = preload("res://assets/themes/main_theme.tres")
const LAYOUT = "ui_scale_layout"
const AXES = "ui_scale_axes"  # "x": scaled across only (offsets left/right, min width)
const OWN_FACTOR = "_ui_factor"  # set_subtree_factor's
const SKIP = "ui_scale_skip"
const GROUP = "ui_scaled"
const BASE = "_ui_base"  # A control's sizes at 1.0
const DONE = "_ui_done"  # What was last set from them
const MARGINS = ["margin_left", "margin_top", "margin_right", "margin_bottom"]

var factor: float = 1.0
var layout_factor: float = 1.0  # A LAYOUT's: the factor, held to what the screen's width allows
var _font_sizes: Dictionary = {}  # DynamicFont -> its size at 1.0
var _pending: Array = []


func _ready() -> void:
	for font in _theme_fonts(MainTheme):
		_font_sizes[font] = font.size
	get_tree().connect("node_added", self, "_on_node_added")
	_take_present(get_tree().root)  # A game run from its main scene: the scene is in before this runs
	Settings.connect("changed", self, "_on_settings_changed")
	Settings.connect("loaded", self, "_on_settings_loaded")
	get_tree().root.connect("size_changed", self, "_on_screen_resized")
	set_factor(float(Settings.get_option("ui_scale")))


func set_factor(value: float) -> void:
	value = clamp(value, Constants.UI_SCALE_MIN, Constants.UI_SCALE_MAX)
	var layout: float = layout_factor_for(value, get_tree().root.get_visible_rect().size.x)
	if is_equal_approx(value, factor) and is_equal_approx(layout, layout_factor) and _fonts_at(value):
		return
	factor = value
	layout_factor = layout
	for font in _font_sizes:
		font.size = int(max(1, round(_font_sizes[font] * factor)))
	for node in get_tree().get_nodes_in_group(GROUP):
		_apply(node)
	emit_signal("changed", factor)


# A layout's factor for a UI factor on a screen this wide (px of the stretched view): no more than
# HUD_SCALE_WIDTH fills, and never held below 1.0 (nor above the factor).
static func layout_factor_for(value: float, screen_width: float) -> float:
	return min(value, max(1.0, screen_width / Constants.HUD_SCALE_WIDTH))


func _on_screen_resized() -> void:
	set_factor(factor)


# Gives a control under a layout, and all under it, a factor of its own (<= 0: back to the
# layout's), and scales them to it at once.
func set_subtree_factor(control: Control, value: float) -> void:
	if value > 0.0:
		if control.has_meta(OWN_FACTOR) and is_equal_approx(control.get_meta(OWN_FACTOR), value):
			return
		control.set_meta(OWN_FACTOR, value)
	elif control.has_meta(OWN_FACTOR):
		control.remove_meta(OWN_FACTOR)
	else:
		return
	_apply_subtree(control)


# Sets a control's sizes at 1.0 (property -> value), and scales it to them at once.
func set_base(control: Control, values: Dictionary) -> void:
	if not control.has_meta(BASE):
		_take(control)
	if not control.has_meta(BASE):
		return  # Not one of ours: as given
	var base: Dictionary = control.get_meta(BASE)
	for key in values:
		base[key] = values[key]
	control.set_meta(BASE, base)
	_apply(control)


func _apply_subtree(node: Node) -> void:
	if node is Control and node.is_in_group(GROUP):
		_apply(node)
	for child in node.get_children():
		_apply_subtree(child)


# The factor a scaled control takes.
func factor_of(control: Control) -> float:
	if control.get_meta("_ui_mode") != "layout":
		return factor
	var node: Node = control
	while node != null and not node.has_meta(LAYOUT):
		if node.has_meta(OWN_FACTOR):
			return node.get_meta(OWN_FACTOR)
		node = node.get_parent()
	return layout_factor


# A scaled control's property (a margin, rect_min_size, "separation") at 1.0.
func base_of(control: Control, property: String):
	if control.has_meta(BASE):
		var base: Dictionary = control.get_meta(BASE)
		if base.has(property):
			return base[property]
	if property == "separation":
		return control.get_constant("separation")
	return control.get(property)


func _fonts_at(value: float) -> bool:
	for font in _font_sizes:
		if font.size != int(max(1, round(_font_sizes[font] * value))):
			return false
	return true


static func _theme_fonts(theme: Theme) -> Array:
	var fonts: Array = []
	if theme.default_font is DynamicFont:
		fonts.append(theme.default_font)
	for type in theme.get_type_list(""):
		for name in theme.get_font_list(type):
			var font = theme.get_font(name, type)
			if font is DynamicFont and not font in fonts:
				fonts.append(font)
	return fonts


func _on_settings_changed(key: String, value) -> void:
	if key == "ui_scale":
		set_factor(float(value))


# A phone or tablet whose player never chose a UI scale starts at auto_factor's (saved, so it is
# theirs to change); a desktop at 1.0.
func _on_settings_loaded() -> void:
	if not Settings.is_saved("ui_scale") and OS.get_name() in ["Android", "iOS"]:
		var size: Vector2 = OS.get_screen_size()
		Settings.set_option("ui_scale", auto_factor(min(size.x, size.y), OS.get_screen_dpi()))
	var saved: float = float(Settings.get_option("ui_scale"))
	if saved != clamp(saved, Constants.UI_SCALE_MIN, Constants.UI_SCALE_MAX):  # Saved under a wider range
		Settings.set_option("ui_scale", clamp(saved, Constants.UI_SCALE_MIN, Constants.UI_SCALE_MAX))
	set_factor(float(Settings.get_option("ui_scale")))


# The UI scale that makes the UI about as tall on a screen (its short side in px, its dots per inch)
# as on the 12" 1366x768 it is drawn for (the view keeps its height: a shorter screen draws it
# smaller), rounded down to a UI_SCALE_STEPS step, from 1.0 to UI_SCALE_AUTO_MAX.
static func auto_factor(screen_height_px: float, dpi: float) -> float:
	var want: float = Constants.UI_SCALE_BASE_HEIGHT_IN / max(screen_height_px / max(dpi, 1.0), 0.1)
	var best: float = 1.0
	for step in Constants.UI_SCALE_STEPS:
		if step > best and step <= want and step <= Constants.UI_SCALE_AUTO_MAX:
			best = step
	return best


# Controls already in the tree when UiScale starts: as the game starts from its main scene, Godot puts
# the autoloads and the main scene in the tree together and only then readies them, so "node_added"
# was missed for all of the scene (a scene changed to later, or a tool's, comes after).
func _take_present(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_take_present(child)


func _on_node_added(node: Node) -> void:
	if not node is Control:
		return
	if _pending.empty():
		call_deferred("_flush")
	_pending.append(node)


func _flush() -> void:
	var nodes: Array = _pending
	_pending = []
	for node in nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			_take(node)
			clamp_words(node)


# Keeps a control's words inside its button (see the header). Labels a container lays out are left
# to it: wrapped there, they would shrink to nothing.
static func clamp_words(control: Control) -> void:
	if control is Button:
		if not control.clip_text and (control.rect_min_size.x > 0.0 or control.size_flags_horizontal & Control.SIZE_EXPAND):
			if not _skipped(control):
				control.clip_text = true
		return
	if not control is Label or control.get_parent() is Container or _skipped(control):
		return
	var node: Node = control.get_parent()
	while node is Control and not node is Container:
		if node is BaseButton:
			control.autowrap = true
			control.clip_text = true
			return
		node = node.get_parent()


static func _skipped(control: Node) -> bool:
	var node: Node = control
	while node != null:
		if node.has_meta(SKIP):
			return true
		node = node.get_parent()
	return false


# Scales a control that came into the tree, if it is one of ours (again when it moves, or comes as
# a duplicate of a scaled one: _apply goes by its own record, so what is in place stays).
func _take(control: Control) -> void:
	var mode: String = _mode_of(control)
	if mode == "":
		return
	control.set_meta("_ui_mode", mode)
	control.add_to_group(GROUP)
	if control is TextureButton:
		_stretch_texture(control)
	_apply(control)


# A TextureButton drawn at its texture's own size (no expand) is made to stretch its texture over
# itself, sized at least as the texture: the same at 1.0, and its picture grows with it. Only where
# it is as large as its texture (else stretching would change how it looks at 1.0).
static func _stretch_texture(button: TextureButton) -> void:
	if button.expand or button.texture_normal == null or button.has_meta(BASE):
		return
	var size: Vector2 = button.texture_normal.get_size()
	var rect: Vector2 = button.rect_size
	if not (button.get_parent() is Container) and (abs(rect.x - size.x) > 0.5 or abs(rect.y - size.y) > 0.5):
		return
	button.rect_min_size = Vector2(max(button.rect_min_size.x, size.x), max(button.rect_min_size.y, size.y))
	button.expand = true
	button.stretch_mode = TextureButton.STRETCH_SCALE


# "layout" (under a LAYOUT), "button" (any other BaseButton) or "" (left as it is).
static func _mode_of(control: Control) -> String:
	var node: Node = control
	while node != null:
		if node.has_meta(SKIP):
			return ""
		if node.has_meta(LAYOUT):
			return "layout"
		node = node.get_parent()
	return "button" if control is BaseButton else ""


func _apply(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var mode: String = control.get_meta("_ui_mode")
	var in_container: bool = control.get_parent() is Container
	var now: Dictionary = _read(control, mode, in_container)
	var base: Dictionary = control.get_meta(BASE) if control.has_meta(BASE) else {}
	var done: Dictionary = control.get_meta(DONE) if control.has_meta(DONE) else {}
	for key in now:
		if not done.has(key) or done[key] != now[key]:
			base[key] = now[key]  # New, or set by its code since (at 1.0)
	var out: Dictionary = {}
	var by: float = factor_of(control)
	var across_only: bool = control.has_meta(AXES) and control.get_meta(AXES) == "x"
	var y_by: float = min(by, 1.0) if across_only else by  # Across only: its length grows no more, but shrinks with it
	out.rect_min_size = Vector2(base.rect_min_size.x * by, base.rect_min_size.y * y_by)
	if base.has("separation"):
		out.separation = int(round(base.separation * (y_by if control is VBoxContainer else by)))  # Constants are whole
	if not in_container:
		if mode == "layout":
			for margin in MARGINS:
				out[margin] = base[margin] * (y_by if margin in ["margin_top", "margin_bottom"] else by)
		else:
			_grow_from_anchor(base, out, "margin_left", "margin_right", control.anchor_left, control.anchor_right, by)
			_grow_from_anchor(base, out, "margin_top", "margin_bottom", control.anchor_top, control.anchor_bottom, by)
	control.set_meta(BASE, base)
	control.rect_min_size = out.rect_min_size
	if out.has("separation"):
		control.add_constant_override("separation", out.separation)
	for margin in MARGINS:
		if out.has(margin):
			control.set(margin, out[margin])
	control.set_meta(DONE, _read(control, mode, in_container))


# A button laid out by hand: its size on an axis it does not stretch on grows about the point its
# anchor names (left or top edge at 0, centre at 0.5, right or bottom edge at 1).
static func _grow_from_anchor(base: Dictionary, out: Dictionary, low: String, high: String, anchor_low: float, anchor_high: float, factor: float) -> void:
	if not is_equal_approx(anchor_low, anchor_high):
		return
	var size: float = base[high] - base[low]
	if size <= 0.0:
		return  # Sized by its min size alone
	var pivot: float = base[low] + size * anchor_low
	out[low] = pivot - size * factor * anchor_low
	out[high] = out[low] + size * factor


static func _read(control: Control, mode: String, in_container: bool) -> Dictionary:
	var values := {"rect_min_size": control.rect_min_size}
	if not in_container:
		for margin in MARGINS:
			values[margin] = control.get(margin)
	if mode == "layout" and control is BoxContainer:
		values.separation = control.get_constant("separation")
	return values
