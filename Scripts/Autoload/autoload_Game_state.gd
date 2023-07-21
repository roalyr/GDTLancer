extends Node

# UI
var window_height = 1
var window_width = 1
var ui_alpha = 1.0
var ui_scale = Vector2(1,1)
var ui_reverse_scale = Vector2(1,1)
var touch_touch_pad_base_rect_position = Vector2(0,0)
var touch_touch_pad_base_rect_size = Vector2(0,0)
var touch_touch_throttle_base_rect_position = Vector2(0,0)
var touch_touch_throttle_base_rect_size = Vector2(0,0)
var touchscreen_controls_swapped = false
var update_debug_text_on = false
var debug_output_text = ""

# GAME STATE
var game_started = false
var game_paused = false

# temp
var player_hidden = false

# CONTROLS
var touchscreen_mode = false
var turret_view = false

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_game_paused", self, "is_game_paused")
	Signals.connect_checked("sig_game_started", self, "is_game_started")
	# =========================================================================

	# FPS INIT
	Engine.set_iterations_per_second(Constants.physics_fps)
	Engine.set_target_fps(Constants.graphic_fps)

func debug(out):
	debug_output_text += str(out)
	debug_output_text += "\n"
	
func is_game_paused(flag):
	if flag:
		game_paused = true
	else:
		game_paused = false
	GameState.debug("Game paused: " + str(game_paused))
		

func is_game_started(flag):
	if flag:
		game_started = true
	else:
		game_started = false
	GameState.debug("Game started: " + str(game_started))
