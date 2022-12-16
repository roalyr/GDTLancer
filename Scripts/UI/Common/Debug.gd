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
