# EventBus: global signals for decoupled communication between systems and UI.

extends Node

# --- Game lifecycle ---
signal game_state_loaded  # Emitted after GameStateManager restores state
signal new_game_requested
signal main_menu_requested

# --- Agents ---
signal agent_spawned(agent_body, init_data)
signal agent_despawning(agent_body)
signal agent_reached_destination(agent_body)
signal player_spawned(player_agent_body)

# --- Camera ---
signal camera_set_target_requested(target_node)

# --- Player input / targeting ---
signal player_target_selection_requested(target_node)
signal player_target_selected(target_node)
signal player_target_deselected
signal player_free_flight_toggled
signal player_stop_pressed
signal player_orbit_pressed
signal player_approach_pressed
signal player_flee_pressed
signal player_dock_pressed  # Explicit dock button
signal player_interact_pressed  # Interact button: general interaction with the selected target
signal player_tool_pressed(tool_index)  # A tool button: switch that fitted tool on the selected target, or off
signal player_lance_pressed  # The LANCE button: arm the kinetic lance, or make it safe
signal player_camera_zoom_changed(value)
signal player_ship_speed_changed(value)

# --- Zones ---
signal zone_unloading(zone_node)  # zone_node is the root of the scene being unloaded
signal zone_loaded(zone_node, zone_path, agent_container_node)

# --- Combat ---
signal combat_initiated(player_agent, enemy_agents)
signal combat_ended(result_dict)  # result_dict: {outcome: "victory"/"defeat"/"flee", ...}
signal agent_damaged(agent_body, damage_amount, source_agent)
signal agent_disabled(agent_body)  # When hull <= 0

# --- Docking ---
signal dock_available(location_id)  # Player near dockable station
signal dock_unavailable
signal player_docked(location_id)
signal player_undocked
signal dock_action_feedback(success, message)  # Feedback from dock button press
signal attack_action_feedback(success, message)  # Feedback from attack button press

# --- Jumping ---
signal jump_available(target_sector_id, target_sector_name)
signal jump_unavailable
signal player_jump_requested(target_sector_id)
signal sector_changed(new_sector_id, old_sector_id)
