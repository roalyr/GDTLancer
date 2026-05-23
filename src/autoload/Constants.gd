#
# PROJECT: GDTLancer
# MODULE: Constants.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §4, §7; TRUTH_SIMULATION-GRAPH.md §3.3, §6.4
# LOG_REF: 2026-05-23 17:10:12
#

extends Node

## Constants: Global game constants, thresholds, and configuration values.
## Centralizes magic numbers for balance tuning and consistency.

const VERBOSE_RUNTIME_LOGS = false

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

# =============================================================================
# === QUALITATIVE SIMULATION ==================================================
# =============================================================================

# --- World Age Cycle ---
const WORLD_AGE_CYCLE: Array = ["PROSPERITY", "DISRUPTION", "RECOVERY"]
const WORLD_AGE_DURATIONS: Dictionary = {
	"PROSPERITY": 150,
	"DISRUPTION": 75,
	"RECOVERY": 105,
}
const WORLD_AGE_CONFIGS: Dictionary = {
	"PROSPERITY": {},
	"DISRUPTION": {},
	"RECOVERY": {},
}

# --- Colony Structure ---
const COLONY_LEVELS: Array = ["frontier", "outpost", "colony", "hub"]
const COLONY_UPGRADE_TICKS_REQUIRED: int = 10
const COLONY_DOWNGRADE_TICKS_REQUIRED: int = 12
const COLONY_UPGRADE_REQUIRED_SECURITY: String = "SECURE"
const COLONY_UPGRADE_REQUIRED_ECONOMY: Array = ["RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
const COLONY_DOWNGRADE_SECURITY_TRIGGER: String = "LAWLESS"
const COLONY_DOWNGRADE_ECONOMY_TRIGGER: Array = ["RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
const COLONY_MINIMUM_LEVEL: String = "outpost"

# --- Security Progression ---
const SECURITY_CHANGE_TICKS_MIN: int = 3
const SECURITY_CHANGE_TICKS_MAX: int = 6

# --- Economy Progression ---
const ECONOMY_UPGRADE_TICKS_REQUIRED: int = 3
const ECONOMY_DOWNGRADE_TICKS_REQUIRED: int = 3
const ECONOMY_CHANGE_TICKS_MIN: int = 2
const ECONOMY_CHANGE_TICKS_MAX: int = 5

# --- Hostile Infestation Progression ---
const HOSTILE_INFESTATION_TICKS_REQUIRED: int = 3

# --- Affinity Thresholds ---
const ATTACK_THRESHOLD: float = 1.5
const TRADE_THRESHOLD: float = 0.5
const FLEE_THRESHOLD: float = -1.0

# --- Combat Cooldown ---
const COMBAT_COOLDOWN_TICKS: int = 5

# --- Agent Upkeep ---
const AGENT_UPKEEP_CHANCE: float = 0.05
const WEALTHY_DRAIN_CHANCE: float = 0.08
const BROKE_RECOVERY_CHANCE: float = 0.15

# --- Mortal Agent Lifecycle ---
const MORTAL_GLOBAL_CAP: int = 200
const MORTAL_SPAWN_REQUIRED_SECURITY: Array = ["SECURE", "CONTESTED", "LAWLESS"]
const MORTAL_SPAWN_BLOCKED_SECTOR_TAGS: Array = ["DISABLED", "HOSTILE_INFESTED"]
const MORTAL_SPAWN_MIN_ECONOMY_TAGS: Array = ["RAW_ADEQUATE", "RAW_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE", "CURRENCY_RICH"]
const MORTAL_SPAWN_CHANCE: float = 0.2
const MORTAL_ROLES: Array = ["trader", "hauler", "prospector", "explorer", "pirate"]
const MORTAL_SURVIVAL_CHANCE: float = 0.4
const DISRUPTION_MORTAL_ATTRITION_CHANCE: float = 0.03

# --- Structural Constants (caps / timeouts) ---
const EVENT_BUFFER_CAP: int = 200
const RUMOR_BUFFER_CAP: int = 200
const RESPAWN_COOLDOWN_TICKS: int = 1
const RESPAWN_COOLDOWN_MAX_DEBT: int = 25
const MAX_SECTOR_COUNT: int = 220
const EXPLORATION_COOLDOWN_TICKS: int = 10
const EXPLORATION_SUCCESS_CHANCE: float = 0.1

# --- Topology ---
const MAX_CONNECTIONS_PER_SECTOR: int = 4
const EXTRA_CONNECTION_1_CHANCE: float = 0.20
const EXTRA_CONNECTION_2_CHANCE: float = 0.05
const LOOP_MIN_HOPS: int = 3

# --- Discovery Spatialization ---
const DISCOVERY_BRANCH_DISTANCE_BASE: float = 96000.0
const DISCOVERY_BRANCH_DISTANCE_JITTER: float = 24000.0
const DISCOVERY_BRANCH_MIN_CLEARANCE: float = 36000.0
const DISCOVERY_BRANCH_POSITION_ATTEMPTS: int = 14
const DISCOVERY_BRANCH_DIRECTION_JITTER_DEG: float = 32.0
const DISCOVERY_BRANCH_JITTER_PER_EXISTING_BRANCH_DEG: float = 18.0
const DISCOVERY_BRANCH_MIN_SIBLING_ANGLE_DEG: float = 26.0
const DISCOVERY_BRANCH_ANGLE_SCORE_WEIGHT: float = 1200.0
const DISCOVERY_PLANAR_VERTICAL_JITTER: float = 6000.0
const DISCOVERY_VERTICAL_BRANCH_CHANCE: float = 0.14
const DISCOVERY_VERTICAL_BRANCH_CONTINUE_CHANCE: float = 0.60
const DISCOVERY_VERTICAL_BRANCH_Y_BIAS: float = 0.72
const DISCOVERY_VERTICAL_BRANCH_MIN_OFFSET: float = 6000.0
const DISCOVERY_VERTICAL_BRANCH_MAX_OFFSET: float = 14000.0
const DISCOVERY_MAX_LINK_DISTANCE: float = 164000.0

# --- Catastrophe ---
const CATASTROPHE_CHANCE_PER_TICK: float = 0.005
const CATASTROPHE_DISABLE_DURATION: int = 6
const CATASTROPHE_MORTAL_KILL_CHANCE: float = 0.7

# --- Sub-tick System ---
const SUB_TICKS_PER_TICK: int = 10
const SUBTICK_COST_SECTOR_TRAVEL: int = 10
const SUBTICK_COST_DOCK: int = 3
const SUBTICK_COST_UNDOCK: int = 2
const SUBTICK_COST_DEEP_SPACE_EVENT: int = 5

# ---- SECTOR TRAVEL ----
const JUMP_POINT_RING_RADIUS: float = 80000.0       # Fallback distance from sector center (procedural sectors)
const JUMP_POINT_STATION_OFFSET: float = 2000.0      # Distance from station where JumpPoints appear
const JUMP_POINT_DETECTION_RADIUS: float = 300.0     # Area radius for player detection
const DOCKING_PROMPT_RADIUS: float = 500.0           # Distance at which prompt appears
const DOCKING_ACTION_RADIUS: float = 300.0           # Distance at which dock/jump actually works
const SECTOR_JUMP_ARRIVAL_RADIUS: float = 50000.0   # Arrival shell radius for route-based sector jumps
const REFERENCE_ORIGIN: Vector3 = Vector3(0, 0, 0)  # Elace System global_position (nebula reference)
const SECTOR_CONTENT_RADIUS: float = 100000.0        # Recommended content placement radius
const INITIAL_SECTOR_ID: String = "sector_system_elace"    # Starting sector for new game

# ---- JUMP TRANSITION ----
const JUMP_TRANSITION_RIG_NODE_NAME: String = "JumpTransitionRig"
const JUMP_TRANSITION_DEFAULT_DIRECTION: Vector3 = Vector3(0, 0, -1)
const JUMP_TRANSITION_TARGET_FOV_DEG: float = 140.0
const JUMP_TRANSITION_CAMERA_AIM_DURATION_SEC: float = 2.0
const JUMP_TRANSITION_FOV_EASE_POWER: float = 2.35
const JUMP_TRANSITION_FOV_DURATION_SEC: float = 5.0
const JUMP_TRANSITION_HUD_SHOW_DELAY_SEC: float = 1.5
const JUMP_TRANSITION_VELOCITY_TOLERANCE: float = 20.0
const JUMP_TRANSITION_VELOCITY_TIMEOUT_SEC: float = 7.5
const JUMP_TRANSITION_LOAD_TIMEOUT_SEC: float = 1.5
# Route distance is converted into cruise speed using this total travel window.
const JUMP_TRANSITION_TRAVEL_DURATION_SEC: float = 15.0
# Takeoff and arrival use the same mirrored speed ramp.
const JUMP_TRANSITION_SPEED_RAMP_DURATION_SEC: float = 2.0
const JUMP_TRANSITION_ROUTE_COMPLETION_TOLERANCE: float = 2000.0
const JUMP_TRANSITION_OVERLAY_PEAK_ALPHA: float = 1.0
const JUMP_TRANSITION_OVERLAY_CURVE_POWER: float = 0.70
const JUMP_TRANSITION_OVERLAY_ARRIVAL_FADE_IN_CURVE_POWER: float = 0.5
const JUMP_TRANSITION_OVERLAY_ARRIVAL_FADE_IN_DURATION_SEC: float = 1.0
const JUMP_TRANSITION_OVERLAY_POST_DEPARTURE_HOLD_SEC: float = 2.0
const JUMP_TRANSITION_OVERLAY_ARRIVAL_POST_FULL_OPACITY_HOLD_SEC: float = 2.0


func get_reference_origin_offset(world_position: Vector3) -> Vector3:
	return REFERENCE_ORIGIN - world_position

# ---- CONTACT MANAGER ----
const DISPOSITION_FRIENDLY_THRESHOLD: float = 0.5
const DISPOSITION_HOSTILE_THRESHOLD: float = -0.5
