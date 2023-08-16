extends Node

# GLOBAL PATHS 
onready var main = get_parent()
onready var ui = main.get_node("UI")
# Logic node
onready var ui_functions = ui.get_node("UI_functions")
# Common
onready var common = ui.get_node("Common")
onready var common_touchscreen_pad = common.get_node("Touchscreen_pad")
onready var common_touchscreen_throttle = common.get_node("Touchscreen_throttle")
onready var common_readouts = common.get_node("Readouts")
onready var common_debug = common.get_node("Debug")


# Desktop UI
onready var desktop_gui = ui.get_node("GUI_desktop")
onready var desktop_mouse_area = desktop_gui.get_node("Mouse_area_container/Mouse_area")
# Menu bar
onready var desktop_bar_menu = desktop_gui.get_node("Bar_menu")
onready var desktop_button_options = desktop_bar_menu.get_node("Button_options")
# Menu bar 2
onready var desktop_bar_menu_2 = desktop_gui.get_node("Bar_menu_2")
onready var desktop_button_turret = desktop_bar_menu_2.get_node("Button_turret")
onready var desktop_button_hide_ui = desktop_bar_menu_2.get_node("Button_hide_ui")
onready var desktop_slider_zoom = desktop_bar_menu_2.get_node("Slider_zoom")
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
# Control bar 2
onready var desktop_bar_control_2 = desktop_gui.get_node("Bar_control_2")
onready var desktop_button_velocity_limiter = desktop_bar_control_2.get_node("Button_velocity_limiter")
# Ship bar
onready var desktop_bar_items = desktop_gui.get_node("Bar_items")
onready var desktop_ship_popup = desktop_bar_items.get_node("Popup_PLACEHOLDER")
# Readings
onready var desktop_readings = desktop_gui.get_node("Readings")
onready var desktop_readings_info_popup = desktop_readings.get_node("Popup_info")
onready var desktop_readings_info_container = desktop_readings_info_popup.get_node("ScrollContainer/LabelContainer")
onready var desktop_readings_info_label = desktop_readings_info_container.get_node("Label")

onready var desktop_readings_debug = desktop_readings.get_node("Debug_panel")
onready var desktop_readings_debug_output = desktop_readings.get_node("Debug_panel/ScrollContainer/VBoxContainer/Print_out")
onready var desktop_readings_target_autopilot = desktop_readings.get_node("Target_autopilot_desktop")
onready var desktop_readings_target_aim = desktop_readings.get_node("Target_aim_desktop")
# Velocity panel area
onready var desktop_velocity_panel = desktop_readings.get_node("Velocity_panel")
onready var desktop_velocity_panel_apparent_velocity = desktop_velocity_panel.get_node("Apparent_velocity")
onready var desktop_velocity_panel_apparent_velocity_units = desktop_velocity_panel.get_node("Apparent_velocity_units")
onready var desktop_velocity_panel_accel_ticks = desktop_velocity_panel.get_node("Accel_ticks")
# Status panel area
onready var desktop_status_panel = desktop_readings.get_node("Status_panel")


# Touchscreen Full-HD UI
onready var touch_gui = ui.get_node("GUI_touchscreen")
# Menu bar
onready var touch_bar_menu = touch_gui.get_node("Bar_menu")
onready var touch_button_options = touch_bar_menu.get_node("Button_options")
# Menu bar 2
onready var touch_bar_menu_2 = touch_gui.get_node("Bar_menu_2")
onready var touch_button_turret = touch_bar_menu_2.get_node("Button_turret")
onready var touch_button_hide_ui = touch_bar_menu_2.get_node("Button_hide_ui")
onready var touch_slider_zoom = touch_bar_menu_2.get_node("Slider_zoom")
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
# Control bar 2
onready var touch_bar_control_2 = touch_gui.get_node("Bar_control_2")
onready var touch_button_velocity_limiter = touch_bar_control_2.get_node("Button_velocity_limiter")
# Ship bar
onready var touch_bar_items = touch_gui.get_node("Bar_items")
onready var touch_ship_popup = touch_bar_items.get_node("Popup_PLACEHOLDER")


# Control area
onready var touch_control_area = touch_gui.get_node("Controls_area")
onready var touch_touch_pad_base = touch_control_area.get_node("Touch_pad_base")
onready var touch_touch_pad_stick = touch_touch_pad_base.get_node("Stick")
#onready var touch_touch_throttle_base = touch_control_area.get_node("Touch_throttle_base")
onready var touch_touch_buttons = touch_control_area.get_node("Touch_buttons")
#onready var touch_touch_throttle = touch_touch_throttle_base.get_node("Throttle")
# Readings
onready var touch_readings = touch_gui.get_node("Readings")
onready var touch_readings_info_popup = touch_readings.get_node("Popup_info")
onready var touch_readings_info_container = touch_readings_info_popup.get_node("ScrollContainer/LabelContainer")
onready var touch_readings_info_label = touch_readings_info_container.get_node("Label")
onready var touch_readings_character_popup = touch_readings.get_node("Popup_character")

onready var touch_readings_debug = touch_readings.get_node("Debug_panel")
onready var touch_readings_target_autopilot = touch_readings.get_node("Target_autopilot_touchscreen")
onready var touch_readings_target_aim = touch_readings.get_node("Target_aim_touchscreen")
# Velocity panel area
onready var touch_velocity_panel = touch_readings.get_node("Velocity_panel")
onready var touch_velocity_panel_apparent_velocity = touch_velocity_panel.get_node("Apparent_velocity")
onready var touch_velocity_panel_apparent_velocity_units = touch_velocity_panel.get_node("Apparent_velocity_units")
onready var touch_velocity_panel_accel_ticks = touch_velocity_panel.get_node("Accel_ticks")
# Status panel area
onready var touch_status_panel = touch_readings.get_node("Status_panel")

# Options
onready var options_gui = ui.get_node("GUI_options")
# Button side bar
onready var options_buttons_general_bar = options_gui.get_node("Buttons_general_bar")
onready var options_button_start = options_buttons_general_bar.get_node("Button_start")
onready var options_button_resume = options_buttons_general_bar.get_node("Button_resume")
onready var options_button_options_general = options_buttons_general_bar.get_node("Button_options_general")
onready var options_button_options_graphic = options_buttons_general_bar.get_node("Button_options_graphic")
onready var options_button_options_audio = options_buttons_general_bar.get_node("Button_options_audio")
onready var options_button_info = options_buttons_general_bar.get_node("Button_info")
onready var options_button_quit = options_buttons_general_bar.get_node("Button_quit")
# Starting prompt
onready var options_prompt_start = options_gui.get_node("Options_prompt_start")
onready var options_prompt_start_label = options_prompt_start.get_node("Label")
onready var options_prompt_start_desktop_gui = options_prompt_start.get_node("Button_desktop_gui")
onready var options_prompt_start_touch_gui = options_prompt_start.get_node("Button_touch_gui")
# Starting prompt confirmation
onready var options_prompt_start_confirm = options_gui.get_node("Options_prompt_start_confirm")
onready var options_prompt_start_confirm_button = options_prompt_start_confirm.get_node("Button_start_confirm")
# General options tab
onready var options_tab_options_general = options_gui.get_node("Options_tab_options_general")
onready var options_tab_options_general_button_desktop_gui = options_tab_options_general.get_node("Button_desktop_gui")
onready var options_tab_options_general_button_touch_gui = options_tab_options_general.get_node("Button_touch_gui")
onready var options_tab_options_general_button_touch_swap_controls = options_tab_options_general.get_node("Button_controls_swap")
onready var options_tab_options_general_button_debug = options_tab_options_general.get_node("Button_debug")
# Graphic options tab
onready var options_tab_options_graphic = options_gui.get_node("Options_tab_options_graphic")
onready var options_graphic_color_presets = options_tab_options_graphic.get_node("Color_presets")
onready var options_graphic_slider_screen_res = options_tab_options_graphic.get_node("Slider_screen_res")
onready var options_graphic_slider_color_power = options_tab_options_graphic.get_node("Slider_color_power")
# Audio options tab
onready var options_tab_options_audio = options_gui.get_node("Options_tab_options_audio")
# Info tab
onready var options_tab_info = options_gui.get_node("Options_tab_info")
onready var options_info_container = options_tab_info.get_node("ScrollContainer/Container")
onready var options_info_target = options_info_container.get_node("HBoxContainer1/Label_info_target")
onready var options_info_autopilot = options_info_container.get_node("HBoxContainer2/Label_info_autopilot")
onready var options_info_options = options_info_container.get_node("HBoxContainer3/Label_info_options")
onready var options_info_gui_opacity = options_info_container.get_node("HBoxContainer4/Label_info_gui_opacity")
onready var options_info_turret_camera = options_info_container.get_node("HBoxContainer5/Label_info_turret_camera")
onready var options_info_nav_nebula = options_info_container.get_node("HBoxContainer6/Label_info_nav_nebula")
onready var options_info_nav_system = options_info_container.get_node("HBoxContainer7/Label_info_nav_system")
onready var options_info_nav_star = options_info_container.get_node("HBoxContainer8/Label_info_nav_star")
onready var options_info_nav_planet = options_info_container.get_node("HBoxContainer9/Label_info_nav_planet")
onready var options_info_nav_object = options_info_container.get_node("HBoxContainer10/Label_info_nav_object")
onready var options_info_ship = options_info_container.get_node("HBoxContainer11/Label_info_ship")










