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
const NPC_FACTION_TEMPLATE_PATHS = {  # Faction id -> {AgentTemplate spawned on the battlefield: chance}
	"verdant": {
		"res://database/registry/agents/npc_verdant_fighter.tres": 0.7,
		"res://database/registry/agents/npc_verdant_heavy.tres": 0.3,
	},
	"violet": {
		"res://database/registry/agents/npc_violet_fighter.tres": 0.7,
		"res://database/registry/agents/npc_violet_heavy.tres": 0.3,
	},
}

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
const TETHER_SNAP_STRETCH = 500.0  # m beyond the cable's length: it snaps
const TETHER_SLACK_TAKEUP_SPEED = 20.0  # m/s the winch takes up slack when the ships close in (on top of reeling); closing faster shows a loose cable
# Cable looks (TetherRope, tether_cable.gdshader): shape, strain cue.
# Simulated points follow the cable's length: one per TETHER_ROPE_SEGMENT_LENGTH, within the
# min/max below. Cost grows with points (~0.75 ms per cable per physics frame at 32, ~0.2 at 8);
# a short towing cable needs few. Drawn smoother still (TETHER_RENDER_SUBDIVISIONS).
const TETHER_ROPE_POINTS = 32  # At most
const TETHER_ROPE_MIN_POINTS = 8
const TETHER_ROPE_SEGMENT_LENGTH = 6.0  # m
const TETHER_ROPE_ITERATIONS = 12  # Spacing passes per step: more = stiffer, truer length (more points need more)
const TETHER_ROPE_HULL_PASSES = 3  # Of those, the last this many also keep the cable out of the hulls
const TETHER_ROPE_DAMPING = 0.97  # Share of a point's own motion (relative to the ships) kept per step
const TETHER_ROPE_BUCKLE_NUDGE = 0.05  # m of random nudge per step on a fully slack cable, so it buckles
const TETHER_RENDER_SUBDIVISIONS = 4  # Drawn segments per simulated one (a smooth curve through the points)
const TETHER_ROPE_SIM_DISTANCE = 1500.0  # m from the camera; further cables are not simulated, just drawn straight
const TETHER_LAUNCH_REACH_FACTOR = 1.25  # A hook still flying this far past the harpoon's max range has missed: winched back
const TETHER_RETRACT_SPEED = 40.0  # m/s the winch pulls in a cable that has let go; the harpoon fires again once it is in
const TETHER_CABLE_WIDTH = 0.35  # m
const TETHER_STRAIN_FULL_STRETCH = 8.0  # m of stretch shown as full strain
const TETHER_STRAIN_THINNING = 0.35  # Share of the width lost at full strain
const TETHER_SHIVER_AMPLITUDE = 0.12  # m of sideways shiver at full strain
const TETHER_SHIVER_FREQUENCY = 40.0  # rad/s


# ==================================================================================================
# SIGNATURE AND DETECTION (one rule for everyone)
# ==================================================================================================

# A ship's signature is a distance: the hull's base (ShipTemplate.signature, plus modules) plus what
# it is doing. Another ship detects it within signature * its own sensor strength.
const SIG_ENGINE_FULL = 2500.0  # m added at full thrust
const SIG_ENGINE_SMOOTHING = 0.5  # s; engine signature follows thrust this quickly
const SIG_TOOL_FIRING = 3000.0  # m added right after a tool cycle
const SIG_TOOL_DECAY = 4.0  # s for the firing signature to fade
const SIG_PER_LEAK = 800.0  # m per fuel leak at full pressure
const SIG_WRECK_FACTOR = 0.6  # A wreck's signature is this share of its hull's base (cold, but a big lump of metal)
const SIG_MIN = 200.0  # m; nothing is quieter than this

# The player reads these as cues, not numbers (NPCs use the numbers directly).
# Own signature meter: signature / hull base.
const SIG_LEVEL_ACTIVE = 1.15  # Above this ratio: ACTIVE (below: QUIET)
const SIG_LEVEL_LOUD = 2.0
const SIG_LEVEL_BLAZING = 3.5
# Target difficulty from the player's advantage (see CombatAssessment).
const DIFFICULTY_EASY_ADVANTAGE = 2.0
const DIFFICULTY_EVEN_ADVANTAGE = 0.8
const DIFFICULTY_HARD_ADVANTAGE = 0.3


# ==================================================================================================
# COLLISION HULLS (CollisionHull)
# ==================================================================================================

# Convex, from the lowest level of detail; shots land on them too.
const COLLISION_HULL_MAX_POINTS = 48  # Points per hull: the extreme vertex in this many directions
const HIT_RAY_PASSES = 4  # A shot's ray skips this many other bodies before giving up on its target


# ==================================================================================================
# DAMAGE EFFECTS (looks: scenes/prefabs/effects/, assets/art/effects/)
# ==================================================================================================

# Laser hit flash and vapour.
# Every hit effect scales with absolute beam damage: a weak hit barely shows, a powerful one flashes
# hard and throws a big, fast vapour jet. Intensity = sqrt(damage / HIT_FX_REFERENCE_DAMAGE).
# Engine exhausts (EngineExhaustSet): plume size relative to the exhaust cone models, by thrust.
const ENGINE_PLUME_IDLE_LENGTH = 0.15
const ENGINE_PLUME_MAX_LENGTH = 6.0
const ENGINE_PLUME_MIN_WIDTH = 0.5
const ENGINE_PLUME_MAX_WIDTH = 1.0
const ENGINE_GLOW_IDLE = 0.12  # Exhaust brightness of an idle engine (1 = full burn)

const HIT_FX_REFERENCE_DAMAGE = 6.0  # A hit of this damage shows at intensity 1
const HIT_FX_MAX_INTENSITY = 4.0
const HIT_FX_COOL_COLOR = Color(1.0, 0.45, 0.2)  # Flash colour of a weak hit
const HIT_FX_HOT_COLOR = Color(1.0, 0.95, 0.88)  # Flash colour at HIT_FX_HOT_INTENSITY and above
const HIT_FX_HOT_INTENSITY = 2.0
const HIT_FX_FLASH_DURATION = 0.15  # s
const HIT_FX_LIGHT_DISTANCE = 800.0  # m from the camera; farther hits flash without lighting their surroundings
const HIT_FX_LIGHT_LIFT = 6.0  # m the light sits off the contact point toward the shooter, clear of the full-detail mesh
const HIT_FX_MAX_LIGHTS = 4  # Hits lighting their surroundings at once (GLES2: every light is another pass per object it touches)
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
const EXPLOSION_MAX_LIGHTS = 1  # Explosions lighting their surroundings at once (GLES2: every light is another pass per object it touches)
const EXPLOSION_DRAG = 0.8  # Per second; the cloud centre slows a bit faster than a wreck (LINEAR_DRAG)
# Cloud puffs (spheroids), sizes for the authored ship radius: each grows as it thins out.
const EXPLOSION_PUFF_START_SIZE = 5.0  # m, radius of the spheroid at the start
const EXPLOSION_PUFF_END_SIZE = 32.0  # m, by the end of EXPLOSION_LIFETIME
const EXPLOSION_PUFF_SPREAD = 14.0  # m the puffs drift apart from the centre
const EXPLOSION_PUFF_OPACITY = 0.85  # Glow at the start (additive: brightness)
const EXPLOSION_PUFF_HOT_COLOR = Color(1.0, 0.45, 0.12)
const EXPLOSION_PUFF_SMOKE_COLOR = Color(0.32, 0.3, 0.29)
const EXPLOSION_PUFF_COOL_SHARE = 0.15  # Share of the lifetime over which the puffs cool from orange to grey


# ==================================================================================================
# LEVELS OF DETAIL (MeshLod, tools/generate_lods.py)
# ==================================================================================================

# A model switches to LOD n+1 beyond LOD_DISTANCE_RADII[n] of its own radii from the camera:
# at 15 radii it is ~70 px tall on a 743 px screen (70 degree view), at 40 ~25 px, at 100 ~10 px.
const LOD_DISTANCE_RADII = [15.0, 40.0, 100.0]  # Low-poly models (ships): keep detail long
const LOD_DISTANCE_RADII_DENSE = [4.0, 10.0, 25.0]  # Dense meshes (rocks, tens of thousands of triangles): drop it early
const LOD_HYSTERESIS = 0.1  # Share of a threshold to pass beyond before switching back, so levels do not flicker
const LOD_CHECK_INTERVAL = 0.25  # s between distance checks per model


# ==================================================================================================
# AI AND NPC POPULATION
# ==================================================================================================

const AI_PATROL_RADIUS: float = 1000.0  # m
const AI_PATROL_ARRIVAL_DISTANCE = 50.0  # m
# Predator rule: desire = advantage * clamp(gain / AI_GAIN_REFERENCE, AI_GAIN_FACTOR_MIN, AI_GAIN_FACTOR_MAX),
# where advantage = (own time to die) / (time to kill the target) from current hulls and laser DPS,
# and gain = the target's salvage + cargo value. Engage at desire >= AI_ENGAGE_DESIRE, keep
# fighting while >= AI_DISENGAGE_DESIRE, otherwise break off and flee.
const AI_GAIN_REFERENCE = 200.0  # WP; a target worth this counts as gain factor 1
const AI_GAIN_FACTOR_MIN = 0.25
const AI_GAIN_FACTOR_MAX = 4.0
const AI_ENGAGE_DESIRE = 1.0
const AI_DISENGAGE_DESIRE = 0.8  # Below the engage level, so a fight does not flip-flop
const AI_FLEE_DISTANCE = 6000.0  # m from the threat at which a fleeing ship resumes patrol
const AI_ENEMY_DESIRE_FACTOR = 1.5  # Ships at war (or holding a grudge) want the fight this much more
const AI_SALVAGE_SEARCH_RANGE = 6000.0  # m; wrecks further than this are not worth the trip
const AI_DEPART_ARRIVAL_DISTANCE = 300.0  # m from its spawn point at which a hauler leaves the sector

# NPCs hesitate like people: a decision the rule calls for (engage, break off, answer being shot)
# is taken after a delay, then re-checked. Delay = lerp(SLOW, FAST, skill)
# * (1 + AMBIGUITY_WEIGHT * how close the call is) * random(1 +- RANDOMNESS).
const AI_DECISION_DELAY_SLOW = 3.0  # s for a novice (skill 0)
const AI_DECISION_DELAY_FAST = 0.3  # s for a veteran (skill 1)
const AI_DECISION_AMBIGUITY_WEIGHT = 1.0  # A coin-flip situation takes up to this much longer again
const AI_DECISION_RANDOMNESS = 0.4
const AI_REPATH_INTERVAL = 0.5  # s
const AI_SCAN_INTERVAL = 1.0  # s

# Factions: who is at war with whom. "player" is the player's faction; NPCs are neutral to the
# player unless at war with it, or holding a grudge (the player shot them).
const FACTIONS = {
	"verdant": {"name": "Verdant", "color": Color(0.45, 1.0, 0.35, 1.0), "enemies": ["violet"]},
	"violet": {"name": "Violet", "color": Color(0.85, 0.45, 1.0, 1.0), "enemies": ["verdant"]},
	"raiders": {"name": "Raiders", "color": Color(1.0, 0.55, 0.3, 1.0), "enemies": ["player", "verdant", "violet"]},
}

# The battlefield: each faction arrives from its own side of a point near the home station,
# patrols around that point and fights whoever it meets there. Losses are topped up one ship per
# faction per interval. Haulers with a full hold fly back to their side and leave.
const BATTLE_OFFSET_FROM_HOME = 2500.0  # m from the home station to the middle of the battlefield
const BATTLE_FACTION_SPAWN_DISTANCE = 6000.0  # m from the middle to each faction's arrival point
const BATTLE_SPAWN_SPREAD = 800.0  # m of scatter around the arrival point
const NPC_POPULATION_PER_FACTION: int = 4
const NPC_RESPAWN_INTERVAL: float = 15.0  # s between top-ups

# Wrecks pile up in a long fight: past this many, the oldest stripped ones are removed.
const WRECK_LOOTED_CAP: int = 6
const WRECK_MAX: int = 16  # Past this, the oldest are removed even with salvage left


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
const MUSIC_AMBIENT_VOLUME_DB = -8.0  # Space ambient soundtrack (AmbientMusic)
const MUSIC_AMBIENT_FADE_IN = 6.0  # s
const MUSIC_SILENT_DB = -60.0

const RENDER_SCALE_STEPS = [1.0, 0.5, 0.25]  # Render resolution shares the HUD's render scale button cycles through

const COLOR_UI_TARGET_SELECTED = Color(1.0, 0.9, 0.35, 1.0)  # Yellow: anything not hostile, wrecks included
const COLOR_UI_TARGET_HOSTILE = Color(1.0, 0.22, 0.18, 1.0)  # Red: a live ship hostile to the player
const COLOR_UI_TARGET_NEUTRAL = Color(0.35, 0.95, 1.0, 0.95)  # Cyan: brackets of things without a faction
const COLOR_UI_WRECK = Color(0.6, 0.6, 0.6, 0.9)  # Grey: wreck brackets

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
