extends Control

func _process(_delta):
	# Connect the UI with the data.
	if GameOptions.touchscreen_mode:
		UiPaths.touch_velocity_panel_apparent_velocity.text = UiPaths.common_readouts.apparent_velocity
		UiPaths.touch_velocity_panel_apparent_velocity_units.text = UiPaths.common_readouts.apparent_velocity_units
		UiPaths.touch_velocity_panel_accel_ticks.text = UiPaths.common_readouts.accel_ticks
	else:
		UiPaths.desktop_velocity_panel_apparent_velocity.text = UiPaths.common_readouts.apparent_velocity
		UiPaths.desktop_velocity_panel_apparent_velocity_units.text = UiPaths.common_readouts.apparent_velocity_units
		UiPaths.desktop_velocity_panel_accel_ticks.text = UiPaths.common_readouts.accel_ticks
