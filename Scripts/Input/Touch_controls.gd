extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")
onready var ui = get_node("/root/Main/UI")

const throttle_deadzone = 0.5
const stick_distance_factor = 3

# VARIABLES
var pad_x_abs = 0
var pad_y_abs = 0
var drag_index = 0

var on_controls_area = false
var stick_dragged = false


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
	
			
	if event is InputEventScreenDrag:
		# Get the absolute event relative position.
		pad_x_abs = (event.position.x-GameState.touch_touch_pad_base_rect_position.x*fx)/fx
		pad_y_abs = (event.position.y-GameState.touch_touch_pad_base_rect_position.y*fy)/fy
		
		# Get factored values to deternine whether the event is within the threshold.
		var pad_xf = clamp(((pad_x_abs-GameState.touch_touch_pad_base_rect_size.x/2) \
			/ GameState.touch_touch_pad_base_rect_size.x*2), -stick_distance_factor, stick_distance_factor)
		var pad_yf = clamp(((pad_y_abs-GameState.touch_touch_pad_base_rect_size.y/2) \
			/ GameState.touch_touch_pad_base_rect_size.y*2), -stick_distance_factor, stick_distance_factor)
		
		var distance = Vector2(pad_xf, pad_yf).length()
		
		if distance < stick_distance_factor and GlobalInput.stick_held and on_controls_area:

			var pad_x = clamp(pad_xf, -1, 1)
			var pad_y = clamp(pad_yf, -1, 1)
			GlobalInput.mouse_vector = Vector2(pad_x, pad_y)

			
			
func is_mouse_on_control_area(flag):
	if flag:
		on_controls_area = true
	else:
		on_controls_area = false
