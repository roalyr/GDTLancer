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
