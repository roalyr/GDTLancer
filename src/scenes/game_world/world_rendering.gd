# WorldRendering: viewport and rendering settings, plus HUD/jump presentation toggles.

extends Node

# This is a section that holds rendering settings.
var viewport_downscale_factor = 1.0
var viewport_msaa = Viewport.MSAA_DISABLED
var viewport_fxaa = false
var viewport_disable_3d = false
var viewport_sharpen_intensity = 0.5
var viewport_keep_3d_linear = false
var projected_target_center_fade_enabled = true
var jump_transition_enabled = true


var _viewport_size = Vector2(1920, 1080)
var _prev_viewport_size = Vector2(1920, 1080)

func _ready():
	get_viewport().msaa = viewport_msaa
	get_viewport().fxaa = viewport_fxaa
	get_viewport().disable_3d = viewport_disable_3d
	get_viewport().sharpen_intensity = viewport_sharpen_intensity
	get_viewport().keep_3d_linear = viewport_keep_3d_linear
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Viewport: Is ready")

func _process(delta):
	# Handle each option via signal instead maybe.
	
	_viewport_size = get_viewport().size 
	if _viewport_size != _prev_viewport_size:
		get_viewport().size = _viewport_size / viewport_downscale_factor
		_prev_viewport_size = get_viewport().size
		if Constants.VERBOSE_RUNTIME_LOGS:
			print(_viewport_size)
