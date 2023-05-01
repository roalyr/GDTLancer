extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")
onready var ui = get_node("/root/Main/UI")

const throttle_deadzone = 0.5

# VARIABLES
var pad_x_abs = 0
var pad_y_abs = 0
var throttle_y_abs = 0
#var acceleration_delay = true

var on_controls_area = false

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_mouse_on_control_area", self, "is_mouse_on_control_area")
	# ========================================================================

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
	var fx = GameState.ui_scale.x
	var fy = GameState.ui_scale.y
	
	# Process drag events (pad and throttle).
	if event is InputEventScreenDrag:

		if ((event.position.x < GameState.window_width*fx/2) and not GameState.touchscreen_controls_swapped and on_controls_area)\
			or ((event.position.x > GameState.window_width*fx/2) and GameState.touchscreen_controls_swapped and on_controls_area):
			
			if event.relative.length() > 0:
				GlobalInput.stick_held = true
			else:
				GlobalInput.stick_held = false
			
			pad_x_abs = (event.position.x-GameState.touch_touch_pad_base_rect_position.x*fx)/fx
			pad_y_abs = (event.position.y-GameState.touch_touch_pad_base_rect_position.y*fy)/fy

			var pad_x = clamp(((pad_x_abs-GameState.touch_touch_pad_base_rect_size.x/2) \
				/ GameState.touch_touch_pad_base_rect_size.x*2), -1, 1)
			var pad_y = clamp(((pad_y_abs-GameState.touch_touch_pad_base_rect_size.y/2) \
				/ GameState.touch_touch_pad_base_rect_size.y*2), -1, 1)
			GlobalInput.mouse_vector = Vector2(pad_x, pad_y) 
		
		elif ((event.position.x > GameState.window_width*fx/2) and not GameState.touchscreen_controls_swapped and on_controls_area)\
			or ((event.position.x < GameState.window_width*fx/2) and GameState.touchscreen_controls_swapped and on_controls_area):
			
			if event.relative.length() > 0:
				GlobalInput.throttle_held = true
			else:
				GlobalInput.throttle_held = false
				
			
			throttle_y_abs = (event.position.y-GameState.touch_touch_throttle_base_rect_position.y*fy)/fy
			var throttle_y = clamp(((throttle_y_abs-GameState.touch_touch_throttle_base_rect_size.y/2) \
				/ GameState.touch_touch_throttle_base_rect_size.y*2), -1, 1)
			
			# Reverse it for proper alignment.
			GlobalInput.throttle_vector = -throttle_y

	# Process touches and unpressed touches.
	if event is InputEventScreenTouch:

		# Keep a track of only this input.
		var index = event.index

		# Prevent the case of triple+ touch.
		if index >= 2:
			pass
			
		# Release the controls when finger is removed.
		if ((event.position.x < GameState.window_width*fx/2) and not GameState.touchscreen_controls_swapped and not event.is_pressed())\
			or ((event.position.x > GameState.window_width*fx/2) and GameState.touchscreen_controls_swapped and not event.is_pressed()):
			GlobalInput.stick_held = false
			
		if ((event.position.x > GameState.window_width*fx/2) and not GameState.touchscreen_controls_swapped and not event.is_pressed())\
			or ((event.position.x < GameState.window_width*fx/2) and GameState.touchscreen_controls_swapped and not event.is_pressed()):
			GlobalInput.throttle_held = false
			
func is_mouse_on_control_area(flag):
	if flag:
		on_controls_area = true
	else:
		on_controls_area = false
