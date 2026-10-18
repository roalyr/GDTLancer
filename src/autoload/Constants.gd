# Constants: every tuning value in one place, grouped by system. Look and feel of effects lives in
# their scenes (scenes/prefabs/effects/) and materials (assets/art/effects/); timing and gameplay
# numbers live here.

extends Node

const VERBOSE_RUNTIME_LOGS = false


# ==================================================================================================
# PATHS, NODE NAMES, GAME START
# ==================================================================================================

const PLAYER_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/npc_agent.tscn"
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://database/registry/agents/player_default.tres"
const NPC_HOSTILE_TEMPLATE_PATH = "res://database/registry/agents/npc_hostile_default.tres"

const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

const INITIAL_SECTOR_ID: String = "sector_star_elace"  # Starting sector for a new game
const RUN_PERMADEATH = true  # Losing the ship ends the run: its saves are deleted
const DEFAULT_GAME_START_ID = "start_default"
const FALLBACK_SHIP_TEMPLATE_ID = "ship_default"  # If the game start names no ship


# ==================================================================================================
# FLIGHT PHYSICS
# ==================================================================================================

const LINEAR_DRAG = 0.5  # Velocity damping per second; top speed = thrust / (mass * LINEAR_DRAG)
const ANGULAR_DRAG = 2.0  # Angular velocity damping per second

# Defaults when a ship template does not set its own.
const DEFAULT_LINEAR_THRUST = 5e6  # N
const DEFAULT_ANGULAR_THRUST = 5e6  # N*m
const DEFAULT_SHIP_MASS = 6e4  # kg
const DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45.0  # Degrees

# Autopilot rotation PID: angular velocity toward the target orientation.
const PID_ROTATION_KP = 8.0
const PID_ROTATION_KI = 0.1  # Low to prevent windup
const PID_ROTATION_KD = 4.0

# Autopilot position / velocity PID: orbit radius and stopping precision.
const PID_POSITION_KP = 0.5
const PID_POSITION_KI = 0.01
const PID_POSITION_KD = 0.8


# ==================================================================================================
# AUTOPILOT COMMANDS (approach, move, orbit)
# ==================================================================================================

const NAV_APPROACH_DISTANCE_MULTIPLIER = 1.3
const NAV_APPROACH_MIN_DISTANCE = 50.0  # m
const NAV_ARRIVAL_DISTANCE_THRESHOLD = 20.0  # m
const NAV_ARRIVAL_SPEED_THRESHOLD = 5.0  # m/s
const NAV_CLOSE_ORBIT_DISTANCE_FACTOR = 1.5

# Obstacle avoidance (rocks, stations): the autopilot looks ahead along its velocity and pushes
# sideways off anything whose clearance sphere the path would cross. Manual flight is not steered.
const NAV_AVOID_LOOKAHEAD_TIME = 8.0  # s of travel checked ahead
const NAV_AVOID_CLEARANCE = 1.6  # Keep (obstacle radius + own radius) * this between path and centre
const NAV_AVOID_THRUST = 1.0  # Share of linear thrust used to sidestep at full urgency
const NAV_AVOID_MIN_SPEED = 2.0  # m/s; slower than this, nothing to avoid


# ==================================================================================================
# PLAYER INPUT
# ==================================================================================================

const PLAYER_KEY_THROTTLE_STEP = 0.05  # Throttle change per key press
const TARGETING_RAY_LENGTH = 1e7  # m; double-click "fly toward" ray

# Pointer (mouse / touch): see src/core/ui/pointer_router.gd for the ownership rules.
const POINTER_DRAG_THRESHOLD_PX = 10.0  # A press that moves further is a camera drag, not a click
const POINTER_DOUBLE_CLICK_MS = 400


# ==================================================================================================
# CAMERA
# ==================================================================================================

# Orbit and smoothing.
const CAMERA_START_DISTANCE = 55.0  # m
const CAMERA_POSITION_SMOOTHING = 30.0
const CAMERA_ROTATION_SMOOTHING = 18.0
const CAMERA_TARGET_SMOOTHING = 50.0
const CAMERA_BOB_FREQUENCY = 0.1  # Hz
const CAMERA_BOB_AMPLITUDE = 0.2  # m

# Zoom: distances scale with the target's apparent radius (ShipTemplate.apparent_radius).
const CAMERA_ZOOM_SPEED = 0.5  # Wheel step = this * 0.1 of the zoom range
const CAMERA_MIN_DISTANCE_MULTIPLIER = 1.0
const CAMERA_MAX_DISTANCE_MULTIPLIER = 5.0
const CAMERA_PREFERRED_DISTANCE_MULTIPLIER = 1.0
const CAMERA_MIN_DISTANCE = 1.0  # m, absolute floor
const CAMERA_MAX_DISTANCE = 500.0  # m, absolute ceiling
const CAMERA_NEAR_PLANE_MARGIN = 1.5  # Closest camera distance is radius + near plane * this
const CAMERA_DEFAULT_TARGET_RADIUS = 10.0  # m, for targets without an apparent radius

# Field of view. Zooming past the closest distance (telephoto) narrows the FoV instead.
const CAMERA_MIN_FOV_DEG = 25.0  # At the closest distance
const MAX_ORBIT_CAMERA_FOV: float = 100.0  # At the farthest distance
const CAMERA_TELEPHOTO_MIN_FOV_DEG = 6.0  # Narrowest FoV
const CAMERA_TELEPHOTO_ZOOM_FRACTION = 0.3  # Share of the zoom range spent narrowing the FoV

# Target lock: camera raised so the hull sits below the line of sight to the target.
const CAMERA_TRACKING_TOP_EDGE_SHARE = 0.3  # Hull top edge sits this share of half the FoV below centre
const CAMERA_TRACKING_MAX_ELEVATION = 1.4  # Radians

# Rotation (drag / free flight) and its PIDs.
const CAMERA_PITCH_MIN_DEG = -83.0
const CAMERA_PITCH_MAX_DEG = 83.0
const CAMERA_ROTATION_MAX_SPEED = 15.0
const CAMERA_ROTATION_INPUT_CURVE = 1.1
const CAMERA_PID_YAW_KP = 10.0
const CAMERA_PID_YAW_KI = 0.01
const CAMERA_PID_YAW_KD = 0.1
const CAMERA_PID_PITCH_KP = 10.0
const CAMERA_PID_PITCH_KI = 0.01
const CAMERA_PID_PITCH_KD = 0.1
const CAMERA_PID_INTEGRAL_LIMIT = 10.0
const CAMERA_PID_OUTPUT_LIMIT_MULTIPLIER = 100.0


# ==================================================================================================
# TOOLS, COMBAT AND SALVAGE
# ==================================================================================================

const TOOL_MAX_RANGE_FALLOFFS = 2.0  # A tool stops cycling beyond optimal range + falloff * this
const HIT_AIM_SPREAD = 0.3  # Shots aim at a random point within this central share of the hull bounds

# Harpoon tether.
const TETHER_CLEARANCE = 1.5  # Reels in to (both apparent radii) * this
const TETHER_PERIOD = 2.0  # s; cable stiffness for the pair's combined mass
const TETHER_DAMPING_RATIO = 0.9


# ==================================================================================================
# HULL DAMAGE MARKS (HullScorch + solid shaders)
# ==================================================================================================

const SCORCH_RADIUS_PER_SQRT_DAMAGE = 1.0  # m; a 6-damage hit marks about 2.5 m across
const SCORCH_CENTRE_MARK = 0.35  # Share of the clean surface a single hit marks at its centre
const SCORCH_SURFACE_DEPTH = 1.0  # m; vertices this far behind the first surface count as it
const SCORCH_MIN_SURFACE_POINTS = 8  # Fewer distinct vertices near the shot line = a thin detail (antenna); the shot passes it
const SCORCH_REBUILD_INTERVAL = 0.2  # s; marks paint at once, the mesh re-uploads at most this often
const SCORCH_HEAT_PER_DAMAGE = 0.11  # Heat added at a mark's centre per point of damage (1 = full glow)
const SCORCH_MAX_HEAT = 1.0
const SCORCH_COOL_TIME = 6.0  # s for heat to fall to ~37%; pushed to the shader so both agree


# ==================================================================================================
# DAMAGE EFFECTS (looks: scenes/prefabs/effects/, assets/art/effects/)
# ==================================================================================================

# Laser hit flash and vapour.
const HIT_FX_MAX_INTENSITY = 2.0  # Hits above the tool's full damage flash brighter, up to this
const HIT_FX_FLASH_DURATION = 0.15  # s
const HIT_FX_LIFETIME = 2.0  # s

# Fuel leaks: open where hits land.
const FUEL_LEAK_EVERY_DAMAGE = 40.0  # Hull damage that opens one more leak
const FUEL_LEAK_MAX_PER_SHIP = 3  # The oldest leak gives way beyond this
const FUEL_LEAK_DURATION = 25.0  # s until a leak has bled out
const FUEL_LEAK_THRUST = 400.0  # N at full pressure, opposite the jet, at the leak point (mostly turns the ship)

# Wreck explosion.
const EXPLOSION_REFERENCE_RADIUS = 12.0  # Apparent radius the explosion scene is authored for
const EXPLOSION_LIFETIME = 30.0  # s
const EXPLOSION_FLASH_DURATION = 0.6  # s
const EXPLOSION_DRAG = 0.8  # Per second; the cloud centre slows a bit faster than a wreck (LINEAR_DRAG)


# ==================================================================================================
# AI AND NPC POPULATION
# ==================================================================================================

const AI_DETECTION_RANGE: float = 3000.0  # m, until signature and detection exist
const AI_PATROL_RADIUS: float = 1000.0  # m
const AI_PATROL_ARRIVAL_DISTANCE = 50.0  # m
const AI_FLEE_HULL_FRACTION: float = 0.2
const AI_REPATH_INTERVAL = 0.5  # s
const AI_SCAN_INTERVAL = 1.0  # s

# Uniform in every sector until the layout of space is final.
const NPC_POPULATION_PER_SECTOR: int = 3
const NPC_SPAWN_MIN_DISTANCE: float = 2000.0  # m from the player's arrival point
const NPC_SPAWN_MAX_DISTANCE: float = 6000.0
const NPC_RESPAWN_INTERVAL: float = 60.0  # s between top-ups of a depleted sector


# ==================================================================================================
# SECTORS, DOCKING AND JUMPS
# ==================================================================================================

const DOCKING_PROMPT_RADIUS: float = 500.0  # m; the dock prompt appears
const DOCKING_ACTION_RADIUS: float = 300.0  # m; dock / jump works
const SECTOR_JUMP_ARRIVAL_RADIUS: float = 50000.0  # m; arrival shell for route jumps
const REFERENCE_ORIGIN: Vector3 = Vector3(0, 0, 0)  # Elace system global_position (nebula reference)

const JUMP_ALIGNMENT_MAX_DEVIATION_DEG = 5.0  # Heading error allowed before jumping
const JUMP_ALIGNMENT_FULL_THRUST_SCALE = 1.0

# Jump transition.
const JUMP_ACCEL_DURATION: float = 3.0  # s
const JUMP_FADE_DURATION: float = 3.0  # s
const JUMP_TRANSITION_RIG_NODE_NAME: String = "JumpTransitionRig"
const JUMP_TRANSITION_DEFAULT_DIRECTION: Vector3 = Vector3(0, 0, -1)
const JUMP_TRANSITION_LOAD_TIMEOUT_SEC: float = 1.5

# Travel time by the pair of sector types.
const JUMP_TRAVEL_DURATION: float = 20.0  # Any other pair
const JUMP_DURATION_STAR_STAR: float = 30.0
const JUMP_DURATION_STAR_STAR_COMPANION: float = 15.0
const JUMP_DURATION_STAR_PLANET: float = 10.0
const JUMP_DURATION_PLANET_MOON: float = 5.0
const JUMP_DURATION_ANY_DEEP_SPACE: float = 15.0


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


# ==================================================================================================
# UI COLOURS
# ==================================================================================================

# Selected-target bracket.
const COLOR_UI_TARGET_SELECTED = Color(1.0, 0.9, 0.35, 1.0)  # Yellow: anything not hostile, wrecks included
const COLOR_UI_TARGET_HOSTILE = Color(1.0, 0.22, 0.18, 1.0)  # Red: a live hostile ship

# Jump route brackets, by sector type.
const COLOR_UI_JUMP_ROUTE = Color(0.0, 0.7, 1.0, 1.0)  # Fallback
const COLOR_UI_JUMP_STAR = Color(0.95, 0.65, 0.15, 1.0)  # Warm gold
const COLOR_UI_JUMP_STAR_COMPANION = Color(0.85, 0.45, 0.85, 1.0)  # Violet
const COLOR_UI_JUMP_PLANET = Color(0.15, 0.85, 0.45, 1.0)  # Emerald
const COLOR_UI_JUMP_MOON = Color(0.65, 0.8, 0.95, 1.0)  # Ice blue
const COLOR_UI_JUMP_DEEP_SPACE = Color(0.5, 0.5, 0.9, 1.0)  # Slate blue


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
