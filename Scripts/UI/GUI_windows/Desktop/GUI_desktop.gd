extends Control

onready var ui_paths = get_node("/root/Main/UI_paths")

var icon_velocity_1 =  load("res://Assets/UI_images/PNG/buttons/velocity_limiter_1.png")
var icon_velocity_2 =  load("res://Assets/UI_images/PNG/buttons/velocity_limiter_2.png")
var icon_velocity_3 =  load("res://Assets/UI_images/PNG/buttons/velocity_limiter_3.png")
var icon_velocity_4 =  load("res://Assets/UI_images/PNG/buttons/velocity_limiter_4.png")

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_autopilot_disable", self, "is_autopilot_disable")
	# =========================================================================

func hide_navbars():
	ui_paths.desktop_nav_popup_constellations.hide()	
	ui_paths.desktop_nav_popup_systems.hide()
	ui_paths.desktop_nav_popup_stars.hide()
	ui_paths.desktop_nav_popup_planets.hide()
	ui_paths.desktop_nav_popup_structures.hide()
	
func unpress_nav_buttons():
	ui_paths.desktop_button_constellations.pressed = false
	ui_paths.desktop_button_systems.pressed = false
	ui_paths.desktop_button_stars.pressed = false
	ui_paths.desktop_button_planets.pressed = false
	ui_paths.desktop_button_structures.pressed = false
	
	
# SIGNAL PROCESSING
func _on_Button_target_aim_clear_pressed():
	Signals.emit_signal("sig_target_aim_clear")
	
func _on_Button_autopilot_disable_pressed():
	Signals.emit_signal("sig_autopilot_disable")
	
func _on_Button_autopilot_start_pressed():
	Signals.emit_signal("sig_autopilot_start")
	
func _on_Button_ekill_pressed():
	Signals.emit_signal("sig_engine_kill")
	
func _on_Button_hide_ui_pressed():
	ui_paths.desktop_gui.modulate.a = GameState.ui_alpha
	GameState.ui_alpha -= 0.25
	if GameState.ui_alpha < 0.0:
		GameState.ui_alpha = 1.0


# DESKTOP / MOBILE GUI
func _on_Slider_zoom_value_changed(value):
	Signals.emit_signal("sig_zoom_value_changed", value)


# DESKTOP / MOBILE GUI
func _on_Button_turret_toggled(button_pressed):
	if button_pressed: 
		Signals.emit_signal("sig_turret_mode_on", true)
		ui_paths.desktop_slider_zoom.show()
		ui_paths.desktop_slider_zoom.value = 0
		
	else: 
		Signals.emit_signal("sig_turret_mode_on", false)
		ui_paths.desktop_slider_zoom.hide()
		ui_paths.desktop_slider_zoom.value = 0



# DESKTOP / MOBILE GUI
# Acceleration / decelartion
func _on_Button_accel_plus_pressed():
	Signals.emit_signal("sig_accelerate", true)
	
# DESKTOP / MOBILE GUI
func _on_Button_accel_minus_pressed():
	Signals.emit_signal("sig_accelerate", false)

# DESKTOP / MOBILE GUI
# Other buttons
func _on_Button_options_pressed():
	Signals.emit_signal("sig_switch_to_options_gui")
	

# Mouse capturing for desktop.
# Keep here
func _on_Mouse_area_mouse_entered():
	Signals.emit_signal("sig_mouse_on_control_area", true)

func _on_Mouse_area_mouse_exited():
	Signals.emit_signal("sig_mouse_on_control_area", false)
	

# NAVIGATION BAR BUTTONS
# Open and close navigation lists.
func _on_Button_constellations_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.desktop_nav_popup_constellations.visible: 
		hide_navbars()
#		ui_paths.desktop_button_constellations.pressed = false
		ui_paths.desktop_button_systems.pressed = false
		ui_paths.desktop_button_stars.pressed = false
		ui_paths.desktop_button_planets.pressed = false
		ui_paths.desktop_button_structures.pressed = false
		ui_paths.desktop_nav_popup_constellations.show()
	else: 
		ui_paths.desktop_nav_popup_constellations.hide()


func _on_Button_systems_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.desktop_nav_popup_systems.visible: 
		hide_navbars()
		ui_paths.desktop_button_constellations.pressed = false
#		ui_paths.desktop_button_systems.pressed = false
		ui_paths.desktop_button_stars.pressed = false
		ui_paths.desktop_button_planets.pressed = false
		ui_paths.desktop_button_structures.pressed = false
		ui_paths.desktop_nav_popup_systems.show()
	else: 
		ui_paths.desktop_nav_popup_systems.hide()


func _on_Button_stars_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.desktop_nav_popup_stars.visible: 
		hide_navbars()
		ui_paths.desktop_button_constellations.pressed = false
		ui_paths.desktop_button_systems.pressed = false
#		ui_paths.desktop_button_stars.pressed = false
		ui_paths.desktop_button_planets.pressed = false
		ui_paths.desktop_button_structures.pressed = false
		ui_paths.desktop_nav_popup_stars.show()
	else: 
		ui_paths.desktop_nav_popup_stars.hide()


func _on_Button_planets_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.desktop_nav_popup_planets.visible: 
		hide_navbars()
		ui_paths.desktop_button_constellations.pressed = false
		ui_paths.desktop_button_systems.pressed = false
		ui_paths.desktop_button_stars.pressed = false
#		ui_paths.desktop_button_planets.pressed = false
		ui_paths.desktop_button_structures.pressed = false
		ui_paths.desktop_nav_popup_planets.show()
	else: 
		ui_paths.desktop_nav_popup_planets.hide()
	

func _on_Button_structures_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.desktop_nav_popup_structures.visible: 
		hide_navbars()
		ui_paths.desktop_button_constellations.pressed = false
		ui_paths.desktop_button_systems.pressed = false
		ui_paths.desktop_button_stars.pressed = false
		ui_paths.desktop_button_planets.pressed = false
#		ui_paths.desktop_button_structures.pressed = false
		ui_paths.desktop_nav_popup_structures.show()
	else: 
		ui_paths.desktop_nav_popup_structures.hide()


func _on_Button_autopilot_toggled(button_pressed):
	if button_pressed:
		Signals.emit_signal("sig_autopilot_start")
	else:
		Signals.emit_signal("sig_autopilot_disable")
		
func is_autopilot_disable():
	ui_paths.desktop_button_autopilot.pressed = false
		
	
func _on_Button_info_toggled(button_pressed):
	if button_pressed: 
		ui_paths.desktop_readings_info_popup.show()
		Signals.emit_signal("sig_fetch_object_info")
	else: 
		ui_paths.desktop_readings_info_popup.hide()
		

func _on_Button_PLACEHOLDER4_toggled(button_pressed):
	if button_pressed and not ui_paths.desktop_ship_popup.visible: 
		ui_paths.desktop_ship_popup.show()
	else: 
		ui_paths.desktop_ship_popup.hide()



func _on_Button_debug_menu_show_toggled(button_pressed):
	if button_pressed: 
		ui_paths.ui_functions.debug_gui_show()
	else:
		ui_paths.ui_functions.debug_gui_hide()

func _on_Button_debug_toggled(button_pressed):
	if button_pressed: 
		GameState.update_debug_text_on = true
		GameState.debug("Debug mode ON")
	else:
		GameState.debug("Debug mode OFF")
		GameState.update_debug_text_on = false


func _on_Button_camera_change_pressed():
	if Paths.player.visible:
		GameState.debug("Hide player ship model.")
		Paths.player.hide()
		GameState.player_hidden = true
	else:
		GameState.debug("Show player ship model.")		
		Paths.player.show()
		GameState.player_hidden = false
		
func _on_Button_velocity_limiter_pressed():
	# res://Assets/UI_images/PNG/buttons/velocity_limiter_1.png
	PlayerState.velocity_limiter += 1
	if PlayerState.velocity_limiter > Constants.velocity_limiter_states:
		PlayerState.velocity_limiter = 0
	
	if PlayerState.velocity_limiter == 0:
		ui_paths.desktop_button_velocity_limiter.icon = icon_velocity_1
		Signals.emit_signal("sig_velocity_limiter_set", 0)
	elif PlayerState.velocity_limiter == 1:
		ui_paths.desktop_button_velocity_limiter.icon = icon_velocity_2
		Signals.emit_signal("sig_velocity_limiter_set", 1)
	elif PlayerState.velocity_limiter == 2:
		ui_paths.desktop_button_velocity_limiter.icon = icon_velocity_3
		Signals.emit_signal("sig_velocity_limiter_set", 2)
	elif PlayerState.velocity_limiter == 3:
		ui_paths.desktop_button_velocity_limiter.icon = icon_velocity_4
		Signals.emit_signal("sig_velocity_limiter_set", 3)
