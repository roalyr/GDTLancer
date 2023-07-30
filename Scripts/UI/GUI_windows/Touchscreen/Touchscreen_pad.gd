extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")

onready var pad_base = ui_paths.touch_touch_pad_base
onready var stick = ui_paths.touch_touch_pad_stick
onready var stick_position_init = stick.position


func recenter_stick():
	stick.position = stick_position_init
	GlobalInput.mouse_vector = Vector2(0,0)


func handle_stick():
	# Process virtual stick input.
	if GameState.touchscreen_mode:
		if GlobalInput.stick_held:
			stick.position = GlobalInput.mouse_vector*pad_base.rect_size/2+stick_position_init
		else:
			if stick.position != stick_position_init:
				recenter_stick()

