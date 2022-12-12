extends Node

# VARIABLES
var throttle_y_abs = 0


onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	pass # Replace with function body.

func handle_input(event):

	# =================== For events on touchscreen stick held ===================
	if p.ui.throttle_held:
		# Track the mouse position in +/-1, +/-1 throttle base coordinates.
		if event is InputEventScreenDrag:
			p.ui.debug_output_text = event.index
			
			throttle_y_abs = event.position.y-p.ui_paths.touch_FHD_touch_throttle_base.rect_position.y
			var throttle_y = clamp(((throttle_y_abs-p.ui_paths.touch_FHD_touch_throttle_base.rect_size.y/2) \
				/ p.ui_paths.touch_FHD_touch_throttle_base.rect_size.y*2), -1, 1)
			p.input.throttle_vector = throttle_y
			# TODO: rename mouse vector to throttle vector.
			
#		# Mouse button held check. LMB_released is to reduce calls number.
#		if InputEventScreenTouch.pressed and p.input.LMB_released:
#			p.input.LMB_released = false
#			p.input.LMB_held = true
#
#		# Mouse button released check. LMB_released is to reduce calls number.
#		if not InputEventScreenTouch.pressed and not p.input.LMB_released:
#			p.input.LMB_released = true
#			p.input.LMB_held = false
