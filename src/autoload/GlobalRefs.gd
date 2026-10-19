# GlobalRefs: references to key scene nodes and systems, set by the nodes themselves.

extends Node

const VERBOSE_REF_LOGS = false

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

# --- Core System References ---
var agent_spawner = null setget set_agent_spawner
var asset_system = null setget set_asset_system


# On exit, join the background thread that builds hull-mark vertex grids (VertexGrid): a
# thread still running at exit is an error. Autoloads leave the tree last.
func _exit_tree() -> void:
	load("res://src/core/agents/components/vertex_grid.gd").shutdown()


func _ready():
	if VERBOSE_REF_LOGS:
		print("GlobalRefs Ready.")
	# This script is a passive container; references are set by other nodes.


# --- Setters (Provide controlled way to update references & add validation) ---

func set_player_agent_body(new_ref):
	if new_ref == player_agent_body: return
	if new_ref == null or is_instance_valid(new_ref):
		player_agent_body = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: Player Agent ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Player Agent ref: ", new_ref)

func set_main_camera(new_ref):
	if new_ref == main_camera: return
	if new_ref == null or is_instance_valid(new_ref):
		main_camera = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: Main Camera ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid Main Camera ref: ", new_ref)

func set_world_manager(new_ref):
	if new_ref == world_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		world_manager = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: World Manager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid World Manager ref: ", new_ref)

func set_current_zone(new_ref):
	if new_ref == current_zone: return
	if new_ref == null or is_instance_valid(new_ref):
		current_zone = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: Current Zone ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Current Zone ref: ", new_ref)

func set_agent_container(new_ref):
	if new_ref == agent_container: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_container = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: Agent Container ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Agent Container ref: ", new_ref)

func set_game_state_manager(new_ref):
	if new_ref == game_state_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		game_state_manager = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: GameStateManager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid GameStateManager ref: ", new_ref)

# --- System Setters ---

func set_agent_spawner(new_ref):
	if new_ref == agent_spawner: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_spawner = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: AgentSpawner ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AgentSpawner ref: ", new_ref)

func set_asset_system(new_ref):
	if new_ref == asset_system: return
	if new_ref == null or is_instance_valid(new_ref):
		asset_system = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: AssetSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AssetSystem ref: ", new_ref)

# --- UI ELEMENTS ---

func set_main_hud(new_ref):
	if new_ref == main_hud: return
	if new_ref == null or is_instance_valid(new_ref):
		main_hud = new_ref
		if VERBOSE_REF_LOGS:
			print("GlobalRefs: Main HUD UI ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Main HUD UI ref: ", new_ref)
