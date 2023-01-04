extends Control

func _ready():
	hide_tabs()

func hide_tabs():
	UiPaths.options_tab_info.hide()	
	UiPaths.options_tab_options_audio.hide()
	UiPaths.options_tab_options_graphic.hide()
	UiPaths.options_tab_options_general.hide()
	UiPaths.options_prompt_start.hide()
	UiPaths.options_prompt_start_confirm.hide()

# TODO: should this be used instead?
func unpress_buttons():
	UiPaths.options_button_info.pressed = false
	UiPaths.options_button_options_audio.pressed = false
	UiPaths.options_button_options_graphic.pressed = false
	UiPaths.options_button_options_general.pressed = false


# BUTTON SIDE BAR BUTTONS
func _on_Button_start_pressed():
	if not GameOptions.game_started:
		hide_tabs()
		unpress_buttons()
		UiPaths.ui_functions.options_prompt_start_show()
	else:
		hide_tabs()
		unpress_buttons()
		UiPaths.ui_functions.options_prompt_start_confirm_show()

func _on_Button_start_confirm_pressed():
	hide_tabs()
	unpress_buttons()
	UiPaths.ui_functions.options_prompt_start_show()

func _on_Button_resume_pressed():
	if GameOptions.touchscreen_mode:
		UiPaths.ui_functions.switch_to_touchscreen_gui()
	else:
		UiPaths.ui_functions.switch_to_desktop_gui()
	UiPaths.ui_functions.options_prompt_start_confirm_hide()
	UiPaths.ui_functions.options_prompt_start_hide()
	GameOptions.game_started = true
	UiPaths.options_button_resume.disabled = false

func _on_Button_options_general_toggled(button_pressed):
	if button_pressed and not UiPaths.options_tab_options_general.visible: 
		hide_tabs()
		UiPaths.options_button_info.pressed = false
		UiPaths.options_button_options_audio.pressed = false
		UiPaths.options_button_options_graphic.pressed = false
		#UiPaths.options_button_options_general.pressed = false
		UiPaths.options_tab_options_general.show()
	else: 
		UiPaths.options_tab_options_general.hide()

func _on_Button_options_graphic_toggled(button_pressed):
	if button_pressed and not UiPaths.options_tab_options_graphic.visible: 
		hide_tabs()
		UiPaths.options_button_info.pressed = false
		UiPaths.options_button_options_audio.pressed = false
		#UiPaths.options_button_options_graphic.pressed = false
		UiPaths.options_button_options_general.pressed = false
		UiPaths.options_tab_options_graphic.show()
	else: 
		UiPaths.options_tab_options_graphic.hide()


func _on_Button_options_audio_toggled(button_pressed):
	if button_pressed and not UiPaths.options_tab_options_audio.visible: 
		hide_tabs()
		UiPaths.options_button_info.pressed = false
		#UiPaths.options_button_options_audio.pressed = false
		UiPaths.options_button_options_graphic.pressed = false
		UiPaths.options_button_options_general.pressed = false
		UiPaths.options_tab_options_audio.show()
	else: 
		UiPaths.options_tab_options_audio.hide()
		
func _on_Button_info_toggled(button_pressed):
	if button_pressed and not UiPaths.options_tab_info.visible: 
		hide_tabs()
		#UiPaths.options_button_info.pressed = false
		UiPaths.options_button_options_audio.pressed = false
		UiPaths.options_button_options_graphic.pressed = false
		UiPaths.options_button_options_general.pressed = false
		UiPaths.options_tab_info.show()
	else: 
		UiPaths.options_tab_info.hide()

func _on_Button_quit_pressed():
	get_tree().quit()


# GENERAL OPTIONS
func _on_Button_desktop_gui_pressed():
	UiPaths.ui_functions.switch_to_desktop_gui()
	UiPaths.ui_functions.options_prompt_start_hide()
	GameOptions.game_started = true
	GameOptions.touchscreen_mode = false
	UiPaths.options_button_resume.disabled = false
	UiPaths.options_tab_options_general_button_desktop_gui.pressed = true
	UiPaths.options_tab_options_general_button_touch_gui.pressed = false

func _on_Button_touch_gui_pressed():
	UiPaths.ui_functions.switch_to_touchscreen_gui()
	UiPaths.ui_functions.options_prompt_start_hide()
	GameOptions.game_started = true
	GameOptions.touchscreen_mode = true
	UiPaths.options_button_resume.disabled = false
	UiPaths.options_tab_options_general_button_desktop_gui.pressed = false
	UiPaths.options_tab_options_general_button_touch_gui.pressed = true
	

func _on_Button_desktop_gui_toggled(button_pressed):
	if button_pressed:
		GameOptions.touchscreen_mode = false
		UiPaths.options_tab_options_general_button_touch_gui.pressed = false
	else:
		GameOptions.touchscreen_mode = true
		UiPaths.options_tab_options_general_button_touch_gui.pressed = true

func _on_Button_touch_gui_toggled(button_pressed):
	if button_pressed:
		GameOptions.touchscreen_mode = true
		UiPaths.options_tab_options_general_button_desktop_gui.pressed = false
	else:
		GameOptions.touchscreen_mode = false
		UiPaths.options_tab_options_general_button_desktop_gui.pressed = true

func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		UiPaths.ui_functions.debug_gui_show()
		Paths.ui.update_debug_text_on = true
	else:
		UiPaths.ui_functions.debug_gui_hide()
		Paths.ui.update_debug_text_on = false

func _on_Button_controls_swap_toggled(button_pressed):
	if button_pressed:
		UiPaths.ui_functions.switch_to_touchscreen_controls_swapped()
	else:
		UiPaths.ui_functions.switch_to_touchscreen_controls_unswapped()

func _on_Language_list_item_selected(index):
	Signals.emit_signal("sig_language_selected", index)


# GRAPHIC OPTIONS
func _on_Slider_color_power_value_changed(value):
	UiPaths.options_graphic_color_presets.get_node("Panel_sample").get_material().set_shader_param("power", value)	

func _on_Slider_screen_res_value_changed(value):
	Signals.emit_signal("sig_render_res_value_changed", value)

# Color palette.
func _on_Color_1_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_1/ColorRect").color)

func _on_Color_2_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_2/ColorRect").color)
	
func _on_Color_3_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_3/ColorRect").color)
	
func _on_Color_4_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_4/ColorRect").color)
	
func _on_Color_5_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_5/ColorRect").color)

func _on_Color_6_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_6/ColorRect").color)
	
func _on_Color_7_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_7/ColorRect").color)
	
func _on_Color_8_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_8/ColorRect").color)
	
func _on_Color_9_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_9/ColorRect").color)
	
func _on_Color_10_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_10/ColorRect").color)
	
func _on_Color_11_pressed():
	set_theme_color(UiPaths.options_graphic_color_presets.get_node("Color_11/ColorRect").color)

func set_theme_color(color):
	UiPaths.options_graphic_color_presets.get_node("Panel_sample").get_material().set_shader_param("albedo", color)	

#func _on_Button_screen_filter_toggled(button_pressed):
#	if button_pressed: Signals.emit_signal("sig_screen_filter_on", true)
#	else: Signals.emit_signal("sig_screen_filter_on", false)


