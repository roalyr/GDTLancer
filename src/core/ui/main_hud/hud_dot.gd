# HudDot: what is left of the HUD while it is hidden (MainHUD.toggle_hud, the eye button): a faint
# small dot where the eye button was, the size of the icon's iris. Its whole button-sized square
# takes the tap (a fingertip finds it), and a tap brings the HUD back.

extends TextureButton  # With no texture it draws nothing of its own (BaseButton cannot be made)

const RADIUS_SHARE = 0.08  # Of the button's width: the eye icon's iris (button_ui_opacity.png)
const COLOR = Color(1, 1, 1, 0.3)


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	draw_circle(rect_size * 0.5, rect_size.x * RADIUS_SHARE, COLOR)
