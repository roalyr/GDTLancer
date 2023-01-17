extends Control

onready var ui_paths = get_node("/root/Main/UI_paths")

func _process(_delta):
	# Connect the UI with the data.
	if GameState.touchscreen_mode:
		ui_paths.touch_velocity_panel_apparent_velocity.text = ui_paths.common_readouts.apparent_velocity
		ui_paths.touch_velocity_panel_apparent_velocity_units.text = ui_paths.common_readouts.apparent_velocity_units
		ui_paths.touch_velocity_panel_accel_ticks.text = ui_paths.common_readouts.accel_ticks
	else:
		ui_paths.desktop_velocity_panel_apparent_velocity.text = ui_paths.common_readouts.apparent_velocity
		ui_paths.desktop_velocity_panel_apparent_velocity_units.text = ui_paths.common_readouts.apparent_velocity_units
		ui_paths.desktop_velocity_panel_accel_ticks.text = ui_paths.common_readouts.accel_ticks
