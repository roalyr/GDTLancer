extends Node

# VARIABLES
var mouse_x = 0
var mouse_y = 0
var mouse_x_abs = 0
var mouse_y_abs = 0

var mouse_on_control_area = true

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# ============================ Connect signals ============================
	p.signals.connect("sig_mouse_on_control_area", self, "is_mouse_on_control_area")
	# =========================================================================

func handle_input(event, viewport_size):
	
	# This ensures that desktop UI is enabled and mouse is on control area, not UI
	# (TODO: Overlay UI pads on top of the control area to reserve those areas?)
	if mouse_on_control_area and p.ui_paths.mouse_area.visible:
		
		# Track mouse position.
		if event is InputEventMouseMotion:
			mouse_x_abs = event.global_position.x
			mouse_y_abs = event.global_position.y
			mouse_x = clamp(((mouse_x_abs-viewport_size.x/2) \
				/ viewport_size.x*2), -1, 1)
			mouse_y = clamp(((mouse_y_abs-viewport_size.y/2) \
				/ viewport_size.y*2), -1, 1)
			p.input.mouse_vector = Vector2(mouse_x, mouse_y)
		
		# Mouse button held check. LMB_released is to reduce calls number.
		if Input.is_mouse_button_pressed(BUTTON_LEFT) and p.input.LMB_released:
			p.input.LMB_released = false
			p.input.LMB_held = true
		
		# Mouse button released check. LMB_released is to reduce calls number.
		if not Input.is_mouse_button_pressed(BUTTON_LEFT) and not p.input.LMB_released:
			p.input.LMB_released = true
			p.input.LMB_held = false
		
		# Camera zoom. Pass event in order to check for mouse wheel scroll.
		if event is InputEventMouseButton and p.ship_state.turret_mode:
			p.camera_rig.zoom_camera(event)



# SIGNAL PROCESSING
# Check if we are hovering mouse over the control area in desktop mode.
func is_mouse_on_control_area(flag):
	if flag: mouse_on_control_area = true
	else: mouse_on_control_area = false
