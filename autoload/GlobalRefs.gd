# File: core/autoload/global_refs.gd
# Autoload Singleton: GlobalRefs
# Purpose: Holds easily accessible references to unique global nodes/managers.
# Nodes register themselves here via setter functions during their _ready() phase.
# Version: 1.1

extends Node

# --- Key Node & UI References ---
# Other scripts access these directly (e.g., GlobalRefs.player_agent_body)
# but should ALWAYS check if is_instance_valid() first!

var player_agent_body = null setget set_player_agent_body
var main_camera = null setget set_main_camera
var world_manager = null setget set_world_manager
var current_zone = null setget set_current_zone
var agent_container = null setget set_agent_container
var game_state_manager = null setget set_game_state_manager

# --- UI elements ---
var main_hud = null setget set_main_hud
var character_status = null setget set_character_status
var inventory_screen = null setget set_inventory_screen

# --- Core System References ---
var action_system = null setget set_action_system
var agent_spawner = null setget set_agent_spawner
var asset_system = null setget set_asset_system
var character_system = null setget set_character_system
var chronicle_system = null setget set_chronicle_system
var goal_system = null setget set_goal_system
var inventory_system = null setget set_inventory_system
var progression_system = null setget set_progression_system
var time_system = null setget set_time_system
var traffic_system = null setget set_traffic_system
var world_map_system = null setget set_world_map_system
var event_system = null setget set_event_system


func _ready():
	print("GlobalRefs Ready.")
	# This script is a passive container; references are set by other nodes.


# --- Setters (Provide controlled way to update references & add validation) ---

func set_player_agent_body(new_ref):
	if new_ref == player_agent_body: return
	if new_ref == null or is_instance_valid(new_ref):
		player_agent_body = new_ref
		print("GlobalRefs: Player Agent ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Player Agent ref: ", new_ref)

func set_main_camera(new_ref):
	if new_ref == main_camera: return
	if new_ref == null or is_instance_valid(new_ref):
		main_camera = new_ref
		print("GlobalRefs: Main Camera ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid Main Camera ref: ", new_ref)

func set_world_manager(new_ref):
	if new_ref == world_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		world_manager = new_ref
		print("GlobalRefs: World Manager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid World Manager ref: ", new_ref)

func set_current_zone(new_ref):
	if new_ref == current_zone: return
	if new_ref == null or is_instance_valid(new_ref):
		current_zone = new_ref
		print("GlobalRefs: Current Zone ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Current Zone ref: ", new_ref)

func set_agent_container(new_ref):
	if new_ref == agent_container: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_container = new_ref
		print("GlobalRefs: Agent Container ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Agent Container ref: ", new_ref)

func set_game_state_manager(new_ref):
	if new_ref == game_state_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		game_state_manager = new_ref
		print("GlobalRefs: GameStateManager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid GameStateManager ref: ", new_ref)

# --- System Setters ---

func set_action_system(new_ref):
	if new_ref == action_system: return
	if new_ref == null or is_instance_valid(new_ref):
		action_system = new_ref
		print("GlobalRefs: ActionSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ActionSystem ref: ", new_ref)

func set_agent_spawner(new_ref):
	if new_ref == agent_spawner: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_spawner = new_ref
		print("GlobalRefs: AgentSpawner ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AgentSpawner ref: ", new_ref)

func set_asset_system(new_ref):
	if new_ref == asset_system: return
	if new_ref == null or is_instance_valid(new_ref):
		asset_system = new_ref
		print("GlobalRefs: AssetSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AssetSystem ref: ", new_ref)

func set_character_system(new_ref):
	if new_ref == character_system: return
	if new_ref == null or is_instance_valid(new_ref):
		character_system = new_ref
		print("GlobalRefs: CharacterSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid CharacterSystem ref: ", new_ref)

func set_chronicle_system(new_ref):
	if new_ref == chronicle_system: return
	if new_ref == null or is_instance_valid(new_ref):
		chronicle_system = new_ref
		print("GlobalRefs: ChronicleSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ChronicleSystem ref: ", new_ref)

func set_goal_system(new_ref):
	if new_ref == goal_system: return
	if new_ref == null or is_instance_valid(new_ref):
		goal_system = new_ref
		print("GlobalRefs: GoalSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid GoalSystem ref: ", new_ref)

func set_inventory_system(new_ref):
	if new_ref == inventory_system: return
	if new_ref == null or is_instance_valid(new_ref):
		inventory_system = new_ref
		print("GlobalRefs: InventorySystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid InventorySystem ref: ", new_ref)

func set_progression_system(new_ref):
	if new_ref == progression_system: return
	if new_ref == null or is_instance_valid(new_ref):
		progression_system = new_ref
		print("GlobalRefs: ProgressionSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ProgressionSystem ref: ", new_ref)

func set_time_system(new_ref):
	if new_ref == time_system: return
	if new_ref == null or is_instance_valid(new_ref):
		time_system = new_ref
		print("GlobalRefs: TimeSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid TimeSystem ref: ", new_ref)

func set_traffic_system(new_ref):
	if new_ref == traffic_system: return
	if new_ref == null or is_instance_valid(new_ref):
		traffic_system = new_ref
		print("GlobalRefs: TrafficSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid TrafficSystem ref: ", new_ref)

func set_world_map_system(new_ref):
	if new_ref == world_map_system: return
	if new_ref == null or is_instance_valid(new_ref):
		world_map_system = new_ref
		print("GlobalRefs: WorldMapSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid WorldMapSystem ref: ", new_ref)

func set_event_system(new_ref):
	if new_ref == event_system: return
	if new_ref == null or is_instance_valid(new_ref):
		event_system = new_ref
		print("GlobalRefs: EventSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid EventSystem ref: ", new_ref)



# --- UI ELEMENTS ---

func set_main_hud(new_ref):
	if new_ref == main_hud: return
	if new_ref == null or is_instance_valid(new_ref):
		main_hud = new_ref
		print("GlobalRefs: Main HUD UI ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Main HUD UI ref: ", new_ref)
		
func set_character_status(new_ref):
	if new_ref == character_status: return
	if new_ref == null or is_instance_valid(new_ref):
		character_status = new_ref
		print("GlobalRefs: Character Status UI window ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Character Status UI window ref: ", new_ref)

func set_inventory_screen(new_ref):
	if new_ref == inventory_screen: return
	if new_ref == null or is_instance_valid(new_ref):
		inventory_screen = new_ref
		print("GlobalRefs: Inventory Screen UI window ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Inventory Screen UI window ref: ", new_ref)
