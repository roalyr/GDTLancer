extends Control

onready var ui_paths = get_node("/root/Main/UI_paths")

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect_checked("sig_autopilot_disable", self, "is_autopilot_disable")
	# =========================================================================


func hide_navbars():
	ui_paths.touch_nav_popup_constellations.hide()	
	ui_paths.touch_nav_popup_systems.hide()
	ui_paths.touch_nav_popup_stars.hide()
	ui_paths.touch_nav_popup_planets.hide()
	ui_paths.touch_nav_popup_structures.hide()

# TODO: should this be used instead?
func unpress_nav_buttons():
	ui_paths.touch_button_constellations.pressed = false
	ui_paths.touch_button_systems.pressed = false
	ui_paths.touch_button_stars.pressed = false
	ui_paths.touch_button_planets.pressed = false
	ui_paths.touch_button_structures.pressed = false
	
	
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
	ui_paths.touch_gui.modulate.a = GameState.ui_alpha
	GameState.ui_alpha -= 0.25
	if GameState.ui_alpha < 0.0:
		GameState.ui_alpha = 1.0


# touch_FHD / MOBILE GUI
func _on_Slider_zoom_value_changed(value):
	Signals.emit_signal("sig_zoom_value_changed", value)


# touch_FHD / MOBILE GUI
func _on_Button_turret_toggled(button_pressed):
	if button_pressed: 
		Signals.emit_signal("sig_turret_mode_on", true)
		# Show slider in Touch GUI.
		# TODO: make two buttons instead
		
	else: 
		Signals.emit_signal("sig_turret_mode_on", false)
		# Hide slider in Touch GUI.
		# TODO: make two buttons instead



# touch_FHD / MOBILE GUI
# Acceleration / decelartion
func _on_Button_accel_plus_pressed():
	Signals.emit_signal("sig_accelerate", true)
	
# touch_FHD / MOBILE GUI
func _on_Button_accel_minus_pressed():
	Signals.emit_signal("sig_accelerate", false)

# touch_FHD / MOBILE GUI
# Other buttons
func _on_Button_options_pressed():
	ui_paths.ui_functions.switch_to_options_gui()
	

# Mouse capturing for touch_FHD.
# Keep here
func _on_Mouse_area_mouse_entered():
	Signals.emit_signal("sig_mouse_on_control_area", true)

func _on_Mouse_area_mouse_exited():
	Signals.emit_signal("sig_mouse_on_control_area", false)
	

# NAVIGATION BAR BUTTONS
# Open and close navigation lists.
func _on_Button_constellations_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.touch_nav_popup_constellations.visible: 
		hide_navbars()
#		ui_paths.touch_button_constellations.pressed = false
		ui_paths.touch_button_systems.pressed = false
		ui_paths.touch_button_stars.pressed = false
		ui_paths.touch_button_planets.pressed = false
		ui_paths.touch_button_structures.pressed = false
		ui_paths.touch_nav_popup_constellations.show()
	else: 
		ui_paths.touch_nav_popup_constellations.hide()


func _on_Button_systems_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.touch_nav_popup_systems.visible: 
		hide_navbars()
		ui_paths.touch_button_constellations.pressed = false
#		ui_paths.touch_button_systems.pressed = false
		ui_paths.touch_button_stars.pressed = false
		ui_paths.touch_button_planets.pressed = false
		ui_paths.touch_button_structures.pressed = false
		ui_paths.touch_nav_popup_systems.show()
	else: 
		ui_paths.touch_nav_popup_systems.hide()


func _on_Button_stars_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.touch_nav_popup_stars.visible: 
		hide_navbars()
		ui_paths.touch_button_constellations.pressed = false
		ui_paths.touch_button_systems.pressed = false
#		ui_paths.touch_button_stars.pressed = false
		ui_paths.touch_button_planets.pressed = false
		ui_paths.touch_button_structures.pressed = false
		ui_paths.touch_nav_popup_stars.show()
	else: 
		ui_paths.touch_nav_popup_stars.hide()


func _on_Button_planets_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.touch_nav_popup_planets.visible: 
		hide_navbars()
		ui_paths.touch_button_constellations.pressed = false
		ui_paths.touch_button_systems.pressed = false
		ui_paths.touch_button_stars.pressed = false
#		ui_paths.touch_button_planets.pressed = false
		ui_paths.touch_button_structures.pressed = false
		ui_paths.touch_nav_popup_planets.show()
	else: 
		ui_paths.touch_nav_popup_planets.hide()
	

func _on_Button_structures_toggled(button_pressed):
	Signals.emit_signal("sig_fetch_markers")
	if button_pressed and not ui_paths.touch_nav_popup_structures.visible: 
		hide_navbars()
		ui_paths.touch_button_constellations.pressed = false
		ui_paths.touch_button_systems.pressed = false
		ui_paths.touch_button_stars.pressed = false
		ui_paths.touch_button_planets.pressed = false
#		ui_paths.touch_button_structures.pressed = false
		ui_paths.touch_nav_popup_structures.show()
	else: 
		ui_paths.touch_nav_popup_structures.hide()


func _on_Button_autopilot_toggled(button_pressed):
	if button_pressed:
		Signals.emit_signal("sig_autopilot_start")
	else:
		Signals.emit_signal("sig_autopilot_disable")
		
		
# Virtual stick.
func _on_Stick_pressed():
	GlobalInput.stick_held = true

func _on_Stick_released():
	GlobalInput.stick_held = false
	
# Touchscreen controls.
func _on_Touch_accel_plus_pressed():
	Signals.emit_signal("sig_accelerate", true)

func _on_Touch_accel_minus_pressed():
	Signals.emit_signal("sig_accelerate", false)

func _on_Touch_ekill_pressed():
	Signals.emit_signal("sig_engine_kill")
		
func is_autopilot_disable():
	ui_paths.touch_button_autopilot.pressed = false
		
	
func _on_Button_info_toggled(button_pressed):
	if button_pressed: 
		ui_paths.touch_info_popup.show()
	else: 
		ui_paths.touch_info_popup.hide()


func _on_Button_PLACEHOLDER4_toggled(button_pressed):
	if button_pressed and not ui_paths.touch_ship_popup.visible: 
		ui_paths.touch_ship_popup.show()
	else: 
		ui_paths.touch_ship_popup.hide()


func _on_Throttle_slider_pressed():
	GlobalInput.throttle_held = true


func _on_Throttle_slider_released():
	GlobalInput.throttle_held = false


