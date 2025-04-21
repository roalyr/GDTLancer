# File: autoload/Constants.gd
# Autoload Singleton: Constants
# Purpose: Holds globally accessible constant values like paths, names, tuning params.
# Version: 1.0

extends Node

# --- Scene Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://core/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://core/agents/npc_agent.tscn"
# Add paths for specific ship scenes later if needed, or reference via templates

# Example Zone Path (Add more as zones are created)
const INITIAL_ZONE_SCENE_PATH = "res://scenes/zones/basic_flight_zone.tscn"
# const ZONE_SECTOR_ALPHA_STARBASE_PATH = "res://scenes/zones/sector_alpha/starbase_alpha_orbit.tscn"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://core/ui/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu/main_menu.tscn"

# --- Common Node Names ---
# Used for get_node/find_node where necessary
const AGENT_CONTAINER_NAME = "AgentContainer" # Expected inside Zone scenes
const AGENT_BODY_NODE_NAME = "AgentBody"     # The KinematicBody root inside Agent scenes
const MOVEMENT_COMPONENT_NAME = "MovementComponent" # Child node of AgentBody
const AI_CONTROLLER_NODE_NAME = "AIController" # Child node of AgentBody in npc_agent.tscn
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler" # Child node of AgentBody in player_agent.tscn
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"] # Expected in Zone scenes

# --- Core Mechanics Thresholds ---
const ACTION_CHECK_FAIL_THRESHOLD = 10 # Roll < 10 is Failure
const ACTION_CHECK_SWC_THRESHOLD = 10  # Roll >= 10 is Success w/ Complication or better
const ACTION_CHECK_CRIT_THRESHOLD = 14 # Roll >= 14 is Critical Success

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1 # Spend 1 FP => +1 Bonus

# --- Default Simulation Values (can be overridden by Agent Templates/Data) ---
const DEFAULT_MAX_MOVE_SPEED = 50.0
const DEFAULT_ACCELERATION = 10.0
const DEFAULT_DECELERATION = 15.0
const DEFAULT_MAX_TURN_SPEED = 2.0 # Radians/sec

# --- Placeholder Traffic System Defaults (Used by TrafficSystemPlaceholder initially) ---
const MAX_NPCS_DEFAULT = 10
const SPAWN_INTERVAL_DEFAULT = 2.0
const TRAFFIC_SPEED_MULT_DEFAULT = 0.2

# --- Collision Layers (Example - Define actual layers in Project Settings -> Layer Names) ---
# const COLLISION_LAYER_SHIP = 1
# const COLLISION_LAYER_STATION = 2
# const COLLISION_LAYER_ASTEROID = 3
# const COLLISION_LAYER_INTERACTABLE = 4

# --- Input Actions (Define in Project Settings -> Input Map) ---
# const INPUT_ACTION_FORWARD = "move_forward"
# const INPUT_ACTION_BACKWARD = "move_backward"
# const INPUT_ACTION_STRAFE_LEFT = "strafe_left"
# ... etc ...
