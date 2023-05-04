extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")

#onready var throttle_base = ui_paths.touch_touch_throttle_base
#onready var throttle = ui_paths.touch_touch_throttle
#onready var throttle_size_half = throttle.get_texture().get_size()/2

#func recenter_throttle():
#	# Recenter the joystic according to GUI to prevent jumping.
#	GlobalInput.get_node("Touch_controls").throttle_y_abs = throttle_base.rect_size.x/2
#
#func handle_throttle():
#	# Process virtual throttle input.
#	if GameState.touchscreen_mode:
#		if GlobalInput.throttle_held:
#			throttle.position.y = GlobalInput.get_node("Touch_controls").throttle_y_abs-throttle_size_half.y
#		else:
#			# Recenter throttle.
#			var throttle_neutral_pos = throttle_base.rect_size/2-throttle_size_half
#			if throttle.position != throttle_neutral_pos:
#				throttle.position = throttle_neutral_pos
#
#				# Reset throttle input coords to prevent jumping.
#				recenter_throttle()
#				GlobalInput.throttle_vector = 0
