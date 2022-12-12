extends Node

# VARIABLES
onready var p = get_tree().get_root().get_node("Main/Paths")
onready var pad_base = p.ui_paths.touch_FHD_touch_pad_base
onready var stick = p.ui_paths.touch_FHD_touch_pad_stick

func recenter_stick():
	# Recenter the joystic according to GUI to prevent jumping.
	p.input_pad.pad_x_abs = pad_base.rect_size.x/2
	p.input_pad.pad_y_abs = pad_base.rect_size.x/2

func handle_stick():
	# Process virtual stick input.
	if p.common_game_options.touchscreen_mode:
		if p.ui.stick_held:
			stick.position.x = p.input_pad.pad_x_abs-100
			stick.position.y = p.input_pad.pad_y_abs-100
		else:
			# Recenter stick.
			if stick.position != Vector2(70,70):
				stick.position = Vector2(
					pad_base.rect_size.x/2-100,
					pad_base.rect_size.y/2-100
				)
				# Reset stick input coords to prevent jumping.
				p.input_pad.pad_x_abs = pad_base.rect_size.x/2
				p.input_pad.pad_y_abs = pad_base.rect_size.y/2
				p.input.mouse_vector = Vector2(0,0)
