extends Node

onready var p = get_tree().get_root().get_node("Main/Paths")

var touchscreen_controls_swapped = false

# INIT
func init_gui():
	# Initialize windows in switched off mode to match button states.
	prompt_gui_show()
	gameplay_gui_hide()
	debug_gui_hide()
	
	touchscreen_FHD_gui_hide()
	touchscreen_FHD_options_hide()
	desktop_gui_hide()
	desktop_options_hide()
	
	
	
	
# GLOBAL GUI SWITCHING.
func switch_to_desktop_gui():
	gameplay_gui_show()
	desktop_gui_show()
	
	desktop_options_hide()
	prompt_gui_hide()
	touchscreen_FHD_gui_hide()
	touchscreen_FHD_options_hide()
	
func switch_to_desktop_options():
	desktop_gui_hide()
	gameplay_gui_hide()
	
	desktop_options_show()
	
	
func switch_to_touchscreen_FHD_gui():
	gameplay_gui_show()
	touchscreen_FHD_gui_show()
	is_controls_swapped()
	
	touchscreen_FHD_options_hide()
	prompt_gui_hide()
	desktop_gui_hide()
	desktop_options_hide()

func switch_to_touchscreen_FHD_options():
	touchscreen_FHD_gui_hide()
	gameplay_gui_hide()
	
	touchscreen_FHD_options_show()
	
func switch_to_touchscreen_controls_unswapped():
	touchscreen_controls_swapped = false
	print("unswapped")

func switch_to_touchscreen_controls_swapped():
	touchscreen_controls_swapped = true
	print("swapped")

# TOUCHSCREEN FHD
func is_controls_swapped():
	if touchscreen_controls_swapped:
		p.ui_paths.touch_FHD_touch_throttle_base.rect_position = Vector2(80, 520)
		p.ui_paths.touch_FHD_touch_pad_base.rect_position = Vector2(1440, 520)
	else:
		p.ui_paths.touch_FHD_touch_throttle_base.rect_position = Vector2(1440, 520)
		p.ui_paths.touch_FHD_touch_pad_base.rect_position = Vector2(80, 520)


func touchscreen_FHD_gui_hide():
	p.common_game_options.touchscreen_mode = false
	p.ui_paths.touch_FHD_gui.hide()
	
func touchscreen_FHD_gui_show():
	p.common_game_options.touchscreen_mode = true
	p.ui_paths.touch_FHD_gui.show()

func touchscreen_FHD_options_hide():
	p.ui_paths.touch_FHD_options.hide()

func touchscreen_FHD_options_show():
	p.ui_paths.touch_FHD_options.show()


# DESKTOP
func desktop_gui_hide():
	p.ui_paths.desktop_mouse_area.hide()
	p.ui_paths.desktop_gui.hide()
	
func desktop_gui_show():
	p.ui_paths.desktop_mouse_area.show()
	p.ui_paths.desktop_gui.show()

func desktop_options_hide():
	p.ui_paths.desktop_options.hide()

func desktop_options_show():
	p.ui_paths.desktop_options.show()

# GUI GAMEPLAY
func gameplay_gui_hide():
	p.ui_paths.gameplay.hide()

func gameplay_gui_show():
	p.ui_paths.gameplay.show()

# GUI DEBUG
func debug_gui_hide():
	p.ui_paths.debug.hide()

func debug_gui_show():
	p.ui_paths.debug.show()

# GUI SELECT PROMPT
func prompt_gui_hide():
	p.ui_paths.gui_prompt.hide()

func prompt_gui_show():
	p.ui_paths.gui_prompt.show()

# GUI TARGETING
func target_controls_hide():
	p.ui_paths.target_aim.hide()

func target_controls_show():
	p.ui_paths.target_aim.show()
	
# GUI AUTOPILOT
func autopilot_controls_hide():
	p.ui_paths.target_autopilot.hide()
	
func autopilot_controls_show():
	p.ui_paths.target_autopilot.show()

# GUI PANIC POPUP
func popup_panic(message):
	var panic_screen = p.ui_paths.popup_panic
	var panic_message = panic_screen.get_node("Panic_message")
	panic_screen.popup()
	panic_message.text = message
	# Also write down the message into console.
	var div = "\n\n=====================================================================\n\n"
	print(div + message + div)
	# Pause the game and prompt exit with the button.
	get_tree().paused = true
