extends Node

onready var p = get_tree().get_root().get_node("Main/Paths")

# This is the actual data, without additional formatting.
var debug_output_text = ""

var fps = ""
var mouse_x = ""
var mouse_y = ""
var throttle = ""
var print_out = ""

func update_debug_text():
	fps = str("FPS: ", p.main.fps)
	mouse_x = str("Mouse / Pad x: ", p.input.mouse_vector.x)
	mouse_y = str("Mouse / Pad y: ", p.input.mouse_vector.y)
	throttle = str("Throttle: ", p.input.throttle_vector)
	print_out = str("Output: ", debug_output_text)
	
	if p.common_game_options.touchscreen_mode:
		p.ui_paths.touch_readings_debug.get_node("FPS").text = fps
		p.ui_paths.touch_readings_debug.get_node("Mouse_x").text = mouse_x
		p.ui_paths.touch_readings_debug.get_node("Mouse_y").text = mouse_y
		p.ui_paths.touch_readings_debug.get_node("Throttle").text = throttle
		p.ui_paths.touch_readings_debug.get_node("Print_out").text = print_out
	else:
		p.ui_paths.desktop_readings_debug.get_node("FPS").text = fps
		p.ui_paths.desktop_readings_debug.get_node("Mouse_x").text = mouse_x
		p.ui_paths.desktop_readings_debug.get_node("Mouse_y").text = mouse_y
		p.ui_paths.desktop_readings_debug.get_node("Throttle").text = throttle
		p.ui_paths.desktop_readings_debug.get_node("Print_out").text = print_out
