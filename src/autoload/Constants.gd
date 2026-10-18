# Constants: flight, camera, AI, jump, docking and rendering tuning values.

extends Node

const VERBOSE_RUNTIME_LOGS = false

# --- Scene / Template Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/npc_agent.tscn"

# Agent Template Resource Paths
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://database/registry/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://database/registry/agents/npc_default.tres"
const NPC_HOSTILE_TEMPLATE_PATH = "res://database/registry/agents/npc_hostile_default.tres"

# --- Jump Route Colors (by sector type) ---

const COLOR_UI_JUMP_ROUTE = Color(0.0, 0.7, 1.0, 1.0) # Fallback / Default
const COLOR_UI_JUMP_STAR = Color(0.95, 0.65, 0.15, 1.0)      # Warm Gold
const COLOR_UI_JUMP_STAR_COMPANION = Color(0.85, 0.45, 0.85, 1.0) # Violet / Orchid
const COLOR_UI_JUMP_PLANET = Color(0.15, 0.85, 0.45, 1.0)    # Emerald Green
const COLOR_UI_JUMP_MOON = Color(0.65, 0.8, 0.95, 1.0)       # Ice Blue
const COLOR_UI_JUMP_DEEP_SPACE = Color(0.5, 0.5, 0.9, 1.0)    # Slate Blue / Indigo

func get_jump_type_color(sector_type: String) -> Color:
	match sector_type.to_lower():
		"star":
			return COLOR_UI_JUMP_STAR
		"star_companion":
			return COLOR_UI_JUMP_STAR_COMPANION
		"planet":
			return COLOR_UI_JUMP_PLANET
		"moon":
			return COLOR_UI_JUMP_MOON
		"deep_space", "hazard_zone":
			return COLOR_UI_JUMP_DEEP_SPACE
		_:
			return COLOR_UI_JUMP_ROUTE

# --- Common Node Names ---
const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_MODEL_CONTAINER_NAME = "Model"
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Parameters ---
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

const ORBIT_FULL_SPEED_RADIUS = 2000.0
const TARGETING_RAY_LENGTH = 1e7

# --- Sectors, Docking and Jumping ---
const JUMP_POINT_RING_RADIUS: float = 80000.0       # Fallback distance from sector center (procedural sectors)
const JUMP_POINT_STATION_OFFSET: float = 2000.0      # Distance from station where JumpPoints appear
const JUMP_POINT_DETECTION_RADIUS: float = 300.0     # Area radius for player detection
const DOCKING_PROMPT_RADIUS: float = 500.0           # Distance at which prompt appears
const DOCKING_ACTION_RADIUS: float = 300.0           # Distance at which dock/jump actually works
const SECTOR_JUMP_ARRIVAL_RADIUS: float = 50000.0   # Arrival shell radius for route-based sector jumps
const REFERENCE_ORIGIN: Vector3 = Vector3(0, 0, 0)  # Elace System global_position (nebula reference)
const SECTOR_CONTENT_RADIUS: float = 100000.0        # Recommended content placement radius
const POI_SPAWN_MIN_DISTANCE: float = 20000.0        # Minimum distance from sector center (20km)
const POI_SPAWN_MAX_DISTANCE: float = 100000.0       # Maximum distance from sector center (100km)
const INITIAL_SECTOR_ID: String = "sector_star_elace"    # Starting sector for new game

# ---- JUMP TRANSITION ----
const JUMP_ACCEL_DURATION: float = 3.0
const JUMP_FADE_DURATION: float = 3.0
const JUMP_TRAVEL_DURATION: float = 20.0
const MAX_ORBIT_CAMERA_FOV: float = 100.0

const JUMP_DURATION_STAR_STAR: float = 30.0
const JUMP_DURATION_STAR_STAR_COMPANION: float = 15.0
const JUMP_DURATION_STAR_PLANET: float = 10.0
const JUMP_DURATION_PLANET_MOON: float = 5.0
const JUMP_DURATION_ANY_DEEP_SPACE: float = 15.0

const JUMP_TRANSITION_RIG_NODE_NAME: String = "JumpTransitionRig"
const JUMP_TRANSITION_DEFAULT_DIRECTION: Vector3 = Vector3(0, 0, -1)
const JUMP_TRANSITION_LOAD_TIMEOUT_SEC: float = 1.5


func get_jump_travel_duration(type_a: String, type_b: String) -> float:
	var a = type_a.to_lower()
	var b = type_b.to_lower()
	
	if a == "deep_space" or b == "deep_space":
		return JUMP_DURATION_ANY_DEEP_SPACE
		
	var pair = [a, b]
	pair.sort()
	
	if pair == ["star", "star"]:
		return JUMP_DURATION_STAR_STAR
	elif pair == ["star", "star_companion"]:
		return JUMP_DURATION_STAR_STAR_COMPANION
	elif pair == ["planet", "star"]:
		return JUMP_DURATION_STAR_PLANET
	elif pair == ["moon", "planet"]:
		return JUMP_DURATION_PLANET_MOON
		
	return JUMP_TRAVEL_DURATION


func get_reference_origin_offset(world_position: Vector3) -> Vector3:
	return REFERENCE_ORIGIN - world_position
