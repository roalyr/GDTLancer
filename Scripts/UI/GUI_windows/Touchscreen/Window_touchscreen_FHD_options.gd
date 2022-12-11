extends Control

onready var p = get_tree().get_root().get_node("Main/Paths")

func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		p.ui_paths.debug.show()
		p.ui.update_debug_text_on = true
	else:
		p.ui_paths.debug.hide()
		p.ui.update_debug_text_on = false

func _on_Button_screen_filter_toggled(button_pressed):
	if button_pressed: p.signals.emit_signal("sig_screen_filter_on", true)
	else: p.signals.emit_signal("sig_screen_filter_on", false)

func _on_Slider_screen_res_value_changed(value):
	p.signals.emit_signal("sig_render_res_value_changed", value)

func _on_Button_quit_pressed():
	p.signals.emit_signal("sig_quit_game")

func _on_Button_close_options_pressed():
	p.ui_paths.desktop_gui.show()
	p.ui_paths.desktop_options.hide()
