extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")

func _ready():
	# Options button bar buttons.
	ui_paths.options_button_info.text = tr("BUTTON_INFO")
	ui_paths.options_button_options_audio.text = tr("BUTTON_OPTIONS_AUDIO")
	ui_paths.options_button_options_graphic.text = tr("BUTTON_OPTIONS_GRAPHIC")
	ui_paths.options_button_options_general.text = tr("BUTTON_OPTIONS_GENERAL")
	ui_paths.options_button_resume.text = tr("BUTTON_RESUME")
	ui_paths.options_button_start.text = tr("BUTTON_START")
	ui_paths.options_button_quit.text = tr("BUTTON_QUIT")
	ui_paths.options_tab_options_general_button_desktop_gui.get_node("Label").text = tr("BUTTON_DESKTOP_GUI")
	ui_paths.options_tab_options_general_button_touch_gui.get_node("Label").text = tr("BUTTON_TOUCH_GUI")
	ui_paths.options_tab_options_general_button_touch_swap_controls.get_node("Label").text = tr("BUTTON_TOUCH_SWAP_CONTROLS")
	ui_paths.options_tab_options_general_button_debug.text = tr("BUTTON_DEBUG")
	ui_paths.options_graphic_color_presets.get_node("Label").text = tr("LABEL_GUI_COLOR")
	ui_paths.options_graphic_slider_screen_res.get_node("Label").text = tr("LABEL_SCREEN_RES")
	ui_paths.options_graphic_slider_color_power.get_node("Label").text = tr("LABEL_GUI_COLOR_POWER")
	
	ui_paths.options_prompt_start_label.text = tr("LABEL_START_PROMPT")
	ui_paths.options_prompt_start_desktop_gui.get_node("Label").text = tr("BUTTON_DESKTOP_GUI")
	ui_paths.options_prompt_start_touch_gui.get_node("Label").text = tr("BUTTON_TOUCH_GUI")
	
	ui_paths.options_prompt_start_confirm.get_node("Label").text = tr("LABEL_START_CONFIRM")
	ui_paths.options_prompt_start_confirm_button.text = tr("BUTTON_START_CONFIRM")	
	
	ui_paths.options_info_target.text = tr("LABEL_INFO_TARGET")
	ui_paths.options_info_autopilot.text = tr("LABEL_INFO_AUTOPILOT")
	ui_paths.options_info_options.text = tr("LABEL_INFO_OPTIONS")
	ui_paths.options_info_gui_opacity.text = tr("LABEL_INFO_GUI_OPACITY")
	ui_paths.options_info_turret_camera.text = tr("LABEL_INFO_TURRET_CAMERA")
	ui_paths.options_info_nav_nebula.text = tr("LABEL_INFO_NAV_NEBULA")
	ui_paths.options_info_nav_system.text = tr("LABEL_INFO_NAV_SYSTEM")
	ui_paths.options_info_nav_star.text = tr("LABEL_INFO_NAV_STAR")
	ui_paths.options_info_nav_planet.text = tr("LABEL_INFO_NAV_PLANET")
	ui_paths.options_info_nav_object.text = tr("LABEL_INFO_NAV_OBJECT")
	ui_paths.options_info_ship.text = tr("LABEL_INFO_SHIP")



