# File: autoload/EventBus.gd
# Version: 1.1 Added target picking.

extends Node

# --- Game State Signals ---
signal game_loaded(save_data)
# signal game_saving(slot_id)
# signal save_complete(slot_id, success)

# --- Agent Lifecycle Signals ---
# Emitted by WorldManager after agent initialized and added to tree
# init_data parameter is now Dictionary {"template": Res, "overrides": Dict}
signal agent_spawned(agent_body, init_data)
# Emitted by Agent's despawn() method via EventBus BEFORE queue_free
signal agent_despawning(agent_body)
# Emitted by AI Controller via EventBus when destination reached
signal agent_reached_destination(agent_body)
# Emitted by WorldManager after player specifically spawned
signal player_spawned(player_agent_body)

# --- Camera Control Signals ---
# Emitted by systems requesting camera target change
signal camera_set_target_requested(target_node)
# Emitted by input handlers requesting target cycle (KEEPING for potential future use)
signal camera_cycle_target_requested

# --- Player Interaction Signals --- ADDED SECTION
signal player_target_selected(target_node)
signal player_target_deselected
signal player_free_flight_toggled
signal player_stop_pressed
signal player_orbit_pressed
signal player_approach_pressed
signal player_flee_pressed
signal player_camera_zoom_changed(value)
signal player_ship_speed_changed(value)

# --- Zone Loading Signals ---
# Emitted by WorldManager before unloading current zone instance
signal zone_unloading(zone_node)  # zone_node is the root of the scene being unloaded
# Emitted by WorldManager when starting to load a new zone path
signal zone_loading(zone_path)  # zone_path is path to the complete zone scene
# Emitted by WorldManager after new zone is instanced, added, container found
# zone_node is root of the new zone instance, agent_container_node is ref inside it
signal zone_loaded(zone_node, zone_path, agent_container_node)

# --- Core Mechanics / Gameplay Events (Placeholders) ---
# signal action_check_resolved(agent_body, result_dictionary, action_approach)
# signal focus_changed(agent_body, new_focus_value)
# signal wealth_changed(agent_body, new_wealth_value)
signal world_event_tick_triggered

# --- Goal System Events (Placeholders) ---
# signal goal_progress_updated(agent_body, goal_id, new_progress)
# signal goal_completed(agent_body, goal_id, success_level)

# --- Module Specific Signals (Placeholders - Use sparingly) ---
# signal major_discovery_made(discovery_data)


func _ready():
	print("EventBus Ready.")
