extends Node

# UI
var ui_alpha = 1.0
var ui_scale = Vector2(1,1)
var ui_reverse_scale = Vector2(1,1)
var touch_touch_pad_base_rect_position = Vector2(0,0)
var touch_touch_pad_base_rect_size = Vector2(0,0)
var touch_touch_throttle_base_rect_position = Vector2(0,0)
var touch_touch_throttle_base_rect_size = Vector2(0,0)
var touchscreen_controls_swapped = false

# GAME STATE
var game_started = false
var game_paused = false
var turret_view = false
var update_debug_text_on = false

# CONTROLS
var touchscreen_mode = false
