extends Control

onready var p = get_tree().get_root().get_node("Main/Paths")
	
# UI SWITCHING
func _on_Button_desktop_gui_pressed():
	p.ui_paths.ui_functions.switch_to_desktop_gui()

func _on_Button_touch_gui_pressed():
	p.ui_paths.ui_functions.switch_to_touchscreen_gui()


# DESKTOP OPTIONS BUTTONS
func _on_Button_return_pressed():
	p.ui_paths.ui_functions.switch_to_touchscreen_gui()

func _on_Button_quit_pressed():
	get_tree().quit()

func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		p.ui_paths.ui_functions.debug_gui_show()
		p.ui.update_debug_text_on = true
	else:
		p.ui_paths.ui_functions.debug_gui_hide()
		p.ui.update_debug_text_on = false


# GRAPHIC ADJUSTMENTS
func _on_Slider_screen_res_value_changed(value):
	p.signals.emit_signal("sig_render_res_value_changed", value)

# Color palette.
func _on_Color_1_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_1/ColorRect").color)

func _on_Color_2_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_2/ColorRect").color)
	
func _on_Color_3_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_3/ColorRect").color)
	
func _on_Color_4_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_4/ColorRect").color)
	
func _on_Color_5_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_5/ColorRect").color)

func _on_Color_6_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_6/ColorRect").color)
	
func _on_Color_7_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_7/ColorRect").color)
	
func _on_Color_8_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_8/ColorRect").color)
	
func _on_Color_9_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_9/ColorRect").color)
	
func _on_Color_10_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_10/ColorRect").color)
	
func _on_Color_11_pressed():
	set_theme_color(get_node("Buttons_quick_bar/Controls_visual/Color_presets/Color_11/ColorRect").color)

func set_theme_color(color):
	get_node("Buttons_quick_bar/Controls_visual/Color_presets/Panel_sample").get_material().set_shader_param("albedo", color)	


func _on_Slider_color_power_value_changed(value):
	get_node("Buttons_quick_bar/Controls_visual/Color_presets/Panel_sample").get_material().set_shader_param("power", value)	


#func _on_Button_screen_filter_toggled(button_pressed):
#	if button_pressed: p.signals.emit_signal("sig_screen_filter_on", true)
#	else: p.signals.emit_signal("sig_screen_filter_on", false)
	

func _on_Button_controls_swap_toggled(button_pressed):
	if button_pressed:
		p.ui_paths.ui_functions.switch_to_touchscreen_controls_swapped()
	else:
		p.ui_paths.ui_functions.switch_to_touchscreen_controls_unswapped()
