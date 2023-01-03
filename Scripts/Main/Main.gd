extends Node

var fps = 0

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_language_selected", self, "is_language_selected")
	# =========================================================================

	TranslationServer.set_locale(GameOptions.current_locale)
	print(tr("TEST_LOCALE_LOADED"))

# TODO: need to work on autoload + scene reload to apply translations by restart.
func is_language_selected(index):
	# English
	if index == 0:
		GameOptions.current_locale = GameOptions.game_locale_0
		TranslationServer.set_locale(GameOptions.current_locale)
		get_tree().reload_current_scene()

	# Ukrainian
	elif index == 1:
		GameOptions.current_locale = GameOptions.game_locale_1
		TranslationServer.set_locale(GameOptions.current_locale)
		get_tree().reload_current_scene()

func _process(_delta):
	fps = Engine.get_frames_per_second()
