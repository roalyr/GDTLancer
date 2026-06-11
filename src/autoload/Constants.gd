# PROJECT: GDTLancer
# MODULE: Constants.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-11 20:09:30

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
const COMPOSITE_RESEARCH_TICK_COUNTS: Array = [30, 300, 3000]

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
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"] # Placeholders
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1
const DEFAULT_UPKEEP_COST = 5
const CREDIT_TRUST_THRESHOLD = 0.3

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

# --- Station Market Periodic Restocking ---
const MARKET_RESTOCK_RATE_PER_TICK: int = 1
const MARKET_RESTOCK_MAX_QUANTITY: int = 50

# --- Commodity Classification & Seeding ---
const COMMODITY_CLASSIFICATION: Dictionary = {
	"commodity_ore":        "RAW",
	"commodity_fuel":       "RAW",
	"commodity_scrap":      "RAW",
	"commodity_food":       "MANUFACTURED",
	"commodity_tech":       "MANUFACTURED",
	"commodity_contraband": "MANUFACTURED",
	"commodity_luxury":     "CURRENCY",
	"commodity_specie":     "CURRENCY",
}

const ILLEGAL_COMMODITIES: Array = ["commodity_contraband"]

const ECONOMY_LEVEL_PARAMS: Dictionary = {
	"RICH": {
		"min_quantity": 15,
		"max_quantity": 40,
		"price_multiplier": 0.7
	},
	"ADEQUATE": {
		"min_quantity": 5,
		"max_quantity": 20,
		"price_multiplier": 1.0
	},
	"POOR": {
		"min_quantity": 0,
		"max_quantity": 5,
		"price_multiplier": 1.5
	}
}

const COMMODITY_SELL_PRICE_FRACTION: float = 0.8
const DYNAMIC_PRICE_ELASTICITY: float = 0.5


func get_tag_aware_baseline_quantity(_category: String, level: String) -> int:
	if ECONOMY_LEVEL_PARAMS.has(level):
		var params: Dictionary = ECONOMY_LEVEL_PARAMS[level]
		var min_q: int = params.get("min_quantity", 0)
		var max_q: int = params.get("max_quantity", 0)
		return int((min_q + max_q) / 2)
	return 10


func get_dynamic_price(base_price: int, quantity: int, baseline: int) -> int:
	if baseline <= 0:
		baseline = 1
	var ratio: float = float(quantity) / float(baseline)
	var modifier: float = 1.0 + DYNAMIC_PRICE_ELASTICITY * (1.0 - ratio)
	modifier = clamp(modifier, 0.2, 2.0)
	var price: int = int(round(base_price * modifier))
	return int(max(price, 1))

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
const PROSPERITY_GROWTH_STAGE_1_RATIO: float = 0.34
const PROSPERITY_GROWTH_STAGE_2_RATIO: float = 0.67
const PROSPERITY_ECONOMY_SECURITY_UPGRADE_REDUCTION_MID: int = 1
const PROSPERITY_ECONOMY_SECURITY_UPGRADE_REDUCTION_LATE: int = 2
const PROSPERITY_COLONY_UPGRADE_REDUCTION_MID: int = 1
const PROSPERITY_COLONY_UPGRADE_REDUCTION_LATE: int = 3
const PROSPERITY_MORTAL_SPAWN_MULTIPLIER_EARLY: float = 0.75
const PROSPERITY_MORTAL_SPAWN_MULTIPLIER_MID: float = 1.0
const PROSPERITY_MORTAL_SPAWN_MULTIPLIER_LATE: float = 1.3
const DISRUPTION_MORTAL_SPAWN_MULTIPLIER: float = 0.45
const RECOVERY_MORTAL_SPAWN_MULTIPLIER: float = 0.85

# --- Colony Structure ---
const COLONY_LEVELS: Array = ["frontier", "outpost", "colony", "hub"]
const COLONY_UPGRADE_TICKS_REQUIRED: int = 10
const COLONY_DOWNGRADE_TICKS_REQUIRED: int = 12
const COLONY_UPGRADE_REQUIRED_SECURITY: String = "SECURE"
const COLONY_UPGRADE_REQUIRED_ECONOMY: Array = ["RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
const COLONY_DOWNGRADE_SECURITY_TRIGGER: String = "LAWLESS"
const COLONY_DOWNGRADE_ECONOMY_TRIGGER: Array = ["RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
const COLONY_MINIMUM_LEVEL: String = "outpost"
const FRONTIER_COLONY_UPGRADE_TICKS_REQUIRED: int = 16
const OUTPOST_COLONY_UPGRADE_TICKS_REQUIRED: int = 15
const COLONY_TO_HUB_UPGRADE_TICKS_REQUIRED: int = 15
const OUTPOST_TO_COLONY_REQUIRED_RICH_ECONOMY_COUNT: int = 1
const OUTPOST_TO_COLONY_SELF_SUFFICIENT_RICH_ECONOMY_COUNT: int = 2
const OUTPOST_TO_COLONY_GROWTH_SUPPORT_REQUIRED: int = 2
const COLONY_TO_HUB_REQUIRED_ECONOMY: Array = ["RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"]
const FRONTIER_TO_OUTPOST_REQUIRED_SECURITY: String = "CONTESTED"
const FRONTIER_TO_OUTPOST_BLOCKED_ENVIRONMENT: String = "EXTREME"
const OUTPOST_TO_COLONY_BLOCKED_ENVIRONMENT: String = "EXTREME"
const PROSPERITY_OUTPOST_TO_COLONY_UPGRADE_REDUCTION_MID: int = 1
const PROSPERITY_OUTPOST_TO_COLONY_UPGRADE_REDUCTION_LATE: int = 2
const PROSPERITY_COLONY_TO_HUB_UPGRADE_REDUCTION_MID: int = 1
const PROSPERITY_COLONY_TO_HUB_UPGRADE_REDUCTION_LATE: int = 2
const RECOVERY_OUTPOST_TO_COLONY_UPGRADE_PENALTY: int = 2
const RECOVERY_COLONY_TO_HUB_UPGRADE_PENALTY: int = 2

# --- Security Progression ---
const SECURITY_CHANGE_TICKS_MIN: int = 3
const SECURITY_CHANGE_TICKS_MAX: int = 6
const FRONTIER_SECURITY_UPGRADE_TICKS_BONUS: int = 2
const OUTPOST_SECURITY_UPGRADE_TICKS_BONUS: int = 1
const FRONTIER_MAX_SECURITY_LEVEL: String = "CONTESTED"

# --- Economy Progression ---
const ECONOMY_UPGRADE_TICKS_REQUIRED: int = 3
const ECONOMY_DOWNGRADE_TICKS_REQUIRED: int = 3
const ECONOMY_CHANGE_TICKS_MIN: int = 2
const ECONOMY_CHANGE_TICKS_MAX: int = 5
const FRONTIER_ECONOMY_UPGRADE_TICKS_BONUS: int = 2
const OUTPOST_ECONOMY_UPGRADE_TICKS_BONUS: int = 1
const FRONTIER_MAX_ECONOMY_LEVEL: String = "ADEQUATE"

# --- Qualitative Contract Demand ---
const CONTRACT_PRESSURE_TICKS_MIN: int = 2
const CONTRACT_PRESSURE_TICKS_MAX: int = 4
const CONTRACT_PRESSURE_CAP: int = 6
const CONTRACT_RELIEF_DECAY_PER_TICK: int = 1
const CONTRACT_OCCURRENCE_GLOBAL_CAP: int = 18
const CONTRACT_OCCURRENCE_PER_SECTOR_CAP: int = 3
const CONTRACT_SOURCE_SEARCH_MAX_HOPS: int = 2
const NPC_RUNTIME_CONTRACT_CLAIM_GRACE_TICKS: int = 1
const NPC_RUNTIME_CONTRACT_CLAIM_CHANCE: float = 0.33

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
const EXPLORER_BROKE_RECOVERY_CHANCE_BONUS: float = 0.20

# --- Mortal Agent Lifecycle ---
const MORTAL_GLOBAL_CAP: int = 200
const MORTAL_SPAWN_REQUIRED_SECURITY: Array = ["SECURE", "CONTESTED", "LAWLESS"]
const MORTAL_SPAWN_BLOCKED_SECTOR_TAGS: Array = ["DISABLED", "HOSTILE_INFESTED"]
const MORTAL_SPAWN_MIN_ECONOMY_TAGS: Array = ["RAW_ADEQUATE", "RAW_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE", "CURRENCY_RICH"]
const MORTAL_SPAWN_CHANCE: float = 0.16
const MORTAL_ROLES: Array = ["trader", "hauler", "prospector", "explorer", "pirate"]
const MORTAL_EXPLORER_FRONTIER_SECTOR_RATIO: int = 40
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

# --- Discovery Naming ---
const FRONTIER_DISCOVERY_NAME_PREFIXES: Array = [
	"Void", "Drift", "Nebula", "Rim", "Edge", "Shadow", "Iron",
	"Crimson", "Amber", "Frozen", "Ashen", "Silent", "Storm",
	"Obsidian", "Crystal", "Pale", "Dark",
]
const FRONTIER_DISCOVERY_NAME_SUFFIXES: Array = [
	"Reach", "Expanse", "Passage", "Crossing", "Haven", "Point",
	"Drift", "Hollow", "Gate", "Threshold", "Frontier", "Shelf",
	"Anchorage", "Waypoint", "Depot",
]
const FRONTIER_DISCOVERY_NAME_PREFIXES_BY_PROCEDURAL_TYPE: Dictionary = {
	"asteroid_field": ["Iron", "Shard", "Cinder", "Flint", "Gravel", "Broken", "Ore"],
	"comet_shoal": ["Rime", "Frost", "Tail", "Comet", "Wake", "Glint", "Ice"],
	"rogue_planet": ["Pale", "Silent", "Nomad", "Dusk", "Night", "Far", "Wander"],
	"dark_nebula": ["Void", "Umbral", "Shadow", "Obsidian", "Veil", "Black", "Gloom"],
	"remnant_field": ["Relic", "Ashen", "Broken", "Ember", "Grave", "Shattered", "Cinder"],
}
const FRONTIER_DISCOVERY_NAME_PREFIXES_BY_ENVIRONMENT: Dictionary = {
	"MILD": ["Still", "Quiet", "Silver", "Soft", "Calm", "Clear"],
	"HARSH": ["Ashen", "Storm", "Rime", "Broken", "Jagged", "Cinder"],
	"EXTREME": ["Void", "Bleak", "Frozen", "Obsidian", "Black", "Grim"],
}
const FRONTIER_DISCOVERY_NAME_SUFFIXES_BY_ECONOMY_LEVEL: Dictionary = {
	"POOR": ["Reach", "Hollow", "Frontier", "Drift", "Waste", "Scar", "Shelf"],
	"ADEQUATE": ["Passage", "Crossing", "Point", "Waypoint", "Shelf", "Span", "Threshold"],
	"RICH": ["Anchorage", "Depot", "Haven", "Reserve", "Cache", "Gate", "Exchange"],
}
const DISCOVERY_SYSTEM_NAME_LENGTH_MIN: int = 4
const DISCOVERY_SYSTEM_NAME_LENGTH_MAX: int = 7
const DISCOVERY_NAME_SHORT_ROOT_MAX_LENGTH: int = 4
const DISCOVERY_NAME_MEDIUM_ROOT_MAX_LENGTH: int = 6
const DISCOVERY_NAME_UNIQUENESS_MAX_ATTEMPTS: int = 48

# --- Topology ---
const MAX_CONNECTIONS_PER_SECTOR: int = 4
const EXTRA_CONNECTION_1_CHANCE: float = 0.20
const EXTRA_CONNECTION_2_CHANCE: float = 0.05
const FRONTIER_DISCOVERY_EXTRA_CONNECTION_1_CHANCE: float = 0.55
const FRONTIER_DISCOVERY_EXTRA_CONNECTION_2_CHANCE: float = 0.30
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


func get_economy_level_for_category(sector_tags: Array, category: String) -> String:
	for level in ["POOR", "ADEQUATE", "RICH"]:
		if (category + "_" + level) in sector_tags:
			return level
	return "ADEQUATE"


func get_random_commodity_for_category(category: String, rng: RandomNumberGenerator) -> String:
	var matching: Array = []
	for commodity_id in COMMODITY_CLASSIFICATION:
		if COMMODITY_CLASSIFICATION[commodity_id] == category and not (commodity_id in ILLEGAL_COMMODITIES):
			matching.append(commodity_id)
	if matching.size() == 0:
		return ""
	var index: int = rng.randi() % matching.size()
	return matching[index]

# ---- CONTACT MANAGER ----
const DISPOSITION_FRIENDLY_THRESHOLD: float = 0.5
const DISPOSITION_HOSTILE_THRESHOLD: float = -0.5
