extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")
onready var ui = get_node("/root/Main/UI")

const throttle_deadzone = 0.5

# VARIABLES
var pad_x_abs = 0
var pad_y_abs = 0
var throttle_y_abs = 0
#var acceleration_delay = true

var current_pad_touch_index = 0
var current_throttle_touch_index = 1


func _physics_process(_delta):
	# Skip if not adjusting throttle.
	if GlobalInput.throttle_vector == 0:
		pass
		
	# Process throttle value.
	if GlobalInput.throttle_vector > throttle_deadzone:
		Signals.emit_signal("sig_accelerate", true)
	elif GlobalInput.throttle_vector < -throttle_deadzone:
		Signals.emit_signal("sig_accelerate", false)
	else:
		pass


func handle_input(event):
	# Make sure we start reading the drag position after control is held.
	if event is InputEventScreenTouch and (GlobalInput.stick_held or GlobalInput.throttle_held):
		
		# Keep a track of only this input.
		var index = event.index
		
		# Prevent the case of triple+ touch.
		if index >= 2:
			pass
		
		# See which control was touched first so as to expect the other one.
		if GlobalInput.stick_held and not GlobalInput.throttle_held:
			# Stick touched first.
			current_pad_touch_index = 0
			current_throttle_touch_index = 1
		elif not GlobalInput.stick_held and GlobalInput.throttle_held:
			# Throttle touched first.
			current_pad_touch_index = 1
			current_throttle_touch_index = 0
		else:
			pass
		
	if event is InputEventScreenDrag:
		
		# Keep a track of only this input.
		var index = event.index
		
		var fx = GameState.ui_scale.x
		var fy = GameState.ui_scale.y
		
		# Now dynamically re-assign each index depending on situation.
		# This should work because they are always different (0 and 1).
		if index == current_pad_touch_index and GlobalInput.stick_held:
			# TODO: pad x movement when scaling.
			
			pad_x_abs = (event.position.x-GameState.touch_touch_pad_base_rect_position.x*fx)/fx
			pad_y_abs = (event.position.y-GameState.touch_touch_pad_base_rect_position.y*fy)/fy

			var pad_x = clamp(((pad_x_abs-GameState.touch_touch_pad_base_rect_size.x/2) \
				/ GameState.touch_touch_pad_base_rect_size.x*2), -1, 1)
			var pad_y = clamp(((pad_y_abs-GameState.touch_touch_pad_base_rect_size.y/2) \
				/ GameState.touch_touch_pad_base_rect_size.y*2), -1, 1)
			GlobalInput.mouse_vector = Vector2(pad_x, pad_y) 
		
		elif index == current_throttle_touch_index and GlobalInput.throttle_held:
			throttle_y_abs = (event.position.y-GameState.touch_touch_throttle_base_rect_position.y*fy)/fy
			var throttle_y = clamp(((throttle_y_abs-GameState.touch_touch_throttle_base_rect_size.y/2) \
				/ GameState.touch_touch_throttle_base_rect_size.y*2), -1, 1)
			
			# Reverse it for proper alignment.
			GlobalInput.throttle_vector = -throttle_y

