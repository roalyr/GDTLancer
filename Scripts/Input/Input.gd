extends Node

var LMB_held = false
var LMB_released = true

var mouse_vector = Vector2(0,0)
var viewport_size = Vector2(1,1)

onready var mouse = get_node("Mouse")
onready var keyboard = get_node("Keyboard")
onready var pad = get_node("Pad")
onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# ============================ Connect signals ============================
	p.signals.connect("sig_quit_game", self, "is_quit_game")
	p.signals.connect("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================
	
	# Initial value require for the mouse coords.
	viewport_size = OS.window_size
	
func _input(event):
	
	# MOUSE INPUT HANDLING
	p.input_mouse.handle_input(event, viewport_size)
	
	# KEYBOARD INPUT HANDLING
	p.input_keyboard.handle_input(event)
		
	# PAD INPUT HANDLING
	p.input_pad.handle_input(event)
				

# SIGNAL PROCESSING
func is_quit_game():
	get_tree().quit()
	
func is_viewport_update():
	# For mouse_vector normalized coords.
	viewport_size = OS.window_size
