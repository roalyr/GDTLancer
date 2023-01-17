extends Node

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_language_selected", self, "is_language_selected")
	Signals.connect_checked("sig_game_paused", self, "is_game_paused")
	# =========================================================================

	# TRANSLATION INIT
	TranslationServer.set_locale(GameOptions.current_locale)
	print(tr("TEST_LOCALE_LOADED"))

	# FPS INIT
	Engine.set_iterations_per_second(Constants.physics_fps)
	Engine.set_target_fps(Constants.graphic_fps)
	
	# Start paused.
	Signals.emit_signal("sig_game_paused", true)


# TODO: need to work on autoload + scene reload to apply translations by restart.
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

func is_game_paused(flag):
	if flag:
		GameState.game_paused = true
	else:
		GameState.game_paused = false
	print("Game paused: ", GameState.game_paused)
	
