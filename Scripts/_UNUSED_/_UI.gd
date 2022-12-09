extends CanvasLayer

# TODO: Scalable UI (control panel, texts, buttons, etc).
# TODO: Grouping for overlapping markers.

# VARIABLES
var stick_held = false
var turret_view = false
var update_debug_text_on = false
var ui_hidden = false
var ui_alpha = 1.0
var viewport_size = Vector2(1,1)

onready var p = get_tree().get_root().get_node("Main/Paths")

# TODO: to paths
onready var mouse_vector_debug = p.ui.get_node("Gameplay/Debug/Mouse_vector")

# TODO: to paths
onready var apparent_velocity = p.ui.get_node("Gameplay/Apparent_velocity")
onready var apparent_velocity_c = p.ui.get_node("Gameplay/Apparent_velocity_c")
onready var apparent_velocity_units = p.ui.get_node("Gameplay/Apparent_velocity_units")


func _ready():
	p.ui_paths.common_mobile_buttons_pad.pad_recenter_stick()
	p.ui_paths.gui_logic.init_gui()

	
	
	

func _input(event):

	# Duplicated input listening function for the sake of mouse vector drawing.
	if event is InputEventMouseMotion and p.ui_paths.debug.visible:
		# Mouse vector positions.
		mouse_vector_debug.points[0] = Vector2(viewport_size.x/2, viewport_size.y/2)
		mouse_vector_debug.points[1] = Vector2(
				p.input.mouse_vector.x*viewport_size.x/2 + viewport_size.x/2, 
				p.input.mouse_vector.y*viewport_size.y/2 + viewport_size.y/2
			)
	
func _process(_delta):
	p.ui_paths.common_mobile_buttons_pad.pad_handle_stick()
	
	# DEBUG
	if update_debug_text_on: update_debug_text()
	
	# READOUTS
	# Adjust displayed speed
	var speed_val = round(p.ship_state.apparent_velocity)
	var result_s = p.ui_paths.common_readouts.get_magnitude_units(speed_val)
	# To prevent from crashing on Nil
	if result_s:
		apparent_velocity.text = str(result_s[0])
		apparent_velocity_units.text = str(result_s[1])+"/s"
		apparent_velocity_c.text = "| c: " + str(speed_val/p.common_constants.C)
	p.ui_paths.gameplay.get_node("Accel_ticks").text = str("Accel: ", p.ship_state.accel_ticks)

# ================================== Other ====================================
# DEBUG
func update_debug_text():
	p.ui_paths.debug.get_node("FPS").text = str("FPS: ", p.main.fps)
	p.ui_paths.debug.get_node("Mouse_x").text = str("Mouse / Pad x: ", p.input.mouse_vector.x)
	p.ui_paths.debug.get_node("Mouse_y").text = str("Mouse / Pad y: ", p.input.mouse_vector.y)


# SIGNAL PROCESSING
# TODO: sort out

# Setting up GUI on start.
# TOUCHSCREEN

# UI SWITCHING
func _on_Button_touchscreen_switch_pressed():
	p.common_game_options.touchscreen_mode = true
	p.ui_paths.gui_logic.gameplay_gui_show()
	p.ui_paths.gui_logic.touchscreen_gui_show()
	p.ui_paths.gui_logic.desktop_gui_hide()
	p.ui_paths.gui_logic.select_gui_prompt_hide()

# DESKTOP
# UI SWITCHING
func _on_Button_cumputer_gui_switch_pressed():
	p.common_game_options.touchscreen_mode = false
	p.ui_paths.gui_logic.gameplay_gui_show()
	p.ui_paths.gui_logic.desktop_gui_show()
	p.ui_paths.gui_logic.touchscreen_gui_hide()
	p.ui_paths.gui_logic.select_gui_prompt_hide()



# TODO: improve
# Keep here
func _on_Viewport_main_resized():
	# Has to be called manually bc "Paths/Signals" doesn't initiate at start.
	get_node("/root/Main/Common/Signals").emit_signal("sig_viewport_update")
	viewport_size = OS.window_size

# DESKTOP / MOBILE GUI
func _on_Button_quit_pressed():
	p.signals.emit_signal("sig_quit_game")

# DESKTOP / MOBILE GUI
func _on_Button_turret_toggled(button_pressed):
	if button_pressed: 
		p.signals.emit_signal("sig_turret_mode_on", true)
		# Show slider in Touch GUI.
		# TODO: make two buttons instead
		
	else: 
		p.signals.emit_signal("sig_turret_mode_on", false)
		# Hide slider in Touch GUI.
		# TODO: make two buttons instead


# DESKTOP / MOBILE GUI
func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		p.ui_paths.debug.show()
		update_debug_text_on = true
	else:
		p.ui_paths.debug.hide()
		update_debug_text_on = false

# DESKTOP / MOBILE GUI
func _on_Button_text_panel_toggled(button_pressed):
	if button_pressed: p.ui_paths.text_panel.show()
	else: p.ui_paths.text_panel.hide()

# DESKTOP / MOBILE GUI
func _on_Button_screen_filter_toggled(button_pressed):
	if button_pressed: p.signals.emit_signal("sig_screen_filter_on", true)
	else: p.signals.emit_signal("sig_screen_filter_on", false)

# DESKTOP / MOBILE GUI
func _on_Slider_screen_res_value_changed(value):
	p.signals.emit_signal("sig_render_res_value_changed", value)


# DESKTOP / MOBILE GUI
# Acceleration / decelartion
func _on_Button_accel_plus_pressed():
	p.signals.emit_signal("sig_accelerate", true)
	
# DESKTOP / MOBILE GUI
func _on_Button_accel_minus_pressed():
	p.signals.emit_signal("sig_accelerate", false)

# DESKTOP / MOBILE GUI
# Other buttons
func _on_Button_options_pressed():
	p.ui_paths.touchscreen_main.hide()
	p.ui_paths.touchscreen_options.show()
	p.ui_paths.desktop_main.hide()
	p.ui_paths.desktop_options.show()
	
func _on_Button_close_options_pressed():
	p.ui_paths.touchscreen_main.show()
	p.ui_paths.touchscreen_options.hide()
	p.ui_paths.desktop_main.show()
	p.ui_paths.desktop_options.hide()


# Mouse capturing for desktop.
# Keep here
func _on_Mouse_area_mouse_entered():
	p.signals.emit_signal("sig_mouse_on_control_area", true)

func _on_Mouse_area_mouse_exited():
	p.signals.emit_signal("sig_mouse_on_control_area", false)

# DESKTOP / MOBILE GUI
func _on_Slider_zoom_value_changed(value):
	p.signals.emit_signal("sig_zoom_value_changed", value)


# Virtual stick.
func _on_Stick_pressed():
	stick_held = true

func _on_Stick_released():
	stick_held = false



# DESKTOP / MOBILE GUI
# Touchscreen controls.
func _on_Touch_accel_plus_pressed():
	p.signals.emit_signal("sig_accelerate", true)

func _on_Touch_accel_minus_pressed():
	p.signals.emit_signal("sig_accelerate", false)

func _on_Touch_ekill_pressed():
	p.signals.emit_signal("sig_engine_kill")



# DESKTOP / MOBILE GUI
func _on_Button_hide_ui_pressed():
	p.ui_paths.touchscreen_main.modulate.a = ui_alpha
	p.ui_paths.desktop_main.modulate.a = ui_alpha
	p.ui_paths.gameplay.modulate.a = ui_alpha
	ui_alpha -= 0.25
	if ui_alpha < 0.0:
		ui_alpha = 1.0

# DESKTOP / MOBILE GUI
func _on_Button_ekill_pressed():
	p.signals.emit_signal("sig_engine_kill")

# Navigation button
# DESKTOP
func _on_Button_nav_pressed():
	p.signals.emit_signal("sig_fetch_markers")
	if not p.ui_paths.desktop_nav_popup.visible: p.ui_paths.desktop_nav_popup.show()
	else: p.ui_paths.desktop_nav_popup.hide()

# MOBILE
func _on_Button_nav_touchscreen_pressed():
	p.signals.emit_signal("sig_fetch_markers")
	if not p.ui_paths.touchscreen_nav_popup.visible: p.ui_paths.touchscreen_nav_popup.show()
	else: p.ui_paths.touchscreen_nav_popup.hide()

# Autopilot controls
# DESKTOP
func _on_Button_autopilot_start_pressed():
	p.signals.emit_signal("sig_autopilot_start")
# MOBILE
func _on_Button_autopilot_start_touchscreen_pressed():
	p.signals.emit_signal("sig_autopilot_start")

# DESKTOP 
func _on_Button_autopilot_disable_pressed():
	p.signals.emit_signal("sig_autopilot_disable")
	
# MOBILE
func _on_Button_autopilot_disable_touchscreen_pressed():
	p.signals.emit_signal("sig_autopilot_disable")

# Targeting
# DESKTOP
func _on_Button_target_aim_clear_pressed():
	p.signals.emit_signal("sig_target_aim_clear")
# MOBILE
func _on_Button_target_aim_clear_touchscreen_pressed():
	p.signals.emit_signal("sig_target_aim_clear")


