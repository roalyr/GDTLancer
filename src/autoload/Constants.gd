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
const NPC_BASE_TEMPLATE_PATH = "res://database/registry/agents/npc_default.tres"  # Arena NPCs: their ship and fit come from their genome

const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

const INITIAL_SECTOR_ID: String = "sector_elace"  # Starting sector for a new game
# Losing the ship is not the end: the player watches the wreck for RESPAWN_DELAY s, the screen fades
# to black, and they wake docked at home in the start's ship (its default fit). Lost: the ship, its
# fit, cargo, loaded rounds and the bounties on it. Kept: the bank, station storage, standing and the world. The save is overwritten.
const RESPAWN_DELAY = 7.0  # s
const RESPAWN_FADE_DURATION = 2.0  # s, each way
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
const NAV_APPROACH_RESUME_MARGIN = 30.0  # m past the hold distance before a holding approach closes in again
# Ramming (command_ram): charges at the target's lead point, or beside it for a ship (lead time
# distance / closing speed, at least MIN_LEAD_SPEED, at most MAX_LEAD_TIME s), thrusting while the
# nose is within acos(THRUST_ALIGNMENT) of the heading; too close to reach strike speed (less the
# throw), it runs straight away until it has the room for that plus TURN_ROOM m to turn in.
const NAV_AIM_PID_GAIN = 2.0  # Rotation PID gain while aiming a cannon
const NAV_AIM_RANGE_TIME = 5.0  # s to make up a range error: closing speed = error / this
const NAV_AIM_MAX_CLOSING = 80.0  # m/s at most, closing or opening
const NAV_AIM_STRAFE_SPEED = 90.0  # m/s sideways while aiming: at 1.8 km, 0.05 rad/s for the target's turrets to track
const NAV_RAM_TURN_ROOM = 150.0  # m
const NAV_RAM_WEAVE_ANGLE = 35.0  # degrees off the line a charge at a ship comes in at from afar: turrets must track it (command_ram)
const NAV_RAM_WEAVE_FULL = 400.0  # m: the full angle from here out
const NAV_RAM_WEAVE_NONE = 200.0  # m: straight in from here in (smoothstep between)
const NAV_RAM_WEAVE_MIN_CLOSING = 60.0  # m/s: closing slower than this, it comes straight in (twice this: the full angle); a target backing away or circling is not lost
const NAV_RAM_PASS_CLEARANCE = 10.0  # m between hulls a ram passes a ship by (it throws its lance on the way, LanceController)
const NAV_RAM_ROCK_STANDOFF = 40.0  # m off a rock's surface a ram on a rock stops its lance's tip, to throw from
const NAV_RAM_ROCK_SPEED_GAIN = 0.5  # 1/s: closing on that standoff at this times the distance left
const NAV_RAM_ROCK_MAX_SPEED = 80.0  # m/s
const NAV_RAM_MIN_LEAD_SPEED = 50.0  # m/s
const NAV_RAM_MAX_LEAD_TIME = 5.0  # s
const NAV_RAM_PID_GAIN = 3.0  # Times PID_ROTATION_KP at the target while charging (command_ram.aim_gain)
const NAV_RAM_PID_GAIN_FROM = 200.0  # m: the usual gain from here out
const NAV_RAM_PID_GAIN_FULL = 15.0  # m: the full gain from here in (smoothstep between)
const NAV_RAM_MAX_RUN_UP = 600.0  # m: a run-up never goes further
const NAV_RAM_MAX_RUN_UP_TIME = 8.0  # s: nor longer (a target that keeps up with it is charged anyway)
const NAV_RAM_PASS_DISTANCE = 150.0  # m: moving away from the target within this, it has passed it: run up
const NAV_RAM_STALL_DISTANCE = 40.0  # m: this close and short of strike speed, it has stalled: run up
const NAV_RAM_DRIFT_GAIN = 1.0  # How hard it leans against its sideways slip relative to the target
const NAV_RAM_THRUST_ALIGNMENT = 0.5  # Thrusts while the nose is within 60 degrees of the heading (drag bleeds speed fast when it coasts)
const NAV_ARRIVAL_SPEED_THRESHOLD = 5.0  # m/s
const NAV_CLOSE_ORBIT_DISTANCE_FACTOR = 1.5  # The orbit radius is at least the target's size times this
const NAV_ORBIT_SPEED_SHARE = 0.6  # Orbit speed as a share of top speed (less on tight orbits: turning limits it)
const NAV_ORBIT_RADIAL_GAIN = 0.2  # Per second: radius error (m) -> speed back toward the orbit radius (m/s)
const NAV_ORBIT_MAX_RADIAL_SHARE = 0.8  # Radial correction speed at most this share of top speed
const NAV_WATCH_BRAKE_SHARE = 0.3  # Watching a target (an NPC hesitating): eases off with this share of its thrust

# Obstacle avoidance (rocks, stations): the autopilot looks ahead along its velocity and pushes
# sideways off anything whose clearance sphere the path would cross. Manual flight is not steered.
const NAV_AVOID_LOOKAHEAD_TIME = 8.0  # s of travel checked ahead
const NAV_AVOID_CLEARANCE = 1.6  # Keep (obstacle radius + own radius) * this between path and centre
const NAV_AVOID_THRUST = 1.0  # Share of linear thrust used to sidestep at full urgency
const NAV_AVOID_MIN_SPEED = 2.0  # m/s; slower than this, nothing to avoid
const NAV_AVOID_INTERVAL = 0.1  # s between a ship's avoidance checks (the push holds in between)


# ==================================================================================================
# PLAYER INPUT
# ==================================================================================================

const PLAYER_KEY_THROTTLE_STEP = 0.05  # Throttle change per key press
const TARGETING_RAY_LENGTH = 1e7  # m; double-click "fly toward" ray

# Pointer (mouse / touch): see src/core/ui/pointer_router.gd for the ownership rules.
const POINTER_DRAG_THRESHOLD_PX = 10.0  # A press that moves further is a camera drag, not a click
const POINTER_DOUBLE_CLICK_MS = 400

# HUD target brackets.
const HUD_BRACKET_REFRESH_INTERVAL = 0.25  # s between re-checks of which target brackets show and their cues (positions follow every frame)


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
const CAMERA_DEFAULT_ZOOM_LEVEL = 0.5  # Middle of the zoom scale: where a new target starts and leaving tracking returns; zooming in past it slides the chase view toward the tracking framing
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
# Cable looks (TetherRope, fx_tether_cable.gdshader): shape, strain cue.
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
# it is doing. Another ship detects it within signature * its own sensor strength. Celestials follow
# the same rule: a star is detected anywhere; planets, moons, asteroids and stations within their
# radius times SIG_PER_METRE_OF_SIZE (a 1 km planet: 100 km, a 20 m rock: 2 km). A station with a
# beacon (the home station) is detected anywhere, like a star.
const SIG_ENGINE_FULL = 2500.0  # m added at full thrust
const SIG_ENGINE_SMOOTHING = 0.5  # s; engine signature follows thrust this quickly
const SIG_TOOL_FIRING = 3000.0  # m added right after a tool cycle
const SIG_TOOL_DECAY = 4.0  # s for the firing signature to fade
const SIG_PER_LEAK = 800.0  # m per fuel leak at full pressure
const SIG_WRECK_FACTOR = 0.6  # A wreck's signature is this share of its hull's base (cold, but a big lump of metal)
const SIG_MIN = 200.0  # m; nothing is quieter than this
const SIG_REACTOR_SHARE = 0.4  # Share of a hull's signature that is its reactor's heat (ShipFit.reactor_signature_factor)
const SIG_REACTOR_MIN_FACTOR = 0.6
const SIG_PER_METRE_OF_SIZE = 100.0  # m of signature per metre of a celestial's or station's radius

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

# Convex, from the lowest level of detail; shots land on them when a ship has no hit surface.
const COLLISION_HULL_MAX_POINTS = 48  # Points per hull: the extreme vertex in this many directions
const HIT_RAY_PASSES = 4  # A shot's ray skips this many other bodies before giving up on its target
# Hit surfaces (ships only): trimeshes of a lower level of detail, baked by tools/bake_hit_shapes.gd.
# Only shot rays look at them; nothing collides with them.
const HIT_SURFACE_LAYER = 1 << 19  # Collision layer 20
const HIT_SURFACE_LOD = 1  # Level of detail the trimesh is made from (0 = the model itself)
const SHOT_BLOCK_MASK = 0x7FFFFFFF & ~HIT_SURFACE_LAYER  # What blocks a line of fire: every layer but the hit surfaces

# Hull scars (HullScars): every hit on a ship's plating leaves a glowing blob that cools to a dark
# lump, sunk into the plating. Sizes are in metres, not scaled with the ship (a beam is a beam).
# Scar and slag counts are for a ship of interaction radius HULL_SCAR_REFERENCE_RADIUS (the Phoenix
# Light) and scale with it: a heavy of twice the radius carries twice as many.
const HULL_SCAR_REFERENCE_RADIUS = 15.0  # m
const HULL_SCAR_MAX_PER_SHIP = 36  # The oldest scar gives way beyond this
const HULL_SCAR_SIZE_PER_SQRT_DAMAGE = 0.6  # m across; a 5-damage hit leaves about 1.3 m
const HULL_SCAR_MIN_SIZE = 0.6  # m
const HULL_SCAR_MAX_SIZE = 3.0  # m
const HULL_SCAR_FLATNESS = 0.35  # Height as a share of the width
const HULL_SCAR_SINK = 0.25  # Share of the height the blob's centre sits below the plating
const HULL_SCAR_MIN_FACING = 0.5  # Cosine; glancing hits stretch along the beam up to 1/this
const HULL_SCAR_ROUND_STRETCH = 1.3  # Below this stretch a scar turns freely about its normal; above, it stays along the beam
const HULL_SCAR_COOL_TIME = 20.0  # s from the hit until the scar is cold char
const HULL_SCAR_LUMP = 0.12  # Bumps on a scar's dome, as a share of its size
const HULL_SCAR_REBUILD_INTERVAL = 0.1  # s; a ship's changed scar and slag chunks are rebuilt at most this often
const HULL_SCAR_CHUNK_BLOBS = 16  # Blobs merged into one chunk mesh (one draw call; a change rebuilds only its chunk)
# Slag (HullScars): lasting damage shows as small slag blobs on the scars that flare up again every
# few seconds, as if re-igniting (timings in hull_slag_material.tres). More the more hull is lost.
const HULL_SLAG_MAX = 56  # Per ship, at no hull left: one per 1/56 of the hull lost
const HULL_SLAG_PER_SCAR = 2  # At most this many slag blobs on one scar
const HULL_SLAG_LUMP = 0.25  # Bumps on a slag blob, as a share of its size
const HULL_SLAG_SIZE_SHARE = 0.7  # A slag blob's size as a share of its scar's
const HULL_SLAG_MAX_SIZE = 0.9  # m: never larger than this (a fresh hit's scar is about 1.3 m)


# ==================================================================================================
# DAMAGE EFFECTS (looks: scenes/prefabs/effects/, assets/art/effects/)
# ==================================================================================================

# Engine exhausts (EngineExhaustSet): plume size relative to the exhaust cone models, by thrust,
# then scaled by speed (a share of the ship's top speed): short when slow, long and slim when fast,
# so a plume grows as a ship speeds up and shrinks as it slows down, even while braking hard.
const ENGINE_PLUME_IDLE_LENGTH = 0.15
const ENGINE_PLUME_MAX_LENGTH = 6.0
const ENGINE_PLUME_MIN_WIDTH = 0.5
const ENGINE_PLUME_MAX_WIDTH = 1.0
const ENGINE_PLUME_STANDSTILL_SHARE = 0.2  # Plume length at no speed, as a share of its length by thrust
const ENGINE_GLOW_STANDSTILL_SHARE = 0.3  # and its brightness above idle: a braking ship's exhaust fades as it stops
const ENGINE_PLUME_SPEED_STRETCH = 0.8  # At top speed the plume is this much longer (0.8: 1.8x)
const ENGINE_PLUME_SPEED_SLIM = 0.2  # and this much slimmer
const ENGINE_PLUME_SPEED_STEP = 0.02  # Speed share change that redraws the plume
const ENGINE_GLOW_IDLE = 0.12  # Exhaust brightness of an idle engine (1 = full burn)

# Laser hit flash and vapour.
# Every hit effect scales with absolute beam damage: a weak hit barely shows, a powerful one flashes
# hard and throws a big, fast vapour jet. Intensity = sqrt(damage / HIT_FX_REFERENCE_DAMAGE).
const HIT_FX_REFERENCE_DAMAGE = 6.0  # A hit of this damage shows at intensity 1
const HIT_FX_MAX_INTENSITY = 4.0
const HIT_FX_COOL_COLOR = Color(1.0, 0.45, 0.2)  # Flash colour of a weak hit
const HIT_FX_HOT_COLOR = Color(1.0, 0.95, 0.88)  # Flash colour at HIT_FX_HOT_INTENSITY and above
const HIT_FX_HOT_INTENSITY = 2.0
const HIT_FX_FLASH_DURATION = 0.15  # s
const HIT_FX_LIGHT_LIFT = 6.0  # m the light sits off the contact point toward the shooter, clear of the full-detail mesh
const HIT_FX_MAX_LIGHTS = 10  # Hits lighting their surroundings at once (GLES2: every light is another pass per object it touches)
const HIT_FX_LIFETIME = 1.5  # s
const HIT_FX_MAX_VAPOR_FACTOR = 1.5  # Vapour count and size grow with intensity up to this many times the authored ones
# Laser beams (LaserBeam): a faint line per shot from the shooter to where it landed, so it reads
# who is firing at whom (gameplay; lasers are otherwise invisible in vacuum). Hit-flash colour.
const LASER_BEAM_BRIGHTNESS = 0.2  # 0..1: barely visible
const LASER_BEAM_DURATION = 0.5  # s to fade out (a laser cycles about once a second)

# Fuel leaks: open where hits land.
const FUEL_LEAK_EVERY_DAMAGE = 20.0  # Hull damage that opens one more leak
const FUEL_LEAK_MAX_PER_SHIP = 3  # The oldest leak gives way beyond this
const FUEL_LEAK_DURATION = 25.0  # s until a leak has bled out
const FUEL_LEAK_THRUST = 400.0  # N at full pressure, opposite the jet, at the leak point (mostly turns the ship)

# Smoulder spots (HullSmoulder): every hit on a ship leaves one, sparking at first, then trailing
# embers until it goes out. Heat is the hit's intensity (sqrt(damage / HIT_FX_REFERENCE_DAMAGE)).
# Sizes and distances are for a fighter (apparent radius SMOULDER_REFERENCE_RADIUS) and scale with ship size.
const SMOULDER_REFERENCE_RADIUS = 12.0  # m
const SMOULDER_DURATION = 10.0  # s of smouldering per unit of heat after the last hit
const SMOULDER_MAX_HEAT = 2.5  # Reheats add up to this (so at most 25 s, 50 s on a wreck)
const SMOULDER_SPARK_TIME = 2.5  # s of sparks after each hit
const SMOULDER_MAX_PER_SHIP = 3  # The oldest spot gives way beyond this
const SMOULDER_MERGE_DISTANCE = 2.0  # m on a fighter (scaled with ship size); a hit this close to a spot reheats it instead of adding one
const EMBER_INSET_SHARE = 0.4  # Ember emitters (smoulder spots, damage trails) sit this share of the way from the hit point to the hull centre (hits land on the collision hull, outside the plating)
const SMOULDER_WRECK_FACTOR = 2.0  # Wrecks smoulder this much longer
const SMOULDER_MAX_SHOWN = 12  # Spots emitting at once
const SMOULDER_CHECK_INTERVAL = 0.25  # s between checks per spot (its ship's view band, the shown budget)
# Damage trails (DamageTrail): lasting, sparse ember trails on a hurt hull, one more per share of
# hull lost, until repaired. They start where the latest hit landed.
const DAMAGE_TRAIL_HULL_STEP = 0.25  # One trail per this share of hull lost (so 75% lost = 3)
const DAMAGE_TRAIL_MAX = 3  # Per ship
const DAMAGE_TRAIL_MAX_SHOWN = 12  # Trails emitting at once
# Rocks do not burn: a hit leaves a slow dust puff instead (RockDust).
const ROCK_DUST_MAX = 6  # Puffs at once

# Wreck explosion.
const EXPLOSION_REFERENCE_RADIUS = 12.0  # Apparent radius the explosion scene is authored for
const EXPLOSION_LIFETIME = 16.0  # s
const EXPLOSION_FLASH_DURATION = 0.6  # s
const EXPLOSION_MAX_LIGHTS = 1  # Explosions lighting their surroundings at once (GLES2: every light is another pass per object it touches)
const EXPLOSION_DRAG = 0.8  # Per second; the cloud centre slows a bit faster than a wreck (LINEAR_DRAG)
# Cloud puffs (spheres, fx_explosion_cloud.gdshader; colours in explosion_puff_material.tres), sizes
# for the authored ship radius: a fireball that swells fast, burns out to smoke, then thins away.
const EXPLOSION_PUFF_START_SIZE = 4.0  # Scale of the puff sphere (radius 1.25 m) at the start
const EXPLOSION_PUFF_END_SIZE = 36.0  # and by the end of EXPLOSION_LIFETIME
const EXPLOSION_PUFF_SPREAD = 12.0  # m the puffs drift apart from the centre
const EXPLOSION_PUFF_OPACITY = 0.95  # At the start
const EXPLOSION_PUFF_FADE_START = 0.1  # Share of the lifetime the smoke holds before it thins
const EXPLOSION_PUFF_MIN_OPACITY = 0.02  # A puff fainter than this is hidden (it still costs a full blended layer)
const EXPLOSION_PUFF_COOL_SHARE = 0.15  # Share of the lifetime over which the fire burns out to smoke


# ==================================================================================================
# VIEW DETAIL (ViewBand, ViewDetail; levels of detail: MeshLod, tools/generate_lods.py)
# ==================================================================================================

# One rule for everything that drops detail with distance: apparent size, in bands. An object's
# screen share is the part of the screen height its diameter covers, zoom included (a narrow field
# of view makes far objects large). Its band is the first whose share it reaches:
#   CLOSE >= 0.33, NEAR >= 0.12, MID >= 0.04, FAR >= 0.013, else DOT
# (about 245, 90, 30 and 10 px tall on a 743 px screen), with VIEW_BAND_HYSTERESIS so a band does
# not flicker at a threshold.
# - Hosts (ships, rocks) carry a ViewDetail that keeps their band. Everything on a host follows the
#   host's band: its levels of detail, scars, slag, smoulder, damage trails, hit lights, cables. So a
#   ship's model, scars and embers always change together.
# - Loose effects with no host to follow (rock dust) take a band from their own size (ViewBand.band_of).
# - Each *_MAX_BAND below is the last (most distant) band the thing still shows in.
const VIEW_CLOSE = 0
const VIEW_NEAR = 1
const VIEW_MID = 2
const VIEW_FAR = 3
const VIEW_DOT = 4
const VIEW_BAND_SHARES = [0.33, 0.12, 0.04, 0.013]  # Screen share to reach CLOSE, NEAR, MID, FAR
const VIEW_BAND_HYSTERESIS = 0.1  # Share of a threshold to pass beyond before switching back
const VIEW_CHECK_INTERVAL = 0.25  # s between band checks per host (and at once when the field of view changes)
# Levels of detail by band (CLOSE, NEAR, MID, FAR, DOT), clamped to the levels a model has.
const LOD_LEVEL_BY_BAND = [0, 0, 1, 2, 3]  # Low-poly models (ships): keep detail long
const LOD_LEVEL_BY_BAND_DENSE = [0, 1, 2, 3, 3]  # Dense meshes (rocks, tens of thousands of triangles): drop it early
const HULL_SCAR_MAX_BAND = VIEW_FAR  # Scars (1-3 m)
const HULL_SLAG_MAX_BAND = VIEW_MID  # Slag (under 1 m) goes a band before the scars
const SMOULDER_MAX_BAND = VIEW_FAR  # Smoulder spots emit
const DAMAGE_TRAIL_MAX_BAND = VIEW_FAR  # Damage trails emit
const HIT_FX_LIGHT_MAX_BAND = VIEW_FAR  # A hit lights its surroundings (the band of the body hit and of the light's own reach; still capped by HIT_FX_MAX_LIGHTS)
const TETHER_ROPE_SIM_MAX_BAND = VIEW_FAR  # A cable is simulated (band of the ship holding it); farther, drawn straight
const ROCK_DUST_MAX_BAND = VIEW_FAR  # A dust puff shows (its own size, ROCK_DUST_RADIUS)
const ROCK_DUST_RADIUS = 8.0  # m: a dust puff's rough extent, for its band


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
# Runners (see ShipControllerAI): a ship moving away from its pursuer at over RUNNER_SPEED_SHARE of
# its top speed is running. The pursuer goes on only while (runner's time to safety) / (its own time
# to get the runner in reach) * PURSUIT >= 1, and lets one go that has not hit it for
# RETURN_FIRE_WINDOW s with chance MERCY; a ship let go is left alone for SPARE_TIME s unless it
# shoots. A runner shoots back with chance RETURN_FIRE (rolled per flight). Defaults for NPCs
# without behaviour genes (the evolving genes start from the same).
const AI_PURSUIT = 1.0
const AI_MERCY = 0.5
const AI_RETURN_FIRE = 0.5
const AI_RUNNER_SPEED_SHARE = 0.5
const AI_RETURN_FIRE_WINDOW = 4.0  # s
const AI_SPARE_TIME = 60.0  # s
# Desperation (Agent.get_desperation): 1 - wallet / (the ship's value * DESPERATION_COMFORT), 0..1.
# A broke pilot takes worse odds: engage and break-off levels * (1 - DESPERATION_NERVE * d); it
# spares less (mercy * (1 - d)), chases harder (pursuit * (1 + d)), shoots back more (return fire
# toward 1 by d) and runs home later (retreat hull * (1 - d)). NPCs that do not evolve start with a
# random wallet of up to WALLET_MAX_SHARE of their ship's value; evolving pilots, see EVO_PILOT_STAKE_SHARE.
const AI_DESPERATION_COMFORT = 1.0
const AI_HAUL_SHARE = 0.25  # An NPC goes home to sell once its hold is worth this share of its ship (behaviour gene "haul")
const AI_DESPERATION_NERVE = 0.5
const AI_WALLET_MAX_SHARE = 2.0
# Ramming (kinetic lance; ShipControllerAI, command_ram): a lance counts in a ship's damage per second
# as one throw at its top speed plus LANCE_LAUNCH_SPEED per RAM_PASS_TIME s (or per reload, if
# longer). An NPC rams while its top speed is at least LANCE_CATCH_SPEED and it has lances left.
const AI_RAM_PASS_TIME = 10.0  # s between strikes: run-up, turn and charge
# Whether a charge pays (Agent.ram_outlook; ShipControllerAI.ram_worth): the hull it can expect to
# lose on the way in (the target's side's damage per second, times HIT_SHARE for the angled approach,
# over the time from the side's reach to release range, plus TURN_EXPOSURE s round for the next
# pass) against what its throws would do (less MISS_SHARE). An NPC charges only while that loss keeps
# it above its retreat level, or when a throw would finish the target (and not it); it weighs it
# again between passes, and may break off a charge until NO_RETURN m from the target. A lancer with
# no other weapon on the target hangs back, HOLD_OFF times the side's reach away. The player's RAM
# button reads RAM: TOO HOT when the loss would be its whole hull.
const AI_RAM_HIT_SHARE = 0.5
const AI_RAM_TURN_EXPOSURE = 4.0  # s
const AI_RAM_MISS_SHARE = 0.2
const AI_RAM_NO_RETURN = 300.0  # m
const AI_RAM_HOLD_OFF = 1.2
const AI_TEAM_RADIUS = 3000.0  # m: friends this near a ship count on its side of a fight (CombatAssessment.side_of)
const AI_ASSIST_RADIUS = 4000.0  # m: an NPC this near a friend under fire considers going to help
const AI_ENEMY_DESIRE_FACTOR = 1.5
# Seeing first (sensor boosters, quiet hulls): a target that cannot see this ship is a first
# strike, AI_UNSEEN_DESIRE_FACTOR times as tempting; an enemy it sees but that cannot see it, under
# AI_AVOID_SHARE of the fight it would take on, it keeps clear of while it can ("avoided").
const AI_UNSEEN_DESIRE_FACTOR = 1.3
const AI_AVOID_SHARE = 0.5
const AI_AFTERBURNER_RESERVE = 0.3  # Share of its power an NPC keeps for its weapons (it burns on past it only to run)
const AI_AFTERBURNER_CLOSE_FACTOR = 2.0  # Burns to close in from beyond this many times its fighting range  # Ships at war (or holding a grudge) want the fight this much more
const AI_SALVAGE_SEARCH_RANGE = 6000.0  # m; wrecks further than this are not worth the trip
const AI_MINE_SEARCH_RANGE = 6000.0  # m; rocks further than this are not worth the trip
const AI_MINE_GIVE_UP = 120.0  # s on one rock without a chunk before it tries another
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
const AI_THINK_INTERVAL = 0.1  # s between an NPC's thinks (its commands and tools run on in between)

# Factions: who is at war with whom. "player" is the player's faction; NPCs treat the player by
# standing (Standing: the faction's "standing" to start with, 0 if none) or a grudge (the player shot them).
const FACTIONS = {
	"verdant": {"name": "Verdant", "color": Color(0.45, 1.0, 0.35, 1.0), "enemies": ["violet"]},
	"violet": {"name": "Violet", "color": Color(0.85, 0.45, 1.0, 1.0), "enemies": ["verdant"]},
	"raiders": {"name": "Raiders", "color": Color(1.0, 0.55, 0.3, 1.0), "enemies": ["verdant", "violet"], "standing": -1.0},
	# Aliens: no standing or bounties; they react on the spot, and take any ship within `territory` m of
	# their hive for an enemy. Their carcasses hold biotech (`salvage_as`: a wreck's salvage, all of it).
	"xenohive": {"name": "Xenohive", "color": Color(0.35, 0.95, 0.75, 1.0), "enemies": [], "no_standing": true,
		"territory": 2500.0, "salvage_as": "commodity_biotech"},
}

# Standing (Standing): the player's name with each faction, -1 to 1, as in Freelancer.
const STANDING_HOSTILE = -0.6  # At or below: its ships attack the player on sight, its stations refuse docking
const STANDING_FRIENDLY = 0.6  # At or above: friendly (shown; prices are best)
const STANDING_ATTACK = 0.03  # Lost with a ship's faction the first time the player hits that ship
const STANDING_KILL = 0.12  # Lost with a ship's faction when the player kills it
const STANDING_KILL_ENEMY = 0.04  # Gained with each faction at war with the victim's

# Bounties (Bounty): shares of the ship's value (Agent.get_value).
const BOUNTY_WAR_SHARE = 0.2  # Paid by a faction for a ship of a faction it is at war with
const BOUNTY_POST_SHARE = 0.1  # Posted by a faction on whoever kills one of its ships, per kill
const BOUNTY_HUNT_SHARE = 0.05  # Ships go after a ship carrying a claimable posting worth this much of their own value

# Fuel (Fuel): a jump burns ceil(ship mass / FUEL_MASS_PER_UNIT) units from the hold.
const FUEL_COMMODITY = "commodity_fuel"
const FUEL_MASS_PER_UNIT = 2500.0  # kg
const FUEL_STARTING_UNITS = 6  # In the hold of a new game's ship and of the ship given after a loss

# Mining (Asteroid, OreChunk, LanceController): a composite act. A lance thrown into a rock at strike
# speed breaks damage / MINING_DAMAGE_PER_UNIT units of its deposit (at most MINING_CHUNK_MAX, and
# what is left) off its face, in 1 to MINING_PIECES_MAX pieces; the lance stays in the rock (a
# LooseLance, harpooned out). Each piece is crusted: laser fire burns the crust off (MINING_CRUST_HP)
# and bares the ore, a metal lump unlike the rock, glowing hot, that cools in MINING_COOL_TIME s;
# cooled, a harpoon tows it and strips it like a wreck.
const MINING_DAMAGE_PER_UNIT = 15.0  # Lance damage per unit broken out
const MINING_CHUNK_MAX = 12  # Units broken out by one strike
const MINING_PIECES_MAX = 3
const MINING_PIECE_SPREAD = 30.0  # Degrees the pieces fan out off the face
const MINING_CRUST_HP = 40.0  # Laser damage to burn a piece's crust off
const MINING_COOL_TIME = 15.0  # s the bared slag glows before a harpoon can take it
const MINING_ORE_PER_METRE = 1.0  # A rock's deposit: units per metre of its radius
const MINING_CHUNK_SPEED = 8.0  # m/s the chunk drifts off the rock's face
const MINING_CHUNK_BASE_MASS = 100.0  # kg of rock round the deposit in a chunk
const MINING_CHUNK_RADIUS = 0.75  # m for a one-unit chunk (grows as the cube root of its units)
const MINING_CHUNK_MODELS = [  # Low-poly rocks (the rock models' last LOD)
	"res://assets/models/rocks/lod/rock_01_6k_LOD3.glb", "res://assets/models/rocks/lod/rock_03_4k_LOD3.glb",
	"res://assets/models/rocks/lod/rock_05_4k_LOD3.glb",
]
const MINING_SLAG_COLOR = Color(1.0, 0.45, 0.15, 1.0)  # Hot slag's glow, fading as it cools
const MINING_DEPOSIT = "commodity_ore"  # What rocks hold

# Megastructures (Megastructure): clusters of remnants left by successive builders, one layer each,
# in plain geometric shapes for now (to judge scale by eye). Per layer: its material (the solid
# shader with NLP off), how many pieces, their size (m, longest side), how far out from the cluster's
# middle (times the first layer's size; 0: at the middle), and whether its pieces are mined (for what,
# units per metre of radius).
const MEGASTRUCTURE_LAYERS = [
	{"name": "Ancient remnant", "material": "res://assets/art/materials_generic/mat_megastructure_ancient.tres",
		"count": [1, 2], "size": [1500.0, 4000.0], "spread": [0.0, 0.3], "mineable": false},
	{"name": "Old structure", "material": "res://assets/art/materials_generic/mat_megastructure_middle.tres",
		"count": [5, 9], "size": [150.0, 600.0], "spread": [0.4, 0.7], "mineable": false},
	{"name": "Derelict debris", "material": "res://assets/art/materials_generic/mat_megastructure_recent.tres",
		"count": [14, 22], "size": [15.0, 80.0], "spread": [0.8, 1.6], "mineable": true,
		"deposit_id": "commodity_relic", "deposit_per_metre": 0.15},
]
const MEGASTRUCTURE_SHAPES = ["box", "cylinder", "sphere", "prism", "capsule"]

# Off-screen resolution (Offscreen): ships far from the player are not flown but resolved by rule.
const OFFSCREEN_RADIUS = 12000.0  # m from the player past which a ship is resolved off-screen
const OFFSCREEN_FULL_RADIUS = 10000.0  # m within which it is flown again (the gap stops flicker)
const OFFSCREEN_CHECK_INTERVAL = 0.5  # s between looks at who is near and far
const OFFSCREEN_TICK = 1.0  # s per resolution step
const OFFSCREEN_SPEED_SHARE = 0.6  # Of its top speed it moves at (to be fitted to flown runs)
const OFFSCREEN_ENGAGE_RANGE = 1500.0  # m at which an off-screen fight is resolved
const OFFSCREEN_HIT_SHARE = 0.35  # Of its damage per second that lands (to be fitted to flown fights)
const OFFSCREEN_MINE_RANGE = 1000.0  # m off a rock's surface a prospector works from
const OFFSCREEN_ORE_PER_SECOND = 0.1  # Units a prospector gets off a rock (to be fitted to flown mining)
const OFFSCREEN_PATROL_RADIUS = 1500.0  # m from the middle of its patrol it keeps within

# Threat ring (HUD ThreatRing): arrows round the screen's middle toward hostile ships out of sight.
const THREAT_RANGE = 15000.0  # m; detected hostiles further than this are not shown
const THREAT_REFRESH_INTERVAL = 0.25  # s between rechecks of who is hostile
const THREAT_RING_RADIUS_SHARE = 0.25  # Ring radius, of the screen's shorter side
const THREAT_ARROW_SIZE = [28.0, 56.0]  # px, far to near
const THREAT_COLOR = Color(1.0, 0.36, 0.12, 1.0)  # Red-orange, as hostile brackets

# Traffic (Traffic): persistent NPCs travelling the sector graph, the population besides the evolving NPCs.
const TRAFFIC_ROSTER = [  # Kind (faction, niche role; "" any) and how many
	{"faction": "verdant", "role": "prospector", "count": 2},
	{"faction": "violet", "role": "prospector", "count": 2},
	{"faction": "verdant", "role": "fighter", "count": 1},
	{"faction": "violet", "role": "fighter", "count": 1},
	{"faction": "raiders", "role": "", "count": 3},
]
const TRAFFIC_DWELL_TIME = [240.0, 720.0]  # s of world time a traveller stays in a sector
const TRAFFIC_TRANSIT_TIME = 60.0  # s between leaving a sector and arriving in the next
const TRAFFIC_REPLACE_TIME = 600.0  # s before a lost traveller's place is filled again
const TRAFFIC_FUEL_JUMPS = 4  # Fuel bought in Elace: this many jumps' worth
const TRAFFIC_START_BANK = 2000.0  # WP a new traveller has
const TRAFFIC_WORK_RADIUS = 1500.0  # m round its work point a traveller turns up at
const TRAFFIC_WORK_SEARCH = 40000.0  # m from the entry point a prospector looks for something to mine

# Prices (Market): physics value * (1 + the station's markup) * (1 -+ standing share).
const PRICE_MARKUP_MAX = 0.5  # A station's markup is rolled in 0..this
const PRICE_MARKUP_PERIOD = [1440.0, 2160.0]  # s of world time a markup holds before it is rolled again
const PRICE_STANDING_SHARE = 0.1  # Standing 1 buys this much cheaper and sells this much dearer; -1 the reverse
const PRICE_CARGO_SELL_SHARE = 0.8  # What a station pays for cargo, of what it charges (under (1-S)/(1+S): no round trip pays)
const PRICE_PART_SELL_SHARE = 0.5  # and for parts and a traded-in hull

# Wrecks pile up in a long fight: past this many, the oldest stripped ones are removed.
const WRECK_LOOTED_CAP: int = 6
const WRECK_MAX: int = 16  # Past this, the oldest are removed even with salvage left


# ==================================================================================================
# SHIP AND PART LAWS (ShipLaws)
# ==================================================================================================

# Every ship and part stat follows from a few physical quantities (masses, a laser's shot energy)
# by power laws: amount = REF_AMOUNT * (quantity / REF_QUANTITY) ^ EXPONENT. Exponents under 1:
# returns diminish, so piling up one stat never pays and the best designs sit somewhere in the
# middle. The reference points are the Phoenix Light and the Ablative Laser: their genes give
# their old numbers. A ship's own subsystems follow the same laws as the modules that add to them.
# Laws as [reference mass kg, amount at that mass, exponent].
const LAW_HULL = [3300.0, 120.0, 0.8]  # Structure or plating mass -> hull points
const LAW_THRUST = [1200.0, 450000.0, 0.9]  # Engine or thruster mass -> N
const LAW_REGEN = [600.0, 10.0, 0.9]  # Reactor or power cell mass -> power per second
const LAW_CAPACITY = [300.0, 100.0, 1.0]  # Capacitor mass -> power stored
const LAW_HOLD = [600.0, 20.0, 1.0]  # Hold mass -> cargo units

# Ships: size factor s = mass / LAW_SHIP_REF_MASS; length grows as s^(1/3), surface as s^(2/3).
# The mass splits into structure, engines, reactor, capacitor and hold by the ship's shares.
const LAW_SHIP_REF_MASS = 6000.0  # kg (the Phoenix Light)
const LAW_SHIP_SIZE_MIN = 0.2
const LAW_SHIP_SIZE_MAX = 8.0
const LAW_SHIP_SHARES = {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}  # The Phoenix Light's
const LAW_SHIP_SHARE_MIN = {"structure": 0.2, "engine": 0.03, "reactor": 0.02, "capacitor": 0.01, "hold": 0.0}
const LAW_SHIP_RADIUS = 12.0  # m apparent radius at s = 1, times length
const LAW_SHIP_INTERACTION_RADIUS = 15.0  # m at s = 1, times length
const LAW_SHIP_SIGNATURE = 1500.0  # m at s = 1, times length (cross-section seen edge-on)
const LAW_TORQUE_PER_THRUST = 1.11  # N*m of turning torque per N of engine thrust at s = 1, times length (lever)
const LAW_TOOL_SLOTS = 2.0  # Hardpoints at s = 1, times surface (rounded, at least 1)
const LAW_MODULE_SLOTS = 2.0  # Module bays at s = 1, times s^(1/2) (rounded)
const LAW_SLOT_MEDIUM_SIZE = 2.0  # s from which hardpoints take medium tools
const LAW_SLOT_LARGE_SIZE = 5.0  # and large ones
const LAW_SHIP_VALUE_PER_KG = 1.0 / 6.0  # WP
const LAW_SCRAP_PER_KG = 1.0 / 300.0  # Salvage units of scrap in a wreck, per kg of ship
const LAW_TECH_PER_KG = 1.0 / 200.0  # and of tech, per kg of engines and reactor

# Lasers: shot energy E (power spent per cycle) and mass m (aperture, cooling).
#   damage = DAMAGE * (E/E0)^a, optimal = RANGE * (m/m0)^b * (E/E0)^c, tracking = TRACKING * (m/m0)^d,
#   cycle = CYCLE * (E/E0) / (m/m0)^k (the heat of a shot leaves through the cooling train).
const LAW_LASER_REF_MASS = 300.0  # kg
const LAW_LASER_REF_ENERGY = 5.0
const LAW_LASER_DAMAGE = [6.0, 0.8]  # [at E0, exponent of E]
const LAW_LASER_RANGE = [1000.0, 1.0 / 3.0, 0.25]  # [m at m0 and E0, exponent of m, of E]
const LAW_LASER_FALLOFF_SHARE = 0.25  # Falloff as a share of optimal range
const LAW_LASER_TRACKING = [0.1, -0.5]  # [rad/s at m0, exponent of m]: heavier turrets swing slower
const LAW_LASER_CYCLE = [1.0, 0.5]  # [s at m0 and E0, exponent k of m the cooling grows with]
const LAW_LASER_CYCLE_RANGE = [0.25, 8.0]  # s
const LAW_LASER_MEDIUM_MASS = 800.0  # kg from which a laser needs a medium hardpoint
const LAW_LASER_LARGE_MASS = 2500.0  # and a large one
const LAW_LASER_VALUE = [0.2, 8.0]  # WP per kg, per unit of shot energy
const LAW_PART_VALUE_PER_KG = 0.25  # WP for modules

# Gene bounds (the laws hold anywhere; these keep the search in sensible ranges).
const LAW_LASER_MASS_RANGE = [50.0, 4000.0]
const LAW_LASER_ENERGY_RANGE = [0.5, 60.0]
const LAW_MODULE_MASS_RANGE = [50.0, 5000.0]
# Modules that do more than add a stat (ShipLaws.module_stats, ShipFit, Agent):
# Sensor booster: sees farther (sensor strength, 1 for a bare hull, multiplies every detection range).
# It also steadies the ship's targeting against sensor dampers (below): their jamming is divided by it.
const LAW_SENSOR = [250.0, 0.5, 0.5]  # Module mass -> sensor strength added (0.3 lagged: -0.10 fitness over rounds 34-37)
# Sensor damper (electronic warfare): the ship is still seen, but enemy weapons fail to lock on it
# from afar. It jams a share of their reach (lasers, missiles, cannons), more the bigger it is
# against the hull: LAW_DAMPER_SHARE at LAW_DAMPER_REF_SHARE of the hull's mass, as the square root,
# at most LAW_DAMPER_MAX; divided by the attacker's sensor strength. Never below the range at which
# the ship is seen well by eye, EWAR_SIGHT_PER_METRE times its apparent radius (a Phoenix Light,
# 12 m: 960 m). Active: it draws LAW_DAMPER_POWER_PER_KG power a second per kg off the reactor.
const LAW_DAMPER_SHARE = 0.5
const LAW_DAMPER_REF_SHARE = 0.05
const LAW_DAMPER_MAX = 0.75
const LAW_DAMPER_POWER_PER_KG = 0.007  # The reference 300 kg damper: 2.1 a second (a Phoenix Light makes 10)
const EWAR_SIGHT_PER_METRE = 80.0
# Decoy launcher: a charge per LAW_DECOY_CHARGE_MASS kg. A missile coming at the ship within
# DECOY_TRIGGER_TIME s of impact draws a decoy (one each); DECOY_SEDUCE_CHANCE of them take the missile
# off after the flare, which drifts off at DECOY_EJECT_SPEED and burns DECOY_LIFETIME s. Refilled at a
# base for LAW_DECOY_VALUE WP each.
const LAW_DECOY_CHARGE_MASS = 50.0
const LAW_DECOY_VALUE = 15
const DECOY_TRIGGER_TIME = 2.5
const DECOY_SEDUCE_CHANCE = 0.85  # 0.7 lagged (-0.39 fitness over era 45, against dominant missiles)
const DECOY_EJECT_SPEED = 80.0
const DECOY_LIFETIME = 5.0
const DECOY_BURST_DISTANCE = 25.0  # m: a missile this near its decoy bursts on it
const DECOY_COLOR = Color(1.0, 0.85, 0.5)
const DECOY_MODEL_RADIUS = 1.5  # m
# Afterburner: while lit, extra thrust LAW_AFTERBURNER_FACTOR times a thruster of its mass gives, at
# LAW_AFTERBURNER_POWER_PER_KN power a second per kN in use (none while coasting), and a hot plume
# (SIG_AFTERBURNER at full thrust). Goes out when power runs short.
const LAW_AFTERBURNER_FACTOR = 3.0
const LAW_AFTERBURNER_POWER_PER_KN = 0.03
const SIG_AFTERBURNER = 3000.0

# Kinetic lance (module "lance"): a seat that strikes like a hammer, and a quiver of lances (nails)
# fixed on the hull. An armed lance strikes a ship its tip meets at a closing speed along the lance
# of at least LANCE_MIN_SPEED, within LANCE_GLANCE_ANGLE of square-on; otherwise it glances off. A
# strike leaves the lance in the target; the next slides into the seat after the reload time.
# Genes: lance (nail) mass m and count n.
#   damage = DAMAGE * (m/m0)^a * (v / REF_SPEED)^SPEED_EXP, past the nose LENGTH * (m/m0)^(1/3) m,
#   reload RELOAD * (m/m0)^b s, module mass m * (n + SEAT_NAILS) (the seat weighs as much as that).
const LAW_LANCE_DAMAGE = [200.0, 120.0, 0.8]  # A 200 kg lance kills a Phoenix Light at 200 m/s
const LAW_LANCE_LENGTH = [200.0, 12.0, 1.0 / 3.0]
const LAW_LANCE_RELOAD = [200.0, 4.0, 0.5]
const LAW_LANCE_REF_SPEED = 200.0  # m/s
const LAW_LANCE_SPEED_EXP = 1.0
const LAW_LANCE_MIN_SPEED = 60.0  # m/s; slower, it glances off
const LAW_LANCE_GLANCE_ANGLE = 60.0  # degrees off square-on: the hit chance falls from 1 square-on to the slip chance here
const LAW_LANCE_GLANCE_EXP = 2.0  # The hit chance falls as (angle / GLANCE_ANGLE)^EXP: slowly near square-on, fast near the threshold
const LAW_LANCE_SLIP_CHANCE = 0.15  # Past the glance angle, the chance a 12 m lance slips between parts and goes in (times length / 12 m, fading to 0 side-on)
const LAW_LANCE_SLIP_MAX = 0.4
const LAW_LANCE_SEAT_NAILS = 2.0
const LAW_LANCE_PROW_SHARE = 1.0  # The module armours the bow: hull as plating of this share of its mass (a lancer must live through its approach)
const LAW_LANCE_NAIL_MASS_RANGE = [30.0, 1500.0]
const LAW_LANCE_COUNT_RANGE = [1.0, 12.0]

# Weapon archetypes. Lasers: turrets, no ammunition, drain power (sustained fire needs a big reactor
# or power cells). Lances: melee, recoverable, no power. Missiles: guided heavy hitters,
# one use each; more only from a base or a missile ship's wreck. Cannons (rail drives): fixed
# forward, the ship aims; rounds fly at a finite speed (lead the target), a magazine of them, little
# power. Laws below are [reference, value there, exponent], as LAW_HULL.
const LAW_LASER_POWER_PER_ENERGY = 1.5  # Power drawn per unit of shot energy: two reference lasers outdraw a Phoenix Light's reactor

# Missiles (genes: round_mass kg, count). The rack holds count missiles, plus RACK_ROUNDS' mass of frame.
const LAW_MISSILE_REF_MASS = 100.0  # kg
const LAW_MISSILE_DAMAGE = [100.0, 50.0, 0.9]  # Round mass -> warhead damage: three reference missiles kill a Phoenix Light
const LAW_MISSILE_SPEED = [100.0, 320.0, -0.1]  # -> top speed, m/s past the launcher's
const LAW_MISSILE_ACCEL = [100.0, 120.0, -0.2]  # -> m/s^2
const LAW_MISSILE_TURN = [100.0, 1.2, -0.25]  # -> rad/s: heavy missiles turn wide, so an agile ship can make them overshoot
const LAW_MISSILE_FLIGHT = [100.0, 20.0, 0.2]  # -> s of fuel
const LAW_MISSILE_CYCLE = [100.0, 3.0, 0.3]  # -> s between launches
const LAW_MISSILE_RANGE_SHARE = 0.5  # Launch range: this share of top speed times flight time
const LAW_MISSILE_HP = [100.0, 18.0, 0.8]  # -> laser damage that shoots it down (three reference laser shots square-on)
const LAW_MISSILE_RACK_ROUNDS = 1.0
const LAW_MISSILE_POWER = 2.0  # Per launch
const LAW_MISSILE_VALUE_PER_KG = 0.25  # WP per kg of missile (restock and salvage): as any part
const LAW_MISSILE_MASS_RANGE = [10.0, 1000.0]
const LAW_MISSILE_COUNT_RANGE = [1.0, 16.0]
# Cannons (genes: mass kg of the gun, round_mass kg, count rounds). Muzzle speed grows with the gun
# and falls with the round; damage with the round's mass and speed.
const LAW_CANNON_REF_MASS = 300.0  # kg of gun
const LAW_CANNON_REF_ROUND = 5.0  # kg
const LAW_CANNON_SPEED = [300.0, 900.0, 0.3]  # Gun mass -> muzzle speed m/s for the reference round, times (round/REF_ROUND)^ROUND_SPEED_EXP
const LAW_CANNON_ROUND_SPEED_EXP = -0.2
const LAW_CANNON_DAMAGE = [5.0, 12.0, 0.9]  # Round mass -> damage at the reference muzzle speed (times speed / 900)
const LAW_CANNON_CYCLE = [5.0, 1.2, 0.5]  # Round mass -> s between shots
const LAW_CANNON_POWER = [5.0, 1.0, 1.0]  # Round mass -> power per shot: a fifth of a laser's
const LAW_CANNON_FLIGHT = 4.0  # s a round flies
const LAW_CANNON_AIM_TIME = 2.0  # Optimal range: this many seconds of round flight (outside a reference laser's reach)
const LAW_CANNON_VALUE = [0.2, 0.2]  # WP per kg of gun, per kg of rounds
const LAW_CANNON_MASS_RANGE = [50.0, 4000.0]
const LAW_CANNON_ROUND_RANGE = [0.5, 100.0]
const LAW_CANNON_COUNT_RANGE = [5.0, 300.0]

# Projectiles in flight (Projectile, Missile, cannon shells).
const PROJECTILE_FUSE_MARGIN = 1.0  # m past a hull box at which a round meets it
const MISSILE_MODEL_LENGTH = 3.0  # m, for a reference missile (scaled by mass^(1/3))
const MISSILE_MODEL_RADIUS = 0.25
const MISSILE_MODEL_COLOR = Color(0.55, 0.57, 0.6)
const MISSILE_EXHAUST_SCALE = 0.35  # Of a ship's engine exhaust, for a reference missile
const MISSILE_LAUNCH_SPEED = 30.0  # m/s the rack throws a missile toward its target, before it burns
const MISSILE_BLAST_RADIUS = 3.0  # m: the warhead's explosion, as a ship's of this radius
const SHELL_MODEL_LENGTH = 12.0  # m: the tracer streak a cannon round draws (it covers 15 m a frame)
const SHELL_MODEL_RADIUS = 0.25
const SHELL_COLOR = Color(1.0, 0.85, 0.5)
const POINT_DEFENCE_RANGE_SHARE = 0.6  # Lasers fire at missiles coming at their ship within this share of their optimal range
const CANNON_AIM_SHARE = 0.6  # Fires when the round, aimed as the nose points, would pass within this share of the target's size
const AMMO_RECOVER_SHARE = 0.1  # Cannon rounds a harpoon strip takes out of a wreck: this share of a magazine (missiles: one)
const AMMO_RECOVER_MASS_TOLERANCE = 0.15  # A wreck's rounds fit a launcher whose round mass is within this share of theirs
const AI_MISSILE_FIGHT_TIME = 30.0  # s: missiles' damage counts as spread over this in a fight's odds
const AI_MISSILE_HIT_SHARE = 0.7  # Expected share of missiles that hit
const AI_CANNON_HIT_SHARE = 0.75  # and of cannon rounds (duels: 73-94%)
const LANCE_RADIUS = 0.15  # m at the lance's base, for a 200 kg lance (grows as mass^(1/3))
const LANCE_LAUNCH_SPEED = 100.0  # m/s a thrown lance gains on the ship's own speed (LanceController.fire)
const LANCE_RELEASE_RANGE = 80.0  # m from the tip to the target's hull (or a rock's surface) within which an armed lance is thrown
const LANCE_AIM_CONE = 60.0  # degrees off the nose the seat can throw it, to cancel the ship's drift past the target
const LANCE_SHOT_LIFE = 1.5  # s a thrown lance flies before it is lost
const LANCE_CATCH_SPEED = 20.0  # m/s a lancer must be able to gain on a runner to get within release range (Agent.outruns_ram)
const LANCE_TIP_MARGIN = 0.5  # m: a thrown lance strikes a ship it comes this close to (its hull box, LanceShot)
const LANCE_STUCK_CENTERING = 0.7  # A stuck lance turns this share of the way from its line toward the target's centre
const LANCE_TIP_SHARE = 0.6  # The tip's radius as a share of the base's
const LANCE_SEAT_DEPTH = 0.3  # Share of the nose's distance from the origin that the seated lance starts behind the nose
const LANCE_RECOVER_MASS_TOLERANCE = 0.15  # A salvaged lance fits a seat for lances within this share of its mass
const AI_LANCE_SALVAGE_PRIORITY = 3.0  # A wreck with lances that fit its seat looks this many times nearer to a salvager short of lances
const LANCE_STUCK_MAX = 6  # Lances left in one hull; past this the oldest goes
const CHARGE_ALERT_DISTANCE = 500.0  # m: a lance charging from nearer than this is seen for what it is; its target turns hostile (2-3 s before it strikes)
const CHARGE_ALERT_ALIGNMENT = 0.9  # Nose . direction to the target at least this (about 25 degrees)
const CHARGE_ALERT_MISS = 60.0  # m past the target's size its line may pass and still count as a charge at it
const CHARGE_ALERT_COOLDOWN = 10.0  # s before the same ship is warned of the same charger again
const CHARGE_WATCH_INTERVAL = 0.25  # s between a charging ship's looks for whom it is charging
const LANCE_STUCK_DEPTH = 0.5  # Share of a struck lance's length inside the hull
# A lance that glances off or misses drifts on as a LooseLance, a harpoon's to recover: off a face
# at LANCE_GLANCE_KEEP of its speed against it, mirrored; a miss at its own speed. It slows by
# LANCE_LOOSE_DAMP (a share of its speed a second); past LANCE_LOOSE_MAX loose lances the oldest go.
const LANCE_GLANCE_KEEP = 0.3
const LANCE_LOOSE_DAMP = 0.5
const LANCE_LOOSE_MAX = 12
# A ship with a launcher it fits scoops a loose lance up without a harpoon: within LANCE_SCOOP_RANGE
# of it (past NAV_APPROACH_MIN_DISTANCE: an approach does it) at LANCE_SCOOP_SPEED or less relative to
# it, checked every LANCE_SCOOP_INTERVAL.
const LANCE_SCOOP_RANGE = 60.0  # m, centre to centre
const LANCE_SCOOP_SPEED = 20.0  # m/s
const LANCE_SCOOP_INTERVAL = 0.25  # s
const LANCE_QUIVER_RING = 0.25  # Spares sit round the stern this share of the nose distance off the axis
const LANCE_QUIVER_SCALE = 0.6  # and are drawn this much shorter (stowed)

# Ship types and part types (lineages 1-3): seeds evolution starts from, and how they look.
const SHIP_TYPE_SEEDS = {
	1: {"size": 0.5, "shares": {"structure": 0.45, "engine": 0.3, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
	2: {"size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
	3: {"size": 2.5, "shares": {"structure": 0.65, "engine": 0.15, "reactor": 0.1, "capacitor": 0.04, "hold": 0.06}},
}
const SHIP_TYPE_PANEL_MATERIALS = {  # Hull panel material (surface 1 of the Phoenix hull) by ship type
	1: "res://assets/art/materials_generic/mat_hull_panel_offwhite.tres",
	2: "res://assets/art/materials_generic/mat_hull_panel_dark.tres",
	3: "res://assets/art/materials_generic/mat_hull_accent_orange.tres",
}
const SHIP_FACTION_SCENES = {  # Hull model by faction (scaled to the ship's size)
	"verdant": "res://scenes/prefabs/ships/phoenix_light_verdant.tscn",
	"violet": "res://scenes/prefabs/ships/phoenix_light_violet.tscn",
	"raiders": "res://scenes/prefabs/ships/phoenix_light_raiders.tscn",
	"xenohive": "res://scenes/prefabs/ships/xenohive_vessel.tscn",
}
# The xenohive's forms (XenoForm): rings of petals, spikes and glowing cells round a spindle, at odd
# counts, leaning `lean` degrees off the tail-ward axis (over 90: forward) and twisted `twist` about
# their own. `size`, `z` (along the axis, + aft) and `out` (from it) are shares of the form's length.
const XENO_FORMS = {
	"vessel": {"girth": 0.13, "rings": [
		{"shape": "petal", "count": 3, "lean": 55.0, "twist": 25.0, "size": 0.45, "z": 0.05, "out": 0.1},
		{"shape": "spike", "count": 3, "lean": 115.0, "twist": 10.0, "size": 0.3, "z": -0.1, "out": 0.08},
	]},
	"hive": {"girth": 0.16, "rings": [
		{"shape": "petal", "count": 5, "lean": 40.0, "twist": 30.0, "size": 0.5, "z": 0.1, "out": 0.12},
		{"shape": "cell", "count": 7, "lean": 90.0, "twist": 0.0, "size": 0.12, "z": -0.05, "out": 0.2},
		{"shape": "spike", "count": 5, "lean": 130.0, "twist": 15.0, "size": 0.35, "z": -0.25, "out": 0.08},
		{"shape": "petal", "count": 3, "lean": 70.0, "twist": -20.0, "size": 0.4, "z": 0.3, "out": 0.05},
	]},
}
const XENO_VESSEL_LENGTH = 17.0  # m at model scale 1, like the other hull models
const XENO_VESSEL_SEED = 5
const XENO_HIVE_LENGTH = 240.0  # m
const XENO_HIVE_SEED = 13
const SHIP_DEFAULT_SCENE = "res://scenes/prefabs/ships/phoenix_light.tscn"
const PART_TYPE_SEEDS = {  # Part kind -> type -> genes
	"laser": {1: {"mass": 150.0, "energy": 2.5}, 2: {"mass": 300.0, "energy": 5.0}, 3: {"mass": 600.0, "energy": 12.0}},
	"plating": {1: {"mass": 500.0}, 2: {"mass": 1000.0}, 3: {"mass": 2000.0}},
	"thruster": {1: {"mass": 200.0}, 2: {"mass": 400.0}, 3: {"mass": 800.0}},
	"power_cell": {1: {"mass": 150.0}, 2: {"mass": 300.0}, 3: {"mass": 600.0}},
	"lance": {1: {"nail_mass": 100.0, "count": 3.0}, 2: {"nail_mass": 200.0, "count": 3.0}, 3: {"nail_mass": 350.0, "count": 4.0}},
	"missile": {1: {"round_mass": 40.0, "count": 4.0}, 2: {"round_mass": 100.0, "count": 4.0}, 3: {"round_mass": 250.0, "count": 4.0}},
	"cannon": {1: {"mass": 150.0, "round_mass": 2.0, "count": 80.0}, 2: {"mass": 300.0, "round_mass": 5.0, "count": 60.0}, 3: {"mass": 700.0, "round_mass": 15.0, "count": 40.0}},
	"sensor": {1: {"mass": 120.0}, 2: {"mass": 250.0}, 3: {"mass": 500.0}},
	"damper": {1: {"mass": 150.0}, 2: {"mass": 300.0}, 3: {"mass": 600.0}},
	"decoy": {1: {"mass": 100.0}, 2: {"mass": 200.0}, 3: {"mass": 400.0}},
	"afterburner": {1: {"mass": 200.0}, 2: {"mass": 400.0}, 3: {"mass": 800.0}},
}
const PART_NAMES = {"laser": "Laser", "plating": "Hull Plating", "thruster": "Thruster", "power_cell": "Power Cell", "harpoon": "Harpoon", "lance": "Kinetic Lance", "missile": "Missile Rack", "cannon": "Rail Cannon", "sensor": "Sensor Booster", "damper": "Sensor Damper", "decoy": "Decoy Launcher", "afterburner": "Afterburner"}
const PART_TYPE_NAMES = {1: "I", 2: "II", 3: "III"}
const HARPOON_TEMPLATE_ID = "tool_harpoon"  # Not evolved: the same harpoon for everyone


# ==================================================================================================
# SECTOR LAYOUT, HAVENS, BEACONS AND HAZARDS (SectorLayout, Havens, Beacon, BeaconNetwork, Hazard)
# ==================================================================================================

# A sector's layout (SECTOR_LAYOUTS, by sector id) is built on load by SectorLayout: its havens, its
# beacons, its rock fields and its hazards. Positions are in m from the sector's middle; planets and
# moons stand in the sector scene, and havens and beacons are placed round them.
#
# Haven: a station NPCs live from. "faction" ("" neutral); "ships" per faction living from it (the
# evolving NPCs: each haven's are a group, with their own ranks and leader; "prefer_role" and
# "prefer_share" bend what flies there). "services": "repair", "rearm" (lances, rounds, decoys) and
# "buys": commodity id (or "*" for any) -> price factor on its cargo price; it buys nothing else.
# "station": a station already in the scene (the free port, by node name), otherwise one is built.
# NPCs dock where they are welcome (Havens.welcome): their own faction's havens, and neutral ones
# unless they are raiders or the xenohive. Every haven is a beacon too (kind "haven").
# Beacon kinds: "patrol" (a faction's: its patrol ships go round them, its safe zone), "field" (a
# rock field to mine: "rocks" of them within "radius", "ring": only the outer share past it, round a
# planet), "landmark" (a point routes go through; every planet and moon is one too).
# Hazard "radiation": round a star, from "core" (its surface) out to "radius"; hull damage a second
# rises from 0 at the edge to HAZARD_RADIATION_DPS at the surface, as the square of the depth.
const SECTOR_LAYOUTS = {
	"sector_elace": {
		"play_radius": 60000.0,  # m from the middle: NPCs do not chase, salvage or patrol beyond it
		"hazards": [{"kind": "radiation", "at": Vector3(0, 0, 0), "core": 5000.0, "radius": 15000.0}],  # Three star diameters across
		"havens": [
			{"id": "station_elace_home", "name": "Elace Free Port", "faction": "", "station": "ElaceHomeStation",
				"services": {"repair": true, "rearm": true, "buys": {"*": 1.0}}},
			{"id": "verdant_haven", "name": "Verdant Haven", "faction": "verdant", "at": Vector3(6000, 0, 25000), "ships": {"verdant": 5},
				"services": {"repair": true, "rearm": true, "buys": {"*": 0.9}}},
			{"id": "verdant_post", "name": "Verdant Post", "faction": "verdant", "at": Vector3(-2000, 0, 29500), "ships": {"verdant": 2},
				"prefer_role": "prospector", "prefer_share": 0.7, "services": {"repair": true, "buys": {"commodity_ore": 0.8}}},
			{"id": "violet_haven", "name": "Violet Haven", "faction": "violet", "at": Vector3(6000, 0, -25000), "ships": {"violet": 5},
				"services": {"repair": true, "rearm": true, "buys": {"*": 0.9}}},
			{"id": "violet_post", "name": "Violet Post", "faction": "violet", "at": Vector3(-2000, 0, -29500), "ships": {"violet": 2},
				"prefer_role": "prospector", "prefer_share": 0.7, "services": {"repair": true, "buys": {"commodity_ore": 0.8}}},
			{"id": "elace_refinery", "name": "Elace Refinery", "faction": "", "at": Vector3(32500, 0, 0),
				"services": {"buys": {"commodity_ore": 1.4, "commodity_relic": 1.2}}},
			{"id": "raider_den", "name": "Raider Den", "faction": "raiders", "at": Vector3(0, 24000, 0), "ships": {"raiders": 4},
				"services": {"repair": true, "rearm": true, "buys": {"*": 0.7}}},
			{"id": "xenohive", "name": "Xenohive", "faction": "xenohive", "at": Vector3(48000, 0, 0), "ships": {"xenohive": 3},
				"services": {"buys": {"*": 1.0}}},
		],
		"beacons": [
			{"kind": "patrol", "owner": "verdant", "name": "Verdant Picket West", "at": Vector3(-8000, 0, 20000)},
			{"kind": "patrol", "owner": "verdant", "name": "Verdant Picket East", "at": Vector3(16000, 0, 16000)},
			{"kind": "patrol", "owner": "verdant", "name": "Verdant Picket North", "at": Vector3(6000, 0, 33000)},
			{"kind": "patrol", "owner": "violet", "name": "Violet Picket West", "at": Vector3(-8000, 0, -20000)},
			{"kind": "patrol", "owner": "violet", "name": "Violet Picket East", "at": Vector3(16000, 0, -16000)},
			{"kind": "patrol", "owner": "violet", "name": "Violet Picket South", "at": Vector3(6000, 0, -33000)},
			{"kind": "field", "name": "Verdant Home Field", "at": Vector3(14000, 0, 28000), "radius": 2000.0, "rocks": 14},
			{"kind": "field", "name": "Violet Home Field", "at": Vector3(14000, 0, -28000), "radius": 2000.0, "rocks": 14},
			{"kind": "field", "name": "Elace B Belt", "at": Vector3(25000, 0, 0), "radius": 5000.0, "ring": 0.5, "rocks": 30},
			{"kind": "field", "name": "Deep Field", "at": Vector3(42000, 0, 0), "radius": 4000.0, "rocks": 12},  # And the scene's old rocks
			{"kind": "landmark", "name": "West Pass North", "at": Vector3(-18000, 0, 11000)},
			{"kind": "landmark", "name": "West Pass South", "at": Vector3(-18000, 0, -11000)},
			{"kind": "landmark", "name": "East Pass North", "at": Vector3(20000, 0, 11000)},
			{"kind": "landmark", "name": "East Pass South", "at": Vector3(20000, 0, -11000)},
		],
	},
}
const HAZARD_RADIATION_DPS = 12.0  # Hull a second at a star's surface (a Phoenix Light has 120)
const HAZARD_TICK = 0.5  # s between hazard damage steps
# Beacons (BeaconNetwork) remember what goes on round them: heat (hull lost to enemy fire within
# BEACON_HEAT_RADIUS, as shares of the victims' hulls, a kill counting BEACON_HEAT_PER_KILL more) and
# traffic (ships passing within BEACON_TRAFFIC_RADIUS), each halving every *_HALF_LIFE s; and when
# each faction's ships were last there. Fields know the ore left in them.
const BEACON_HEAT_RADIUS = 6000.0  # m
const BEACON_HEAT_PER_KILL = 1.0
const BEACON_HEAT_HALF_LIFE = 300.0  # s
const BEACON_TRAFFIC_RADIUS = 3000.0  # m
const BEACON_TRAFFIC_HALF_LIFE = 600.0  # s
const BEACON_UPDATE_INTERVAL = 2.0  # s between traffic and decay steps
const BEACON_FIELD_VALUE_INTERVAL = 10.0  # s between recounts of a field's ore
const BEACON_LOITER_RADIUS = 1500.0  # m round a beacon a ship picks points to go to while there
const BEACON_LOITER_TIME = [30.0, 90.0]  # s a ship stays at a beacon before choosing again
# Words for the player (target info), as heat and traffic pass these.
const BEACON_HEAT_WORDS = [[0.3, "CALM"], [1.5, "TENSE"], [INF, "HOT"]]
const BEACON_TRAFFIC_WORDS = [[1.0, "QUIET"], [4.0, "BUSY"], [INF, "CROWDED"]]
# Routes (BeaconNetwork.route): beacons within ROUTE_LINK_RANGE of each other are linked, and the
# start and the goal to each other too. A link costs its flying time plus, for a ship of caution c
# (relative to the default, AI_AVOID_SHARE), c * (ROUTE_HEAT_COST s per unit of heat at its ends,
# ROUTE_DAMAGE_COST s per share of the hull a hazard would take on the way). Fearless ships go
# straight; careful ones go round.
const ROUTE_LINK_RANGE = 24000.0  # m
const ROUTE_HEAT_COST = 60.0  # s
const ROUTE_DAMAGE_COST = 600.0  # s per whole hull
const ROUTE_SAMPLES = 16  # Points a link is sampled at for hazards
const ROUTE_WAYPOINT_REACHED = 1500.0  # m from a waypoint at which the next is flown to
# Where an NPC goes (BeaconNetwork.choose): interest / (route time + ROUTE_TIME_FLOOR), by its job.
# Patrol (armed faction ships): its own patrol beacons, fields and landmarks (CHOICE_* interest),
# times 1 + time since its faction was there / CHOICE_STALE_TIME, times 1 + heat (trouble draws it);
# enemy patrol beacons too, as much as it is keen to fight (a raid). Hunt (raiders): traffic, less
# where its enemies are there now. Scavenge (unarmed): heat. Mine (prospectors): a field's ore over
# CHOICE_FIELD_VALUE, less where it is hot (e^(-c * heat)).
const ROUTE_TIME_FLOOR = 60.0  # s
const CHOICE_OWN_PATROL = 1.0
const CHOICE_FIELD = 0.5
const CHOICE_LANDMARK = 0.2
const CHOICE_RAID = 0.4  # Enemy patrol beacons, times how keen it is to fight
const CHOICE_STALE_TIME = 300.0  # s
const CHOICE_FIELD_VALUE = 100.0  # Units of ore
const CHOICE_HUNT_FLOOR = 0.2  # Traffic it reckons even a quiet beacon has
const HAVEN_RESPAWN_DELAY = 8.0  # s between a loss and its replacement undocking
const HAVEN_DOCK_TIME = 10.0  # s an NPC stays docked (selling, repairs) before undocking
const HAVEN_UNDOCK_CLEAR_RADIUS = 3500.0  # m: with an enemy this near its undock point (past a heavy laser's reach), a docked NPC waits
const HAVEN_DOCK_MAX_WAIT = 90.0  # s, at most, past its dock time (upkeep runs on meanwhile)
const HAVEN_DOCK_DISTANCE = 250.0  # m from a station's undock point at which an NPC docks
const HAVEN_BEACON_RADIUS = 3000.0  # m: a haven's beacon
# Rock fields (SectorLayout), the same on every load: rocks of FIELD_ROCK_SCALE m, some big
# (FIELD_ROCK_BIG_CHANCE), within FIELD_ROCK_HEIGHT of the plane, clear of havens and each other.
const FIELD_ROCK_HEIGHT = 600.0  # m above and below the field's plane
const FIELD_ROCK_CLEARANCE = 600.0  # m kept clear round each station
const FIELD_ROCK_SCALE = [30.0, 70.0]
const FIELD_ROCK_BIG_SCALE = [120.0, 200.0]
const FIELD_ROCK_BIG_CHANCE = 0.2
const FIELD_ROCK_MODELS = [
	"res://assets/models/rocks/rock_01_6k.glb", "res://assets/models/rocks/rock_02_3k.glb",
	"res://assets/models/rocks/rock_03_4k.glb", "res://assets/models/rocks/rock_04_3k.glb",
	"res://assets/models/rocks/rock_05_4k.glb",
]
const FIELD_ROCK_SCENE = "res://scenes/prefabs/celestial/asteroid.tscn"
const EVO_SECTOR_ID = "sector_elace"  # The evolving NPCs live in this sector's havens
const EVO_FACTIONS = ["verdant", "violet", "raiders", "xenohive"]  # Each keeps a gene pool
# The xenohive's drones grow with what they bring home: one more per XENOHIVE_MASS_PER_DRONE kg of cargo
# delivered (all time), up to XENOHIVE_DRONES_MAX extra. A fixed spawner for now; the hive does not grow.
const XENOHIVE_MASS_PER_DRONE = 5000.0  # kg
const XENOHIVE_DRONES_MAX = 3
const PRESETS_DIR = "res://database/presets"  # Exported designs (tools/export_presets.gd): the home station sells them
const PRESET_WEIGHT_CLASSES = [["light", -0.5], ["medium", 1.0], ["heavy", INF]]  # Preset export: niche size class up to this
const NPC_MAX_LIFETIME = 900.0  # s; after this an NPC retires at its next dock (its record is kept)
# Rank (Evolution): a faction's ships living from one haven are a group, ranked by renown, what they have
# won in this life (RENOWN_PER_KILL a kill, RENOWN_PER_ASSIST going to help a friend, RENOWN_PER_DAMAGE
# per hull point dealt). The first, with RENOWN_LEADER_MIN and a group to lead, is its leader: the
# others patrol near it (AI_FOLLOW_RADIUS) and join its fights. Renown can also put off retiring: the
# lifetime grows by NPC_LIFETIME_PER_RENOWN of itself per point, at most NPC_LIFETIME_MAX_FACTOR
# times (a ship that dies still dies).
const RENOWN_PER_KILL = 10.0
const RENOWN_PER_ASSIST = 2.0
const RENOWN_PER_DAMAGE = 0.02  # 500 hull dealt: as much as a kill
const RENOWN_LEADER_MIN = 10.0
const NPC_LIFETIME_PER_RENOWN = 0.05  # A kill: half as long again
const NPC_LIFETIME_MAX_FACTOR = 1.0  # Off (1): long lives slowed the turnover by a quarter; templates are the point
const AI_FOLLOW_RADIUS = 1000.0  # m round its leader a follower patrols
const AI_FOLLOW_MIN_TEAMWORK = 0.5  # A loner (teamwork gene under this) patrols on its own
const FACTION_STATION_MATERIALS = {  # Station paint by faction
	"verdant": "res://assets/art/materials_generic/mat_hull_faction_verdant.tres",
	"violet": "res://assets/art/materials_generic/mat_hull_faction_violet.tres",
	"raiders": "res://assets/art/materials_generic/mat_hull_faction_raiders.tres",
	"xenohive": "res://assets/art/materials_generic/mat_hull_faction_xenohive.tres",
}

# Evolution: each faction keeps its own gene pool, so the two drift apart. A genome is a ship
# (type, size, mass shares), its parts per slot, and (later) behaviour. Fitness is return on cost:
# (WP banked from salvage + kill bounties - repairs - upkeep) / (ship and parts value), minus 1 if
# the ship died. Repairs and upkeep make sitting docked a slow loss, not a free pass.
# The pool is an archive of niches (MAP-Elites): size class x role x laser range. Each niche keeps its
# best genome; a spawn picks a niche (softly by fitness, so near-equal ones all carry on), then
# re-flies its genome or a mutant. Fitness is noisy, so it is shrunk toward 0 by EVO_PRIOR_LIVES.
const EVO_WEAPON_ODDS = {"laser": 0.5, "missile": 0.25, "cannon": 0.25}  # A new weapon is of this kind this often
const EVO_REPAIR_COST_SHARE = 0.5  # A full repair costs this share of the hull's value (less for less)
const EVO_UPKEEP_PER_HOUR = 0.5  # Running costs: this share of the ship's value per hour alive
# Combat niches (fighters, raiders, lancers: Genome.is_combat_role) are judged on the exchange: the
# value of enemy ships they destroyed (each hit worth its share of the victim's hull, times the
# victim's cost) counts toward fitness at this weight, next to what they earned and lost.
const EVO_COMBAT_EXCHANGE_WEIGHT = 1.0
const EVO_PRIOR_LIVES = 2.0  # Fitness mean = sum / (lives + this)
const EVO_SELECTION_TEMPERATURE = 0.2  # Niche pick weight = exp(fitness / this)
const EVO_REFLY_CHANCE = 0.25  # A spawn flies a niche's genome unchanged (to measure it again)
const EVO_IMMIGRANT_CHANCE = 0.05  # A spawn is a fresh random genome
const EVO_PROVING = true  # Proving mode: most spawns re-fly the archetypes' leading genomes until they have EVO_PROVE_LIVES lives (presets need the evidence)
const EVO_PROVE_REFLY_CHANCE = 0.7  # In proving mode: a spawn re-flies a leading genome short of its lives (a mutant otherwise; no immigrants)
const EVO_PROVE_LIVES = 10  # Lives that make a genome proven (tools/export_presets.gd --min-lives)
const EVO_PROVE_PER_ARCHETYPE = 3  # The fittest this many niche bests of each archetype (PresetExporter.archetype, both factions) are proved
const EVO_MUTATION_SIGMA = 0.08  # Log-normal step on each mutated gene
const EVO_SLOT_SHARE_SIGMA = 0.1  # Step on a hull's tool_share (how its slots split; ShipLaws.slot_counts)
const EVO_GENE_MUTATION_CHANCE = 0.4  # Per gene
const EVO_MACRO_MUTATION_CHANCE = 0.03  # A mutation with 5x the step
const EVO_PART_SWAP_CHANCE = 0.08  # Per slot: a different part (another kind or type, or empty)
const EVO_PILOT_STAKE_SHARE = 1.0  # An evolving pilot's wallet: this share of its ship's cost, plus its life's net takings (comfortable at first; losses make it desperate)
const EVO_EMPTY_SLOT_CHANCE = 0.15  # When a slot's part is picked anew, the chance it is left empty
const EVO_HARPOON_CHANCE = 0.15  # and that a tool slot gets a harpoon (a weapon otherwise)
const EVO_EXTRA_HARPOON_CHANCE = 0.05  # on a ship that has a harpoon already
const EVO_BEHAVIOR_START_LIVES = 150  # Behaviour genes start mutating once a faction has logged this many lives
const EVO_BEHAVIOR_RANGES = {  # Gene -> [min, max, default]
	"engage": [0.3, 4.0, 1.0],  # Desire at which it starts a fight (AI_ENGAGE_DESIRE)
	"disengage": [0.1, 3.0, 0.8],  # below which it breaks off (AI_DISENGAGE_DESIRE)
	"range": [0.3, 1.5, 1.0],  # Orbit distance as a share of its laser's optimal range
	"retreat_hull": [0.0, 0.8, 0.0],  # Hull share at which it runs home whatever the odds
	"pursuit": [0.0, 3.0, 1.0],  # Chases a runner while it would catch it within this share of its time to safety (AI_PURSUIT)
	"mercy": [0.0, 1.0, 0.5],  # Chance of letting a runner go that is not shooting back (AI_MERCY)
	"return_fire": [0.0, 1.0, 0.5],  # Chance, per flight, of shooting back while running (AI_RETURN_FIRE)
	"teamwork": [0.0, 2.0, 1.0],  # Times its desire to help a friend or join its leader; under AI_FOLLOW_MIN_TEAMWORK it trails no leader
	"caution": [0.0, 1.0, 0.5],  # Keeps clear of unseen enemies under this share of its engage desire (AI_AVOID_SHARE)
	"burn": [0.0, 0.8, 0.3],  # Share of its power kept from the afterburner for its weapons (AI_AFTERBURNER_RESERVE)
	"prospect": [0.0, 1.0, 0.0],  # At 0.5 or more, with a laser, a lance and a harpoon, it mines when it has nothing else to do
	"haul": [0.05, 1.0, 0.25],  # Goes home to sell once its hold is worth this share of its ship (AI_HAUL_SHARE)
}
# Starting designs, guessed, planted in each pool's empty niches (Evolution.plant_seeds; Genome.seed_genome):
# prospectors and escorts for the factions, raiders, and the xenohive's drones, gatherers and wardens.
const EVO_FACTION_SEEDS = [
	{"type": 2, "size": 1.0, "tools": ["laser", "harpoon"], "modules": ["lance", "plating"], "behavior": {"prospect": 1.0, "engage": 2.0, "retreat_hull": 0.4}},
	{"type": 1, "size": 0.7, "tools": ["laser", "harpoon"], "modules": ["lance", "thruster"], "behavior": {"prospect": 1.0, "engage": 2.5, "retreat_hull": 0.5}},
	{"type": 2, "size": 1.2, "tools": [["laser", 2], ["laser", 2]], "modules": [["plating", 2], "sensor"], "behavior": {"teamwork": 2.0, "engage": 0.8}},
]
const EVO_SEEDS = {
	"verdant": EVO_FACTION_SEEDS,
	"violet": EVO_FACTION_SEEDS,
	"raiders": [
		{"type": 1, "size": 0.7, "tools": ["laser", "harpoon"], "modules": ["afterburner", "plating"], "behavior": {"engage": 0.7, "mercy": 0.1, "pursuit": 2.0}},
		{"type": 2, "size": 1.0, "tools": ["laser", "harpoon"], "modules": [["lance", 2], "afterburner"], "behavior": {"engage": 0.8, "mercy": 0.2}},
		{"type": 2, "size": 1.3, "tools": [["cannon", 2], "harpoon"], "modules": [["plating", 2], ["afterburner", 2]], "behavior": {"engage": 0.8}},
	],
	"xenohive": [
		{"type": 1, "size": 0.5, "tools": ["laser"], "modules": ["thruster"], "behavior": {"teamwork": 2.0, "engage": 0.6}},
		{"type": 1, "size": 0.7, "tools": ["harpoon", "laser"], "modules": ["plating", "thruster"], "behavior": {"engage": 2.5, "retreat_hull": 0.5}},
		{"type": 2, "size": 1.5, "tools": [["laser", 2], "laser"], "modules": ["lance", ["plating", 2]], "behavior": {"engage": 0.6, "teamwork": 1.5}},
	],
}
const EVO_GENOME_MEMORY = 3000  # Genomes whose records are kept (elites and live ones always are)
const EVO_REPORT_INTERVAL = 300.0  # s of game time between console reports
const EVO_LOG_LEVEL = 2  # Console: 0 nothing, 1 deaths and reports, 2 every birth, dock, sale and kill
const EVO_LOG_DIR = "user://evolution_logs/"  # One .jsonl per evolution run: every life, in full


# ==================================================================================================
# SECTORS, DOCKING AND JUMPS
# ==================================================================================================

const DOCKING_PROMPT_RADIUS: float = 500.0  # m; the dock prompt appears
const DOCKING_ACTION_RADIUS: float = 300.0  # m; dock / jump works
const SECTOR_JUMP_ARRIVAL_RADIUS: float = 50000.0  # m; arrival shell for route jumps
const JUMP_ARRIVAL_SCATTER: float = 0.3  # Arrivals land on the side facing the source system, scattered this much
const REFERENCE_ORIGIN: Vector3 = Vector3(0, 0, 0)  # Elace system global_position (nebula reference)

const JUMP_ALIGNMENT_MAX_DEVIATION_DEG = 5.0  # Heading error allowed before jumping
const JUMP_ALIGNMENT_FULL_THRUST_SCALE = 1.0

# Jump transition.
const JUMP_ACCEL_DURATION: float = 3.0  # s
const JUMP_FADE_DURATION: float = 3.0  # s
const JUMP_TRANSITION_RIG_NODE_NAME: String = "JumpTransitionRig"
const JUMP_TRANSITION_DEFAULT_DIRECTION: Vector3 = Vector3(0, 0, -1)
const JUMP_TRANSITION_LOAD_TIMEOUT_SEC: float = 1.5

# Travel time by the pair of sector types. A sector is a whole star system (star, planets, moons,
# companion stars) or a patch of deep space; bodies inside a system are flown to, not jumped to.
const JUMP_TRAVEL_DURATION: float = 20.0  # Any other pair
const JUMP_DURATION_SYSTEM_SYSTEM: float = 30.0
const JUMP_DURATION_ANY_DEEP_SPACE: float = 15.0

# Starsphere sprites of stars this close (galactic units) to the current system's global_position
# are hidden: those stars are in the sector itself (Lywin's companions).
const STARSPHERE_OWN_SYSTEM_RADIUS: float = 100000.0


func get_jump_travel_duration(type_a: String, type_b: String) -> float:
	var a = type_a.to_lower()
	var b = type_b.to_lower()
	if a == "deep_space" or b == "deep_space":
		return JUMP_DURATION_ANY_DEEP_SPACE
	if a == "system" and b == "system":
		return JUMP_DURATION_SYSTEM_SYSTEM
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

# HUD announcements (Announcements): fading labels stacked up from ANNOUNCE_ANCHOR (share of the
# screen height, from the top), newest at the bottom.
const ANNOUNCE_COLORS = {"info": Color(0.75, 1.0, 0.8), "warning": Color(1.0, 0.8, 0.35), "danger": Color(1.0, 0.35, 0.3)}
const ANNOUNCE_HOLD = 2.5  # s at full strength
const ANNOUNCE_FADE = 1.5  # s fading out
const ANNOUNCE_MAX = 5  # Shown at once; the oldest goes first
const ANNOUNCE_ANCHOR = 0.62  # The newest's bottom edge, as a share of the screen height
const ANNOUNCE_GAP = 4.0  # px between two
const ANNOUNCE_PADDING = Vector2(14, 6)  # px round the text
const ANNOUNCE_SLIDE_RATE = 12.0  # How fast pushed ones slide up to their places (1/s)
const COLOR_UI_TARGET_SELECTED = Color(1.0, 0.9, 0.35, 1.0)  # Yellow: the selected target, anything not hostile, wrecks included
# Unselected targets' marks and labels. Ships and stations by their side to the player only, not
# their factions' colours: green allied (standing friendly), blue neutral, red hostile (attacking it
# on sight, a refused dock, a territorial alien). Everything else by its kind.
const COLOR_UI_TARGET_HOSTILE = Color(1.0, 0.22, 0.12, 1.0)  # Red
const COLOR_UI_TARGET_ALLIED = Color(0.35, 1.0, 0.45, 1.0)  # Green
const COLOR_UI_TARGET_SIDE_NEUTRAL = Color(0.35, 0.65, 1.0, 1.0)  # Blue
const COLOR_UI_BEACON = Color(1.0, 0.75, 0.3, 1.0)  # Amber: beacons (SectorLayout)
const COLOR_UI_BODY = Color(0.95, 0.92, 0.8, 1.0)  # Pale sand: stars, planets, moons
const COLOR_UI_ROCK = Color(0.8, 0.65, 0.5, 1.0)  # Tan: rocks
const COLOR_UI_PICKUP = Color(1.0, 0.5, 0.9, 1.0)  # Pink: ore chunks and loose lances
const COLOR_UI_TARGET_NEUTRAL = Color(0.85, 0.85, 0.85, 0.95)  # Light grey: anything else
const COLOR_UI_WRECK = Color(0.55, 0.55, 0.55, 0.9)  # Grey: wrecks
const UI_UNAWARE_DIM = 0.55  # A live ship that has not detected the player shows its colour this bright
const UI_UNAWARE_ALPHA = 0.85  # and this opaque (its mark only: labels stay readable)
const UI_CELESTIAL_ALPHA = 0.45  # Marks on rocks, planets and the like are this faint
const HUD_MARKER_STYLES = ["shapes", "ring", "ticks", "dot"]  # TargetMarker; the debug overlay's MARKERS cycles them, the first by default

# Jump route brackets, by sector type.
const COLOR_UI_JUMP_ROUTE = Color(0.0, 0.7, 1.0, 1.0)  # Fallback
const COLOR_UI_JUMP_SYSTEM = Color(0.95, 0.65, 0.15, 1.0)  # Warm gold
const COLOR_UI_JUMP_DEEP_SPACE = Color(0.5, 0.5, 0.9, 1.0)  # Slate blue


func get_jump_type_color(sector_type: String) -> Color:
	match sector_type.to_lower():
		"system":
			return COLOR_UI_JUMP_SYSTEM
		"deep_space", "hazard_zone":
			return COLOR_UI_JUMP_DEEP_SPACE
		_:
			return COLOR_UI_JUMP_ROUTE
