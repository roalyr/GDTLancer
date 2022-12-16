extends Node

# GLOBAL PATHS 
onready var p = get_tree().get_root().get_node("Main/Paths")
# Logic node
onready var ui_functions = p.ui.get_node("UI_functions")
# Common
onready var common = p.ui.get_node("Common")
onready var common_touchscreen_pad = common.get_node("Touchscreen_pad")
onready var common_touchscreen_throttle = common.get_node("Touchscreen_throttle")
onready var common_readouts = common.get_node("Readouts")
onready var common_debug = common.get_node("Debug")


# Desktop UI
onready var desktop_gui = p.ui.get_node("GUI_desktop")
onready var desktop_options = p.ui.get_node("GUI_desktop_options")
onready var desktop_mouse_area = desktop_gui.get_node("Mouse_area")
# Menu bar
onready var desktop_bar_menu = desktop_gui.get_node("Bar_menu")
onready var desktop_button_options = desktop_bar_menu.get_node("Button_options")
onready var desktop_button_turret = desktop_bar_menu.get_node("Button_turret")
onready var desktop_button_hide_ui = desktop_bar_menu.get_node("Button_hide_ui")
# Nav bar
onready var desktop_bar_nav = desktop_gui.get_node("Bar_nav")
# Nav bar popup lists
onready var desktop_nav_popup_constellations = desktop_bar_nav.get_node("Popup_nav_constellations")
onready var desktop_nav_list_constellations = desktop_nav_popup_constellations.get_node("ItemList_nav")
onready var desktop_nav_popup_systems = desktop_bar_nav.get_node("Popup_nav_systems")
onready var desktop_nav_list_systems = desktop_nav_popup_systems.get_node("ItemList_nav")
onready var desktop_nav_popup_stars = desktop_bar_nav.get_node("Popup_nav_stars")
onready var desktop_nav_list_stars = desktop_nav_popup_stars.get_node("ItemList_nav")
onready var desktop_nav_popup_planets = desktop_bar_nav.get_node("Popup_nav_planets")
onready var desktop_nav_list_planets = desktop_nav_popup_planets.get_node("ItemList_nav")
onready var desktop_nav_popup_structures = desktop_bar_nav.get_node("Popup_structures")
onready var desktop_nav_list_structures = desktop_nav_popup_structures.get_node("ItemList_nav")
# Nav bar buttons
onready var desktop_button_constellations = desktop_bar_nav.get_node("Button_constellations")
onready var desktop_button_systems = desktop_bar_nav.get_node("Button_systems")
onready var desktop_button_stars = desktop_bar_nav.get_node("Button_stars")
onready var desktop_button_planets = desktop_bar_nav.get_node("Button_planets")
onready var desktop_button_structures = desktop_bar_nav.get_node("Button_structures")
# Control bar
onready var desktop_bar_control = desktop_gui.get_node("Bar_control")
onready var desktop_button_target_aim_clear = desktop_bar_control.get_node("Button_target_aim_clear")
onready var desktop_button_autopilot = desktop_bar_control.get_node("Button_autopilot")
# Ship bar
onready var desktop_bar_ship = desktop_gui.get_node("Bar_ship_PLACEHOLDER")
onready var desktop_ship_popup = desktop_bar_ship.get_node("Popup_PLACEHOLDER")


# Touchscreen Full-HD UI
onready var touch_gui = p.ui.get_node("GUI_touchscreen")
onready var touch_options = p.ui.get_node("GUI_touchscreen_options")
# Menu bar
onready var touch_bar_menu = touch_gui.get_node("Bar_menu")
onready var touch_button_options = touch_bar_menu.get_node("Button_options")
onready var touch_button_turret = touch_bar_menu.get_node("Button_turret")
onready var touch_button_hide_ui = touch_bar_menu.get_node("Button_hide_ui")
# Nav bar
onready var touch_bar_nav = touch_gui.get_node("Bar_nav")
# Nav bar popup lists
onready var touch_nav_popup_constellations = touch_bar_nav.get_node("Popup_nav_constellations")
onready var touch_nav_list_constellations = touch_nav_popup_constellations.get_node("ItemList_nav")
onready var touch_nav_popup_systems = touch_bar_nav.get_node("Popup_nav_systems")
onready var touch_nav_list_systems = touch_nav_popup_systems.get_node("ItemList_nav")
onready var touch_nav_popup_stars = touch_bar_nav.get_node("Popup_nav_stars")
onready var touch_nav_list_stars = touch_nav_popup_stars.get_node("ItemList_nav")
onready var touch_nav_popup_planets = touch_bar_nav.get_node("Popup_nav_planets")
onready var touch_nav_list_planets = touch_nav_popup_planets.get_node("ItemList_nav")
onready var touch_nav_popup_structures = touch_bar_nav.get_node("Popup_structures")
onready var touch_nav_list_structures = touch_nav_popup_structures.get_node("ItemList_nav")
# Nav bar buttons
onready var touch_button_constellations = touch_bar_nav.get_node("Button_constellations")
onready var touch_button_systems = touch_bar_nav.get_node("Button_systems")
onready var touch_button_stars = touch_bar_nav.get_node("Button_stars")
onready var touch_button_planets = touch_bar_nav.get_node("Button_planets")
onready var touch_button_structures = touch_bar_nav.get_node("Button_structures")
# Control bar
onready var touch_bar_control = touch_gui.get_node("Bar_control")
onready var touch_button_target_aim_clear = touch_bar_control.get_node("Button_target_aim_clear")
onready var touch_button_autopilot = touch_bar_control.get_node("Button_autopilot")
# Ship bar
onready var touch_bar_ship = touch_gui.get_node("Bar_ship_PLACEHOLDER")
onready var touch_ship_popup = touch_bar_ship.get_node("Popup_PLACEHOLDER")
# Control area
onready var touch_control_area = touch_gui.get_node("Controls_area")
onready var touch_touch_pad_base = touch_control_area.get_node("Touch_pad_base")
onready var touch_touch_pad_stick = touch_touch_pad_base.get_node("Stick")
onready var touch_touch_throttle_base = touch_control_area.get_node("Touch_throttle_base")
onready var touch_touch_throttle = touch_touch_throttle_base.get_node("Throttle")
# Readings
onready var touch_readings = p.ui.get_node("GUI_touchscreen_readings")
onready var touch_readings_debug = touch_readings.get_node("Debug")
onready var touch_readings_target_autopilot = touch_readings.get_node("Target_autopilot")
onready var touch_readings_target_aim = touch_readings.get_node("Target_aim")
# Readings top area
onready var touch_top_readings = touch_readings.get_node("Top_readings")
onready var touch_top_readings_apparent_velocity = touch_top_readings.get_node("Apparent_velocity")
onready var touch_top_readings_apparent_velocity_units = touch_top_readings.get_node("Apparent_velocity_units")
onready var touch_top_readings_accel_ticks = touch_top_readings.get_node("Accel_ticks")

# Other windows
onready var gui_prompt = p.ui.get_node("GUI_prompt_greeting")
onready var popup_panic = p.ui.get_node("GUI_popup_panic")
#onready var gui_window_options = p.ui.get_node("GUI_window_options")
