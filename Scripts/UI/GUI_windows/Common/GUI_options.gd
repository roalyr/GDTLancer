extends Control

onready var ui_paths = get_node("/root/Main/UI_paths")


func _ready():
	hide_tabs()


func hide_tabs():
	ui_paths.options_tab_info.hide()
	ui_paths.options_tab_options_audio.hide()
	ui_paths.options_tab_options_graphic.hide()
	ui_paths.options_tab_options_general.hide()
	ui_paths.options_prompt_start.hide()
	ui_paths.options_prompt_start_confirm.hide()


func unpress_buttons():
	ui_paths.options_button_info.pressed = false
	ui_paths.options_button_options_audio.pressed = false
	ui_paths.options_button_options_graphic.pressed = false
	ui_paths.options_button_options_general.pressed = false


# GAME START / RESUME / QUIT BUTTONS.
func _on_Button_start_pressed():
	if not GameState.game_started:
		hide_tabs()
		unpress_buttons()
		ui_paths.ui_functions.options_prompt_start_show()
	else:
		hide_tabs()
		unpress_buttons()
		ui_paths.ui_functions.options_prompt_start_confirm_show()


# If the game was already started.
func _on_Button_start_confirm_pressed():
	hide_tabs()
	unpress_buttons()
	ui_paths.ui_functions.options_prompt_start_show()


func _on_Button_resume_pressed():
	ui_paths.ui_functions.resume_game()


func _on_Button_desktop_gui_pressed():
	ui_paths.ui_functions.switch_to_desktop_gui()


func _on_Button_touch_gui_pressed():
	ui_paths.ui_functions.switch_to_touchscreen_gui()
	

# OPTIONS BUTTONS.
func _on_Button_options_general_toggled(button_pressed):
	if button_pressed and not ui_paths.options_tab_options_general.visible: 
		hide_tabs()
		ui_paths.options_button_info.pressed = false
		ui_paths.options_button_options_audio.pressed = false
		ui_paths.options_button_options_graphic.pressed = false
		#ui_paths.options_button_options_general.pressed = false
		ui_paths.options_tab_options_general.show()
	else: 
		ui_paths.options_tab_options_general.hide()


func _on_Button_options_graphic_toggled(button_pressed):
	if button_pressed and not ui_paths.options_tab_options_graphic.visible: 
		hide_tabs()
		ui_paths.options_button_info.pressed = false
		ui_paths.options_button_options_audio.pressed = false
		#ui_paths.options_button_options_graphic.pressed = false
		ui_paths.options_button_options_general.pressed = false
		ui_paths.options_tab_options_graphic.show()
	else: 
		ui_paths.options_tab_options_graphic.hide()


func _on_Button_options_audio_toggled(button_pressed):
	if button_pressed and not ui_paths.options_tab_options_audio.visible: 
		hide_tabs()
		ui_paths.options_button_info.pressed = false
		#ui_paths.options_button_options_audio.pressed = false
		ui_paths.options_button_options_graphic.pressed = false
		ui_paths.options_button_options_general.pressed = false
		ui_paths.options_tab_options_audio.show()
	else: 
		ui_paths.options_tab_options_audio.hide()
		
		
func _on_Button_info_toggled(button_pressed):
	if button_pressed and not ui_paths.options_tab_info.visible: 
		hide_tabs()
		#ui_paths.options_button_info.pressed = false
		ui_paths.options_button_options_audio.pressed = false
		ui_paths.options_button_options_graphic.pressed = false
		ui_paths.options_button_options_general.pressed = false
		ui_paths.options_tab_info.show()
	else: 
		ui_paths.options_tab_info.hide()


func _on_Button_quit_pressed():
	get_tree().quit()


func _on_Button_desktop_gui_toggled(button_pressed):
	if button_pressed:
		GameState.touchscreen_mode = false
		ui_paths.options_tab_options_general_button_touch_gui.pressed = false
	else:
		GameState.touchscreen_mode = true
		ui_paths.options_tab_options_general_button_touch_gui.pressed = true


func _on_Button_touch_gui_toggled(button_pressed):
	if button_pressed:
		GameState.touchscreen_mode = true
		ui_paths.options_tab_options_general_button_desktop_gui.pressed = false
	else:
		GameState.touchscreen_mode = false
		ui_paths.options_tab_options_general_button_desktop_gui.pressed = true


func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		ui_paths.ui_functions.debug_gui_show()
		GameState.update_debug_text_on = true
	else:
		ui_paths.ui_functions.debug_gui_hide()
		GameState.update_debug_text_on = false


func _on_Button_controls_swap_toggled(button_pressed):
	if button_pressed:
		ui_paths.ui_functions.switch_to_touchscreen_controls_swapped()
	else:
		ui_paths.ui_functions.switch_to_touchscreen_controls_unswapped()

func _on_Language_list_item_selected(index):
	Signals.emit_signal("sig_language_selected", index)


# GRAPHIC OPTIONS
func _on_Slider_color_power_value_changed(value):
	ui_paths.options_graphic_color_presets.get_node("Panel_sample").get_material().set_shader_param("power", value)	


func _on_Slider_screen_res_value_changed(value):
	Signals.emit_signal("sig_render_res_value_changed", value)


# Color palette.
func _on_Color_1_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_1/ColorRect").color)

func _on_Color_2_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_2/ColorRect").color)
	
func _on_Color_3_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_3/ColorRect").color)
	
func _on_Color_4_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_4/ColorRect").color)
	
func _on_Color_5_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_5/ColorRect").color)

func _on_Color_6_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_6/ColorRect").color)
	
func _on_Color_7_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_7/ColorRect").color)
	
func _on_Color_8_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_8/ColorRect").color)
	
func _on_Color_9_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_9/ColorRect").color)
	
func _on_Color_10_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_10/ColorRect").color)
	
func _on_Color_11_pressed():
	set_theme_color(ui_paths.options_graphic_color_presets.get_node("Color_11/ColorRect").color)

func set_theme_color(color):
	ui_paths.options_graphic_color_presets.get_node("Panel_sample").get_material().set_shader_param("albedo", color)	

#func _on_Button_screen_filter_toggled(button_pressed):
#	if button_pressed: Signals.emit_signal("sig_screen_filter_on", true)
#	else: Signals.emit_signal("sig_screen_filter_on", false)


