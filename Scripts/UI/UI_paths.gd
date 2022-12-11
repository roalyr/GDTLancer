extends Node

# GLOBAL PATHS 
onready var p = get_tree().get_root().get_node("Main/Paths")
# Logic node
onready var ui_functions = p.ui.get_node("UI_functions")
# Common
onready var common = p.ui.get_node("Common")
onready var common_mobile_buttons = common.get_node("Mobile_buttons")
onready var common_touchscreen_pad = common.get_node("Touchscreen_pad")
onready var common_desktop_buttons = common.get_node("Desktop_buttons")
onready var common_readouts = common.get_node("Readouts")
onready var common_debug = common.get_node("Debug")


# Desktop UI
onready var desktop_gui = p.ui.get_node("GUI_desktop")
onready var desktop_options = p.ui.get_node("Window_desktop_options")
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


# Touchscreen Full-HD UI
onready var touch_FHD_gui = p.ui.get_node("GUI_touchscreen_FHD")
onready var touch_FHD_options = p.ui.get_node("Window_touchscreen_FHD_options")
# Menu bar
onready var touch_FHD_bar_menu = touch_FHD_gui.get_node("Bar_menu")
onready var touch_FHD_button_options = touch_FHD_bar_menu.get_node("Button_options")
onready var touch_FHD_button_turret = touch_FHD_bar_menu.get_node("Button_turret")
onready var touch_FHD_button_hide_ui = touch_FHD_bar_menu.get_node("Button_hide_ui")
# Nav bar
onready var touch_FHD_nav = touch_FHD_gui.get_node("Bar_nav")
# Nav bar popup lists
onready var touch_FHD_nav_popup_constellations = touch_FHD_nav.get_node("Popup_nav_constellations")
onready var touch_FHD_nav_list_constellations = touch_FHD_nav_popup_constellations.get_node("ItemList_nav")
onready var touch_FHD_nav_popup_systems = touch_FHD_nav.get_node("Popup_nav_systems")
onready var touch_FHD_nav_list_systems = touch_FHD_nav_popup_systems.get_node("ItemList_nav")
onready var touch_FHD_nav_popup_stars = touch_FHD_nav.get_node("Popup_nav_stars")
onready var touch_FHD_nav_list_stars = touch_FHD_nav_popup_stars.get_node("ItemList_nav")
onready var touch_FHD_nav_popup_planets = touch_FHD_nav.get_node("Popup_nav_planets")
onready var touch_FHD_nav_list_planets = touch_FHD_nav_popup_planets.get_node("ItemList_nav")
onready var touch_FHD_nav_popup_structures = touch_FHD_nav.get_node("Popup_structures")
onready var touch_FHD_nav_list_structures = touch_FHD_nav_popup_structures.get_node("ItemList_nav")
# Nav bar buttons
onready var touch_FHD_button_constellations = touch_FHD_nav.get_node("Button_constellations")
onready var touch_FHD_button_systems = touch_FHD_nav.get_node("Button_systems")
onready var touch_FHD_button_stars = touch_FHD_nav.get_node("Button_stars")
onready var touch_FHD_button_planets = touch_FHD_nav.get_node("Button_planets")
onready var touch_FHD_button_structures = touch_FHD_nav.get_node("Button_structures")
# Control bar
onready var touch_FHD_bar_control = touch_FHD_gui.get_node("Bar_control")
onready var touch_FHD_button_target_aim_clear = touch_FHD_bar_control.get_node("Button_target_aim_clear")
onready var touch_FHD_button_autopilot = touch_FHD_bar_control.get_node("Button_autopilot")
# Control area
onready var touch_FHD_control_area = touch_FHD_gui.get_node("Controls_area")
onready var touch_FHD_touch_pad_base = touch_FHD_control_area.get_node("Touch_pad_base")
onready var touch_FHD_touch_pad_stick = touch_FHD_touch_pad_base.get_node("Stick")
onready var touch_FHD_touch_buttons_container = touch_FHD_control_area.get_node("Touch_buttons_container")
onready var touch_FHD_touch_button_ekill = touch_FHD_touch_buttons_container.get_node("Touch_ekill")
onready var touch_FHD_touch_button_accel_minus = touch_FHD_touch_buttons_container.get_node("Touch_accel_minus")
onready var touch_FHD_touch_button_accel_plus = touch_FHD_touch_buttons_container.get_node("Touch_accel_plus")

# Common
# Gameplay UI
onready var gameplay = p.ui.get_node("Gameplay")
onready var debug = gameplay.get_node("Debug")
onready var target_autopilot = gameplay.get_node("Target_autopilot")
onready var target_aim = gameplay.get_node("Target_aim")


# Other windows
onready var gui_prompt = p.ui.get_node("GUI_prompt_greeting")
onready var popup_panic = p.ui.get_node("GUI_popup_panic")
