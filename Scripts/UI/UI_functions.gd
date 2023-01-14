extends Node

var touchscreen_controls_swapped = false

# INIT
func init_gui():
	# Initialize windows in switched off mode to match button states.
	options_gui_show()
	options_prompt_start_show()
	
	gameplay_gui_hide()
	touchscreen_gui_hide()
	desktop_gui_hide()
	debug_gui_hide()
	
# GLOBAL GUI SWITCHING.
func switch_to_desktop_gui():
	gameplay_gui_show()
	desktop_gui_show()
	options_gui_hide()
	touchscreen_gui_hide()
	
func switch_to_touchscreen_gui():
	gameplay_gui_show()
	touchscreen_gui_show()
	is_controls_swapped()
	options_gui_hide()
	desktop_gui_hide()

func switch_to_options_gui():
	touchscreen_gui_hide()
	desktop_gui_hide()
	gameplay_gui_hide()
	options_gui_show()
	
func switch_to_touchscreen_controls_unswapped():
	touchscreen_controls_swapped = false
	print("unswapped")

func switch_to_touchscreen_controls_swapped():
	touchscreen_controls_swapped = true
	print("swapped")

# TOUCHSCREEN FHD
func is_controls_swapped():
	if touchscreen_controls_swapped:
		UiPaths.touch_touch_throttle_base.margin_left = 80
		UiPaths.touch_touch_throttle_base.margin_right = 480
		UiPaths.touch_touch_throttle_base.anchor_left = 0
		UiPaths.touch_touch_throttle_base.anchor_right = 0
		
		UiPaths.touch_touch_pad_base.margin_left = -480
		UiPaths.touch_touch_pad_base.margin_right = -80
		UiPaths.touch_touch_pad_base.anchor_left = 1
		UiPaths.touch_touch_pad_base.anchor_right = 1
	else:
		UiPaths.touch_touch_pad_base.margin_left = 80
		UiPaths.touch_touch_pad_base.margin_right = 480
		UiPaths.touch_touch_pad_base.anchor_left = 0
		UiPaths.touch_touch_pad_base.anchor_right = 0
		
		UiPaths.touch_touch_throttle_base.margin_left = -480
		UiPaths.touch_touch_throttle_base.margin_right = -80
		UiPaths.touch_touch_throttle_base.anchor_left = 1
		UiPaths.touch_touch_throttle_base.anchor_right = 1


func touchscreen_gui_hide():
	UiPaths.touch_gui.hide()
	
func touchscreen_gui_show():
	UiPaths.touch_gui.show()

# OPTIONS
func options_gui_hide():
	UiPaths.options_gui.hide()

func options_gui_show():
	UiPaths.options_gui.show()

# INITIAL PROMPT
func options_prompt_start_hide():
	UiPaths.options_prompt_start.hide()

func options_prompt_start_show():
	UiPaths.options_prompt_start.show()

func options_prompt_start_confirm_hide():
	UiPaths.options_prompt_start_confirm.hide()

func options_prompt_start_confirm_show():
	UiPaths.options_prompt_start_confirm.show()


# DESKTOP
func desktop_gui_hide():
	UiPaths.desktop_mouse_area.hide()
	UiPaths.desktop_gui.hide()
	
func desktop_gui_show():
	UiPaths.desktop_mouse_area.show()
	UiPaths.desktop_gui.show()

# GUI GAMEPLAY
func gameplay_gui_hide():
	UiPaths.touch_readings.hide()

func gameplay_gui_show():
	UiPaths.touch_readings.show()

# GUI DEBUG
func debug_gui_hide():
	UiPaths.touch_readings_debug.hide()
	UiPaths.desktop_readings_debug.hide()

func debug_gui_show():
	UiPaths.touch_readings_debug.show()
	UiPaths.desktop_readings_debug.show()


# GUI TARGETING
func target_controls_hide():
	UiPaths.touch_readings_target_aim.hide()
	UiPaths.desktop_readings_target_aim.hide()

func target_controls_show():
	UiPaths.touch_readings_target_aim.show()
	UiPaths.desktop_readings_target_aim.show()
	
# GUI AUTOPILOT
func autopilot_controls_hide():
	UiPaths.touch_readings_target_autopilot.hide()
	UiPaths.desktop_readings_target_autopilot.hide()
	
func autopilot_controls_show():
	UiPaths.touch_readings_target_autopilot.show()
	UiPaths.desktop_readings_target_autopilot.show()

# GUI PANIC POPUP
func popup_panic(message):
	var panic_screen = UiPaths.popup_panic_gui
	var panic_message = panic_screen.get_node("Panic_message")
	panic_screen.popup()
	panic_message.text = message
	# Also write down the message into console.
	var div = "\n\n============================= P A N I C =============================\n\n"
	print(div + message + div)
	# Pause the game and prompt exit with the button.
	get_tree().paused = true
