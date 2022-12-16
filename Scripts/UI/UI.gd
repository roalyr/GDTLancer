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


onready var p = get_tree().get_root().get_node("Main/Paths")


func _ready():
	# ============================ Connect signals ============================
	p.signals.connect("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================
	
	p.ui_paths.common_touchscreen_pad.recenter_stick()
	p.ui_paths.common_touchscreen_throttle.recenter_throttle()
	p.ui_paths.ui_functions.init_gui()


func is_viewport_update():
	var ratio_height = OS.window_size.y/ProjectSettings.get_setting("display/window/size/height")
	var ratio_width = OS.window_size.x/ProjectSettings.get_setting("display/window/size/width")
	self.scale = Vector2(ratio_width, ratio_height)
	# Calculate reverse scale, but make sure 1/0 is not happening.
	reverse_scale = Vector2(
		1.0/max(self.scale.x, 1e-6), 
		1.0/max(self.scale.y, 1e-6))
	
	# Restore the proportions of the controls.
	restore_proportions(p.ui_paths.touch_bar_ship)
	restore_proportions(p.ui_paths.touch_bar_control)
	restore_proportions(p.ui_paths.touch_bar_nav)
	restore_proportions(p.ui_paths.touch_bar_menu)
	restore_proportions(p.ui_paths.touch_touch_throttle_base)
	restore_proportions(p.ui_paths.touch_touch_pad_base)
	restore_proportions(p.ui_paths.touch_top_readings)

func restore_proportions(c):
	c.rect_pivot_offset.x = c.rect_size.x/2
	c.rect_pivot_offset.y = c.rect_size.y/2
	c.rect_scale = reverse_scale/reverse_scale.y

	
func _process(_delta):
	p.ui_paths.common_touchscreen_pad.handle_stick()
	p.ui_paths.common_touchscreen_throttle.handle_throttle()
	
	# DEBUG
	if update_debug_text_on: p.ui_paths.common_debug.update_debug_text()
	
	# READOUTS
	# Adjust displayed speed
	var speed_val = round(p.ship_state.apparent_velocity)
	var result_s = p.ui_paths.common_readouts.get_magnitude_units(speed_val)
	# To prevent from crashing on Nil
	if result_s:
		var vel = str(result_s[0]).pad_decimals(3).left(5)
		var units = str(result_s[1])
		var vel_c = str(stepify(speed_val/p.common_constants.C, 0.001)) \
			.pad_decimals(3).left(5)
		
		p.ui_paths.common_readouts.apparent_velocity = " v: " + vel
		p.ui_paths.common_readouts.apparent_velocity_units = units + " / s"
		p.ui_paths.common_readouts.apparent_velocity_c = " c: " + vel_c
	p.ui_paths.common_readouts.accel_ticks = str("Accel: ", p.ship_state.accel_ticks)

	
