# File: scenes/game_world/world_rendering.gd
# Version: 1.0 - Handles rendering options for viewport as a whole.

extends Node

var viewport_downscale_factor = 1
var viewport_msaa = Viewport.MSAA_DISABLED
var viewport_fxaa = true
var viewport_disable_3d = false


var _viewport_size = Vector2(1920, 1080)
var _prev_viewport_size = Vector2(1920, 1080)

func _ready():
	get_viewport().msaa = viewport_msaa
	get_viewport().fxaa = viewport_fxaa
	get_viewport().disable_3d = viewport_disable_3d
	print("Viewport: Is ready")

func _process(delta):
	# Handle each option via signal instead maybe.
	
	_viewport_size = get_viewport().size 
	if _viewport_size != _prev_viewport_size:
		get_viewport().size = _viewport_size / viewport_downscale_factor
		_prev_viewport_size = get_viewport().size
		print(_viewport_size)
