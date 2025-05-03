# File: autoload/Constants.gd
# Autoload Singleton: Constants
# Version: 1.3 - Reverted paths/names for Complete Zone Scene architecture

extends Node

# --- Scene Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://core/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://core/agents/npc_agent.tscn"

# Complete Zone Scene Paths (Self-contained environments with AgentContainer etc.)
const INITIAL_ZONE_SCENE_PATH = "res://scenes/zones/basic_flight_zone.tscn"
# Example future zones:
# const ZONE_ASTEROID_BELT_BETA_PATH = "res://scenes/zones/asteroid_belt_beta.tscn"
# const ZONE_SCRAPYARD_STATION_PATH = "res://scenes/zones/scrapyard_station.tscn"

# Agent Template Resource Paths
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://assets/data/templates/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://assets/data/templates/agents/npc_traffic.tres"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://core/ui/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu/main_menu.tscn"

# --- Common Node Names ---
# Inside main_game_scene.tscn
const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"  # Node holding the loaded zone instance

# Inside Zone Scenes (e.g., basic_flight_zone.tscn)
const AGENT_CONTAINER_NAME = "AgentContainer"  # Child node for housing agents
const AGENT_MODEL_CONTAINER_NAME = "Model"
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"]  # Expected Position3D/Spatial nodes

# Inside Agent Scenes (e.g., agent.tscn, npc_agent.tscn)
const AGENT_BODY_NODE_NAME = "AgentBody"  # The KinematicBody root in agent scenes
# MOVEMENT_COMPONENT_NAME removed as component was merged
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Thresholds ---
const ACTION_CHECK_FAIL_THRESHOLD = 10
const ACTION_CHECK_SWC_THRESHOLD = 10
const ACTION_CHECK_CRIT_THRESHOLD = 14

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1

# --- Default Simulation Values ---
const DEFAULT_MAX_MOVE_SPEED = 50.0
const DEFAULT_ACCELERATION = 10.0
const DEFAULT_DECELERATION = 15.0
const DEFAULT_MAX_TURN_SPEED = 2.0

# --- Gameplay / Physics Approximations ---
const ORBIT_FULL_SPEED_RADIUS = 2000.0  # Example value (e.g., 5000 units)

# --- System Defaults (Examples - Used by placeholder systems) ---
const MAX_NPCS_DEFAULT = 10
const SPAWN_INTERVAL_DEFAULT = 2.0
const TRAFFIC_SPEED_MULT_DEFAULT = 0.2
const TARGETING_RAY_LENGTH = 1e4
