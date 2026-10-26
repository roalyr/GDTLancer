# Announcements: short HUD messages (dock and attack feedback, warnings) as labels instead of
# windows. Each sits on a flat 25% black strip (the HUD button style), coloured by how much attention
# it needs (Constants ANNOUNCE_COLORS: info, warning, danger), holds for ANNOUNCE_HOLD seconds and
# fades out over ANNOUNCE_FADE. A new one takes the slot at ANNOUNCE_ANCHOR and pushes the older ones
# up, just enough to fit, where they keep fading; at most ANNOUNCE_MAX show, the oldest dropped
# first. The same message again while it still shows starts it over instead of stacking.
# Drawn above the other HUD panels; clicks pass through (mouse_filter ignore).

extends Control

var _entries: Array = []  # [{"panel", "label", "age", "y"}], newest first


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	pause_mode = Node.PAUSE_MODE_PROCESS
	theme = preload("res://assets/themes/main_theme.tres")  # The HUD's font


# `level`: "info", "warning" or "danger".
func announce(message: String, level: String = "info") -> void:
	raise()  # Above the HUD's panels (the station's too)
	for entry in _entries:
		if entry.label.text == message:
			entry.age = 0.0
			entry.label.add_color_override("font_color", _color(level))
			_entries.erase(entry)
			_entries.push_front(entry)
			return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.content_margin_left = Constants.ANNOUNCE_PADDING.x
	style.content_margin_right = Constants.ANNOUNCE_PADDING.x
	style.content_margin_top = Constants.ANNOUNCE_PADDING.y
	style.content_margin_bottom = Constants.ANNOUNCE_PADDING.y
	panel.add_stylebox_override("panel", style)
	var label := Label.new()
	label.text = message
	label.align = Label.ALIGN_CENTER
	label.autowrap = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_color_override("font_color", _color(level))
	panel.add_child(label)
	add_child(panel)
	var entry := {"panel": panel, "label": label, "age": 0.0, "y": INF}
	_entries.push_front(entry)
	while _entries.size() > Constants.ANNOUNCE_MAX:
		var oldest: Dictionary = _entries.pop_back()
		oldest.panel.queue_free()
	_layout(0.0)


func _process(delta: float) -> void:
	if _entries.empty():
		return
	for entry in _entries.duplicate():
		entry.age += delta
		var fade: float = clamp((entry.age - Constants.ANNOUNCE_HOLD) / Constants.ANNOUNCE_FADE, 0.0, 1.0)
		entry.panel.modulate.a = 1.0 - fade
		if fade >= 1.0:
			entry.panel.queue_free()
			_entries.erase(entry)
	_layout(delta)


# Newest at the anchor, each older one just above the one after it; they slide to their places.
func _layout(delta: float) -> void:
	var bottom: float = rect_size.y * Constants.ANNOUNCE_ANCHOR
	for entry in _entries:
		var size: Vector2 = entry.panel.get_combined_minimum_size()
		var target: float = bottom - size.y
		if entry.y == INF:
			entry.y = target  # New: straight into the slot
		else:
			entry.y = lerp(entry.y, target, clamp(delta * Constants.ANNOUNCE_SLIDE_RATE, 0.0, 1.0))
		entry.panel.rect_size = size
		entry.panel.rect_position = Vector2((rect_size.x - size.x) * 0.5, entry.y)
		bottom = target - Constants.ANNOUNCE_GAP


static func _color(level: String) -> Color:
	return Constants.ANNOUNCE_COLORS.get(level, Constants.ANNOUNCE_COLORS.info)
