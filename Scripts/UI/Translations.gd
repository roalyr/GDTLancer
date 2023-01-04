extends Node

func _ready():
	# Options button bar buttons.
	UiPaths.options_button_info.text = tr("BUTTON_INFO")
	UiPaths.options_button_options_audio.text = tr("BUTTON_OPTIONS_AUDIO")
	UiPaths.options_button_options_graphic.text = tr("BUTTON_OPTIONS_GRAPHIC")
	UiPaths.options_button_options_general.text = tr("BUTTON_OPTIONS_GENERAL")
	UiPaths.options_button_resume.text = tr("BUTTON_RESUME")
	UiPaths.options_button_start.text = tr("BUTTON_START")
	UiPaths.options_button_quit.text = tr("BUTTON_QUIT")
