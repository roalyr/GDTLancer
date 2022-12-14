extends Node

# VARIABLES
onready var p = get_tree().get_root().get_node("Main/Paths")
onready var throttle_base = p.ui_paths.touch_FHD_touch_throttle_base
onready var throttle = p.ui_paths.touch_FHD_touch_throttle

func recenter_throttle():
	# Recenter the joystic according to GUI to prevent jumping.
	p.input_touch_controls.throttle_y_abs = throttle_base.rect_size.x/2

func handle_throttle():
	# Process virtual throttle input.
	if p.common_game_options.touchscreen_mode:
		if p.ui.throttle_held:
			throttle.position.y = p.input_touch_controls.throttle_y_abs-100
		else:
			# Recenter throttle.
			if throttle.position != Vector2(100, 100):
				throttle.position.x = 100
				throttle.position.y = throttle_base.rect_size.y/2-100
				
				# Reset throttle input coords to prevent jumping.
				p.input_touch_controls.throttle_y_abs = throttle_base.rect_size.y/2
				p.input.throttle_vector = 0
