extends Node

onready var ui_paths = get_node("/root/Main/UI_paths")
# Rename all signals to "sig_<name_action>".
# Emitting functions should be "<name>_is_<action>".
# Receiving functions should be "is_<name_action>".
# Respective state vars should be "state_<name>"

# Have to supress warning because they all flare up.
# warning-ignore-all:unused_signal

# GENERIC
signal sig_mouse_on_control_area(flag)
signal sig_screen_filter_on(flag)
signal sig_render_res_value_changed(value)
signal sig_fov_value_changed(value)
signal sig_viewport_update
signal sig_game_started(flag)
signal sig_game_paused(flag)
signal sig_quit_game
signal sig_language_selected(index)

# UI
signal sig_switch_to_options_gui

# UI MARKERS
signal sig_fetch_markers
signal sig_fetch_object_info

# SPACE OBJECTS SPAWNING
signal sig_system_coordinates_selected(coordinates)
signal sig_system_spawned(system_scene)

# CAMERA
signal sig_turret_mode_on(flag)
signal sig_mouse_flight_on(flag)
signal sig_zoom_value_changed(value)

# SHIP
signal sig_accelerate(flag)
signal sig_engine_kill
signal sig_autopilot_start
signal sig_autopilot_disable
signal sig_target_aim_locked(scene)
signal sig_target_autopilot_locked(scene)
signal sig_target_aim_clear
signal sig_velocity_limiter_set(value)

# LOCAL SPACE TRIGGERS
#signal sig_entered_local_space_galaxy(zone)
#signal sig_exited_local_space_galaxy(zone)
signal sig_entered_local_space_system(zone)
signal sig_exited_local_space_system(zone)
signal sig_entered_local_space_star(zone)
signal sig_exited_local_space_star(zone)
signal sig_entered_local_space_planet(zone)
signal sig_exited_local_space_planet(zone)
signal sig_entered_local_space_structure(zone)
signal sig_exited_local_space_structure(zone)

signal sig_nebula_distance(data)

func connect_checked(signal_name, target, function_name):
	var e = Signals.connect(signal_name, target, function_name)
	var message = "Scene " + str(target.name) + " has failed to connect signal:\n" \
		+ "*  " +signal_name + "\n\nto a function:\n" \
		+ "*  " + function_name
	if e != OK: ui_paths.ui_functions.popup_panic(message)
