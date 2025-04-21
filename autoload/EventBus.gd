# File: autoload/EventBus.gd
# Autoload Singleton: EventBus
# Purpose: Central hub for globally emitted signals. Facilitates communication
#          between decoupled systems and modules.
# Version: 1.0

extends Node

# --- Game State Signals ---
signal game_loaded(save_data) # Emitted by GameStateManager AFTER loading data dict
# signal game_saving(slot_id) # Optional: If systems need to prepare before save
# signal save_complete(slot_id, success) # Optional: Notification after save attempt


# --- Agent Lifecycle Signals ---
# Emitted by WorldManager AFTER agent node is added to tree and initialized
signal agent_spawned(agent_body, init_data)
# Emitted by the Agent's despawn() method BEFORE queue_free is called
signal agent_despawning(agent_body)
# Emitted by AI Controller when it reaches its destination (used by WM to trigger despawn)
signal agent_reached_destination(agent_body)
# Emitted when the designated player agent is spawned/ready
signal player_spawned(player_agent_body)


# --- Camera Control Signals ---
# Emitted by systems (like WorldManager) requesting the camera target a specific node
signal camera_set_target_requested(target_node) # Pass null to clear target
# Emitted by input handlers (like OrbitCamera or UI) when player requests next target
signal camera_cycle_target_requested()


# --- Zone Loading Signals ---
# Emitted by WorldManager right before unloading the current zone
signal zone_unloading(zone_node)
# Emitted by WorldManager when a new zone scene path is about to be loaded
signal zone_loading(zone_path)
# Emitted by WorldManager AFTER a new zone is instanced, added to tree, and basic refs found
signal zone_loaded(zone_node, zone_path, agent_container_node)


# --- Core Mechanics / Gameplay Events (Add as needed) ---
# Example: Emitted after an Action Check is resolved (by CoreMechanicsAPI or calling script)
# signal action_check_resolved(agent_body, result_dictionary, action_approach)
# Example: Emitted when Focus Points change significantly
# signal focus_changed(agent_body, new_focus_value)
# Example: Emitted when Wealth Points change significantly
# signal wealth_changed(agent_body, new_wealth_value)
# Example: Emitted when Time Clock ticks over
# signal world_event_tick_triggered()


# --- Goal System Events (Add as needed) ---
# Example: Emitted when a goal's progress changes
# signal goal_progress_updated(agent_body, goal_id, new_progress)
# Example: Emitted when a goal is completed
# signal goal_completed(agent_body, goal_id, success_level)


# --- Module Specific Signals (Use sparingly - prefer module-internal signals first) ---
# Example: If a major discovery in Exploration needs global announcement
# signal major_discovery_made(discovery_data)


# No logic needed in the EventBus itself, it just defines and routes signals.
func _ready():
	print("EventBus Ready.")
