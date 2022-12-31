extends Node

# LANGUAGE
var game_locale = "uk"

# CONTROLS
var touchscreen_mode = false

# CAMERA
var camera_inertia_factor = 1.1 # 1.05 ... 1.5 Affects camera inertia.
var camera_sensitivity = 1.5

# VIEWPORT
var render_res_factor = 1.0
var render_texture_filter = true

func _ready():
	TranslationServer.set_locale(game_locale)
	print(tr("TEST_LOCALE_LOADED"))
