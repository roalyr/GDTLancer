# HudPips: ships the sensors see as small squares, hostile ones first in `hostile_color`, the rest
# in `color`; past `most` a "+" says there are more. Counted at a glance, no reading. Drawn; it
# takes no input.

extends Control

export var color: Color = Color(1, 1, 1, 0.7)
export var hostile_color: Color = Color(1, 0.2, 0.2, 1)
export var size_px: float = 10.0
export var gap: float = 5.0
export var most: int = 12

var counts: Array = [0, 0]  # [seen, of them hostile]


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_counts(seen: int, hostile: int, new_hostile_color: Color) -> void:
	if counts == [seen, hostile] and hostile_color == new_hostile_color:
		return
	counts = [seen, hostile]
	hostile_color = new_hostile_color
	update()


func _draw() -> void:
	var scale: float = UiScale.layout_factor  # Sizes are at UI scale 1.0: the HUD's
	var size: float = size_px * scale
	var step: float = (size_px + gap) * scale
	var shown: int = int(min(counts[0], most))
	var top: float = (rect_size.y - size) * 0.5
	for index in range(shown):
		var box := Rect2(index * step, top, size, size)
		if index < counts[1]:
			draw_rect(box, hostile_color)
		else:
			draw_rect(box, color, false, 1.5 * scale)
	if counts[0] > most:
		var font: Font = get_font("font", "Label")
		draw_string(font, Vector2(shown * step, (rect_size.y + font.get_ascent() - font.get_descent()) * 0.5), "+", color)
