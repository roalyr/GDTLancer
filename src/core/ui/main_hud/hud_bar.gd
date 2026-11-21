# HudBar: a thin horizontal bar with its caption before it (the awareness zone's hull, energy and
# cargo; the target's hull). `value` 0..1 fills it in `color`; below `low_share` it takes
# `low_color`. With `flash_on_drop`, a fall turns the fill `flash_color` at once, cooling back to its
# own colour over HUD_BAR_FLASH_TIME s (the player's hull: the moment of a hit). Drawn, no textures;
# it takes no input.

tool
extends Control

export var caption: String = "" setget _set_caption
export var color: Color = Color(1, 1, 1, 0.85) setget _set_color
export var low_color: Color = Color(1.0, 0.3, 0.15, 1.0)
export var low_share: float = 0.0  # Below this the bar turns low_color (0: never)
export var bar_height: float = 8.0
export var caption_width: float = 0.0  # px kept for the caption (0: none)
export var flash_on_drop: bool = false  # A fall flashes the fill flash_color, fading back
export var flash_color: Color = Color(1.0, 0.22, 0.12, 1.0)

var value: float = 1.0 setget set_value
var flash: float = 0.0  # 1 just after a fall, down to 0 over HUD_BAR_FLASH_TIME


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


func set_value(new_value: float) -> void:
	new_value = clamp(new_value, 0.0, 1.0)
	if abs(new_value - value) < 0.002:
		return
	if flash_on_drop and new_value < value and not Engine.editor_hint:
		flash = 1.0
		set_process(true)
	value = new_value
	update()


func _process(delta: float) -> void:
	flash = max(0.0, flash - delta / max(Constants.HUD_BAR_FLASH_TIME, 0.01))
	if flash <= 0.0:
		set_process(false)
	update()


# The fill's colour now: its own (or low_color when low), toward flash_color while flashing.
func fill_color() -> Color:
	var base: Color = low_color if low_share > 0.0 and value < low_share else color
	return base.linear_interpolate(flash_color, flash * flash) if flash > 0.0 else base  # Red at once, cooling quickly then slowly


func _set_caption(text: String) -> void:
	caption = text
	update()


func _set_color(new_color: Color) -> void:
	color = new_color
	update()


func _draw() -> void:
	var font: Font = get_font("font", "Label")
	var x: float = 0.0
	if caption != "" and caption_width > 0.0:
		var baseline: float = (rect_size.y + font.get_ascent() - font.get_descent()) * 0.5
		draw_string(font, Vector2(0, baseline), caption, Color(1, 1, 1, color.a))
		x = caption_width
	var width: float = max(0.0, rect_size.x - x)
	var top: float = (rect_size.y - bar_height) * 0.5
	draw_rect(Rect2(x, top, width, bar_height), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(x, top, width * value, bar_height), fill_color())
