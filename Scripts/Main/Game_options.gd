extends Node

# GAME STATE
var game_started = false

# LANGUAGE
var game_locale_0 = "en"
var game_locale_1 = "uk"

# CONTROLS
var touchscreen_mode = false

# CAMERA
var camera_inertia_factor = 1.1 # 1.05 ... 1.5 Affects camera inertia.
var camera_sensitivity = 1.5

# VIEWPORT
var render_res_factor = 1.0
var render_texture_filter = true

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_language_selected", self, "is_language_selected")
	# =========================================================================

	TranslationServer.set_locale(game_locale_0)
	print(tr("TEST_LOCALE_LOADED"))

# TODO: need to work on autoload + scene reload to apply translations by restart.
func is_language_selected(index):
	# English
	if index == 0:
		TranslationServer.set_locale(game_locale_0)

	# Ukrainian
	elif index == 1:
		TranslationServer.set_locale(game_locale_1)

