extends CanvasLayer

# TODO: Scalable UI (control panel, texts, buttons, etc).
# TODO: Grouping for overlapping markers.

# COMMON VARIABLES
var stick_held = false
var throttle_held = false

var turret_view = false
var update_debug_text_on = false
var ui_hidden = false
var ui_alpha = 1.0

# Internal values.
var viewport_size = Vector2(1,1)
var reverse_scale = Vector2(1,1)
var ratio_height = 1.0
var ratio_width = 1.0


func _ready():
	# ============================ Connect signals ============================
	Signals.connect("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================
	
	UiPaths.common_touchscreen_pad.recenter_stick()
	UiPaths.common_touchscreen_throttle.recenter_throttle()
	UiPaths.ui_functions.init_gui()


func is_viewport_update():
	ratio_height = OS.window_size.y/ProjectSettings.get_setting("display/window/size/height")
	ratio_width = OS.window_size.x/ProjectSettings.get_setting("display/window/size/width")
	self.scale = Vector2(ratio_width, ratio_height)
	# Calculate reverse scale, but make sure 1/0 is not happening.
	reverse_scale = Vector2(
		1.0/max(self.scale.x, 1e-6), 
		1.0/max(self.scale.y, 1e-6))
	
	# Restore the proportions of the controls.
	restore_proportions(UiPaths.touch_bar_ship)
	restore_proportions(UiPaths.touch_bar_control)
	restore_proportions(UiPaths.touch_bar_control_2)
	restore_proportions(UiPaths.touch_bar_nav)
	restore_proportions(UiPaths.touch_bar_menu)
	restore_proportions(UiPaths.touch_bar_menu_2)
	restore_proportions(UiPaths.touch_touch_throttle_base)
	restore_proportions(UiPaths.touch_touch_pad_base)
	restore_proportions(UiPaths.touch_velocity_panel)
	restore_proportions(UiPaths.touch_status_panel)
	restore_proportions(UiPaths.touch_readings_target_autopilot)
	restore_proportions(UiPaths.touch_readings_target_aim)
	
	#restore_proportions(UiPaths.desktop_mouse_area)
	restore_proportions(UiPaths.desktop_bar_ship)
	restore_proportions(UiPaths.desktop_bar_control)
	restore_proportions(UiPaths.desktop_bar_control_2)
	restore_proportions(UiPaths.desktop_bar_nav)
	restore_proportions(UiPaths.desktop_bar_menu)
	restore_proportions(UiPaths.desktop_bar_menu_2)
	restore_proportions(UiPaths.desktop_velocity_panel)
	restore_proportions(UiPaths.desktop_status_panel)
	restore_proportions(UiPaths.desktop_readings_target_autopilot)
	restore_proportions(UiPaths.desktop_readings_target_aim)
	
	restore_proportions(UiPaths.options_buttons_general_bar)
	restore_proportions(UiPaths.options_tab_options_general)
	restore_proportions(UiPaths.options_tab_options_graphic)
	restore_proportions(UiPaths.options_tab_options_audio)
	restore_proportions(UiPaths.options_tab_info)
	restore_proportions(UiPaths.options_prompt_start)
	

func restore_proportions(c):
	c.rect_pivot_offset.x = c.rect_size.x/2
	c.rect_pivot_offset.y = c.rect_size.y/2
	c.rect_scale = reverse_scale/reverse_scale.y

# Restore the window, provide margins as if it was a FHD resolution.
# TODO: how?
func restore_proportions_with_margins(c):
	c.rect_pivot_offset.x = c.rect_size.x/2
	c.rect_pivot_offset.y = c.rect_size.y/2
	c.rect_scale = reverse_scale/reverse_scale.y
	c.rect_size.x = 1920*reverse_scale.x/reverse_scale.y

	
func _process(_delta):
	if GameOptions.touchscreen_mode:
		UiPaths.common_touchscreen_pad.handle_stick()
		UiPaths.common_touchscreen_throttle.handle_throttle()
	
	# DEBUG
	if update_debug_text_on: UiPaths.common_debug.update_debug_text()
	
	# READOUTS
	# Adjust displayed speed
	var speed_val = round(PlayerState.apparent_velocity)
	var result_s = UiPaths.common_readouts.get_magnitude_units(speed_val)
	# To prevent from crashing on Nil
	if result_s:
		var vel = str(result_s[0]).pad_decimals(3).left(5)
		var units = str(result_s[1])
		UiPaths.common_readouts.apparent_velocity = " V: " + vel
		UiPaths.common_readouts.apparent_velocity_units = units + " / s"
		
	UiPaths.common_readouts.accel_ticks = str(" A: ", PlayerState.accel_ticks)

	
