extends Node


# This is the actual data, without additional formatting.
var debug_output_text = ""

var fps = ""
var mouse_x = ""
var mouse_y = ""
var throttle = ""
var print_out = ""

func update_debug_text():
	#fps = str("FPS: ", p.main.fps)
#
#func _process(_delta):
#	fps = Engine.get_frames_per_second()
	
	mouse_x = str("Mouse / Pad x: ", GlobalInput.mouse_vector.x)
	mouse_y = str("Mouse / Pad y: ", GlobalInput.mouse_vector.y)
	throttle = str("Throttle: ", GlobalInput.throttle_vector)
	print_out = str("Output: ", debug_output_text)
	
	if GameOptions.touchscreen_mode:
		#UiPaths.touch_readings_debug.get_node("FPS").text = fps
		UiPaths.touch_readings_debug.get_node("Mouse_x").text = mouse_x
		UiPaths.touch_readings_debug.get_node("Mouse_y").text = mouse_y
		UiPaths.touch_readings_debug.get_node("Throttle").text = throttle
		UiPaths.touch_readings_debug.get_node("Print_out").text = print_out
	else:
		#UiPaths.desktop_readings_debug.get_node("FPS").text = fps
		UiPaths.desktop_readings_debug.get_node("Mouse_x").text = mouse_x
		UiPaths.desktop_readings_debug.get_node("Mouse_y").text = mouse_y
		UiPaths.desktop_readings_debug.get_node("Throttle").text = throttle
		UiPaths.desktop_readings_debug.get_node("Print_out").text = print_out
