extends Control

onready var p = get_tree().get_root().get_node("Main/Paths")

func _process(delta):
	# Connect the UI with the data.
	if p.common_game_options.touchscreen_mode:
		p.ui_paths.touch_top_readings_apparent_velocity.text = p.ui_paths.common_readouts.apparent_velocity
		p.ui_paths.touch_top_readings_apparent_velocity_units.text = p.ui_paths.common_readouts.apparent_velocity_units
		p.ui_paths.touch_top_readings_accel_ticks.text = p.ui_paths.common_readouts.accel_ticks
