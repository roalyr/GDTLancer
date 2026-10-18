# WorldRendering: viewport and rendering settings, plus HUD/jump presentation toggles.
# The 3D world (zone, camera, jump rig) lives in its own viewport, WorldViewContainer/WorldViewport,
# drawn full-screen behind the HUD. Its resolution is a share of the window
# (viewport_downscale_factor) and is stretched to fill it, so the HUD keeps full resolution.
# One camera, one 3D pass; HUD and pointer code convert between the two resolutions with ScreenSpace.

extends Node

# This is a section that holds rendering settings.
# Render resolution of the 3D world as a share of the window: 1.0 full, 0.5 half, 0.25 quarter.
# Cycled from the HUD's render scale button (Constants.RENDER_SCALE_STEPS).
var viewport_downscale_factor = 1.0
var viewport_msaa = Viewport.MSAA_DISABLED
var viewport_fxaa = false
var viewport_disable_3d = false
var viewport_sharpen_intensity = 0.5
var viewport_keep_3d_linear = false
var viewport_filter_upscaled = false  # Smooth the reduced picture when stretching it (false: crisp pixels)
var projected_target_center_fade_enabled = true
var jump_transition_enabled = true

var _world_viewport: Viewport = null


func _ready():
	_world_viewport = get_parent().get_node_or_null("WorldViewContainer/WorldViewport")
	if not is_instance_valid(_world_viewport):
		printerr("WorldRendering: no WorldViewContainer/WorldViewport next to it")
		set_process(false)
		return
	_world_viewport.msaa = viewport_msaa
	_world_viewport.fxaa = viewport_fxaa
	_world_viewport.disable_3d = viewport_disable_3d
	_world_viewport.sharpen_intensity = viewport_sharpen_intensity
	_world_viewport.keep_3d_linear = viewport_keep_3d_linear
	_world_viewport.get_texture().flags = Texture.FLAG_FILTER if viewport_filter_upscaled else 0
	_apply_downscale()
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Viewport: Is ready")


# The container resizes the world viewport to its own size whenever it is resized; put the
# render resolution back.
func _process(_delta):
	if _world_viewport.size != get_world_render_size_for_window():
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


func get_world_render_size_for_window() -> Vector2:
	return (OS.window_size * viewport_downscale_factor).floor()


func _apply_downscale() -> void:
	if not is_instance_valid(_world_viewport):
		return
	_world_viewport.size = get_world_render_size_for_window()
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Viewport: world renders at ", _world_viewport.size, " for a ", OS.window_size, " window")
