extends CanvasLayer

onready var ui_paths = get_node("/root/Main/UI_paths")

# TODO: Scalable UI (control panel, texts, buttons, etc).
# TODO: Grouping for overlapping markers.

# COMMON VARIABLES
var ui_hidden = false
var ui_alpha = 1.0

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_language_selected", self, "is_language_selected")
	# =========================================================================

	# TRANSLATION INIT
	TranslationServer.set_locale(GameOptions.current_locale)
	print(tr("TEST_LOCALE_LOADED"))
	
	# INITIATE GUI
	ui_paths.ui_functions.init_gui()

	
func _process(_delta):
	if GameState.touchscreen_mode:
		ui_paths.common_touchscreen_pad.handle_stick()
		#ui_paths.common_touchscreen_throttle.handle_throttle()
	
	# DEBUG
	if GameState.update_debug_text_on: ui_paths.common_debug.update_debug_text()
	
	# READOUTS
	# Adjust displayed speed
	var speed_val = round(PlayerState.ship_linear_velocity)
	var result_s = ui_paths.common_readouts.get_magnitude_units(speed_val)
	# To prevent from crashing on Nil
	if result_s:
		var vel = str(result_s[0]).pad_decimals(3).left(5)
		var units = str(result_s[1])
		ui_paths.common_readouts.apparent_velocity = " V: " + vel
		ui_paths.common_readouts.apparent_velocity_units = units + " / s"
		
	ui_paths.common_readouts.accel_ticks = str(" A: ", PlayerState.accel_ticks)

func is_language_selected(index):
	# English
	if index == 0:
		GameOptions.current_locale = GameOptions.game_locale_0
		TranslationServer.set_locale(GameOptions.current_locale)
		# warning-ignore:return_value_discarded
		get_tree().reload_current_scene()

	# Ukrainian
	elif index == 1:
		GameOptions.current_locale = GameOptions.game_locale_1
		TranslationServer.set_locale(GameOptions.current_locale)
		# warning-ignore:return_value_discarded
		get_tree().reload_current_scene()
