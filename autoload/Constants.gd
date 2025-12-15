# File: autoload/Constants.gd
# Autoload Singleton: Constants
# Version: 1.5 - Updated with new and removed the old.

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
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://assets/data/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://assets/data/agents/npc_default.tres"
const NPC_HOSTILE_TEMPLATE_PATH = "res://assets/data/agents/npc_hostile_default.tres"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://core/ui/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu/main_menu.tscn"

# --- Common Node Names ---
const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_MODEL_CONTAINER_NAME = "Model"
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"] # Placeholders
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1
const DEFAULT_UPKEEP_COST = 5

# --- Default Simulation Values ---
const DEFAULT_MAX_MOVE_SPEED = 300.0
const DEFAULT_ACCELERATION = 0.5
const DEFAULT_DECELERATION = 0.5
const DEFAULT_MAX_TURN_SPEED = 0.75
const DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45 # Degrees

# Time units to trigger world tick
const TIME_CLOCK_MAX_TU = 60
const TIME_TICK_INTERVAL_SECONDS = 1.0 # How often (in real seconds) to add a Time Unit.

# --- Gameplay / Physics Approximations ---
const ORBIT_FULL_SPEED_RADIUS = 2000.0
const TARGETING_RAY_LENGTH = 1e7
