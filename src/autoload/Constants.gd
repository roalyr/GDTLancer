#
# PROJECT: GDTLancer
# MODULE: Constants.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Node

## Constants: Global game constants, thresholds, and configuration values.
## Centralizes magic numbers for balance tuning and consistency.

# --- Action Approach Enum ---
enum ActionApproach { CAUTIOUS, NEUTRAL, RISKY }
enum ActionStakes { HIGH_STAKES, NARRATIVE, MUNDANE }

# --- Core Mechanics Thresholds ---
# Cautious approach has a wider success band.
const ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS = 14
const ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS = 10

# Neutral approach (Standard difficulty)
const ACTION_CHECK_CRIT_THRESHOLD_NEUTRAL = 15
const ACTION_CHECK_SWC_THRESHOLD_NEUTRAL = 11

# Risky approach has a narrower success band but a higher critical chance.
const ACTION_CHECK_CRIT_THRESHOLD_RISKY = 16
const ACTION_CHECK_SWC_THRESHOLD_RISKY = 12

# --- Scene Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/npc_agent.tscn"
const INITIAL_ZONE_SCENE_PATH = "res://scenes/levels/zones/zone1/basic_flight_zone.tscn"

# Agent Template Resource Paths
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://database/registry/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://database/registry/agents/npc_default.tres"
const NPC_HOSTILE_TEMPLATE_PATH = "res://database/registry/agents/npc_hostile_default.tres"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://scenes/ui/hud/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/ui/menus/main_menu.tscn"

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

# --- RigidBody Physics Parameters (6DOF Flight) ---
# Global drag coefficients - prevent endless acceleration in space
const LINEAR_DRAG = 0.5  # Linear velocity damping factor
const ANGULAR_DRAG = 2.0  # Angular velocity damping factor (reduced for responsiveness)

# Default ship thrust/torque limits (can be overridden per-ship)
const DEFAULT_LINEAR_THRUST = 5e6  # Force in Newtons
const DEFAULT_ANGULAR_THRUST = 5e6  # Torque in Newton-meters
const DEFAULT_SHIP_MASS = 6e4  # kg
const DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45.0  # Degrees

# PID Controller Gains for Autopilot
# Rotation PID - controls angular velocity to achieve target orientation
const PID_ROTATION_KP = 8.0   # Proportional gain
const PID_ROTATION_KI = 0.1   # Integral gain (low to prevent windup)
const PID_ROTATION_KD = 4.0   # Derivative gain (damping)

# Position/Velocity PID - for orbit radius and stopping precision
const PID_POSITION_KP = 0.5   # Proportional gain for position error
const PID_POSITION_KI = 0.01  # Integral gain
const PID_POSITION_KD = 0.8   # Derivative gain

# Thrust throttle range for player control (0.0 to 1.0)
const MIN_THRUST_THROTTLE = 0.0
const MAX_THRUST_THROTTLE = 1.0

# Time units to trigger world tick
# 60 seconds = 1 minute tick? Or longer? Keeping 60 for now.
const WORLD_TICK_INTERVAL_SECONDS = 60
const TIME_TICK_INTERVAL_SECONDS = 1.0 # Real-time seconds per game-time update (simulation speed)

# --- Gameplay / Physics Approximations ---
const ORBIT_FULL_SPEED_RADIUS = 2000.0
const TARGETING_RAY_LENGTH = 1e7
