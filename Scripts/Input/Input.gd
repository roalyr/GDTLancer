extends Node

var LMB_held = false
var LMB_released = true

var stick_held = false
var throttle_held = false

var mouse_vector = Vector2(0,0)
var throttle_vector = 0

var viewport_size = Vector2(1,1)

onready var mouse = get_node("Mouse")
onready var keyboard = get_node("Keyboard")


func _ready():
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_quit_game", self, "is_quit_game")
	Signals.connect_checked("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================
	
	# Initial value require for the mouse coords.
	viewport_size = OS.window_size
	
func _input(event):
	
	# MOUSE INPUT HANDLING
	GlobalInput.get_node("Mouse").handle_input(event, viewport_size)
	
	# KEYBOARD INPUT HANDLING
	GlobalInput.get_node("Keyboard").handle_input(event)
		
	# PAD AND THROTTLE INPUT HANDLING
	if GameState.touchscreen_mode:
		GlobalInput.get_node("Touch_controls").handle_input(event)
				

# SIGNAL PROCESSING
func is_quit_game():
	get_tree().quit()
	
func is_viewport_update():
	# For mouse_vector normalized coords.
	viewport_size = OS.window_size
