# File: autoload/GlobalRefs.gd
# Autoload Singleton: GlobalRefs
# Purpose: Holds easily accessible references to unique global nodes/managers.
# Nodes register themselves here via setter functions during their _ready() phase.
# Version: 1.0

extends Node

# --- Key Node References ---
# Other scripts access these directly (e.g., GlobalRefs.player_agent_body)
# but should ALWAYS check if is_instance_valid() first!

var player_agent_body = null setget set_player_agent_body
var main_camera = null setget set_main_camera
var world_manager = null setget set_world_manager
var event_system = null setget set_event_system  # If EventSystem is a Node, not Autoload
var goal_system = null setget set_goal_system  # If GoalSystem is a Node
var character_system = null setget set_character_system  # If CharacterSystem is a Node
var asset_system = null setget set_asset_system  # If AssetSystem is a Node
# Add other core system node references as needed...

var current_zone = null setget set_current_zone  # Reference to the root node of the loaded zone scene
var agent_container = null setget set_agent_container  # Reference to the node *within* the zone where agents are parented


func _ready():
	print("GlobalRefs Ready.")
	# This script typically doesn't do much itself, it just holds references set by others.


# --- Setters (Provide controlled way to update references & add validation) ---
# Using setget ensures these are called automatically on assignment.


func set_player_agent_body(new_ref):
	if new_ref == player_agent_body:
		return  # No change
	if new_ref == null or is_instance_valid(new_ref):
		player_agent_body = new_ref
		print("GlobalRefs: Player Agent reference ", "set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Player Agent reference: ", new_ref)


func set_main_camera(new_ref):
	if new_ref == main_camera:
		return
	if new_ref == null or is_instance_valid(new_ref):
		main_camera = new_ref
		print("GlobalRefs: Main Camera reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Main Camera reference: ", new_ref)


func set_world_manager(new_ref):
	if new_ref == world_manager:
		return
	if new_ref == null or is_instance_valid(new_ref):
		world_manager = new_ref
		print("GlobalRefs: World Manager reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid World Manager reference: ", new_ref)


func set_event_system(new_ref):
	if new_ref == event_system:
		return
	if new_ref == null or is_instance_valid(new_ref):
		event_system = new_ref
		print("GlobalRefs: Event System reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Event System reference: ", new_ref)


func set_goal_system(new_ref):
	if new_ref == goal_system:
		return
	if new_ref == null or is_instance_valid(new_ref):
		goal_system = new_ref
		print("GlobalRefs: Goal System reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Goal System reference: ", new_ref)


func set_character_system(new_ref):
	if new_ref == character_system:
		return
	if new_ref == null or is_instance_valid(new_ref):
		character_system = new_ref
		print("GlobalRefs: Character System reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Character System reference: ", new_ref)


func set_asset_system(new_ref):
	if new_ref == asset_system:
		return
	if new_ref == null or is_instance_valid(new_ref):
		asset_system = new_ref
		print("GlobalRefs: Asset System reference ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Asset System reference: ", new_ref)


func set_current_zone(new_ref):
	if new_ref == current_zone:
		return
	if new_ref == null or is_instance_valid(new_ref):
		current_zone = new_ref
		print("GlobalRefs: Current Zone reference ", "set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Current Zone reference: ", new_ref)


func set_agent_container(new_ref):
	if new_ref == agent_container:
		return
	if new_ref == null or is_instance_valid(new_ref):
		agent_container = new_ref
		print(
			"GlobalRefs: Agent Container reference ", "set to ", new_ref.name if new_ref else "null"
		)
	else:
		printerr("GlobalRefs Error: Attempted to set invalid Agent Container reference: ", new_ref)

# --- Optional: Add simple getter functions if needed ---
# func get_player() -> KinematicBody:
#     return player_agent_body if is_instance_valid(player_agent_body) else null
