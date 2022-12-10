extends Node

# VARIABLES
var pad_x_abs = 0
var pad_y_abs = 0

var LMB_held = false
var LMB_released = true

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	pass # Replace with function body.

func handle_input(event):
	# =================== For events on touchscreen stick held ===================
	if p.ui.stick_held:
		# Track the mouse position in +/-1, +/-1 Pad base coordinates.
		if event is InputEventMouseMotion:
			pad_x_abs = event.global_position.x-p.ui_paths.touchscreen_pad_base.rect_position.x
			pad_y_abs = event.global_position.y-p.ui_paths.touchscreen_pad_base.rect_position.y
			var pad_x = clamp(((pad_x_abs-p.ui_paths.touchscreen_pad_base.rect_size.x/2) \
				/ p.ui_paths.touchscreen_pad_base.rect_size.x*2), -1, 1)
			var pad_y = clamp(((pad_y_abs-p.ui_paths.touchscreen_pad_base.rect_size.y/2) \
				/ p.ui_paths.touchscreen_pad_base.rect_size.y*2), -1, 1)
			p.input.mouse_vector = Vector2(pad_x, pad_y) 
			# TODO: rename mouse vector to joystick vector.
			
		# Mouse button held check. LMB_released is to reduce calls number.
		if Input.is_mouse_button_pressed(BUTTON_LEFT) and p.input.LMB_released:
			p.input.LMB_released = false
			p.input.LMB_held = true
		
		# Mouse button released check. LMB_released is to reduce calls number.
		if not Input.is_mouse_button_pressed(BUTTON_LEFT) and not p.input.LMB_released:
			p.input.LMB_released = true
			p.input.LMB_held = false
