#
# PROJECT: GDTLancer
# MODULE: constants.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6.3 + TACTICAL_TODO.md PHASE 2 TASK_6
# LOG_REF: 2026-02-22 00:10:00
#

"""Qualitative simulation constants (Phase 1 gut of numeric model).

All tuning knobs for the tag-driven qualitative simulation live here.
Values are balanced for ~90 ticks per 9-hour play session (via the
sub-tick system) and a full world-age cycle of ~330 ticks (~3.7 sessions).

# =========================================================================
# TAG DICTIONARY — single reference for every tag used in the simulation
# =========================================================================
#
# SECTOR TAGS
#   Economy (one per resource axis, three axes):
#     RAW_RICH / RAW_ADEQUATE / RAW_POOR
#     MANUFACTURED_RICH / MANUFACTURED_ADEQUATE / MANUFACTURED_POOR
#     CURRENCY_RICH / CURRENCY_ADEQUATE / CURRENCY_POOR
#   Security (mutually exclusive):
#     SECURE        — patrols present, pirates flee
#     CONTESTED     — mixed control, skirmishes likely
#     LAWLESS       — no authority, piracy rampant
#   Environment (mutually exclusive):
#     MILD          — safe operating conditions
#     HARSH         — elevated hazard, equipment strain
#     EXTREME       — critical hazard, exploration territory
#   Special / status:
#     STATION       — dockable hub (derived from sector_type != frontier)
#     FRONTIER      — fringe outpost (derived from sector_type == frontier)
#     HAS_SALVAGE   — wreckage available for harvest
#     DISABLED      — catastrophe aftermath, operations halted
#     HOSTILE_INFESTED   — active hostile presence
#     HOSTILE_THREATENED — hostiles detected but not dominant
#
# AGENT TAGS (derived every tick by BridgeSystems)
#   Condition:  HEALTHY / DAMAGED / DESTROYED
#   Wealth:     WEALTHY / COMFORTABLE / BROKE
#   Cargo:      LOADED / EMPTY
#   Role:       TRADER / HAULER / PROSPECTOR / EXPLORER / PIRATE / MILITARY / IDLE
#   Personality (from character traits):
#     GREEDY     (greed > 0.6)
#     AGGRESSIVE (aggression > 0.5)
#     COWARD     (risk_tolerance < 0.3)
#     BOLD       (risk_tolerance > 0.7)
#     LOYAL      (loyalty > 0.6)
#   Dynamic:    DESPERATE (DAMAGED + BROKE), SCAVENGER (prospector role)
#
# WORLD TAGS (set by world-age)
#   ABUNDANT / STABLE      — during PROSPERITY
#   SCARCE / VOLATILE      — during DISRUPTION
#   RECOVERING             — during RECOVERY
# =========================================================================
"""

# ---------------------------------------------------------------------------
# World Age Cycle
# ---------------------------------------------------------------------------
# The world cycles through three ages.  Each age lasts a fixed number of
# ticks before transitioning to the next.  Total cycle = 330 ticks ≈ 3.7
# gameplay sessions ≈ 33 hours.
WORLD_AGE_CYCLE = ["PROSPERITY", "DISRUPTION", "RECOVERY"]
WORLD_AGE_DURATIONS = {          # ticks each age lasts
    "PROSPERITY": 150,           # stable growth, trade flourishes
    "DISRUPTION": 75,            # piracy surges, supply lines break
    "RECOVERY": 105,             # rebuilding, order slowly returns
}
WORLD_AGE_CONFIGS = {             # reserved for per-age rule overrides
    "PROSPERITY": {},
    "DISRUPTION": {},
    "RECOVERY": {},
}

# ---------------------------------------------------------------------------
# Colony Structure
# ---------------------------------------------------------------------------
# Sectors progress through colony levels: frontier → outpost → colony → hub.
# Upgrade requires sustained SECURE security + ADEQUATE+ economy for N ticks.
# Downgrade triggers when LAWLESS security or POOR economy persists.
COLONY_LEVELS = ["frontier", "outpost", "colony", "hub"]
COLONY_UPGRADE_TICKS_REQUIRED = 10      # consecutive qualifying ticks to grow
COLONY_DOWNGRADE_TICKS_REQUIRED = 12    # consecutive bad ticks to shrink
COLONY_UPGRADE_REQUIRED_SECURITY = "SECURE"
COLONY_UPGRADE_REQUIRED_ECONOMY = ["RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
COLONY_DOWNGRADE_SECURITY_TRIGGER = "LAWLESS"
COLONY_DOWNGRADE_ECONOMY_TRIGGER = ["RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
COLONY_MINIMUM_LEVEL = "outpost"          # colonies never degrade below this

# ---------------------------------------------------------------------------
# Security Progression
# ---------------------------------------------------------------------------
# Security changes require sustained pressure over N ticks, mirroring the
# colony upgrade/downgrade pattern.  Each sector gets a per-sector threshold
# drawn from [MIN, MAX] at initialisation (seeded on world_seed + sector_id)
# so different sectors have different inertia, breaking CA checkerboard sync.
SECURITY_CHANGE_TICKS_MIN = 3        # minimum consecutive ticks to shift
SECURITY_CHANGE_TICKS_MAX = 6        # maximum consecutive ticks to shift

# ---------------------------------------------------------------------------
# Economy Progression
# ---------------------------------------------------------------------------
# Economy tags (RAW/MANUFACTURED/CURRENCY) change only after sustained
# pressure over multiple ticks, preventing every-tick tag flipping.
ECONOMY_UPGRADE_TICKS_REQUIRED = 3    # consecutive positive-pressure ticks
ECONOMY_DOWNGRADE_TICKS_REQUIRED = 3  # consecutive negative-pressure ticks
ECONOMY_CHANGE_TICKS_MIN = 2          # per-sector/category threshold minimum
ECONOMY_CHANGE_TICKS_MAX = 5          # per-sector/category threshold maximum

# ---------------------------------------------------------------------------
# Hostile Infestation Progression
# ---------------------------------------------------------------------------
# Sectors must remain LAWLESS for sustained ticks before infestation appears.
HOSTILE_INFESTATION_TICKS_REQUIRED = 3

# ---------------------------------------------------------------------------
# Affinity Thresholds
# ---------------------------------------------------------------------------
# When compute_affinity(actor, target) crosses these, an interaction fires.
ATTACK_THRESHOLD = 1.5   # score >= this → attack / harvest salvage
TRADE_THRESHOLD = 0.5    # score >= this (< attack) → trade / dock
FLEE_THRESHOLD = -1.0    # score <= this → flee

# ---------------------------------------------------------------------------
# Combat Cooldown
# ---------------------------------------------------------------------------
# After initiating an attack, an agent must wait this many ticks before it
# can initiate another attack. Other interactions (trade/flee/move/dock)
# remain available during cooldown.
COMBAT_COOLDOWN_TICKS = 5

# ---------------------------------------------------------------------------
# Agent Upkeep
# ---------------------------------------------------------------------------
# Per-tick random wear: each agent independently rolls for condition
# degradation (HEALTHY→DAMAGED) and wealth loss (one step down).
AGENT_UPKEEP_CHANCE = 0.05  # probability per agent per tick
WEALTHY_DRAIN_CHANCE = 0.08 # additional per-tick WEALTHY -> COMFORTABLE drain
BROKE_RECOVERY_CHANCE = 0.15 # per-tick chance a BROKE agent at a station recovers to COMFORTABLE

# ---------------------------------------------------------------------------
# Mortal Agent Lifecycle
# ---------------------------------------------------------------------------
# Mortal agents spawn dynamically and can die permanently (unlike persistent
# named NPCs who always respawn).  On destruction a mortal rolls against
# MORTAL_SURVIVAL_CHANCE: success → reset to DAMAGED/BROKE at home sector;
# failure → permanently removed from the simulation.
MORTAL_GLOBAL_CAP = 200                                         # max total agents alive
MORTAL_SPAWN_REQUIRED_SECURITY = ["SECURE", "CONTESTED", "LAWLESS"]  # any of these allows spawn
MORTAL_SPAWN_BLOCKED_SECTOR_TAGS = ["DISABLED", "HOSTILE_INFESTED"]  # these block spawn
MORTAL_SPAWN_MIN_ECONOMY_TAGS = ["RAW_ADEQUATE", "RAW_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE", "CURRENCY_RICH"]
MORTAL_SPAWN_CHANCE = 0.08                                      # per-tick roll if eligible
MORTAL_ROLES = ["trader", "hauler", "prospector", "explorer", "pirate"]
MORTAL_SURVIVAL_CHANCE = 0.4                                    # 40 % survive destruction
DISRUPTION_MORTAL_ATTRITION_CHANCE = 0.03                       # per-tick exposed mortal death chance during DISRUPTION

# ---------------------------------------------------------------------------
# Structural Constants (caps / timeouts)
# ---------------------------------------------------------------------------
EVENT_BUFFER_CAP = 200              # max events kept in rolling buffer
RUMOR_BUFFER_CAP = 200              # max rumours kept in rolling buffer
RESPAWN_COOLDOWN_TICKS = 1          # ticks a persistent NPC waits before respawning
RESPAWN_COOLDOWN_MAX_DEBT = 25      # max accumulated respawn debt ticks
MAX_SECTOR_COUNT = 20               # world graph won't grow beyond this many sectors
NEW_SECTOR_MAX_CONNECTIONS = 3      # max connections a newly discovered sector starts with
NEW_SECTOR_EXTRA_CONNECTION_CHANCE = 0.4  # per-candidate chance to form an extra link
EXPLORATION_COOLDOWN_TICKS = 5      # ticks an explorer must wait between discoveries
EXPLORATION_SUCCESS_CHANCE = 0.3    # probability each attempt actually finds something

# ---------------------------------------------------------------------------
# Catastrophe
# ---------------------------------------------------------------------------
# Rare per-tick random event that disables a random sector.
# Mortals caught in the sector roll CATASTROPHE_MORTAL_KILL_CHANCE for death.
CATASTROPHE_CHANCE_PER_TICK = 0.005  # 0.5 % per tick
CATASTROPHE_DISABLE_DURATION = 6     # ticks the sector stays DISABLED
CATASTROPHE_MORTAL_KILL_CHANCE = 0.7 # per-mortal chance of death in catastrophe

# ---------------------------------------------------------------------------
# Sub-tick System
# ---------------------------------------------------------------------------
# One full simulation tick = SUB_TICKS_PER_TICK sub-ticks.
# Player actions accumulate sub-ticks; when the accumulator reaches the
# threshold a full tick fires.  This decouples the simulation clock from
# any real-time or frame-based timing.
#
# Estimated session (9 h): ~54 travels + ~66 docks + ~27 deep-space events
#   = ~900 sub-ticks = ~90 full ticks per session.
# World-age cycle (330 ticks) -> ~3.7 sessions (~33 h).
SUB_TICKS_PER_TICK = 10

# Sub-tick costs for player-driven transition events.
SUBTICK_COST_SECTOR_TRAVEL = 10   # 1 full tick  — jump / travel screen
SUBTICK_COST_DOCK = 3              # minor — landing sequence
SUBTICK_COST_UNDOCK = 2            # trivial — launch sequence
SUBTICK_COST_DEEP_SPACE_EVENT = 5  # half-tick — encounter / scan / anomaly

