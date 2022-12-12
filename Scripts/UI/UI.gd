extends CanvasLayer

# TODO: Scalable UI (control panel, texts, buttons, etc).
# TODO: Grouping for overlapping markers.

# VARIABLES
var stick_held = false
var throttle_held = false
var turret_view = false
var update_debug_text_on = false
var ui_hidden = false
var ui_alpha = 1.0
var viewport_size = Vector2(1,1)
var debug_output_text = ""

onready var p = get_tree().get_root().get_node("Main/Paths")

# TODO: to paths
onready var apparent_velocity = p.ui.get_node("Gameplay/Apparent_velocity")
onready var apparent_velocity_c = p.ui.get_node("Gameplay/Apparent_velocity_c")
onready var apparent_velocity_units = p.ui.get_node("Gameplay/Apparent_velocity_units")


func _ready():
	p.ui_paths.common_touchscreen_pad.recenter_stick()
	p.ui_paths.common_touchscreen_throttle.recenter_throttle()
	p.ui_paths.ui_functions.init_gui()

	
	

	
func _process(_delta):
	p.ui_paths.common_touchscreen_pad.handle_stick()
	p.ui_paths.common_touchscreen_throttle.handle_throttle()
	
	# DEBUG
	if update_debug_text_on: update_debug_text()
	
	# READOUTS
	# Adjust displayed speed
	var speed_val = round(p.ship_state.apparent_velocity)
	var result_s = p.ui_paths.common_readouts.get_magnitude_units(speed_val)
	# To prevent from crashing on Nil
	if result_s:
		apparent_velocity.text = str(result_s[0])
		apparent_velocity_units.text = str(result_s[1])+"/s"
		apparent_velocity_c.text = "|  c: " + str(stepify(speed_val/p.common_constants.C, 0.1))
	p.ui_paths.gameplay.get_node("Accel_ticks").text = str("Accel: ", p.ship_state.accel_ticks)

# ================================== Other ====================================
# DEBUG
func update_debug_text():
	p.ui_paths.debug.get_node("FPS").text = str("FPS: ", p.main.fps)
	p.ui_paths.debug.get_node("Mouse_x").text = str("Mouse / Pad x: ", p.input.mouse_vector.x)
	p.ui_paths.debug.get_node("Mouse_y").text = str("Mouse / Pad y: ", p.input.mouse_vector.y)
	p.ui_paths.debug.get_node("Throttle").text = str("Throttle: ", p.input.throttle_vector)
	p.ui_paths.debug.get_node("Print_out").text = str("Output: ", debug_output_text)
	
