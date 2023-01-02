extends Node

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# Options button bar buttons.
	p.ui_paths.options_button_info.text = tr("BUTTON_INFO")
	p.ui_paths.options_button_options_audio.text = tr("BUTTON_OPTIONS_AUDIO")
	p.ui_paths.options_button_options_graphic.text = tr("BUTTON_OPTIONS_GRAPHIC")
	p.ui_paths.options_button_options_general.text = tr("BUTTON_OPTIONS_GENERAL")
	p.ui_paths.options_button_resume.text = tr("BUTTON_RESUME")
	p.ui_paths.options_button_start.text = tr("BUTTON_START")
	p.ui_paths.options_button_quit.text = tr("BUTTON_QUIT")
