# WorldRendering: viewport and rendering settings, plus HUD/jump presentation toggles.

extends Node

# This is a section that holds rendering settings.
# Render resolution as a share of the window: 1.0 full, 0.5 half, 0.25 quarter (stretched to fill
# the window). Cycled from the HUD's render scale button (Constants.RENDER_SCALE_STEPS).
var viewport_downscale_factor = 1.0
var viewport_msaa = Viewport.MSAA_DISABLED
var viewport_fxaa = false
var viewport_disable_3d = false
var viewport_sharpen_intensity = 0.5
var viewport_keep_3d_linear = false
var projected_target_center_fade_enabled = true
var jump_transition_enabled = true


var _viewport_size = Vector2(1920, 1080)  # The window
var _prev_viewport_size = Vector2(1920, 1080)  # What the viewport was last set to

func _ready():
	get_viewport().msaa = viewport_msaa
	get_viewport().fxaa = viewport_fxaa
	get_viewport().disable_3d = viewport_disable_3d
	get_viewport().sharpen_intensity = viewport_sharpen_intensity
	get_viewport().keep_3d_linear = viewport_keep_3d_linear
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Viewport: Is ready")

func _process(_delta):
	# The engine resets the viewport to the window size on every window resize: apply the scale again.
	if get_viewport().size != _prev_viewport_size:
		_apply_downscale()


func set_downscale_factor(factor: float) -> void:
	viewport_downscale_factor = factor
	_apply_downscale()


# Steps to the next render scale in Constants.RENDER_SCALE_STEPS (wrapping around) and returns it.
func cycle_downscale_factor() -> float:
	var steps: Array = Constants.RENDER_SCALE_STEPS
	var index: int = steps.find(viewport_downscale_factor)
	set_downscale_factor(steps[(index + 1) % steps.size()])
	return viewport_downscale_factor


func _apply_downscale() -> void:
	_viewport_size = OS.window_size
	get_viewport().size = (_viewport_size * viewport_downscale_factor).floor()
	_prev_viewport_size = get_viewport().size
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Viewport: rendering at ", _prev_viewport_size, " for a ", _viewport_size, " window")
