extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")

func _ready():
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================


# INIT
func init_gui():
	# Initialize windows in switched off mode to match button states.
	Signals.emit_signal("sig_game_paused", true)
	
	# Check if resume button must be enabled.
	is_game_started()
	is_viewport_update()
	
	# Start with options window.
	options_gui_show()

	# Hide all the gameplay elements and UI for now.
	gameplay_gui_hide()
	touchscreen_gui_hide()
	desktop_gui_hide()
	debug_gui_hide()
	
	
# GLOBAL GUI SWITCHING.
func switch_to_desktop_gui():
	if not GameState.game_started: Signals.emit_signal("sig_game_started", true)
	Signals.emit_signal("sig_game_paused", false)
	GameState.touchscreen_mode = false
	# Switch the button for GUI changing.
	ui_paths.options_tab_options_general_button_desktop_gui.pressed = true
	ui_paths.options_tab_options_general_button_touch_gui.pressed = false
	gameplay_gui_show()
	desktop_gui_show()
	options_gui_hide()
	options_prompt_start_hide()
	options_prompt_start_confirm_hide()
	touchscreen_gui_hide()
	is_game_started()
	is_viewport_update()
	
	
func switch_to_touchscreen_gui():
	if not GameState.game_started: Signals.emit_signal("sig_game_started", true)
	Signals.emit_signal("sig_game_paused", false)
	GameState.touchscreen_mode = true
	# Switch the button for GUI changing.
	ui_paths.options_tab_options_general_button_desktop_gui.pressed = false
	ui_paths.options_tab_options_general_button_touch_gui.pressed = true
	gameplay_gui_show()
	touchscreen_gui_show()
	options_gui_hide()
	options_prompt_start_hide()
	options_prompt_start_confirm_hide()
	desktop_gui_hide()
	ui_paths.common_touchscreen_pad.recenter_stick()
	ui_paths.common_touchscreen_throttle.recenter_throttle()
	is_controls_swapped()
	is_game_started()
	is_viewport_update()


func switch_to_options_gui():
	Signals.emit_signal("sig_game_paused", true)
	touchscreen_gui_hide()
	desktop_gui_hide()
	gameplay_gui_hide()
	options_gui_show()
	is_viewport_update()
	
	
func resume_game():
	if GameState.game_started and GameState.touchscreen_mode:
		switch_to_touchscreen_gui()
	elif GameState.game_started and not GameState.touchscreen_mode:
		switch_to_desktop_gui()
	else:
		switch_to_options_gui()
		
	
func switch_to_touchscreen_controls_unswapped():
	GameState.touchscreen_controls_swapped = false
	print("Controls unswapped")
	

func switch_to_touchscreen_controls_swapped():
	GameState.touchscreen_controls_swapped = true
	print("Controls swapped")
	

func is_controls_swapped():
	if GameState.touchscreen_controls_swapped:
		ui_paths.touch_touch_throttle_base.margin_left = 80
		ui_paths.touch_touch_throttle_base.margin_right = 480
		ui_paths.touch_touch_throttle_base.anchor_left = 0
		ui_paths.touch_touch_throttle_base.anchor_right = 0
		
		ui_paths.touch_touch_pad_base.margin_left = -480
		ui_paths.touch_touch_pad_base.margin_right = -80
		ui_paths.touch_touch_pad_base.anchor_left = 1
		ui_paths.touch_touch_pad_base.anchor_right = 1
	else:
		ui_paths.touch_touch_pad_base.margin_left = 80
		ui_paths.touch_touch_pad_base.margin_right = 480
		ui_paths.touch_touch_pad_base.anchor_left = 0
		ui_paths.touch_touch_pad_base.anchor_right = 0
		
		ui_paths.touch_touch_throttle_base.margin_left = -480
		ui_paths.touch_touch_throttle_base.margin_right = -80
		ui_paths.touch_touch_throttle_base.anchor_left = 1
		ui_paths.touch_touch_throttle_base.anchor_right = 1
	
	# Call this after swapping.
	is_viewport_update()


func is_game_started():
	if GameState.game_started:
		ui_paths.options_button_resume.disabled = false
	else:
		ui_paths.options_button_resume.disabled = true
		

# SERVICE
# Service functions, in case we need some more complex behavior than just 'hide'
func touchscreen_gui_hide():
	ui_paths.touch_gui.hide()
	
func touchscreen_gui_show():
	ui_paths.touch_gui.show()

func options_gui_hide():
	ui_paths.options_gui.hide()

func options_gui_show():
	ui_paths.options_gui.show()

func options_prompt_start_hide():
	ui_paths.options_prompt_start.hide()

func options_prompt_start_show():
	ui_paths.options_prompt_start.show()

func options_prompt_start_confirm_hide():
	ui_paths.options_prompt_start_confirm.hide()

func options_prompt_start_confirm_show():
	ui_paths.options_prompt_start_confirm.show()

func desktop_gui_hide():
	ui_paths.desktop_mouse_area.hide()
	ui_paths.desktop_gui.hide()
	
func desktop_gui_show():
	ui_paths.desktop_mouse_area.show()
	ui_paths.desktop_gui.show()

func gameplay_gui_hide():
	ui_paths.touch_readings.hide()

func gameplay_gui_show():
	ui_paths.touch_readings.show()

func debug_gui_hide():
	ui_paths.touch_readings_debug.hide()
	ui_paths.desktop_readings_debug.hide()

func debug_gui_show():
	ui_paths.touch_readings_debug.show()
	ui_paths.desktop_readings_debug.show()

func target_controls_hide():
	ui_paths.touch_readings_target_aim.hide()
	ui_paths.desktop_readings_target_aim.hide()

func target_controls_show():
	ui_paths.touch_readings_target_aim.show()
	ui_paths.desktop_readings_target_aim.show()
	
func autopilot_controls_hide():
	ui_paths.touch_readings_target_autopilot.hide()
	ui_paths.desktop_readings_target_autopilot.hide()
	
func autopilot_controls_show():
	ui_paths.touch_readings_target_autopilot.show()
	ui_paths.desktop_readings_target_autopilot.show()


# VIEWPORT UPDATING
func is_viewport_update():
	var ratio_height = OS.window_size.y/ProjectSettings.get_setting("display/window/size/height")
	var ratio_width = OS.window_size.x/ProjectSettings.get_setting("display/window/size/width")
	ui_paths.ui.scale = Vector2(ratio_width, ratio_height)
	# Calculate reverse scale, but make sure 1/0 is not happening.
	GameState.ui_reverse_scale = Vector2(
		1.0/max(ui_paths.ui.scale.x, 1e-6), 
		1.0/max(ui_paths.ui.scale.y, 1e-6))
	# Save data in the state for other use.
	GameState.ui_scale = ui_paths.ui.scale
	GameState.touch_touch_pad_base_rect_position = ui_paths.touch_touch_pad_base.rect_position
	GameState.touch_touch_pad_base_rect_size = ui_paths.touch_touch_pad_base.rect_size
	GameState.touch_touch_throttle_base_rect_position = ui_paths.touch_touch_throttle_base.rect_position
	GameState.touch_touch_throttle_base_rect_size = ui_paths.touch_touch_throttle_base.rect_size
	
	# Restore the proportions of the controls.
	restore_proportions(ui_paths.touch_bar_ship)
	restore_proportions(ui_paths.touch_bar_control)
	restore_proportions(ui_paths.touch_bar_control_2)
	restore_proportions(ui_paths.touch_bar_nav)
	restore_proportions(ui_paths.touch_bar_menu)
	restore_proportions(ui_paths.touch_bar_menu_2)
	restore_proportions(ui_paths.touch_touch_throttle_base)
	restore_proportions(ui_paths.touch_touch_pad_base)
	restore_proportions(ui_paths.touch_velocity_panel)
	restore_proportions(ui_paths.touch_status_panel)
	restore_proportions(ui_paths.touch_readings_target_autopilot)
	restore_proportions(ui_paths.touch_readings_target_aim)
	
	#restore_proportions(ui_paths.desktop_mouse_area)
	restore_proportions(ui_paths.desktop_bar_ship)
	restore_proportions(ui_paths.desktop_bar_control)
	restore_proportions(ui_paths.desktop_bar_control_2)
	restore_proportions(ui_paths.desktop_bar_nav)
	restore_proportions(ui_paths.desktop_bar_menu)
	restore_proportions(ui_paths.desktop_bar_menu_2)
	restore_proportions(ui_paths.desktop_velocity_panel)
	restore_proportions(ui_paths.desktop_status_panel)
	restore_proportions(ui_paths.desktop_readings_target_autopilot)
	restore_proportions(ui_paths.desktop_readings_target_aim)
	
	restore_proportions(ui_paths.options_buttons_general_bar)
	restore_proportions(ui_paths.options_tab_options_general)
	restore_proportions(ui_paths.options_tab_options_graphic)
	restore_proportions(ui_paths.options_tab_options_audio)
	restore_proportions(ui_paths.options_tab_info)
	restore_proportions(ui_paths.options_prompt_start)
	

func restore_proportions(c):
	c.rect_pivot_offset.x = c.rect_size.x/2
	c.rect_pivot_offset.y = c.rect_size.y/2
	c.rect_scale = GameState.ui_reverse_scale/GameState.ui_reverse_scale.y


# Restore the window, provide margins as if it was a FHD resolution.
# TODO: how?
func restore_proportions_with_margins(c):
	c.rect_pivot_offset.x = c.rect_size.x/2
	c.rect_pivot_offset.y = c.rect_size.y/2
	c.rect_scale = GameState.ui_reverse_scale/GameState.ui_reverse_scale.y
	c.rect_size.x = 1920*GameState.ui_reverse_scale.x/GameState.ui_reverse_scale.y


# GUI PANIC POPUP WINDOW.
func popup_panic(message):
	var panic_screen = ui_paths.popup_panic_gui
	var panic_message = panic_screen.get_node("Panic_message")
	panic_screen.popup()
	panic_message.text = message
	# Also write down the message into console.
	var div = "\n\n============================= P A N I C =============================\n\n"
	print(div + message + div)
	# Pause the game and prompt exit with the button.
	get_tree().paused = true