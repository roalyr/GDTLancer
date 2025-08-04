# File: autoload/Constants.gd
# Autoload Singleton: Constants
# Version: 1.4 - Added ActionApproach and thresholds

extends Node

# --- Action Approach Enum ---
enum ActionApproach { CAUTIOUS, RISKY }

# --- Core Mechanics Thresholds ---
# Cautious approach has a wider success band.
const ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS = 14
const ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS = 10

# Risky approach has a narrower success band but a higher critical chance.
const ACTION_CHECK_CRIT_THRESHOLD_RISKY = 16
const ACTION_CHECK_SWC_THRESHOLD_RISKY = 12

# --- Scene Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://core/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://core/agents/npc_agent.tscn"
const INITIAL_ZONE_SCENE_PATH = "res://scenes/zones/basic_flight_zone.tscn"

# Agent Template Resource Paths
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://assets/data/templates/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://assets/data/templates/agents/npc_traffic.tres"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://core/ui/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu/main_menu.tscn"

# --- Common Node Names ---
const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_MODEL_CONTAINER_NAME = "Model"
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"]
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1

# --- Default Simulation Values ---
const DEFAULT_MAX_MOVE_SPEED = 300.0
const DEFAULT_ACCELERATION = 0.5
const DEFAULT_DECELERATION = 0.5
const DEFAULT_MAX_TURN_SPEED = 0.75

# --- Gameplay / Physics Approximations ---
const ORBIT_FULL_SPEED_RADIUS = 2000.0

# --- System Defaults ---
const MAX_NPCS_DEFAULT = 10
const SPAWN_INTERVAL_DEFAULT = 2.0
const TRAFFIC_SPEED_MULT_DEFAULT = 0.2
const TARGETING_RAY_LENGTH = 1e7
