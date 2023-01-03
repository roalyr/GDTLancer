extends Node

# VARIABLES
onready var p = get_tree().get_root().get_node("Main/Paths")
onready var pad_base = p.ui_paths.touch_touch_pad_base
onready var stick = p.ui_paths.touch_touch_pad_stick
onready var stick_size_half = stick.get_texture().get_size()/2


func recenter_stick():
	# Recenter the joystic according to GUI to prevent jumping.
	# Those are stick positions on the pad base.
	p.input_touch_controls.pad_x_abs = pad_base.rect_size.x/2
	p.input_touch_controls.pad_y_abs = pad_base.rect_size.x/2

func handle_stick():
	# Process virtual stick input.
	if GameOptions.touchscreen_mode:
		if p.ui.stick_held:
			stick.position.x = p.input_touch_controls.pad_x_abs-stick_size_half.x
			stick.position.y = p.input_touch_controls.pad_y_abs-stick_size_half.y
		else:
			# Recenter stick.
			var stick_neutral_pos = pad_base.rect_size/2-stick_size_half
			if stick.position != stick_neutral_pos:
				stick.position = stick_neutral_pos
				
				# Reset stick input coords to prevent jumping.
				recenter_stick()
				p.input.mouse_vector = Vector2(0,0)
