# File: autoload/EventBus.gd
# Version: 1.2 - Added Phase 1 signals for combat, contracts, trading, docking, narrative.

extends Node

# --- Game State Signals ---
signal game_loaded(save_data)
signal game_state_loaded  # Emitted after GameStateManager restores state
# Sprint 10 integration signals
signal new_game_requested
signal main_menu_requested
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
signal player_interact_pressed
signal player_camera_zoom_changed(value)
signal player_ship_speed_changed(value)
signal player_wp_changed(new_wp_value)
signal player_fp_changed(new_fp_value)

# --- Zone Loading Signals ---
# Emitted by WorldManager before unloading current zone instance
signal zone_unloading(zone_node)  # zone_node is the root of the scene being unloaded
# Emitted by WorldManager when starting to load a new zone path
signal zone_loading(zone_path)  # zone_path is path to the complete zone scene
# Emitted by WorldManager after new zone is instanced, added, container found
# zone_node is root of the new zone instance, agent_container_node is ref inside it
signal zone_loaded(zone_node, zone_path, agent_container_node)

# --- Core Mechanics / Gameplay Events ---
signal world_event_tick_triggered(tu_amount)

# --- Combat Signals ---
signal combat_initiated(player_agent, enemy_agents)
signal combat_ended(result_dict)  # result_dict: {outcome: "victory"/"defeat"/"flee", ...}
signal agent_damaged(agent_body, damage_amount, source_agent)
signal agent_disabled(agent_body)  # When hull <= 0

# --- Contract Signals ---
signal contract_accepted(contract_id)
signal contract_completed(contract_id, success)  # success: bool
signal contract_abandoned(contract_id)
signal contract_failed(contract_id)  # e.g., time limit exceeded

# --- Trading Signals ---
signal trade_transaction_completed(transaction_dict)  # {type, commodity_id, quantity, price, ...}

# --- Docking Signals ---
signal dock_available(location_id)  # Player near dockable station
signal dock_unavailable
signal player_docked(location_id)
signal player_undocked

# --- Narrative Action Signals ---
signal narrative_action_requested(action_type, context)  # Shows Action Check UI
signal narrative_action_resolved(result_dict)  # Contains outcome, effects applied

# --- Goal System Events (Placeholders for Phase 2+) ---
# signal goal_progress_updated(agent_body, goal_id, new_progress)
# signal goal_completed(agent_body, goal_id, success_level)


func _ready():
	print("EventBus Ready.")
