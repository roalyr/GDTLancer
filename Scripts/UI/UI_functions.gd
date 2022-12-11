extends Node

onready var p = get_tree().get_root().get_node("Main/Paths")

# INIT
func init_gui():
	# Initialize windows in switched off mode to match button states.
	select_gui_prompt_show()
	touchscreen_gui_hide()
	desktop_gui_hide()
	gameplay_gui_hide()
	debug_gui_hide()
	
	# Test.
	#popup_panic("Test panic msg")

# GUI TOUCHSCREEN
func touchscreen_gui_hide():
	p.ui_paths.touch_FHD_gui.hide()
	p.ui_paths.touch_FHD_nav_popup_constellations.hide()
	p.ui_paths.touch_FHD_nav_popup_systems.hide()
	p.ui_paths.touch_FHD_nav_popup_stars.hide()
	p.ui_paths.touch_FHD_nav_popup_planets.hide()
	p.ui_paths.touch_FHD_nav_popup_structures.hide()
	p.ui_paths.gui_window_options.hide()
	target_controls_hide()
	
func touchscreen_gui_show():
	p.ui_paths.touch_FHD_gui.show()
	# Always hide initially.
	p.ui_paths.touch_FHD_nav_popup_constellations.hide()
	p.ui_paths.touch_FHD_nav_popup_systems.hide()
	p.ui_paths.touch_FHD_nav_popup_stars.hide()
	p.ui_paths.touch_FHD_nav_popup_planets.hide()
	p.ui_paths.touch_FHD_nav_popup_structures.hide()
	p.ui_paths.gui_window_options.hide()
	target_controls_hide() # Always hide initially.

# GUI DESKTOP
func desktop_gui_hide():
	p.ui_paths.desktop_mouse_area.hide()
	p.ui_paths.desktop_gui.hide()
	p.ui_paths.desktop_nav_popup_constellations.hide()
	p.ui_paths.desktop_nav_popup_systems.hide()
	p.ui_paths.desktop_nav_popup_stars.hide()
	p.ui_paths.desktop_nav_popup_planets.hide()
	p.ui_paths.desktop_nav_popup_structures.hide()
	
	p.ui_paths.gui_window_options.hide()
	target_controls_hide()
	
func desktop_gui_show():
	p.ui_paths.desktop_mouse_area.show()
	p.ui_paths.desktop_gui.show()
	# Always hide initially.
	p.ui_paths.desktop_nav_popup_constellations.hide()
	p.ui_paths.desktop_nav_popup_systems.hide()
	p.ui_paths.desktop_nav_popup_stars.hide()
	p.ui_paths.desktop_nav_popup_planets.hide()
	p.ui_paths.desktop_nav_popup_structures.hide()
	p.ui_paths.gui_window_options.hide() # Always hide initially.
	target_controls_hide() # Always hide initially.	

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
func select_gui_prompt_hide():
	p.ui_paths.gui_prompt.hide()

func select_gui_prompt_show():
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
