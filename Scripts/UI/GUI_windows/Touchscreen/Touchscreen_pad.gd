extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")

onready var pad_base = ui_paths.touch_touch_pad_base
onready var stick = ui_paths.touch_touch_pad_stick
onready var stick_size_half = stick.get_texture().get_size()/2


func recenter_stick():
	# Recenter the joystic according to GUI to prevent jumping.
	# Those are stick positions on the pad base.
	GlobalInput.get_node("Touch_controls").pad_x_abs = pad_base.rect_size.x/2
	GlobalInput.get_node("Touch_controls").pad_y_abs = pad_base.rect_size.x/2

func handle_stick():
	# Process virtual stick input.
	if GameState.touchscreen_mode:
		if GlobalInput.stick_held:
			stick.position.x = GlobalInput.get_node("Touch_controls").pad_x_abs-stick_size_half.x
			stick.position.y = GlobalInput.get_node("Touch_controls").pad_y_abs-stick_size_half.y
		else:
			# Recenter stick.
			var stick_neutral_pos = pad_base.rect_size/2-stick_size_half
			if stick.position != stick_neutral_pos:
				stick.position = stick_neutral_pos
				
				# Reset stick input coords to prevent jumping.
				recenter_stick()
				GlobalInput.mouse_vector = Vector2(0,0)
