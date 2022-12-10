extends Control

onready var p = get_tree().get_root().get_node("Main/Paths")


# DESKTOP
# UI SWITCHING
func _on_Button_cumputer_gui_switch_pressed():
	p.common_game_options.touchscreen_mode = false
	p.ui_paths.ui_functions.gameplay_gui_show()
	p.ui_paths.ui_functions.desktop_gui_show()
	p.ui_paths.ui_functions.touchscreen_gui_hide()
	p.ui_paths.ui_functions.select_gui_prompt_hide()

# TOUCHSCREEN

# UI SWITCHING
func _on_Button_touchscreen_switch_pressed():
	p.common_game_options.touchscreen_mode = true
	p.ui_paths.ui_functions.gameplay_gui_show()
	p.ui_paths.ui_functions.touchscreen_gui_show()
	p.ui_paths.ui_functions.desktop_gui_hide()
	p.ui_paths.ui_functions.select_gui_prompt_hide()

# DESKTOP / MOBILE GUI
func _on_Button_screen_filter_toggled(button_pressed):
	if button_pressed: p.signals.emit_signal("sig_screen_filter_on", true)
	else: p.signals.emit_signal("sig_screen_filter_on", false)

# DESKTOP / MOBILE GUI
func _on_Slider_screen_res_value_changed(value):
	p.signals.emit_signal("sig_render_res_value_changed", value)
