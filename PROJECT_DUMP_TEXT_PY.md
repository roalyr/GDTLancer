--- Start of ./python_sandbox/autoload/constants.py ---

#
# PROJECT: GDTLancer
# MODULE: constants.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md PHASE 1 TASK_1
# LOG_REF: 2026-02-22 01:00:00
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
MORTAL_SPAWN_CHANCE = 0.2                                      # per-tick roll if eligible
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
EXPLORATION_COOLDOWN_TICKS = 10     # ticks an explorer must wait between discoveries
EXPLORATION_SUCCESS_CHANCE = 0.1    # probability each attempt actually finds something

# ---------------------------------------------------------------------------
# Topology
# ---------------------------------------------------------------------------
# Discovery now builds filament/web structure with hard per-sector degree caps,
# mostly-single-link expansion, and occasional loop-forming links.
MAX_CONNECTIONS_PER_SECTOR = 4      # hard cap on total connections per sector
EXTRA_CONNECTION_1_CHANCE = 0.20    # nearby branch link chance (after primary)
EXTRA_CONNECTION_2_CHANCE = 0.05    # distant loop link chance (requires first extra)
LOOP_MIN_HOPS = 3                   # minimum graph distance for loop candidate

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

--- Start of ./python_sandbox/autoload/game_state.py ---

#
# PROJECT: GDTLancer
# MODULE: game_state.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2, §3.4 + TACTICAL_TODO.md PHASE 1 TASK_1
# LOG_REF: 2026-02-21 23:15:00
#

import copy


class GameState:
    """Central qualitative state store for world, sectors, agents, and chronicle."""

    def __init__(self):
        # === World ===
        self.world_topology: dict = {}
        self.world_hazards: dict = {}
        self.world_tags: list = []
        self.world_seed: str = ""

        # === Sector/Grid ===
        self.grid_dominion: dict = {}
        self.sector_tags: dict = {}

        # === Agents ===
        self.characters: dict = {}
        self.agents: dict = {}
        self.agent_tags: dict = {}
        self.player_character_uid: str = ""

        # === Colony progression ===
        self.colony_levels: dict = {}
        self.colony_upgrade_progress: dict = {}
        self.colony_downgrade_progress: dict = {}
        self.colony_level_history: list = []

        # === Security progression ===
        self.security_upgrade_progress: dict = {}    # sector_id -> consecutive ticks of upgrade pressure
        self.security_downgrade_progress: dict = {}  # sector_id -> consecutive ticks of downgrade pressure
        self.security_change_threshold: dict = {}    # sector_id -> per-sector ticks required to shift

        # === Economy progression ===
        self.economy_upgrade_progress: dict = {}     # sector_id -> {category -> consecutive ticks of upgrade pressure}
        self.economy_downgrade_progress: dict = {}   # sector_id -> {category -> consecutive ticks of downgrade pressure}
        self.economy_change_threshold: dict = {}     # sector_id -> {category -> per-sector ticks required to shift}

        # === Hostile infestation progression ===
        self.hostile_infestation_progress: dict = {} # sector_id -> transition progress ticks (build/clear)

        # === Catastrophe + lifecycle ===
        self.catastrophe_log: list = []
        self.sector_disabled_until: dict = {}
        self.mortal_agent_counter: int = 0
        self.mortal_agent_deaths: list = []

        # === Discovery ===
        self.discovered_sector_count: int = 0
        self.discovery_log: list = []
        self.sector_names: dict = {}   # sector_id -> display name for discovered sectors

        # === Chronicle ===
        self.chronicle_events: list = []
        self.chronicle_rumors: list = []

        # === Simulation meta ===
        self.sim_tick_count: int = 0
        self.sub_tick_accumulator: int = 0   # accumulates toward SUB_TICKS_PER_TICK
        self.world_age: str = ""
        self.world_age_timer: int = 0
        self.world_age_cycle_count: int = 0

        # === Scene/player state ===
        self.player_docked_at: str = ""

    def deep_copy_dict(self, data: dict) -> dict:
        return copy.deepcopy(data)

--- Start of ./python_sandbox/autoload/__init__.py ---

# autoload/ — mirrors src/autoload/ in Godot project.
# Contains: Constants, GameState, EventBus, TemplateDatabase equivalents.

--- Start of ./python_sandbox/core/__init__.py ---

# core/ — mirrors src/core/ in Godot project.

--- Start of ./python_sandbox/core/simulation/affinity_matrix.py ---

#
# PROJECT: GDTLancer
# MODULE: affinity_matrix.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_6
# LOG_REF: 2026-02-21 22:59:16
#

"""Qualitative tag vocabulary and affinity scoring for the simulation."""

from autoload.constants import ATTACK_THRESHOLD, FLEE_THRESHOLD, TRADE_THRESHOLD


# -------------------------------------------------------------------------
# Tag vocabulary (single source of truth)
# -------------------------------------------------------------------------
SECTOR_ECONOMY_TAGS = {
    "RAW_MATERIALS": {"RAW_RICH", "RAW_ADEQUATE", "RAW_POOR"},
    "MANUFACTURED": {"MANUFACTURED_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_POOR"},
    "CURRENCY": {"CURRENCY_RICH", "CURRENCY_ADEQUATE", "CURRENCY_POOR"},
}

SECTOR_SECURITY_TAGS = {"SECURE", "CONTESTED", "LAWLESS"}
SECTOR_ENVIRONMENT_TAGS = {"MILD", "HARSH", "EXTREME"}
SECTOR_SPECIAL_TAGS = {
    "STATION",
    "FRONTIER",
    "HAS_SALVAGE",
    "DISABLED",
    "HOSTILE_INFESTED",
    "HOSTILE_THREATENED",
}

AGENT_CONDITION_TAGS = {"HEALTHY", "DAMAGED", "DESTROYED"}
AGENT_WEALTH_TAGS = {"WEALTHY", "COMFORTABLE", "BROKE"}
AGENT_CARGO_TAGS = {"LOADED", "EMPTY"}

ROLE_TAGS = {
    "trader": "TRADER",
    "prospector": "PROSPECTOR",
    "military": "MILITARY",
    "hauler": "HAULER",
    "pirate": "PIRATE",
    "explorer": "EXPLORER",
    "idle": "IDLE",
}

PERSONALITY_TAG_RULES = [
    ("greed", ">", 0.6, "GREEDY"),
    ("aggression", ">", 0.5, "AGGRESSIVE"),
    ("risk_tolerance", "<", 0.3, "COWARD"),
    ("risk_tolerance", ">", 0.7, "BOLD"),
    ("loyalty", ">", 0.6, "LOYAL"),
]

DYNAMIC_AGENT_TAGS = {"DESPERATE", "SCAVENGER"}


# -------------------------------------------------------------------------
# Affinity matrix (actor_tag, target_tag) -> score
# -------------------------------------------------------------------------
AFFINITY_MATRIX = {
    # Pirate preferences
    ("PIRATE", "TRADER"): 0.9,
    ("PIRATE", "HAULER"): 0.8,
    ("PIRATE", "WEALTHY"): 1.0,
    ("PIRATE", "LOADED"): 1.2,
    ("PIRATE", "COMFORTABLE"): 0.4,
    ("PIRATE", "DAMAGED"): 0.9,
    ("PIRATE", "MILITARY"): -1.2,
    ("PIRATE", "SECURE"): -0.9,
    ("PIRATE", "LAWLESS"): 1.0,
    ("PIRATE", "STATION"): 0.3,
    ("PIRATE", "CURRENCY_RICH"): 1.0,

    # Trader preferences
    ("TRADER", "STATION"): 0.8,
    ("TRADER", "SECURE"): 0.7,
    ("TRADER", "LAWLESS"): -0.9,
    ("TRADER", "HOSTILE_INFESTED"): -1.2,
    ("TRADER", "CURRENCY_RICH"): 1.0,
    ("TRADER", "MANUFACTURED_RICH"): 0.6,

    # Hauler preferences
    ("HAULER", "RAW_RICH"): 0.9,
    ("HAULER", "MANUFACTURED_POOR"): 0.8,
    ("HAULER", "STATION"): 0.6,
    ("HAULER", "LAWLESS"): -0.8,

    # Prospector/scavenger
    ("PROSPECTOR", "FRONTIER"): 1.0,
    ("PROSPECTOR", "RAW_RICH"): 1.2,
    ("PROSPECTOR", "HAS_SALVAGE"): 1.1,
    ("SCAVENGER", "HAS_SALVAGE"): 1.5,
    ("SCAVENGER", "EXTREME"): -0.7,

    # Military behavior
    ("MILITARY", "HOSTILE_INFESTED"): 1.5,
    ("MILITARY", "HOSTILE_THREATENED"): 1.2,
    ("MILITARY", "LAWLESS"): 1.0,
    ("MILITARY", "PIRATE"): 1.4,
    ("MILITARY", "SECURE"): -0.3,

    # Explorer behavior
    ("EXPLORER", "FRONTIER"): 1.5,
    ("EXPLORER", "MILD"): 0.4,
    ("EXPLORER", "EXTREME"): -0.6,

    # Personality and condition interactions
    ("AGGRESSIVE", "DAMAGED"): 1.1,
    ("AGGRESSIVE", "DESTROYED"): -0.2,
    ("AGGRESSIVE", "LOADED"): 0.5,
    ("GREEDY", "WEALTHY"): 0.9,
    ("GREEDY", "LOADED"): 0.6,
    ("GREEDY", "CURRENCY_RICH"): 0.8,
    ("BOLD", "CONTESTED"): 0.3,
    ("BOLD", "HARSH"): 0.2,
    ("COWARD", "HOSTILE_INFESTED"): -1.5,
    ("COWARD", "LAWLESS"): -1.2,
    ("COWARD", "HARSH"): -0.4,
    ("LOYAL", "MILITARY"): 0.3,

    # Recovery/survival
    ("DESPERATE", "STATION"): 1.5,
    ("DESPERATE", "SECURE"): 0.8,
    ("DAMAGED", "STATION"): 0.7,
    ("BROKE", "STATION"): 0.6,
    ("EMPTY", "RAW_RICH"): 0.6,
}


# -------------------------------------------------------------------------
# Core scoring
# -------------------------------------------------------------------------
def compute_affinity(actor_tags: list, target_tags: list) -> float:
    score = 0.0
    for actor_tag in actor_tags:
        for target_tag in target_tags:
            score += AFFINITY_MATRIX.get((actor_tag, target_tag), 0.0)
    return score


# -------------------------------------------------------------------------
# Tag derivation
# -------------------------------------------------------------------------
def derive_agent_tags(character_data: dict, agent_state: dict, has_cargo: bool = False) -> list:
    tags = []

    role = agent_state.get("agent_role", "idle")
    tags.append(ROLE_TAGS.get(role, "IDLE"))

    for trait_name, op, threshold, tag in PERSONALITY_TAG_RULES:
        value = character_data.get("personality_traits", {}).get(trait_name, 0.5)
        if op == ">" and value > threshold:
            tags.append(tag)
        elif op == "<" and value < threshold:
            tags.append(tag)

    condition_tag = str(agent_state.get("condition_tag", "HEALTHY")).upper()
    wealth_tag = str(agent_state.get("wealth_tag", "COMFORTABLE")).upper()
    cargo_tag = str(agent_state.get("cargo_tag", "LOADED" if has_cargo else "EMPTY")).upper()

    if condition_tag not in AGENT_CONDITION_TAGS:
        condition_tag = "HEALTHY"
    if wealth_tag not in AGENT_WEALTH_TAGS:
        wealth_tag = "COMFORTABLE"
    if cargo_tag not in AGENT_CARGO_TAGS:
        cargo_tag = "LOADED" if has_cargo else "EMPTY"

    tags.extend([condition_tag, wealth_tag, cargo_tag])

    if has_cargo and cargo_tag == "EMPTY":
        tags.append("LOADED")

    dynamic_tags = set(agent_state.get("dynamic_tags", []))
    if dynamic_tags.intersection(DYNAMIC_AGENT_TAGS):
        tags.extend(sorted(dynamic_tags.intersection(DYNAMIC_AGENT_TAGS)))

    if condition_tag == "DAMAGED" and wealth_tag == "BROKE":
        tags.append("DESPERATE")

    if role == "prospector":
        tags.append("SCAVENGER")

    return _unique(tags)


def derive_sector_tags(sector_id: str, state) -> list:
    existing = list(state.sector_tags.get(sector_id, [])) if hasattr(state, "sector_tags") else []
    tags = set(existing)

    topology = state.world_topology.get(sector_id, {}) if hasattr(state, "world_topology") else {}
    hazards = state.world_hazards.get(sector_id, {}) if hasattr(state, "world_hazards") else {}
    dominion = state.grid_dominion.get(sector_id, {}) if hasattr(state, "grid_dominion") else {}
    disabled_until = state.sector_disabled_until.get(sector_id, 0) if hasattr(state, "sector_disabled_until") else 0
    tick = getattr(state, "sim_tick_count", 0)

    if topology.get("sector_type") == "frontier":
        tags.add("FRONTIER")
    else:
        tags.add("STATION")

    if disabled_until and tick < disabled_until:
        tags.add("DISABLED")

    security_tag = _pick_security_tag(tags, dominion)
    env_tag = _pick_environment_tag(hazards, tags)
    economy_tags = _pick_economy_tags(tags)

    tags.difference_update(SECTOR_SECURITY_TAGS)
    tags.add(security_tag)
    tags.difference_update(SECTOR_ENVIRONMENT_TAGS)
    tags.add(env_tag)

    all_economy_tags = set().union(*SECTOR_ECONOMY_TAGS.values())
    tags.difference_update(all_economy_tags)
    tags.update(economy_tags)

    hostile = "HOSTILE_INFESTED" in tags or "HOSTILE_THREATENED" in tags
    if hostile and security_tag == "SECURE":
        tags.discard("HOSTILE_INFESTED")
        tags.add("HOSTILE_THREATENED")

    if "HAS_WRECKS" in tags:
        tags.discard("HAS_WRECKS")
        tags.add("HAS_SALVAGE")

    return _unique(list(tags))


# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------
def _pick_security_tag(existing: set, dominion: dict) -> str:
    for label in SECTOR_SECURITY_TAGS:
        if label in existing:
            return label

    security_level = dominion.get("security_level")
    if isinstance(security_level, (int, float)):
        if security_level >= 0.65:
            return "SECURE"
        if security_level <= 0.35:
            return "LAWLESS"
    return "CONTESTED"


def _pick_environment_tag(hazards: dict, existing: set) -> str:
    for label in SECTOR_ENVIRONMENT_TAGS:
        if label in existing:
            return label

    if isinstance(hazards, dict):
        radiation = float(hazards.get("radiation_level", 0.0) or 0.0)
        thermal = abs(float(hazards.get("thermal_background_k", 0.0) or 0.0))
        severity = radiation + (thermal / 1000.0)
        if severity > 0.35:
            return "EXTREME"
        if severity > 0.12:
            return "HARSH"
    return "MILD"


def _pick_economy_tags(existing: set) -> list:
    tags = []
    for category, options in SECTOR_ECONOMY_TAGS.items():
        current = sorted(existing.intersection(options))
        if current:
            tags.append(current[0])
            continue
        if category == "RAW_MATERIALS":
            tags.append("RAW_ADEQUATE")
        elif category == "MANUFACTURED":
            tags.append("MANUFACTURED_ADEQUATE")
        else:
            tags.append("CURRENCY_ADEQUATE")
    return tags


def _unique(values: list) -> list:
    seen = set()
    result = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result

--- Start of ./python_sandbox/core/simulation/agent_layer.py ---

#
# PROJECT: GDTLancer
# MODULE: agent_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md PHASE 2 TASK_3
# LOG_REF: 2026-02-22 00:55:42
#

"""Qualitative agent layer using affinity-driven tag transitions."""

import copy
import random
from database.registry.template_data import AGENTS, CHARACTERS
from autoload import constants
from core.simulation.affinity_matrix import (
    ATTACK_THRESHOLD,
    FLEE_THRESHOLD,
    TRADE_THRESHOLD,
    compute_affinity,
)


class AgentLayer:
    def __init__(self):
        self._chronicle = None
        self._rng = random.Random()

    def set_chronicle(self, chronicle) -> None:
        self._chronicle = chronicle

    def initialize_agents(self, state) -> None:
        state.agents.clear()
        state.characters.clear()
        state.agent_tags.clear()

        self._initialize_player(state)
        for agent_id, template in AGENTS.items():
            if template.get("agent_type") == "player":
                continue
            self._initialize_agent_from_template(state, agent_id, template)

    def process_tick(self, state, config: dict) -> None:
        self._rng = random.Random(f"{state.world_seed}:{state.sim_tick_count}")

        self._apply_upkeep(state)

        for agent_id, agent in list(state.agents.items()):
            if agent_id == "player":
                continue

            if agent.get("is_disabled", False):
                self._check_respawn(state, agent_id, agent)
                continue

            self._evaluate_goals(agent)
            self._execute_action(state, agent_id, agent)

        self._check_catastrophe(state)
        self._spawn_mortal_agents(state)
        self._cleanup_dead_mortals(state)

    def _initialize_player(self, state) -> None:
        character_id = "character_default"
        state.player_character_uid = character_id
        state.characters[character_id] = copy.deepcopy(CHARACTERS.get(character_id, {}))

        start_sector = next(iter(state.world_topology.keys()), "")
        state.agents["player"] = {
            "character_id": character_id,
            "agent_role": "idle",
            "current_sector_id": start_sector,
            "home_location_id": start_sector,
            "goal_archetype": "idle",
            "goal_queue": [{"type": "idle"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": True,
            "condition_tag": "HEALTHY",
            "wealth_tag": "COMFORTABLE",
            "cargo_tag": "EMPTY",
            "dynamic_tags": [],
        }

    def _initialize_agent_from_template(self, state, agent_id: str, template: dict) -> None:
        character_id = template.get("character_template_id", "") or "character_default"
        char_data = copy.deepcopy(CHARACTERS.get(character_id, {}))
        state.characters[character_id] = char_data

        home = template.get("home_location_id", "")
        start_sector = home if home in state.world_topology else next(iter(state.world_topology.keys()), "")
        initial_tags = template.get("initial_tags", ["HEALTHY", "COMFORTABLE", "EMPTY"])

        state.agents[agent_id] = {
            "character_id": character_id,
            "agent_role": template.get("agent_role", "idle"),
            "current_sector_id": start_sector,
            "home_location_id": home,
            "goal_archetype": "affinity_scan",
            "goal_queue": [{"type": "affinity_scan"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": bool(template.get("is_persistent", False)),
            "condition_tag": self._pick_tag(initial_tags, {"HEALTHY", "DAMAGED", "DESTROYED"}, "HEALTHY"),
            "wealth_tag": self._pick_tag(initial_tags, {"WEALTHY", "COMFORTABLE", "BROKE"}, "COMFORTABLE"),
            "cargo_tag": self._pick_tag(initial_tags, {"LOADED", "EMPTY"}, "EMPTY"),
            "dynamic_tags": [],
        }

    def _evaluate_goals(self, agent: dict) -> None:
        tags = agent.get("sentiment_tags", [])
        if "DESPERATE" in tags:
            agent["goal_archetype"] = "flee_to_safety"
            agent["goal_queue"] = [{"type": "flee_to_safety"}]
            return

        agent["goal_archetype"] = "affinity_scan"
        agent["goal_queue"] = [{"type": "affinity_scan"}]

    def _execute_action(self, state, agent_id: str, agent: dict) -> None:
        goal = (agent.get("goal_queue") or [{"type": "idle"}])[0].get("type", "idle")

        if goal == "flee_to_safety":
            self._action_flee_to_safety(state, agent_id, agent)
            return
        if goal == "affinity_scan":
            self._action_affinity_scan(state, agent_id, agent)

    def _action_flee_to_safety(self, state, agent_id: str, agent: dict) -> None:
        current = agent.get("current_sector_id", "")
        options = [current] + state.world_topology.get(current, {}).get("connections", [])
        best = current
        for sector_id in options:
            tags = state.sector_tags.get(sector_id, [])
            if "SECURE" in tags:
                best = sector_id
                break
        if best != current:
            self._action_move_toward(state, agent_id, agent, best)

    def _action_affinity_scan(self, state, agent_id: str, agent: dict) -> None:
        actor_tags = agent.get("sentiment_tags", [])
        if not actor_tags:
            return

        current_sector = agent.get("current_sector_id", "")
        can_attack = not self._is_combat_cooldown_active(agent, state)

        best_agent_id, best_agent_score = self._best_agent_target(
            state,
            agent_id,
            actor_tags,
            current_sector,
            can_attack,
        )
        if best_agent_id is not None:
            handled = self._resolve_agent_interaction(state, agent_id, best_agent_id, best_agent_score)
            if handled:
                return

        sector_tags = state.sector_tags.get(current_sector, [])
        sector_score = compute_affinity(actor_tags, sector_tags)
        self._resolve_sector_interaction(state, agent_id, sector_score, sector_tags)

    def _resolve_agent_interaction(self, state, actor_id: str, target_id: str, score: float) -> bool:
        actor = state.agents.get(actor_id, {})
        target = state.agents.get(target_id, {})
        if not actor or not target:
            return False

        current_sector = actor.get("current_sector_id", "")

        if score >= ATTACK_THRESHOLD:
            new_target_condition = "DESTROYED" if target.get("condition_tag") == "DAMAGED" else "DAMAGED"
            target["condition_tag"] = new_target_condition
            actor["last_attack_tick"] = state.sim_tick_count
            if new_target_condition == "DESTROYED":
                target["is_disabled"] = True
                target["disabled_at_tick"] = state.sim_tick_count
                state.sector_tags[current_sector] = self._add_tag(state.sector_tags.get(current_sector, []), "HAS_SALVAGE")
                actor["cargo_tag"] = "LOADED"
            self._log_event(state, actor_id, "attack", current_sector, {"target": target_id})
            self._post_combat_dispersal(state, actor_id, actor)
            return True

        if score >= TRADE_THRESHOLD:
            self._bilateral_trade(actor, target)
            self._log_event(state, actor_id, "agent_trade", current_sector, {"target": target_id})
            return True

        if score <= FLEE_THRESHOLD:
            self._action_move_random(state, actor_id, actor)
            self._log_event(state, actor_id, "flee", current_sector, {"target": target_id})
            return True

        return False

    def _resolve_sector_interaction(self, state, agent_id: str, score: float, sector_tags: list) -> None:
        agent = state.agents.get(agent_id, {})
        sector_id = agent.get("current_sector_id", "")

        # Explorers prioritise exploration above almost everything.
        if "FRONTIER" in sector_tags and agent.get("agent_role") == "explorer":
            self._try_exploration(state, agent_id, agent, sector_id)
            return

        if score >= ATTACK_THRESHOLD and "HAS_SALVAGE" in sector_tags:
            self._action_harvest(state, agent_id, agent, sector_id)
            return

        needs_dock = (
            agent.get("condition_tag") == "DAMAGED"
            or agent.get("cargo_tag") == "LOADED"
        )
        at_station = "STATION" in sector_tags or "FRONTIER" in sector_tags

        if needs_dock and at_station:
            self._try_dock(state, agent_id, agent, sector_id)
            return

        if agent.get("cargo_tag") == "EMPTY":
            loaded = self._try_load_cargo(state, agent_id, agent, sector_id)
            if loaded:
                return

        if score <= FLEE_THRESHOLD:
            self._action_move_random(state, agent_id, agent)
            self._log_event(state, agent_id, "flee", sector_id, {"reason": "sector_affinity"})
            return

        self._action_move_toward_role_target(state, agent_id, agent)

    def _try_dock(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        if "STATION" not in state.sector_tags.get(sector_id, []) and "FRONTIER" not in state.sector_tags.get(sector_id, []):
            return

        sold_cargo = False
        if agent.get("cargo_tag") == "LOADED":
            agent["cargo_tag"] = "EMPTY"
            self._wealth_step_up(agent)
            sold_cargo = True

        if agent.get("condition_tag") == "DAMAGED":
            agent["condition_tag"] = "HEALTHY"
            if not sold_cargo:
                self._wealth_step_down(agent)

        self._log_event(state, agent_id, "dock", sector_id, {})

    def _action_harvest(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        tags = state.sector_tags.get(sector_id, [])
        if "HAS_SALVAGE" not in tags:
            return
        agent["cargo_tag"] = "LOADED"
        state.sector_tags[sector_id] = [tag for tag in tags if tag != "HAS_SALVAGE"]
        self._log_event(state, agent_id, "harvest", sector_id, {})

    def _action_move_toward_tag(self, state, agent_id: str, agent: dict, target_tag: str) -> None:
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        for sector_id in neighbors:
            if target_tag in state.sector_tags.get(sector_id, []):
                self._action_move_toward(state, agent_id, agent, sector_id)
                return
        self._action_move_random(state, agent_id, agent)

    def _action_move_toward(self, state, agent_id: str, agent: dict, target_sector_id: str) -> None:
        current = agent.get("current_sector_id", "")
        if target_sector_id in state.world_topology.get(current, {}).get("connections", []):
            agent["current_sector_id"] = target_sector_id
            self._log_event(state, agent_id, "move", target_sector_id, {"from": current})

    def _action_move_random(self, state, agent_id: str, agent: dict) -> None:
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return
        target = self._rng.choice(neighbors)
        self._action_move_toward(state, agent_id, agent, target)

    def _try_exploration(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        # Cap check — stop when the graph is full.
        if len(state.world_topology) >= constants.MAX_SECTOR_COUNT:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {})
            return

        if agent.get("wealth_tag") == "BROKE":
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "broke"})
            return

        # Per-agent cooldown — explorer must wait between discoveries.
        last_discovery = agent.get("last_discovery_tick", -999)
        if state.sim_tick_count - last_discovery < constants.EXPLORATION_COOLDOWN_TICKS:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "cooldown"})
            return

        # Probability gate — diminishing returns: more sectors → lower chance.
        sector_count = len(state.world_topology)
        saturation = sector_count / constants.MAX_SECTOR_COUNT  # 0..1
        effective_chance = constants.EXPLORATION_SUCCESS_CHANCE * (1.0 - saturation)
        if self._rng.random() > effective_chance:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "nothing_found"})
            return

        agent["last_discovery_tick"] = state.sim_tick_count

        state.discovered_sector_count += 1
        new_id = f"discovered_{state.discovered_sector_count}"

        # --- Generate a deterministic name ---
        new_name = self._generate_sector_name(state)

        # --- Determine connections (filament topology: cap + sparse branching) ---
        source_id = sector_id
        if self._graph_degree(state, source_id) >= constants.MAX_CONNECTIONS_PER_SECTOR:
            fallback_candidates = []
            for neighbor_id in state.world_topology.get(source_id, {}).get("connections", []):
                if self._graph_degree(state, neighbor_id) < constants.MAX_CONNECTIONS_PER_SECTOR:
                    fallback_candidates.append(neighbor_id)

            if not fallback_candidates:
                self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "region_saturated"})
                return

            source_id = sorted(fallback_candidates, key=lambda sid: (self._graph_degree(state, sid), sid))[0]

        connections = [source_id]

        extra_one_added = False
        if self._rng.random() < constants.EXTRA_CONNECTION_1_CHANCE:
            nearby = self._nearby_candidates(state, source_id, set(connections))
            if nearby:
                extra_one = self._rng.choice(sorted(nearby))
                if extra_one not in connections:
                    connections.append(extra_one)
                    extra_one_added = True

        if extra_one_added and self._rng.random() < constants.EXTRA_CONNECTION_2_CHANCE:
            loop_candidate = self._distant_loop_candidate(state, source_id, set(connections))
            if loop_candidate is not None and loop_candidate not in connections:
                connections.append(loop_candidate)

        # --- Pick initial tags (frontier bias: harsh, poor, contested) ---
        sec_roll = self._rng.random()
        security = "LAWLESS" if sec_roll < 0.45 else ("CONTESTED" if sec_roll < 0.85 else "SECURE")
        env_roll = self._rng.random()
        environment = "EXTREME" if env_roll < 0.3 else ("HARSH" if env_roll < 0.75 else "MILD")

        econ_tags = []
        econ_options = ["POOR", "POOR", "ADEQUATE", "ADEQUATE", "RICH"]
        for prefix in ("RAW", "MANUFACTURED", "CURRENCY"):
            level = self._rng.choice(econ_options)
            econ_tags.append(f"{prefix}_{level}")

        initial_tags = ["FRONTIER", security, environment] + econ_tags

        # --- Wire into the world graph (bidirectional) ---
        state.world_topology[new_id] = {
            "connections": list(connections),
            "station_ids": [new_id],
            "sector_type": "frontier",
        }
        for conn_id in connections:
            conn_data = state.world_topology.get(conn_id, {})
            existing_conns = conn_data.get("connections", [])
            if new_id not in existing_conns:
                existing_conns.append(new_id)

        # --- Initialize all required state dicts ---
        state.sector_tags[new_id] = list(initial_tags)
        state.world_hazards[new_id] = {"environment": environment}
        state.colony_levels[new_id] = "frontier"
        state.colony_upgrade_progress[new_id] = 0
        state.colony_downgrade_progress[new_id] = 0
        state.security_upgrade_progress[new_id] = 0
        state.security_downgrade_progress[new_id] = 0
        _thresh_rng = random.Random(f"{state.world_seed}:sec_thresh:{new_id}")
        state.security_change_threshold[new_id] = _thresh_rng.randint(
            constants.SECURITY_CHANGE_TICKS_MIN,
            constants.SECURITY_CHANGE_TICKS_MAX,
        )
        state.grid_dominion[new_id] = {
            "controlling_faction_id": "",
            "security_tag": security,
        }
        state.economy_upgrade_progress[new_id] = {cat: 0 for cat in ("RAW", "MANUFACTURED", "CURRENCY")}
        state.economy_downgrade_progress[new_id] = {cat: 0 for cat in ("RAW", "MANUFACTURED", "CURRENCY")}
        state.economy_change_threshold[new_id] = {}
        for category in ("RAW", "MANUFACTURED", "CURRENCY"):
            thresh_rng = random.Random(f"{state.world_seed}:econ_thresh:{new_id}:{category}")
            state.economy_change_threshold[new_id][category] = thresh_rng.randint(
                constants.ECONOMY_CHANGE_TICKS_MIN,
                constants.ECONOMY_CHANGE_TICKS_MAX,
            )
        state.hostile_infestation_progress[new_id] = 0

        # --- Record ---
        state.sector_names[new_id] = new_name
        state.discovery_log.append({
            "tick": state.sim_tick_count,
            "discoverer": agent_id,
            "from": sector_id,
            "new_sector": new_id,
            "name": new_name,
        })
        self._log_event(state, agent_id, "sector_discovered", sector_id, {
            "new_sector": new_id,
            "name": new_name,
            "connections": connections,
        })

    # Name-generation pools for discovered sectors.
    _FRONTIER_PREFIXES = [
        "Void", "Drift", "Nebula", "Rim", "Edge", "Shadow", "Iron",
        "Crimson", "Amber", "Frozen", "Ashen", "Silent", "Storm",
        "Obsidian", "Crystal", "Pale", "Dark",
    ]
    _FRONTIER_SUFFIXES = [
        "Reach", "Expanse", "Passage", "Crossing", "Haven", "Point",
        "Drift", "Hollow", "Gate", "Threshold", "Frontier", "Shelf",
        "Anchorage", "Waypoint", "Depot",
    ]

    def _generate_sector_name(self, state) -> str:
        """Return a deterministic but varied name for a discovered sector."""
        rng = random.Random(f"{state.world_seed}:discovery:{state.discovered_sector_count}")
        prefix = rng.choice(self._FRONTIER_PREFIXES)
        suffix = rng.choice(self._FRONTIER_SUFFIXES)
        return f"{prefix} {suffix}"

    def _graph_degree(self, state, sector_id: str) -> int:
        """Return connection count for a sector in the topology graph."""
        return len(state.world_topology.get(sector_id, {}).get("connections", []))

    def _sectors_below_cap(self, state) -> list[str]:
        """Return all sectors whose degree is below the hard connection cap."""
        sectors = []
        for sid in state.world_topology.keys():
            if self._graph_degree(state, sid) < constants.MAX_CONNECTIONS_PER_SECTOR:
                sectors.append(sid)
        return sectors

    def _nearby_candidates(self, state, source_id: str, exclude: set) -> list[str]:
        """Return neighbors of source that can accept more links and are not excluded."""
        candidates = []
        neighbors = state.world_topology.get(source_id, {}).get("connections", [])
        for sid in neighbors:
            if sid in exclude:
                continue
            if self._graph_degree(state, sid) >= constants.MAX_CONNECTIONS_PER_SECTOR:
                continue
            candidates.append(sid)
        return candidates

    def _distant_loop_candidate(self, state, source_id: str, exclude: set):
        """Pick a deterministic distant loop target at >= LOOP_MIN_HOPS from source."""
        if source_id not in state.world_topology:
            return None

        queue = [(source_id, 0)]
        visited = {source_id}
        distant = []

        while queue:
            current_id, depth = queue.pop(0)
            if (
                depth >= constants.LOOP_MIN_HOPS
                and current_id not in exclude
                and self._graph_degree(state, current_id) < constants.MAX_CONNECTIONS_PER_SECTOR
            ):
                distant.append(current_id)

            for neighbor_id in state.world_topology.get(current_id, {}).get("connections", []):
                if neighbor_id in visited:
                    continue
                visited.add(neighbor_id)
                queue.append((neighbor_id, depth + 1))

        if not distant:
            return None

        rng = random.Random(
            f"{state.world_seed}:loop:{source_id}:{state.discovered_sector_count}:{state.sim_tick_count}"
        )
        return rng.choice(sorted(distant))

    def _best_agent_target(self, state, actor_id: str, actor_tags: list, sector_id: str, can_attack: bool):
        best_id = None
        best_score = 0.0
        for target_id, target in state.agents.items():
            if target_id == actor_id or target.get("is_disabled"):
                continue
            if target.get("current_sector_id") != sector_id:
                continue
            target_tags = target.get("sentiment_tags", [])
            score = compute_affinity(actor_tags, target_tags)
            if not can_attack and score >= ATTACK_THRESHOLD:
                continue
            if abs(score) > abs(best_score):
                best_score = score
                best_id = target_id
        return best_id, best_score

    def _is_combat_cooldown_active(self, agent: dict, state) -> bool:
        last_attack_tick = agent.get("last_attack_tick")
        if last_attack_tick is None:
            return False
        return (state.sim_tick_count - int(last_attack_tick)) < constants.COMBAT_COOLDOWN_TICKS

    def _bilateral_trade(self, actor: dict, target: dict) -> None:
        actor_loaded = actor.get("cargo_tag") == "LOADED"
        target_loaded = target.get("cargo_tag") == "LOADED"
        if actor_loaded and not target_loaded:
            actor["cargo_tag"] = "EMPTY"
            target["cargo_tag"] = "LOADED"
        elif target_loaded and not actor_loaded:
            target["cargo_tag"] = "EMPTY"
            actor["cargo_tag"] = "LOADED"

    def _check_respawn(self, state, agent_id: str, agent: dict) -> None:
        if not agent.get("is_persistent", False):
            return
        disabled_at_tick = agent.get("disabled_at_tick")
        if disabled_at_tick is None:
            return
        if state.sim_tick_count - int(disabled_at_tick) < constants.RESPAWN_COOLDOWN_TICKS:
            return

        agent["is_disabled"] = False
        agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
        agent["condition_tag"] = "HEALTHY"
        agent["wealth_tag"] = "COMFORTABLE"
        agent["cargo_tag"] = "EMPTY"
        self._log_event(state, agent_id, "respawn", agent.get("current_sector_id", ""), {})

    def _check_catastrophe(self, state) -> None:
        if self._rng.random() > constants.CATASTROPHE_CHANCE_PER_TICK:
            return
        sector_ids = list(state.world_topology.keys())
        if not sector_ids:
            return
        sector_id = self._rng.choice(sector_ids)
        state.sector_tags[sector_id] = self._add_tag(state.sector_tags.get(sector_id, []), "DISABLED")
        state.sector_tags[sector_id] = self._replace_one(state.sector_tags[sector_id], {"MILD", "HARSH", "EXTREME"}, "EXTREME")
        state.sector_disabled_until[sector_id] = state.sim_tick_count + constants.CATASTROPHE_DISABLE_DURATION
        state.catastrophe_log.append({"tick": state.sim_tick_count, "sector_id": sector_id})
        self._log_event(state, "system", "catastrophe", sector_id, {})

        # Kill mortals caught in the catastrophe sector.
        to_kill = []
        for agent_id, agent in state.agents.items():
            if agent.get("is_persistent", False) or agent.get("is_disabled", False):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            if self._rng.random() < constants.CATASTROPHE_MORTAL_KILL_CHANCE:
                to_kill.append(agent_id)
        for agent_id in to_kill:
            state.mortal_agent_deaths.append({"tick": state.sim_tick_count, "agent_id": agent_id})
            self._log_event(state, agent_id, "catastrophe_death", sector_id, {})
            del state.agents[agent_id]

    def _spawn_mortal_agents(self, state) -> None:
        if len(state.agents) >= constants.MORTAL_GLOBAL_CAP:
            return

        eligible = []
        for sector_id, tags in state.sector_tags.items():
            if (
                any(tag in tags for tag in constants.MORTAL_SPAWN_REQUIRED_SECURITY)
                and not any(t in tags for t in constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS)
                and any(tag in tags for tag in constants.MORTAL_SPAWN_MIN_ECONOMY_TAGS)
            ):
                eligible.append(sector_id)

        if not eligible:
            return

        # Diminishing returns: more agents → lower spawn chance.
        agent_count = len(state.agents)
        saturation = agent_count / constants.MORTAL_GLOBAL_CAP  # 0..1
        effective_chance = constants.MORTAL_SPAWN_CHANCE * (1.0 - saturation)
        if self._rng.random() > effective_chance:
            return

        spawn_sector = self._rng.choice(eligible)

        state.mortal_agent_counter += 1
        agent_id = f"mortal_{state.mortal_agent_counter}"
        role = self._rng.choice(constants.MORTAL_ROLES)
        state.agents[agent_id] = {
            "character_id": "",
            "agent_role": role,
            "current_sector_id": spawn_sector,
            "home_location_id": spawn_sector,
            "goal_archetype": "affinity_scan",
            "goal_queue": [{"type": "affinity_scan"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": False,
            "condition_tag": "HEALTHY",
            "wealth_tag": "BROKE",
            "cargo_tag": "EMPTY",
            "dynamic_tags": [],
        }
        self._log_event(state, agent_id, "spawn", spawn_sector, {})

    def _cleanup_dead_mortals(self, state) -> None:
        """Handle destroyed mortals: survival roll or permanent death.

        Each destroyed mortal rolls against MORTAL_SURVIVAL_CHANCE.
        Survivors respawn at their home sector after RESPAWN_COOLDOWN_TICKS
        (handled by the normal _check_respawn path once is_persistent is
        temporarily kept).  Those who fail the roll are permanently removed.
        """
        to_remove = []
        to_survive = []
        for agent_id, agent in state.agents.items():
            if agent.get("is_persistent", False):
                continue
            if agent.get("is_disabled", False):
                if self._rng.random() < constants.MORTAL_SURVIVAL_CHANCE:
                    to_survive.append(agent_id)
                else:
                    to_remove.append(agent_id)

        # Survivors: reset at home with enough resources to be functional
        for agent_id in to_survive:
            agent = state.agents[agent_id]
            agent["is_disabled"] = False
            agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
            agent["condition_tag"] = "DAMAGED"
            agent["wealth_tag"] = "BROKE"
            agent["cargo_tag"] = "EMPTY"
            self._log_event(state, agent_id, "survived", agent.get("current_sector_id", ""), {})

        # Permanent deaths
        for agent_id in to_remove:
            state.mortal_agent_deaths.append({"tick": state.sim_tick_count, "agent_id": agent_id})
            self._log_event(state, agent_id, "perma_death", state.agents[agent_id].get("current_sector_id", ""), {})
            del state.agents[agent_id]

    def _apply_upkeep(self, state) -> None:
        """Apply wear-and-tear and subsistence recovery to agents each tick."""
        for agent_id, agent in state.agents.items():
            if agent_id == "player" or agent.get("is_disabled"):
                continue

            if (
                state.world_age == "DISRUPTION"
                and not agent.get("is_persistent", False)
            ):
                sector_tags = state.sector_tags.get(agent.get("current_sector_id", ""), [])
                if (
                    ("HARSH" in sector_tags or "EXTREME" in sector_tags)
                    and self._rng.random() < constants.DISRUPTION_MORTAL_ATTRITION_CHANCE
                ):
                    agent["is_disabled"] = True
                    agent["disabled_at_tick"] = state.sim_tick_count
                    continue

            # Random degradation
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                if agent.get("condition_tag") == "HEALTHY":
                    agent["condition_tag"] = "DAMAGED"
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                self._wealth_step_down(agent)
            if agent.get("wealth_tag") == "WEALTHY" and self._rng.random() < constants.WEALTHY_DRAIN_CHANCE:
                agent["wealth_tag"] = "COMFORTABLE"
            # Subsistence recovery: broke agents at a station/outpost can
            # pick up odd jobs and slowly recover to COMFORTABLE.
            if agent.get("wealth_tag") == "BROKE":
                sector_tags = state.sector_tags.get(agent.get("current_sector_id", ""), [])
                if "STATION" in sector_tags or "FRONTIER" in sector_tags:
                    if self._rng.random() < constants.BROKE_RECOVERY_CHANCE:
                        agent["wealth_tag"] = "COMFORTABLE"

    def _try_load_cargo(self, state, agent_id: str, agent: dict, sector_id: str) -> bool:
        """Load cargo from a resource-rich sector based on role."""
        if agent.get("cargo_tag") != "EMPTY":
            return False
        sector_tags = state.sector_tags.get(sector_id, [])
        role = agent.get("agent_role", "idle")
        can_load = False
        if role in ("hauler", "prospector"):
            can_load = any(t in sector_tags for t in ["RAW_RICH", "MANUFACTURED_RICH"])
        elif role == "trader":
            can_load = ("STATION" in sector_tags or "FRONTIER" in sector_tags) and agent.get("wealth_tag") != "BROKE"
        elif role == "pirate":
            can_load = "HAS_SALVAGE" in sector_tags
        if can_load:
            agent["cargo_tag"] = "LOADED"
            if role == "trader":
                self._wealth_step_down(agent)
            if role == "pirate" and "HAS_SALVAGE" in sector_tags:
                state.sector_tags[sector_id] = [t for t in state.sector_tags.get(sector_id, []) if t != "HAS_SALVAGE"]
            self._log_event(state, agent_id, "load_cargo", sector_id, {})
            return True
        return False

    def _action_move_toward_role_target(self, state, agent_id: str, agent: dict) -> None:
        """Move toward sectors that match the agent's role interest."""
        role = agent.get("agent_role", "idle")
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return
        target_preferences = {
            "trader": ["CURRENCY_POOR", "MANUFACTURED_POOR", "STATION"],
            "hauler": ["RAW_RICH", "MANUFACTURED_RICH"],
            "prospector": ["FRONTIER", "HAS_SALVAGE", "RAW_RICH"],
            "explorer": ["FRONTIER", "HARSH", "EXTREME"],
            "pirate": ["LAWLESS", "HOSTILE_INFESTED", "HAS_SALVAGE"],
            "military": ["CONTESTED", "LAWLESS", "HOSTILE_INFESTED", "HOSTILE_THREATENED"],
        }
        preferred_tags = target_preferences.get(role, [])
        best_sector = None
        best_score = -1
        for neighbor_id in neighbors:
            n_tags = state.sector_tags.get(neighbor_id, [])
            score = sum(1 for tag in preferred_tags if tag in n_tags)
            if score > best_score:
                best_score = score
                best_sector = neighbor_id
        if best_sector and best_score > 0:
            self._action_move_toward(state, agent_id, agent, best_sector)
        else:
            self._action_move_random(state, agent_id, agent)

    def _post_combat_dispersal(self, state, agent_id: str, agent: dict) -> None:
        """After combat, prefer moving into a less-crowded neighboring sector."""
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return

        target_sector = min(neighbors, key=lambda sector_id: self._active_agent_count_in_sector(state, sector_id))
        self._action_move_toward(state, agent_id, agent, target_sector)

    def _active_agent_count_in_sector(self, state, sector_id: str) -> int:
        count = 0
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") == sector_id:
                count += 1
        return count

    def _wealth_step_up(self, agent: dict) -> None:
        """Increase wealth by one level."""
        w = agent.get("wealth_tag", "COMFORTABLE")
        if w == "BROKE":
            agent["wealth_tag"] = "COMFORTABLE"
        elif w == "COMFORTABLE":
            agent["wealth_tag"] = "WEALTHY"

    def _wealth_step_down(self, agent: dict) -> None:
        """Decrease wealth by one level."""
        w = agent.get("wealth_tag", "COMFORTABLE")
        if w == "WEALTHY":
            agent["wealth_tag"] = "COMFORTABLE"
        elif w == "COMFORTABLE":
            agent["wealth_tag"] = "BROKE"

    def _economy_step_up(self, tags: list) -> list:
        levels = ["POOR", "ADEQUATE", "RICH"]
        out = list(tags)
        for prefix in ["RAW_", "MANUFACTURED_", "CURRENCY_"]:
            current = "ADEQUATE"
            for level in levels:
                if f"{prefix}{level}" in out:
                    current = level
                    break
            idx = min(2, levels.index(current) + 1)
            out = [tag for tag in out if not tag.startswith(prefix)]
            out.append(f"{prefix}{levels[idx]}")
        return out

    def _pick_tag(self, values: list, options: set, default: str) -> str:
        for value in values:
            if value in options:
                return value
        return default

    def _replace_one(self, tags: list, options: set, replacement: str) -> list:
        return [tag for tag in tags if tag not in options] + [replacement]

    def _add_tag(self, tags: list, tag: str) -> list:
        return tags if tag in tags else tags + [tag]

    def _log_event(self, state, actor_id: str, action: str, sector_id: str, metadata: dict) -> None:
        event = {
            "tick": state.sim_tick_count,
            "actor_id": actor_id,
            "action": action,
            "sector_id": sector_id,
            "metadata": metadata,
        }
        # Route through the chronicle layer when available (it will push
        # into state.chronicle_events during its own process_tick).
        # Direct append only as fallback when no chronicle is wired up.
        if self._chronicle is not None:
            self._chronicle.log_event(event)
        else:
            state.chronicle_events.append(event)

--- Start of ./python_sandbox/core/simulation/bridge_systems.py ---

#
# PROJECT: GDTLancer
# MODULE: bridge_systems.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_9
# LOG_REF: 2026-02-21 (TASK_8)
#

"""Bridge systems: derive and refresh qualitative tags across layers."""

from core.simulation.affinity_matrix import derive_agent_tags, derive_sector_tags


class BridgeSystems:
    """Cross-layer tag refresh only (agent, sector, world)."""

    def process_tick(self, state, config: dict) -> None:
        self._refresh_sector_tags(state)
        self._refresh_agent_tags(state)
        self._refresh_world_tags(state)

    def _refresh_agent_tags(self, state) -> None:
        state.agent_tags = state.agent_tags or {}
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue
            character_id = agent.get("character_id", "")
            char_data = state.characters.get(character_id, {})
            has_cargo = "LOADED" in agent.get("initial_tags", []) or agent.get("cargo_tag") == "LOADED"
            tags = derive_agent_tags(char_data, agent, has_cargo=has_cargo)
            state.agent_tags[agent_id] = tags
            agent["sentiment_tags"] = tags

    def _refresh_sector_tags(self, state) -> None:
        for sector_id in state.world_topology:
            state.sector_tags[sector_id] = derive_sector_tags(sector_id, state)

    def _refresh_world_tags(self, state) -> None:
        age = state.world_age or "PROSPERITY"
        mapping = {
            "PROSPERITY": ["ABUNDANT", "STABLE"],
            "DISRUPTION": ["SCARCE", "VOLATILE"],
            "RECOVERY": ["RECOVERING"],
        }
        state.world_tags = mapping.get(age, ["STABLE"])

--- Start of ./python_sandbox/core/simulation/chronicle_layer.py ---

#
# PROJECT: GDTLancer
# MODULE: chronicle_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_12
# LOG_REF: 2026-02-21 (TASK_11)
#

"""Chronicle layer: capture events, generate rumors, distribute memory."""

from database.registry.template_data import LOCATIONS


class ChronicleLayer:
    def __init__(self):
        self._staging_buffer = []
        self._max_events = 200
        self._max_rumors = 50
        self._max_agent_memory = 20

    def log_event(self, event_packet: dict) -> None:
        packet = dict(event_packet)
        packet.setdefault("tick", 0)
        packet.setdefault("actor_id", "unknown")
        packet.setdefault("action", "unknown")
        packet.setdefault("sector_id", "")
        packet.setdefault("metadata", {})
        self._staging_buffer.append(packet)

    def process_tick(self, state) -> None:
        if not self._staging_buffer:
            return

        events = self._collect_events(state)
        rumors = self._generate_rumors(state, events)
        self._distribute_events(state, events)

        state.chronicle_rumors.extend(rumors)
        if len(state.chronicle_rumors) > self._max_rumors:
            state.chronicle_rumors = state.chronicle_rumors[-self._max_rumors :]

    def _collect_events(self, state) -> list:
        events = list(self._staging_buffer)
        self._staging_buffer.clear()
        state.chronicle_events.extend(events)
        if len(state.chronicle_events) > self._max_events:
            state.chronicle_events = state.chronicle_events[-self._max_events :]
        return events

    def _generate_rumors(self, state, events: list) -> list:
        rumors = []
        for event in events:
            rumor = self._format_rumor(state, event)
            if rumor:
                rumors.append(rumor)
        return rumors

    def _format_rumor(self, state, event: dict) -> str:
        actor = self._resolve_actor_name(state, event.get("actor_id", ""))
        action = self._humanize_action(event.get("action", "unknown"))
        sector = self._resolve_location_name(event.get("sector_id", ""), state)
        if not actor or not sector:
            return ""
        return f"{actor} {action} at {sector}."

    def _distribute_events(self, state, events: list) -> None:
        for event in events:
            sector_id = event.get("sector_id", "")
            if not sector_id:
                continue
            visible = [sector_id] + state.world_topology.get(sector_id, {}).get("connections", [])
            for agent in state.agents.values():
                if agent.get("is_disabled"):
                    continue
                if agent.get("current_sector_id") not in visible:
                    continue
                memory = list(agent.get("event_memory", []))
                memory.append(event)
                if len(memory) > self._max_agent_memory:
                    memory = memory[-self._max_agent_memory :]
                agent["event_memory"] = memory

    def _resolve_actor_name(self, state, actor_id: str) -> str:
        if actor_id == "player":
            return "You"
        if actor_id in state.agents:
            character_id = state.agents[actor_id].get("character_id", "")
            if character_id in state.characters:
                return state.characters[character_id].get("character_name", actor_id)
        return str(actor_id)

    def _resolve_location_name(self, sector_id: str, state=None) -> str:
        if sector_id in LOCATIONS:
            return LOCATIONS[sector_id].get("location_name", sector_id)
        if state and hasattr(state, "sector_names"):
            return state.sector_names.get(sector_id, sector_id)
        return sector_id

    def _humanize_action(self, action: str) -> str:
        labels = {
            "move": "moved",
            "attack": "attacked",
            "agent_trade": "traded",
            "dock": "docked",
            "harvest": "harvested salvage",
            "load_cargo": "loaded cargo",
            "flee": "fled",
            "exploration": "explored",
            "sector_discovered": "discovered a new sector",
            "spawn": "appeared",
            "respawn": "returned",
            "survived": "narrowly survived destruction",
            "perma_death": "was permanently lost",
            "catastrophe": "witnessed catastrophe",
            "age_change": "reported a world-age shift",
        }
        return labels.get(action, action)

--- Start of ./python_sandbox/core/simulation/grid_layer.py ---

#
# PROJECT: GDTLancer
# MODULE: grid_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md PHASE 1 TASK_4
# LOG_REF: 2026-02-21 23:50:00
#

"""Tag-transition CA engine for economy, security, and environment layers."""

import random
from autoload import constants


class GridLayer:
    ECONOMY_LEVELS = ["POOR", "ADEQUATE", "RICH"]
    SECURITY_LEVELS = ["LAWLESS", "CONTESTED", "SECURE"]
    ENV_LEVELS = ["EXTREME", "HARSH", "MILD"]
    CATEGORIES = ["RAW", "MANUFACTURED", "CURRENCY"]

    def initialize_grid(self, state) -> None:
        state.colony_levels = state.colony_levels or {}
        for sector_id, data in state.world_topology.items():
            if sector_id not in state.sector_tags:
                state.sector_tags[sector_id] = ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
            if sector_id not in state.colony_levels:
                state.colony_levels[sector_id] = data.get("sector_type", "frontier")
            if sector_id not in state.grid_dominion:
                state.grid_dominion[sector_id] = {
                    "controlling_faction_id": "",
                    "security_tag": self._security_tag(state.sector_tags[sector_id]),
                }
            if sector_id not in state.security_upgrade_progress:
                state.security_upgrade_progress[sector_id] = 0
            if sector_id not in state.security_downgrade_progress:
                state.security_downgrade_progress[sector_id] = 0
            if sector_id not in state.security_change_threshold:
                rng = random.Random(f"{state.world_seed}:sec_thresh:{sector_id}")
                state.security_change_threshold[sector_id] = rng.randint(
                    constants.SECURITY_CHANGE_TICKS_MIN,
                    constants.SECURITY_CHANGE_TICKS_MAX,
                )
            if sector_id not in state.economy_upgrade_progress:
                state.economy_upgrade_progress[sector_id] = {}
            if sector_id not in state.economy_downgrade_progress:
                state.economy_downgrade_progress[sector_id] = {}
            if sector_id not in state.economy_change_threshold:
                state.economy_change_threshold[sector_id] = {}
            for category in self.CATEGORIES:
                state.economy_upgrade_progress[sector_id].setdefault(category, 0)
                state.economy_downgrade_progress[sector_id].setdefault(category, 0)
                if category not in state.economy_change_threshold[sector_id]:
                    thresh_rng = random.Random(f"{state.world_seed}:econ_thresh:{sector_id}:{category}")
                    state.economy_change_threshold[sector_id][category] = thresh_rng.randint(
                        constants.ECONOMY_CHANGE_TICKS_MIN,
                        constants.ECONOMY_CHANGE_TICKS_MAX,
                    )
            if sector_id not in state.hostile_infestation_progress:
                state.hostile_infestation_progress[sector_id] = 0

    def process_tick(self, state, config: dict) -> None:
        new_tags = {}
        for sector_id in state.world_topology:
            current = list(state.sector_tags.get(sector_id, []))
            neighbors = state.world_topology.get(sector_id, {}).get("connections", [])
            neighbor_tags = [state.sector_tags.get(n, []) for n in neighbors]

            tags = self._step_economy(current, neighbor_tags, state, sector_id)
            tags = self._step_security(tags, neighbor_tags, state, sector_id)
            tags = self._step_environment(tags, state, sector_id)
            tags = self._step_hostile_presence(tags, state, sector_id)
            tags = self._step_colony_level(tags, state, sector_id)
            new_tags[sector_id] = self._unique(tags)

        state.sector_tags = new_tags
        for sector_id, tags in state.sector_tags.items():
            state.grid_dominion.setdefault(sector_id, {})["security_tag"] = self._security_tag(tags)

    def _step_economy(self, tags: list, neighbor_tags: list, state, sector_id: str) -> list:
        result = list(tags)
        world_age = state.world_age or "PROSPERITY"
        role_counts = self._role_counts_for_sector(state, sector_id)
        sector_upgrade_progress = state.economy_upgrade_progress.setdefault(sector_id, {})
        sector_downgrade_progress = state.economy_downgrade_progress.setdefault(sector_id, {})
        sector_thresholds = state.economy_change_threshold.setdefault(sector_id, {})
        loaded_trade = self._loaded_trade_count_for_sector(state, sector_id)
        colony_level = state.colony_levels.get(sector_id, "frontier")
        has_active_commerce = loaded_trade > 0 or colony_level in ("colony", "hub")
        has_pirate_or_infestation = role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result

        for category in self.CATEGORIES:
            level = self._economy_level(result, category)
            idx = self.ECONOMY_LEVELS.index(level)
            delta = 0
            threshold = sector_thresholds.get(category)
            if threshold is None:
                thresh_rng = random.Random(f"{state.world_seed}:econ_thresh:{sector_id}:{category}")
                threshold = thresh_rng.randint(
                    constants.ECONOMY_CHANGE_TICKS_MIN,
                    constants.ECONOMY_CHANGE_TICKS_MAX,
                )
                sector_thresholds[category] = threshold

            # Homeostatic pressure (corruption / recovery)
            if level == "RICH":
                delta -= 1
            elif level == "POOR":
                delta += 1

            # World age influence (category-specific, condition-aware)
            if world_age == "PROSPERITY":
                if has_active_commerce:
                    delta += 1
            elif world_age == "DISRUPTION":
                if category == "RAW":
                    delta -= 1
                elif category == "MANUFACTURED" and has_pirate_or_infestation:
                    delta -= 1
            elif world_age == "RECOVERY":
                delta += 1

            # Colony maintenance drain
            if colony_level == "hub":
                delta -= 1
            elif colony_level == "colony" and category == "RAW":
                delta -= 1

            # Population density pressure
            if self._active_agent_count_in_sector(state, sector_id) > 3:
                delta -= 1

            # Active commerce
            if loaded_trade > 0:
                delta += 1
            if role_counts.get("pirate", 0) > 0:
                delta -= 1

            up_progress = sector_upgrade_progress.get(category, 0)
            down_progress = sector_downgrade_progress.get(category, 0)

            if delta >= 1:
                up_progress += 1
                down_progress = 0
            elif delta <= -1:
                down_progress += 1
                up_progress = 0
            else:
                up_progress = 0
                down_progress = 0

            if up_progress >= threshold and idx < 2:
                idx = min(2, idx + 1)
                up_progress = 0
            elif down_progress >= threshold and idx > 0:
                idx = max(0, idx - 1)
                down_progress = 0

            sector_upgrade_progress[category] = up_progress
            sector_downgrade_progress[category] = down_progress
            result = self._replace_prefix(result, f"{category}_", f"{category}_{self.ECONOMY_LEVELS[idx]}")

        return result

    def _step_security(self, tags: list, neighbor_tags: list, state, sector_id: str) -> list:
        result = list(tags)
        security = self._security_tag(result)
        idx = self.SECURITY_LEVELS.index(security)
        role_counts = self._role_counts_for_sector(state, sector_id)

        delta = 0

        # Homeostatic pressure (complacency / desperation)
        if security == "SECURE":
            delta -= 1
        elif security == "LAWLESS":
            delta += 1

        # World age influence
        if state.world_age == "DISRUPTION":
            delta -= 1
        elif state.world_age in ("PROSPERITY", "RECOVERY"):
            delta += 1

        # Agent presence
        if role_counts.get("military", 0) > 0:
            delta += 1
        if role_counts.get("pirate", 0) > 0:
            delta -= 1
        if "HOSTILE_INFESTED" in result:
            delta -= 1

        # Regional influence
        neighbor_idx = [self.SECURITY_LEVELS.index(self._security_tag(n)) for n in neighbor_tags if n]
        if neighbor_idx:
            avg = sum(neighbor_idx) / len(neighbor_idx)
            if avg > idx:
                delta += 1
            elif avg < idx:
                delta -= 1

        # Progress-counter gating (mirror of colony upgrade/downgrade pattern)
        up_progress = state.security_upgrade_progress.get(sector_id, 0)
        down_progress = state.security_downgrade_progress.get(sector_id, 0)
        threshold = state.security_change_threshold.get(
            sector_id, constants.SECURITY_CHANGE_TICKS_MIN
        )

        if delta >= 1:
            up_progress += 1
            down_progress = 0
        elif delta <= -1:
            down_progress += 1
            up_progress = 0
        else:
            up_progress = 0
            down_progress = 0

        if up_progress >= threshold and idx < 2:
            idx = min(2, idx + 1)
            up_progress = 0
        elif down_progress >= threshold and idx > 0:
            idx = max(0, idx - 1)
            down_progress = 0

        state.security_upgrade_progress[sector_id] = up_progress
        state.security_downgrade_progress[sector_id] = down_progress

        result = self._replace_one_of(result, {"SECURE", "CONTESTED", "LAWLESS"}, self.SECURITY_LEVELS[idx])
        return result

    def _step_environment(self, tags: list, state, sector_id: str) -> list:
        result = list(tags)
        idx = self.ENV_LEVELS.index(self._environment_tag(result))

        if state.world_age == "DISRUPTION":
            if idx == self.ENV_LEVELS.index("MILD"):
                idx = self.ENV_LEVELS.index("HARSH")
            elif idx == self.ENV_LEVELS.index("HARSH"):
                role_counts = self._role_counts_for_sector(state, sector_id)
                if role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result:
                    idx = self.ENV_LEVELS.index("EXTREME")
        elif state.world_age == "RECOVERY":
            idx = min(2, idx + 1)

        if self._sector_recently_disabled(state, sector_id):
            idx = 0

        result = self._replace_one_of(result, {"MILD", "HARSH", "EXTREME"}, self.ENV_LEVELS[idx])
        return result

    def _step_hostile_presence(self, tags: list, state, sector_id: str) -> list:
        result = [tag for tag in tags if tag not in {"HOSTILE_INFESTED", "HOSTILE_THREATENED"}]
        role_counts = self._role_counts_for_sector(state, sector_id)
        security = self._security_tag(tags)
        had_infested = "HOSTILE_INFESTED" in tags
        progress = state.hostile_infestation_progress.get(sector_id, 0)
        infested_now = had_infested

        if security == "LAWLESS" and role_counts.get("military", 0) == 0:
            if not had_infested:
                build_progress = max(0, progress) + 1
                progress = build_progress
                if build_progress >= constants.HOSTILE_INFESTATION_TICKS_REQUIRED:
                    infested_now = True
                    progress = 0
            else:
                progress = 0
        elif had_infested:
            clear_progress = max(0, -progress) + 1
            progress = -clear_progress
            if clear_progress >= 2:
                infested_now = False
                progress = 0
        else:
            progress = 0

        state.hostile_infestation_progress[sector_id] = progress

        if infested_now:
            result.append("HOSTILE_INFESTED")
        elif security == "CONTESTED":
            result.append("HOSTILE_THREATENED")
        return result

    def _step_colony_level(self, tags: list, state, sector_id: str) -> list:
        level = state.colony_levels.get(sector_id, "frontier")
        levels = constants.COLONY_LEVELS
        up_progress = state.colony_upgrade_progress.get(sector_id, 0)
        down_progress = state.colony_downgrade_progress.get(sector_id, 0)

        economy_ok = all(
            req in tags or req.replace("_ADEQUATE", "_RICH") in tags
            for req in constants.COLONY_UPGRADE_REQUIRED_ECONOMY
        )
        security_ok = constants.COLONY_UPGRADE_REQUIRED_SECURITY in tags
        degrade = constants.COLONY_DOWNGRADE_SECURITY_TRIGGER in tags or any(req in tags for req in constants.COLONY_DOWNGRADE_ECONOMY_TRIGGER)

        if economy_ok and security_ok:
            up_progress += 1
            down_progress = 0
        elif degrade:
            down_progress += 1
            up_progress = 0
        else:
            up_progress = 0
            down_progress = 0

        min_level = constants.COLONY_MINIMUM_LEVEL
        min_idx = levels.index(min_level) if min_level in levels else 0

        if up_progress >= constants.COLONY_UPGRADE_TICKS_REQUIRED and level in levels[:-1]:
            level = levels[levels.index(level) + 1]
            up_progress = 0
        elif down_progress >= constants.COLONY_DOWNGRADE_TICKS_REQUIRED and level in levels[1:]:
            new_idx = levels.index(level) - 1
            if new_idx >= min_idx:
                level = levels[new_idx]
            down_progress = 0

        state.colony_levels[sector_id] = level
        state.colony_upgrade_progress[sector_id] = up_progress
        state.colony_downgrade_progress[sector_id] = down_progress
        return tags

    def _loaded_trade_count_for_sector(self, state, sector_id: str) -> int:
        """Count any agent carrying cargo in this sector (not just traders/haulers)."""
        count = 0
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            if agent.get("cargo_tag") == "LOADED":
                count += 1
        return count

    def _role_counts_for_sector(self, state, sector_id: str) -> dict:
        counts = {}
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            role = agent.get("agent_role", "idle")
            counts[role] = counts.get(role, 0) + 1
        return counts

    def _active_agent_count_in_sector(self, state, sector_id: str) -> int:
        count = 0
        for agent_id, agent in state.agents.items():
            if agent_id == "player":
                continue
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") == sector_id:
                count += 1
        return count

    def _economy_level(self, tags: list, category: str) -> str:
        for level in self.ECONOMY_LEVELS:
            if f"{category}_{level}" in tags:
                return level
        return "ADEQUATE"

    def _security_tag(self, tags: list) -> str:
        for tag in self.SECURITY_LEVELS:
            if tag in tags:
                return tag
        return "CONTESTED"

    def _environment_tag(self, tags: list) -> str:
        for tag in self.ENV_LEVELS:
            if tag in tags:
                return tag
        return "MILD"

    def _replace_prefix(self, tags: list, prefix: str, replacement: str) -> list:
        base = [tag for tag in tags if not tag.startswith(prefix)]
        base.append(replacement)
        return base

    def _replace_one_of(self, tags: list, options: set, replacement: str) -> list:
        base = [tag for tag in tags if tag not in options]
        base.append(replacement)
        return base

    def _sector_recently_disabled(self, state, sector_id: str) -> bool:
        until = state.sector_disabled_until.get(sector_id, 0)
        return until > state.sim_tick_count

    def _unique(self, tags: list) -> list:
        seen = set()
        out = []
        for tag in tags:
            if tag not in seen:
                seen.add(tag)
                out.append(tag)
        return out

--- Start of ./python_sandbox/core/simulation/__init__.py ---

# core/simulation/ — mirrors src/core/simulation/ in Godot project.
# Contains: SimulationEngine, WorldLayer, GridLayer, AgentLayer,
#           BridgeSystems, ChronicleLayer, CARules.

--- Start of ./python_sandbox/core/simulation/simulation_engine.py ---

#
# PROJECT: GDTLancer
# MODULE: simulation_engine.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_11
# LOG_REF: 2026-02-21 (TASK_10)
#

"""Qualitative simulation tick orchestrator."""

from autoload.game_state import GameState
from autoload import constants
from core.simulation.agent_layer import AgentLayer
from core.simulation.bridge_systems import BridgeSystems
from core.simulation.chronicle_layer import ChronicleLayer
from core.simulation.grid_layer import GridLayer
from core.simulation.world_layer import WorldLayer


class SimulationEngine:
    def __init__(self):
        self.state = GameState()
        self.world_layer = WorldLayer()
        self.grid_layer = GridLayer()
        self.bridge_systems = BridgeSystems()
        self.agent_layer = AgentLayer()
        self.chronicle_layer = ChronicleLayer()

        self._initialized = False
        self._tick_config = {}
        self._build_tick_config()

    def initialize_simulation(self, seed_string: str) -> None:
        self.world_layer.initialize_world(self.state, seed_string)
        self.grid_layer.initialize_grid(self.state)
        self.agent_layer.initialize_agents(self.state)
        self.agent_layer.set_chronicle(self.chronicle_layer)

        self.state.world_age = constants.WORLD_AGE_CYCLE[0]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[self.state.world_age]
        self.state.world_age_cycle_count = 0
        self._apply_age_config()

        self._initialized = True

    def process_tick(self) -> None:
        if not self._initialized:
            raise RuntimeError("SimulationEngine is not initialized")

        self.state.sim_tick_count += 1
        self._advance_world_age()

        self.grid_layer.process_tick(self.state, self._tick_config)
        self.bridge_systems.process_tick(self.state, self._tick_config)
        self.agent_layer.process_tick(self.state, self._tick_config)
        self.chronicle_layer.process_tick(self.state)

    def advance_sub_ticks(self, cost: int) -> int:
        """Advance the simulation by *cost* sub-ticks.

        Sub-ticks accumulate in ``state.sub_tick_accumulator``.  Every time
        the accumulator reaches ``SUB_TICKS_PER_TICK`` a full simulation tick
        fires (economy, security, agents, chronicle, etc.).

        Args:
            cost: Number of sub-ticks to add (use the SUBTICK_COST_* constants).

        Returns:
            The number of full ticks that were processed (0, 1, or more).
        """
        if not self._initialized:
            raise RuntimeError("SimulationEngine is not initialized")

        self.state.sub_tick_accumulator += cost
        ticks_fired = 0
        threshold = constants.SUB_TICKS_PER_TICK
        while self.state.sub_tick_accumulator >= threshold:
            self.state.sub_tick_accumulator -= threshold
            self.process_tick()
            ticks_fired += 1
        return ticks_fired

    def _advance_world_age(self) -> None:
        self.state.world_age_timer -= 1
        if self.state.world_age_timer > 0:
            return

        cycle = constants.WORLD_AGE_CYCLE
        index = cycle.index(self.state.world_age)
        next_index = (index + 1) % len(cycle)

        if next_index == 0:
            self.state.world_age_cycle_count += 1

        self.state.world_age = cycle[next_index]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[self.state.world_age]
        self._apply_age_config()

        self.chronicle_layer.log_event(
            {
                "tick": self.state.sim_tick_count,
                "actor_id": "world",
                "action": "age_change",
                "sector_id": "",
                "metadata": {"new_age": self.state.world_age},
            }
        )

    def _apply_age_config(self) -> None:
        self._build_tick_config()
        self._tick_config.update(constants.WORLD_AGE_CONFIGS.get(self.state.world_age, {}))

    def _build_tick_config(self) -> None:
        self._tick_config = {
            "colony_upgrade_ticks_required": constants.COLONY_UPGRADE_TICKS_REQUIRED,
            "colony_downgrade_ticks_required": constants.COLONY_DOWNGRADE_TICKS_REQUIRED,
            "respawn_cooldown_ticks": constants.RESPAWN_COOLDOWN_TICKS,
            "catastrophe_chance_per_tick": constants.CATASTROPHE_CHANCE_PER_TICK,
            "catastrophe_disable_duration": constants.CATASTROPHE_DISABLE_DURATION,
            "mortal_global_cap": constants.MORTAL_GLOBAL_CAP,
            "mortal_spawn_required_security": list(constants.MORTAL_SPAWN_REQUIRED_SECURITY),
            "mortal_spawn_blocked_sector_tags": list(constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS),
        }

    def get_chronicle(self) -> ChronicleLayer:
        return self.chronicle_layer

    def is_initialized(self) -> bool:
        return self._initialized

    def set_config(self, key: str, value) -> None:
        self._tick_config[key] = value

    def get_config(self) -> dict:
        return dict(self._tick_config)

--- Start of ./python_sandbox/core/simulation/world_layer.py ---

#
# PROJECT: GDTLancer
# MODULE: world_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_7
# LOG_REF: 2026-02-21 (TASK_6)
#

"""World layer: initialize topology and initial sector tags from templates."""

from autoload.game_state import GameState
from database.registry.template_data import LOCATIONS


class WorldLayer:
    """Initializes static world topology and sector tag state."""

    def initialize_world(self, state: GameState, seed_string: str) -> None:
        state.world_seed = seed_string
        state.world_topology.clear()
        state.world_hazards.clear()
        state.sector_tags.clear()

        for location_id, location in LOCATIONS.items():
            state.world_topology[location_id] = {
                "connections": list(location.get("connections", [])),
                "station_ids": [location_id],
                "sector_type": location.get("sector_type", "frontier"),
            }
            state.world_hazards[location_id] = {
                "environment": self._derive_environment(location.get("initial_sector_tags", []))
            }
            state.sector_tags[location_id] = list(location.get("initial_sector_tags", []))

    def get_neighbors(self, state: GameState, sector_id: str) -> list:
        return list(state.world_topology.get(sector_id, {}).get("connections", []))

    def get_hazards(self, state: GameState, sector_id: str) -> dict:
        return dict(state.world_hazards.get(sector_id, {"environment": "MILD"}))

    def _derive_environment(self, sector_tags: list) -> str:
        if "EXTREME" in sector_tags:
            return "EXTREME"
        if "HARSH" in sector_tags:
            return "HARSH"
        return "MILD"

--- Start of ./python_sandbox/database/__init__.py ---

# database/ — mirrors database/ in Godot project.

--- Start of ./python_sandbox/database/registry/__init__.py ---

# database/registry/ — mirrors database/registry/ in Godot project.
# Contains hardcoded template dictionaries that mirror .tres files.

--- Start of ./python_sandbox/database/registry/template_data.py ---

#
# PROJECT: GDTLancer
# MODULE: template_data.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_6
# LOG_REF: 2026-02-21 (TASK_5)
#

"""Tag-based template registry for qualitative simulation mode."""

# -------------------------------------------------------------------------
# Locations
# -------------------------------------------------------------------------
# STARTING TOPOLOGY (5 sectors, 5 edges, avg degree = 2.0)
#
#   beta ---- alpha
#     \       /
#      delta ---- gamma ---- epsilon
#
# Core triangle: alpha(colony), beta(colony), delta(colony)
# Frontier tail:  delta -> gamma(frontier) -> epsilon(outpost)
# All connections are bidirectional.
# Degrees: alpha=2, beta=2, gamma=2, delta=3, epsilon=1
# -------------------------------------------------------------------------
LOCATIONS = {
    "station_alpha": {
        "location_name": "Station Alpha - Mining Hub",
        "location_type": "station",
        "connections": ["station_beta", "station_delta"],
        "sector_type": "colony",
        "available_services": ["trade", "contracts", "repair"],
        "controlling_faction_id": "faction_miners",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_RICH",
            "MANUFACTURED_ADEQUATE",
            "CURRENCY_ADEQUATE",
        ],
    },
    "station_beta": {
        "location_name": "Station Beta - Trade Post",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "colony",
        "available_services": ["trade", "contracts"],
        "controlling_faction_id": "faction_traders",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_POOR",
            "MANUFACTURED_RICH",
            "CURRENCY_RICH",
        ],
    },
    "station_gamma": {
        "location_name": "Freeport Gamma",
        "location_type": "station",
        "connections": ["station_delta", "station_epsilon"],
        "sector_type": "frontier",
        "available_services": ["trade", "contracts", "black_market"],
        "controlling_faction_id": "faction_independents",
        "initial_sector_tags": [
            "FRONTIER",
            "LAWLESS",
            "HARSH",
            "RAW_ADEQUATE",
            "MANUFACTURED_POOR",
            "CURRENCY_ADEQUATE",
            "HOSTILE_THREATENED",
        ],
    },
    "station_delta": {
        "location_name": "Outpost Delta - Military Garrison",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_alpha"],
        "sector_type": "colony",
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_military",
        "initial_sector_tags": [
            "STATION",
            "SECURE",
            "MILD",
            "RAW_ADEQUATE",
            "MANUFACTURED_RICH",
            "CURRENCY_ADEQUATE",
        ],
    },
    "station_epsilon": {
        "location_name": "Epsilon Refinery Complex",
        "location_type": "station",
        "connections": ["station_gamma"],
        "sector_type": "outpost",
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_miners",
        "initial_sector_tags": [
            "STATION",
            "CONTESTED",
            "HARSH",
            "RAW_RICH",
            "MANUFACTURED_ADEQUATE",
            "CURRENCY_ADEQUATE",
        ],
    },
}


# -------------------------------------------------------------------------
# Factions
# -------------------------------------------------------------------------
FACTIONS = {
    "faction_miners": {
        "display_name": "Miners Guild",
        "description": "A collective of independent miners and ore processors.",
        "default_standing": 0,
    },
    "faction_traders": {
        "display_name": "Trade Alliance",
        "description": "The dominant commercial entity in the sector.",
        "default_standing": 0,
    },
    "faction_independents": {
        "display_name": "Independent Captains",
        "description": "Unaffiliated pilots operating on their own terms.",
        "default_standing": 0,
    },
    "faction_military": {
        "display_name": "Military Corps",
        "description": "A disciplined military force maintaining order.",
        "default_standing": 0,
    },
    "faction_pirates": {
        "display_name": "Pirate Syndicate",
        "description": "Opportunistic raiders who thrive in chaos and lawless sectors.",
        "default_standing": -50,
    },
}


# -------------------------------------------------------------------------
# Characters
# -------------------------------------------------------------------------
CHARACTERS = {
    "character_default": {
        "character_name": "Unnamed",
        "faction_id": "faction_default",
        "personality_traits": {},
        "description": "",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_vera": {
        "character_name": "Vera",
        "faction_id": "faction_traders",
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.5},
        "description": "Merchant captain, cautious.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "WEALTHY",
    },
    "character_ada": {
        "character_name": "Ada",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.5, "aggression": 0.1},
        "description": "Salvager, resourceful.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_juno": {
        "character_name": "Juno",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.7},
        "description": "Young prospector, ambitious.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "BROKE",
    },
    "character_kai": {
        "character_name": "Kai",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8},
        "description": "Veteran miner, pragmatic.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_milo": {
        "character_name": "Milo",
        "faction_id": "faction_traders",
        "personality_traits": {"greed": 0.7, "aggression": 0.2},
        "description": "Cargo hauler, opportunistic.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_rex": {
        "character_name": "Rex",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.2},
        "description": "Freelancer pilot, risky.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "BROKE",
    },
    "character_siv": {
        "character_name": "Siv",
        "faction_id": "faction_military",
        "personality_traits": {"risk_tolerance": 0.4, "loyalty": 0.9, "greed": 0.6},
        "description": "Military supply officer, disciplined.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_zara": {
        "character_name": "Zara",
        "faction_id": "faction_miners",
        "personality_traits": {"risk_tolerance": 0.7, "greed": 0.4},
        "description": "Survey specialist, maps deposits.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_nyx": {
        "character_name": "Nyx",
        "faction_id": "faction_military",
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8, "aggression": 0.4},
        "description": "Patrol officer, keeps order.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_orin": {
        "character_name": "Orin",
        "faction_id": "faction_traders",
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.3, "loyalty": 0.6},
        "description": "Bulk cargo hauler, reliable.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_crow": {
        "character_name": "Crow",
        "faction_id": "faction_pirates",
        "personality_traits": {"risk_tolerance": 0.9, "greed": 0.8, "aggression": 0.7},
        "description": "Ruthless raider, exploits disruption.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_vex": {
        "character_name": "Vex",
        "faction_id": "faction_pirates",
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.9, "aggression": 0.5},
        "description": "Cunning smuggler turned pirate.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
    "character_nova": {
        "character_name": "Nova",
        "faction_id": "faction_independents",
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.3},
        "description": "Deep-space explorer, restless.",
        "initial_condition_tag": "HEALTHY",
        "initial_wealth_tag": "COMFORTABLE",
    },
}


# -------------------------------------------------------------------------
# Agents
# -------------------------------------------------------------------------
AGENTS = {
    "agent_player_default": {
        "agent_type": "player",
        "is_persistent": False,
        "home_location_id": "",
        "character_template_id": "",
        "agent_role": "idle",
        "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"],
    },
    "persistent_vera": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_beta", "character_template_id": "character_vera", "agent_role": "trader", "initial_tags": ["HEALTHY", "WEALTHY", "LOADED"]},
    "persistent_milo": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_beta", "character_template_id": "character_milo", "agent_role": "trader", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_juno": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_alpha", "character_template_id": "character_juno", "agent_role": "prospector", "initial_tags": ["HEALTHY", "BROKE", "EMPTY"]},
    "persistent_zara": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_epsilon", "character_template_id": "character_zara", "agent_role": "prospector", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_siv": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_delta", "character_template_id": "character_siv", "agent_role": "military", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_nyx": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_delta", "character_template_id": "character_nyx", "agent_role": "military", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_kai": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_alpha", "character_template_id": "character_kai", "agent_role": "hauler", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_orin": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_epsilon", "character_template_id": "character_orin", "agent_role": "hauler", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_ada": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_ada", "agent_role": "trader", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
    "persistent_rex": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_rex", "agent_role": "hauler", "initial_tags": ["HEALTHY", "BROKE", "EMPTY"]},
    "persistent_crow": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_crow", "agent_role": "pirate", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_vex": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_vex", "agent_role": "pirate", "initial_tags": ["HEALTHY", "COMFORTABLE", "LOADED"]},
    "persistent_nova": {"agent_type": "npc", "is_persistent": True, "home_location_id": "station_gamma", "character_template_id": "character_nova", "agent_role": "explorer", "initial_tags": ["HEALTHY", "COMFORTABLE", "EMPTY"]},
}

--- Start of ./python_sandbox/diagnostic.py ---

#!/usr/bin/env python3
"""Diagnostic probe: quantifies simulation behavior over a long run."""
import os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core.simulation.simulation_engine import SimulationEngine

engine = SimulationEngine()
engine.initialize_simulation("diagnostic-probe")

action_counts = collections.Counter()
sector_economy_history = {sid: [] for sid in engine.state.world_topology}
sector_security_history = {sid: [] for sid in engine.state.world_topology}
sector_env_history = {sid: [] for sid in engine.state.world_topology}
agent_condition_history = collections.Counter()
agent_wealth_history = collections.Counter()
agent_cargo_history = collections.Counter()
agent_sector_distribution = collections.Counter()
world_age_log = []
mortal_spawns = 0
mortal_deaths = 0
attacks = 0
trades = 0
prev_age = engine.state.world_age
phase_economy_samples = collections.defaultdict(lambda: collections.Counter())
phase_security_samples = collections.defaultdict(lambda: collections.Counter())

for tick in range(1, 1801):  # 2 full cycles
    engine.process_tick()
    
    # Track world age transitions
    if engine.state.world_age != prev_age:
        world_age_log.append((tick, prev_age, engine.state.world_age))
        prev_age = engine.state.world_age
    
    # Track actions from events
    for ev in engine.state.chronicle_events:
        if ev.get("tick") == tick:
            action_counts[ev["action"]] += 1
            if ev["action"] == "spawn":
                mortal_spawns += 1
            if ev["action"] == "attack":
                attacks += 1
            if ev["action"] == "agent_trade":
                trades += 1
    
    # Sector state every 10 ticks
    if tick % 10 == 0:
        for sid, tags in engine.state.sector_tags.items():
            econ = [t for t in tags if t.startswith(("RAW_", "MANUFACTURED_", "CURRENCY_"))]
            sec = [t for t in tags if t in {"SECURE", "CONTESTED", "LAWLESS"}]
            env = [t for t in tags if t in {"MILD", "HARSH", "EXTREME"}]
            sector_economy_history[sid].append(sorted(econ))
            sector_security_history[sid].append(sec)
            sector_env_history[sid].append(env)
            # track by phase
            phase = engine.state.world_age
            for tag in econ:
                phase_economy_samples[phase][tag] += 1
            for tag in sec:
                phase_security_samples[phase][tag] += 1
    
    # Agent state every 10 ticks
    if tick % 10 == 0:
        for aid, agent in engine.state.agents.items():
            if aid == "player": continue
            agent_condition_history[agent.get("condition_tag", "HEALTHY")] += 1
            agent_wealth_history[agent.get("wealth_tag", "COMFORTABLE")] += 1
            agent_cargo_history[agent.get("cargo_tag", "EMPTY")] += 1
            agent_sector_distribution[agent.get("current_sector_id", "")] += 1

mortal_deaths = len(engine.state.mortal_agent_deaths)

print("=" * 60)
print("DIAGNOSTIC REPORT (1800 ticks = 2 full world age cycles)")
print("=" * 60)

print("\n--- ACTION DISTRIBUTION ---")
for action, count in action_counts.most_common():
    print(f"  {action}: {count}")

print(f"\n--- KEY METRICS ---")
print(f"  Total attacks: {attacks}")
print(f"  Total trades: {trades}")
print(f"  Mortal spawns: {mortal_spawns}")
print(f"  Mortal deaths: {mortal_deaths}")
print(f"  Final agent count: {len(engine.state.agents)}")
print(f"  Final mortal counter: {engine.state.mortal_agent_counter}")

print("\n--- WORLD AGE TRANSITIONS ---")
for tick, old, new in world_age_log:
    print(f"  t{tick}: {old} -> {new}")

print("\n--- AGENT CONDITION DISTRIBUTION (sampled) ---")
total = sum(agent_condition_history.values())
for k, v in agent_condition_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT WEALTH DISTRIBUTION (sampled) ---")
total = sum(agent_wealth_history.values())
for k, v in agent_wealth_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT CARGO DISTRIBUTION (sampled) ---")
total = sum(agent_cargo_history.values())
for k, v in agent_cargo_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT SECTOR DISTRIBUTION (sampled) ---")
total = sum(agent_sector_distribution.values())
for k, v in agent_sector_distribution.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- SECTOR ECONOMY CONVERGENCE (last 5 samples) ---")
for sid, history in sector_economy_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- SECTOR SECURITY CONVERGENCE (last 5 samples) ---")
for sid, history in sector_security_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- SECTOR ENVIRONMENT CONVERGENCE (last 5 samples) ---")
for sid, history in sector_env_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- COLONY LEVELS ---")
for sid, level in sorted(engine.state.colony_levels.items()):
    print(f"  {sid}: {level}")

print("\n--- ECONOMY TAGS BY WORLD AGE PHASE ---")
for phase in ["PROSPERITY", "DISRUPTION", "RECOVERY"]:
    total = sum(phase_economy_samples[phase].values())
    if total:
        print(f"  {phase}:")
        for tag, count in phase_economy_samples[phase].most_common():
            print(f"    {tag}: {count} ({100*count/total:.1f}%)")

print("\n--- SECURITY TAGS BY WORLD AGE PHASE ---")
for phase in ["PROSPERITY", "DISRUPTION", "RECOVERY"]:
    total = sum(phase_security_samples[phase].values())
    if total:
        print(f"  {phase}:")
        for tag, count in phase_security_samples[phase].most_common():
            print(f"    {tag}: {count} ({100*count/total:.1f}%)")

--- Start of ./python_sandbox/__init__.py ---

# GDTLancer Python Simulation Sandbox

--- Start of ./python_sandbox/main.py ---

#!/usr/bin/env python3
#
# PROJECT: GDTLancer
# MODULE: main.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md PHASE 3 TASK_4
# LOG_REF: 2026-02-22 00:57:18
#

"""Qualitative simulation CLI with compact tag dashboard output."""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from core.simulation.simulation_engine import SimulationEngine


def _parse_args():
    parser = argparse.ArgumentParser(description="GDTLancer qualitative simulation runner")
    parser.add_argument("--ticks", type=int, default=50)
    parser.add_argument("--seed", type=str, default="qualitative-default")
    parser.add_argument("--head", type=int, default=5)
    parser.add_argument("--tail", type=int, default=5)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--viz", action="store_true", help="Show tick-by-tick visualization timeline")
    parser.add_argument("--viz-interval", type=int, default=10, help="Ticks between viz samples")
    parser.add_argument("--chronicle", action="store_true", help="Narrative chronicle report mode")
    parser.add_argument("--epoch-size", type=int, default=100, help="Ticks per chronicle epoch (default 100)")
    return parser.parse_args()


def _agent_name(state, agent_id: str) -> str:
    agent = state.agents.get(agent_id, {})
    character_id = agent.get("character_id", "")
    character = state.characters.get(character_id, {})
    return character.get("character_name", agent_id)


def _sector_table(state) -> list:
    rows = ["SECTORS:", "sector | colony | economy | security | environment | special"]
    for sector_id in sorted(state.world_topology.keys()):
        tags = state.sector_tags.get(sector_id, [])
        economy = [tag for tag in tags if tag.startswith(("RAW_", "MANUFACTURED_", "CURRENCY_"))]
        security = [tag for tag in tags if tag in {"SECURE", "CONTESTED", "LAWLESS"}]
        environment = [tag for tag in tags if tag in {"MILD", "HARSH", "EXTREME"}]
        special = [
            tag
            for tag in tags
            if tag in {"STATION", "FRONTIER", "HAS_SALVAGE", "DISABLED", "HOSTILE_INFESTED", "HOSTILE_THREATENED"}
        ]
        rows.append(
            f"{sector_id} | {state.colony_levels.get(sector_id, 'frontier')} | "
            f"{','.join(sorted(economy))} | {','.join(security) or '-'} | "
            f"{','.join(environment) or '-'} | {','.join(sorted(special)) or '-'}"
        )
    return rows


def _agent_table(state) -> list:
    rows = ["AGENTS:", "name | role | sector | condition | wealth | cargo | personality_tags | current_goal"]
    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        name = _agent_name(state, agent_id)
        character = state.characters.get(agent.get("character_id", ""), {})
        traits = sorted(character.get("personality_traits", {}).keys())
        rows.append(
            f"{name} | {agent.get('agent_role','idle')} | {agent.get('current_sector_id','')} | "
            f"{agent.get('condition_tag','HEALTHY')} | {agent.get('wealth_tag','COMFORTABLE')} | "
            f"{agent.get('cargo_tag','EMPTY')} | {','.join(traits) or '-'} | {agent.get('goal_archetype','idle')}"
        )
    return rows


def _chronicle_lines(state, max_items: int = 10) -> list:
    lines = ["CHRONICLE:"]
    rumors = state.chronicle_rumors[-max_items:]
    if not rumors:
        lines.append("-")
        return lines
    lines.extend(rumors)
    return lines


def _lifecycle_lines(state, max_items: int = 10) -> list:
    lines = ["LIFECYCLE:"]
    events = [
        e
        for e in state.chronicle_events
        if e.get("action") in {"spawn", "respawn", "catastrophe"}
    ]
    if not events:
        lines.append("-")
        return lines
    for event in events[-max_items:]:
        lines.append(f"t{event.get('tick', 0)} {event.get('action')} {event.get('actor_id', '')} {event.get('sector_id', '')}")
    return lines


def _transient_snapshot(state) -> dict:
    sector_snapshot = {}
    for sector_id in sorted(state.sector_tags.keys()):
        sector_snapshot[sector_id] = sorted(state.sector_tags.get(sector_id, []))

    agent_snapshot = {}
    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        agent_snapshot[agent_id] = {
            "sector": agent.get("current_sector_id", ""),
            "condition": agent.get("condition_tag", "HEALTHY"),
            "wealth": agent.get("wealth_tag", "COMFORTABLE"),
            "cargo": agent.get("cargo_tag", "EMPTY"),
        }

    return {"sectors": sector_snapshot, "agents": agent_snapshot}


def _transient_lines(history: list, head: int, tail: int) -> list:
    lines = ["TRANSIENT:"]
    if not history:
        lines.append("-")
        return lines

    selected = history[:head] + ([{"sep": True}] if len(history) > head + tail else []) + history[-tail:]
    for item in selected:
        if item.get("sep"):
            lines.append("...")
            continue
        tick = item["tick"]
        lines.append(f"t{tick}")
        lines.append(f"  sectors={item['snapshot']['sectors']}")
        lines.append(f"  agents={item['snapshot']['agents']}")
    return lines


def _build_report(engine: SimulationEngine, transient_history: list, args) -> str:
    state = engine.state
    lines = []

    lines.append("WORLD:")
    lines.append(
        f"age={state.world_age} world_tags={','.join(state.world_tags)} "
        f"cycle_count={state.world_age_cycle_count} timer={state.world_age_timer}"
    )
    lines.append("")
    lines.extend(_sector_table(state))
    lines.append("")
    lines.extend(_agent_table(state))
    lines.append("")
    lines.extend(_chronicle_lines(state))
    lines.append("")
    lines.extend(_lifecycle_lines(state))
    lines.append("")
    lines.extend(_transient_lines(transient_history, args.head, args.tail))
    return "\n".join(lines)


# =========================================================================
# Chronicle report mode
# =========================================================================

_LOCATION_NAMES = {
    k: v.get("location_name", k)
    for k, v in __import__("database.registry.template_data", fromlist=["LOCATIONS"]).LOCATIONS.items()
}


def _loc(sector_id: str, state=None) -> str:
    """Resolve sector_id to short human name."""
    name = _LOCATION_NAMES.get(sector_id)
    if name:
        return name
    if state and hasattr(state, "sector_names"):
        name = state.sector_names.get(sector_id)
        if name:
            return name
    return sector_id or "deep space"


def _agent_display(state, agent_id: str) -> str:
    agent = state.agents.get(agent_id, {})
    cid = agent.get("character_id", "")
    char = state.characters.get(cid, {})
    name = char.get("character_name", agent_id)
    role = agent.get("agent_role", "")
    return f"{name} ({role})" if role else name


def _economy_label(tags: list) -> str:
    for level in ("RICH", "ADEQUATE", "POOR"):
        if any(t.endswith(f"_{level}") for t in tags):
            return level.lower()
    return "adequate"


def _security_label(tags: list) -> str:
    for t in ("SECURE", "CONTESTED", "LAWLESS"):
        if t in tags:
            return t.lower()
    return "contested"


def _environment_label(tags: list) -> str:
    for t in ("MILD", "HARSH", "EXTREME"):
        if t in tags:
            return t.lower()
    return "mild"


def _collect_epoch_events(all_events: list, start: int, end: int) -> list:
    return [e for e in all_events if start < e.get("tick", 0) <= end]


def _chronicle_epoch_narrative(epoch_events: list, state, epoch_start: int,
                               epoch_end: int, prev_sector_snap: dict) -> tuple:
    """Generate narrative lines for one epoch. Returns (lines, sector_snapshot)."""
    lines = []
    counts = {}
    attacker_counts = {}
    attack_sectors = {}
    trade_sectors = {}
    flee_count = 0
    spawn_names = []
    death_ids = set()
    catastrophe_sectors = []
    age_changes = []
    colony_changes = []
    cargo_loads = 0
    harvest_count = 0
    explore_count = 0
    discovered_sectors = []

    for e in epoch_events:
        action = e.get("action", "")
        counts[action] = counts.get(action, 0) + 1
        actor = e.get("actor_id", "")
        sector = e.get("sector_id", "")

        if action == "attack":
            attacker_counts[actor] = attacker_counts.get(actor, 0) + 1
            attack_sectors[sector] = attack_sectors.get(sector, 0) + 1
        elif action == "agent_trade":
            trade_sectors[sector] = trade_sectors.get(sector, 0) + 1
        elif action == "flee":
            flee_count += 1
        elif action == "spawn":
            spawn_names.append((actor, sector))
        elif action == "catastrophe":
            catastrophe_sectors.append(sector)
        elif action == "age_change":
            new_age = e.get("metadata", {}).get("new_age", "")
            age_changes.append(new_age)
        elif action == "load_cargo":
            cargo_loads += 1
        elif action == "harvest":
            harvest_count += 1
        elif action == "exploration":
            explore_count += 1
        elif action == "sector_discovered":
            meta = e.get("metadata", {})
            discovered_sectors.append({
                "actor": actor,
                "name": meta.get("name", "unknown"),
                "new_sector": meta.get("new_sector", ""),
                "from": sector,
                "connections": meta.get("connections", []),
            })

    # Track destroyed agents from respawn events (implies prior death)
    respawn_count = counts.get("respawn", 0)
    perma_deaths = counts.get("perma_death", 0)
    survived_count = counts.get("survived", 0)

    # ---- Build narrative paragraphs ----

    # Sector state transitions  
    sector_snap = {}
    for sid in sorted(state.sector_tags.keys()):
        tags = state.sector_tags.get(sid, [])
        sector_snap[sid] = {
            "economy": _economy_label(tags),
            "security": _security_label(tags),
            "environment": _environment_label(tags),
            "colony": state.colony_levels.get(sid, "frontier"),
            "infested": "HOSTILE_INFESTED" in tags,
            "threatened": "HOSTILE_THREATENED" in tags,
        }

    # Detect sector changes
    changed_sectors = []
    for sid in sorted(sector_snap.keys()):
        cur = sector_snap[sid]
        prev = prev_sector_snap.get(sid, {})
        changes = []
        if prev.get("economy") and prev["economy"] != cur["economy"]:
            changes.append(f"economy shifted from {prev['economy']} to {cur['economy']}")
        if prev.get("security") and prev["security"] != cur["security"]:
            changes.append(f"security changed from {prev['security']} to {cur['security']}")
        if prev.get("environment") and prev["environment"] != cur["environment"]:
            changes.append(f"environment went from {prev['environment']} to {cur['environment']}")
        if prev.get("colony") and prev["colony"] != cur["colony"]:
            changes.append(f"grew from {prev['colony']} to {cur['colony']}" if
                          ["frontier", "outpost", "colony", "hub"].index(cur["colony"]) >
                          ["frontier", "outpost", "colony", "hub"].index(prev["colony"])
                          else f"declined from {prev['colony']} to {cur['colony']}")
        if not prev.get("infested") and cur["infested"]:
            changes.append("became infested with hostiles")
        elif prev.get("infested") and not cur["infested"]:
            changes.append("was cleared of hostile infestation")
        if changes:
            changed_sectors.append((_loc(sid, state), changes))

    # World age changes — major headline
    for new_age in age_changes:
        age_flavor = {
            "PROSPERITY": "A new age of Prosperity dawned across the sector. Trade routes reopened and stations bustled with commerce.",
            "DISRUPTION": "The age of Disruption began. Instability spread as pirate activity surged and supply lines faltered.",
            "RECOVERY": "Recovery took hold. Communities began rebuilding and order slowly returned to the trade lanes.",
        }
        lines.append(f"  >>> {age_flavor.get(new_age, f'The world entered {new_age}.')}")
        lines.append("")

    # Catastrophes — rare, always reported (deduplicate same sector)
    unique_catastrophes = list(dict.fromkeys(catastrophe_sectors))
    for csec in unique_catastrophes:
        lines.append(f"  *** CATASTROPHE struck {_loc(csec, state)}! The station was disabled and operations ceased. ***")
    if unique_catastrophes:
        lines.append("")

    # Sector state overview
    if changed_sectors:
        for loc_name, changes in changed_sectors:
            lines.append(f"  {loc_name}: {'; '.join(changes)}.")
        lines.append("")

    # Combat summary
    total_attacks = counts.get("attack", 0)
    if total_attacks > 0:
        # Most violent sector
        hotspot = max(attack_sectors, key=attack_sectors.get) if attack_sectors else ""
        hotspot_n = attack_sectors.get(hotspot, 0)
        # Most aggressive agent
        top_attacker = max(attacker_counts, key=attacker_counts.get) if attacker_counts else ""
        top_n = attacker_counts.get(top_attacker, 0)

        combat_line = f"  Combat: {total_attacks} engagements"
        if hotspot:
            combat_line += f", fiercest around {_loc(hotspot, state)} ({hotspot_n})"
        if top_attacker and top_n >= 3:
            combat_line += f". {_agent_display(state, top_attacker)} was most aggressive ({top_n} attacks)"
        combat_line += "."
        lines.append(combat_line)

    # Trade & economy
    total_trades = counts.get("agent_trade", 0)
    if total_trades > 0 or cargo_loads > 0:
        econ_parts = []
        if total_trades:
            top_trade_loc = max(trade_sectors, key=trade_sectors.get) if trade_sectors else ""
            trade_str = f"{total_trades} trades"
            if top_trade_loc:
                trade_str += f" (busiest: {_loc(top_trade_loc, state)})"
            econ_parts.append(trade_str)
        if cargo_loads:
            econ_parts.append(f"{cargo_loads} cargo runs loaded")
        if harvest_count:
            econ_parts.append(f"{harvest_count} salvage operations")
        lines.append(f"  Commerce: {', '.join(econ_parts)}.")

    # Flight & danger
    if flee_count >= 3:
        lines.append(f"  Danger: {flee_count} pilots fled dangerous encounters.")

    # Respawns & losses
    loss_parts = []
    if respawn_count > 0:
        loss_parts.append(f"{respawn_count} pilots respawned after prior destruction")
    if survived_count > 0:
        loss_parts.append(f"{survived_count} mortals narrowly survived destruction")
    if perma_deaths > 0:
        loss_parts.append(f"{perma_deaths} were lost permanently")
    if loss_parts:
        lines.append(f"  Losses & returns: {'; '.join(loss_parts)}.")

    # New arrivals — group by sector to avoid spam
    if spawn_names:
        seen_spawns = set()
        unique_spawns = []
        for aid, sec in spawn_names:
            key = (aid, sec)
            if key not in seen_spawns:
                seen_spawns.add(key)
                unique_spawns.append((aid, sec))
        # Group by sector
        sector_spawns: dict = {}
        for aid, sec in unique_spawns:
            sector_spawns.setdefault(sec, []).append(aid)
        for sec, aids in sector_spawns.items():
            names = [_agent_display(state, a) for a in aids]
            if len(names) <= 3:
                lines.append(f"  New arrivals at {_loc(sec, state)}: {', '.join(names)}.")
            else:
                lines.append(f"  {len(names)} new pilots appeared at {_loc(sec, state)}.")

    # Exploration
    if explore_count:
        lines.append(f"  Exploration: {explore_count} survey expeditions launched.")

    # Sector discoveries
    for disc in discovered_sectors:
        conn_names = [_loc(c, state) for c in disc["connections"]]
        lines.append(f"  ** NEW SECTOR DISCOVERED: {disc['name']} (linked to {', '.join(conn_names)}) by {_agent_display(state, disc['actor'])} **")

    # If absolutely nothing interesting happened
    if not lines and total_attacks == 0 and total_trades == 0:
        lines.append("  A quiet period. Routine patrols and cargo runs continued without incident.")

    return lines, sector_snap


def _chronicle_summary(all_events: list, total_ticks: int, state) -> list:
    """Final summary paragraph after all epochs."""
    lines = []
    action_totals = {}
    for e in all_events:
        a = e.get("action", "")
        action_totals[a] = action_totals.get(a, 0) + 1

    total_attacks = action_totals.get("attack", 0)
    total_trades = action_totals.get("agent_trade", 0)
    total_spawns = action_totals.get("spawn", 0)
    total_catastrophes = action_totals.get("catastrophe", 0)
    total_respawns = action_totals.get("respawn", 0)
    total_perma_deaths = action_totals.get("perma_death", 0)
    total_survived = action_totals.get("survived", 0)
    age_changes = action_totals.get("age_change", 0)

    lines.append("=" * 64)
    lines.append("OVERALL SUMMARY")
    lines.append("=" * 64)
    lines.append(f"  Simulation ran for {total_ticks} ticks ({age_changes} world-age transitions).")
    lines.append(f"  Total engagements: {total_attacks}  |  Total trades: {total_trades}")
    lines.append(f"  Newcomers arrived: {total_spawns}  |  Pilots respawned: {total_respawns}")
    if total_perma_deaths:
        lines.append(f"  Permanently lost: {total_perma_deaths}  |  Narrowly survived: {total_survived}")
    if total_catastrophes:
        lines.append(f"  Catastrophes endured: {total_catastrophes}")
    total_discoveries = action_totals.get("sector_discovered", 0)
    if total_discoveries:
        lines.append(f"  New sectors discovered: {total_discoveries}  |  Total sectors: {len(state.sector_tags)}")

    # Final world state
    lines.append("")
    lines.append("  Final state of the sector:")
    for sid in sorted(state.sector_tags.keys()):
        tags = state.sector_tags.get(sid, [])
        econ = _economy_label(tags)
        sec = _security_label(tags)
        env = _environment_label(tags)
        col = state.colony_levels.get(sid, "frontier")
        lines.append(f"    {_loc(sid, state)}: {econ} economy, {sec}, {env} environment [{col}]")

    # Sector topology map
    lines.append("")
    lines.append("  Sector connections:")
    for sid in sorted(state.sector_tags.keys()):
        conns = state.world_topology.get(sid, {}).get("connections", [])
        conn_names = [_loc(c, state) for c in conns]
        lines.append(f"    {_loc(sid, state)} <-> {', '.join(conn_names) if conn_names else '(isolated)'}")

    degree_map = {
        sid: len(state.world_topology.get(sid, {}).get("connections", []))
        for sid in state.sector_tags.keys()
    }
    degree_values = list(degree_map.values())
    max_degree = max(degree_values) if degree_values else 0
    avg_degree = (sum(degree_values) / float(len(degree_values))) if degree_values else 0.0
    bottleneck_count = sum(1 for degree in degree_values if degree <= 2)
    d1 = sum(1 for degree in degree_values if degree == 1)
    d2 = sum(1 for degree in degree_values if degree == 2)
    d3 = sum(1 for degree in degree_values if degree == 3)
    d4 = sum(1 for degree in degree_values if degree == 4)
    lines.append(
        f"  Topology: max_degree={max_degree} avg={avg_degree:.1f} bottlenecks={bottleneck_count} "
        f"distribution=[d1:{d1}, d2:{d2}, d3:{d3}, d4:{d4}]"
    )

    # Final agent roster
    lines.append("")
    lines.append("  Active pilots:")
    for aid in sorted(state.agents.keys()):
        if aid == "player":
            continue
        agent = state.agents[aid]
        if agent.get("is_disabled"):
            continue
        cond = agent.get("condition_tag", "HEALTHY").lower()
        wealth = agent.get("wealth_tag", "COMFORTABLE").lower()
        sector = _loc(agent.get("current_sector_id", ""), state)
        lines.append(f"    {_agent_display(state, aid)}: {cond}, {wealth}, at {sector}")

    return lines


def _run_chronicle(engine, args):
    """Run simulation and produce a narrative chronicle report."""
    epoch_size = max(1, args.epoch_size)
    total_ticks = max(0, args.ticks)
    all_events = []
    epoch_start = 0
    epoch_num = 0
    prev_sector_snap = {}

    # Take initial sector snapshot
    for sid in sorted(engine.state.sector_tags.keys()):
        tags = engine.state.sector_tags.get(sid, [])
        prev_sector_snap[sid] = {
            "economy": _economy_label(tags),
            "security": _security_label(tags),
            "environment": _environment_label(tags),
            "colony": engine.state.colony_levels.get(sid, "frontier"),
            "infested": "HOSTILE_INFESTED" in tags,
            "threatened": "HOSTILE_THREATENED" in tags,
        }

    print("=" * 64)
    print(f"CHRONICLE OF THE SECTOR  (seed: {args.seed})")
    print("=" * 64)
    print()

    seen_event_ids = set()
    for tick_num in range(total_ticks):
        engine.process_tick()
        # Collect only new, unseen events (dedup by object identity)
        for e in engine.state.chronicle_events:
            eid = id(e)
            if eid not in seen_event_ids:
                seen_event_ids.add(eid)
                all_events.append(e)

        # End of epoch?
        current_tick = engine.state.sim_tick_count
        if current_tick % epoch_size == 0 or tick_num == total_ticks - 1:
            epoch_end = current_tick
            epoch_num += 1
            epoch_events = _collect_epoch_events(all_events, epoch_start, epoch_end)

            age = engine.state.world_age
            header = f"--- Epoch {epoch_num}: ticks {epoch_start + 1}–{epoch_end} [{age}] ---"
            print(header)

            narrative, prev_sector_snap = _chronicle_epoch_narrative(
                epoch_events, engine.state, epoch_start, epoch_end, prev_sector_snap
            )
            if narrative:
                print("\n".join(narrative))
            print()

            epoch_start = epoch_end

    # Final summary
    summary = _chronicle_summary(all_events, total_ticks, engine.state)
    print("\n".join(summary))


# =========================================================================
# Visualization mode
# =========================================================================

# ANSI color codes
_C_RESET = "\033[0m"
_C_BOLD = "\033[1m"
_C_DIM = "\033[2m"
_C_RED = "\033[31m"
_C_GREEN = "\033[32m"
_C_YELLOW = "\033[33m"
_C_BLUE = "\033[34m"
_C_MAGENTA = "\033[35m"
_C_CYAN = "\033[36m"
_C_WHITE = "\033[37m"
_C_BG_RED = "\033[41m"
_C_BG_GREEN = "\033[42m"
_C_BG_YELLOW = "\033[43m"

_AGE_COLORS = {
    "PROSPERITY": _C_GREEN,
    "DISRUPTION": _C_RED,
    "RECOVERY": _C_YELLOW,
}

_ECON_GLYPHS = {"RICH": f"{_C_GREEN}\u2588{_C_RESET}", "ADEQUATE": f"{_C_YELLOW}\u2592{_C_RESET}", "POOR": f"{_C_RED}\u2591{_C_RESET}"}
_SEC_GLYPHS = {"SECURE": f"{_C_GREEN}\u25cf{_C_RESET}", "CONTESTED": f"{_C_YELLOW}\u25d0{_C_RESET}", "LAWLESS": f"{_C_RED}\u25cb{_C_RESET}"}
_ENV_GLYPHS = {"MILD": f"{_C_CYAN}~{_C_RESET}", "HARSH": f"{_C_YELLOW}#{_C_RESET}", "EXTREME": f"{_C_RED}!{_C_RESET}"}
_COND_GLYPHS = {"HEALTHY": f"{_C_GREEN}\u2665{_C_RESET}", "DAMAGED": f"{_C_YELLOW}\u2666{_C_RESET}", "DESTROYED": f"{_C_RED}\u2620{_C_RESET}"}
_WEALTH_GLYPHS = {"WEALTHY": f"{_C_GREEN}${_C_RESET}", "COMFORTABLE": f"{_C_YELLOW}c{_C_RESET}", "BROKE": f"{_C_RED}_{_C_RESET}"}


def _viz_economy_level(tags: list, category: str) -> str:
    for level in ("RICH", "ADEQUATE", "POOR"):
        if f"{category}_{level}" in tags:
            return level
    return "ADEQUATE"


def _viz_security(tags: list) -> str:
    for tag in ("SECURE", "CONTESTED", "LAWLESS"):
        if tag in tags:
            return tag
    return "CONTESTED"


def _viz_environment(tags: list) -> str:
    for tag in ("MILD", "HARSH", "EXTREME"):
        if tag in tags:
            return tag
    return "MILD"


# -- ANSI-aware string helpers --
_ANSI_RE = re.compile(r'\033\[[0-9;]*m')


def _visible_len(s: str) -> int:
    """Length of string excluding ANSI escape sequences."""
    return len(_ANSI_RE.sub('', s))


def _pad_right(s: str, width: int) -> str:
    """Pad *s* with spaces so its visible width reaches *width*."""
    return s + ' ' * max(0, width - _visible_len(s))


# -- 2-D grid layout --
# Each row is a list of (sector_id, short_label) tuples.
_GRID_ROWS = [
    [("station_epsilon", "EPS"), ("station_beta", "BET")],
    [("station_alpha", "ALP"), ("station_delta", "DEL")],
    [("station_gamma", "GAM")],
]
_CELL_INNER = 26          # visible-char width inside the box border
_CELL_OUTER = _CELL_INNER + 2   # including │ on each side
_COL_GAP = 1                     # space between columns


def _viz_agent_glyph(agent: dict) -> str:
    cond = _COND_GLYPHS.get(agent.get("condition_tag", "HEALTHY"), "?")
    wealth = _WEALTH_GLYPHS.get(agent.get("wealth_tag", "COMFORTABLE"), "?")
    cargo = f"{_C_BLUE}L{_C_RESET}" if agent.get("cargo_tag") == "LOADED" else f"{_C_DIM}.{_C_RESET}"
    return f"{cond}{wealth}{cargo}"


def _viz_specials(tags: list) -> str:
    """Return coloured special-tag string."""
    s = ""
    if "HOSTILE_INFESTED" in tags:
        s += f" {_C_RED}!H{_C_RESET}"
    elif "HOSTILE_THREATENED" in tags:
        s += f" {_C_YELLOW}?H{_C_RESET}"
    if "HAS_SALVAGE" in tags:
        s += f" {_C_MAGENTA}S{_C_RESET}"
    if "DISABLED" in tags:
        s += f" {_C_RED}X{_C_RESET}"
    return s


def _viz_cell_lines(sector_id: str, label: str, state) -> list:
    """Return 4 fixed-width lines: top border, tag row, agent row, bottom border."""
    w = _CELL_INNER
    tags = state.sector_tags.get(sector_id, [])

    # Economy / security / environment glyphs
    raw = _ECON_GLYPHS[_viz_economy_level(tags, "RAW")]
    mfg = _ECON_GLYPHS[_viz_economy_level(tags, "MANUFACTURED")]
    cur = _ECON_GLYPHS[_viz_economy_level(tags, "CURRENCY")]
    sec = _SEC_GLYPHS[_viz_security(tags)]
    env = _ENV_GLYPHS[_viz_environment(tags)]
    specials = _viz_specials(tags)
    colony = state.colony_levels.get(sector_id, "fro")[:3]

    tag_line = f" {_C_BOLD}{label}{_C_RESET} {raw}{mfg}{cur} {sec}{env}{specials} {_C_DIM}{colony}{_C_RESET}"

    # Agents in this sector
    agents_here = [
        a for aid, a in state.agents.items()
        if aid != "player" and not a.get("is_disabled")
        and a.get("current_sector_id") == sector_id
    ]
    if agents_here:
        glyphs = ""
        for a in agents_here[:6]:
            glyphs += _viz_agent_glyph(a)
        leftover = len(agents_here) - 6
        if leftover > 0:
            glyphs += f" {_C_DIM}+{leftover}{_C_RESET}"
        agent_line = f" {glyphs}"
    else:
        agent_line = f" {_C_DIM}··{_C_RESET}"

    hbar = "\u2500" * w
    top = f"\u250c{hbar}\u2510"
    mid1 = f"\u2502{_pad_right(tag_line, w)}\u2502"
    mid2 = f"\u2502{_pad_right(agent_line, w)}\u2502"
    bot = f"\u2514{hbar}\u2518"
    return [top, mid1, mid2, bot]


def _viz_empty_cell() -> list:
    """Return 4 blank lines the same visible width as a real cell."""
    blank = ' ' * _CELL_OUTER
    return [blank, blank, blank, blank]


def _viz_event_summary(events: list) -> str:
    """Collapse event list into a compact coloured string."""
    counts: dict = {}
    last_age = ""
    for e in events:
        action = e.get("action", "")
        if action in ("attack", "catastrophe", "spawn", "respawn", "perma_death", "survived"):
            counts[action] = counts.get(action, 0) + 1
        elif action == "age_change":
            last_age = e.get("metadata", {}).get("new_age", "")
    parts = []
    if "attack" in counts:
        parts.append(f"{_C_RED}\u2694{counts['attack']}{_C_RESET}")
    if "catastrophe" in counts:
        parts.append(f"{_C_BG_RED}\u26a1{counts['catastrophe']}{_C_RESET}")
    if "spawn" in counts:
        parts.append(f"{_C_CYAN}+{counts['spawn']}{_C_RESET}")
    if "respawn" in counts:
        parts.append(f"{_C_GREEN}\u21ba{counts['respawn']}{_C_RESET}")
    if "perma_death" in counts:
        parts.append(f"{_C_RED}\u2620{counts['perma_death']}{_C_RESET}")
    if "survived" in counts:
        parts.append(f"{_C_YELLOW}\u2764{counts['survived']}{_C_RESET}")
    if last_age:
        parts.append(f"{_C_BOLD}\u2192{last_age}{_C_RESET}")
    return " ".join(parts)


def _viz_render_frame(tick: int, state, prev_events: list) -> str:
    """Render one 2-D grid-map frame."""
    lines: list = []
    age_color = _AGE_COLORS.get(state.world_age, _C_WHITE)
    evt = _viz_event_summary(prev_events)
    dbar_s = "\u2550" * 3
    dbar_l = "\u2550" * 28
    header = (
        f"{_C_DIM}{dbar_s}{_C_RESET} "
        f"t{tick:<5} {age_color}{_C_BOLD}{state.world_age}{_C_RESET} "
        f"{_C_DIM}{dbar_l}{_C_RESET}"
    )
    if evt:
        header += f"  {evt}"
    lines.append(header)

    max_cols = max(len(row) for row in _GRID_ROWS)
    for row_def in _GRID_ROWS:
        cells = []
        for sector_id, label in row_def:
            cells.append(_viz_cell_lines(sector_id, label, state))
        while len(cells) < max_cols:
            cells.append(_viz_empty_cell())
        # Print 4 sub-lines side-by-side
        gap = ' ' * _COL_GAP
        for i in range(4):
            lines.append(gap.join(cells[col][i] for col in range(max_cols)))

    return "\n".join(lines)


def _viz_legend() -> str:
    lines = [
        f"{_C_BOLD}=== SIMULATION MAP ==={_C_RESET}",
        "",
        f"  Economy:  {_ECON_GLYPHS['RICH']}RICH  {_ECON_GLYPHS['ADEQUATE']}ADEQUATE  {_ECON_GLYPHS['POOR']}POOR  (R M C)",
        f"  Security: {_SEC_GLYPHS['SECURE']}SECURE  {_SEC_GLYPHS['CONTESTED']}CONTESTED  {_SEC_GLYPHS['LAWLESS']}LAWLESS",
        f"  Environ:  {_ENV_GLYPHS['MILD']}MILD  {_ENV_GLYPHS['HARSH']}HARSH  {_ENV_GLYPHS['EXTREME']}EXTREME",
        f"  Agents:   {_COND_GLYPHS['HEALTHY']}healthy {_COND_GLYPHS['DAMAGED']}damaged {_COND_GLYPHS['DESTROYED']}destroyed"
        f"  {_WEALTH_GLYPHS['WEALTHY']}wealthy {_WEALTH_GLYPHS['COMFORTABLE']}ok {_WEALTH_GLYPHS['BROKE']}broke"
        f"  {_C_BLUE}L{_C_RESET}loaded {_C_DIM}.{_C_RESET}empty",
        f"  Specials: {_C_RED}!H{_C_RESET}infested  {_C_YELLOW}?H{_C_RESET}threatened  {_C_MAGENTA}S{_C_RESET}salvage  {_C_RED}X{_C_RESET}disabled",
        f"  Events:   {_C_RED}\u2694{_C_RESET}attack  {_C_BG_RED}\u26a1{_C_RESET}catastrophe  {_C_CYAN}+{_C_RESET}spawn  {_C_GREEN}\u21ba{_C_RESET}respawn  {_C_BOLD}\u2192{_C_RESET}age_change",
        "",
    ]
    return "\n".join(lines)


def _run_viz(engine, args):
    print(_viz_legend())

    pending_events = []
    for tick_num in range(max(0, args.ticks)):
        engine.process_tick()
        pending_events.extend(
            e for e in engine.state.chronicle_events
            if e.get("tick") == engine.state.sim_tick_count
        )

        if engine.state.sim_tick_count % args.viz_interval == 0 or tick_num == args.ticks - 1:
            print(_viz_render_frame(engine.state.sim_tick_count, engine.state, pending_events))
            print()
            pending_events.clear()


def main():
    args = _parse_args()

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    if args.viz:
        _run_viz(engine, args)
        return

    if args.chronicle:
        _run_chronicle(engine, args)
        return

    transient_history = []
    for _ in range(max(0, args.ticks)):
        engine.process_tick()
        transient_history.append(
            {
                "tick": engine.state.sim_tick_count,
                "snapshot": _transient_snapshot(engine.state),
            }
        )

    report = _build_report(engine, transient_history, args)
    print(report)


if __name__ == "__main__":
    main()

--- Start of ./python_sandbox/tests/__init__.py ---

# tests/ — mirrors src/tests/core/simulation/ in Godot project.

--- Start of ./python_sandbox/tests/test_affinity.py ---

#
# PROJECT: GDTLancer
# MODULE: test_affinity.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md PHASE 3 TASK_5
# LOG_REF: 2026-02-22 00:58:31
#

"""Unit tests for qualitative affinity and tag-transition CA rules.

Run:
    python3 -m unittest tests.test_affinity -v
"""

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from autoload.game_state import GameState
from autoload import constants
from core.simulation.agent_layer import AgentLayer
from core.simulation.affinity_matrix import (
    AFFINITY_MATRIX,
    ATTACK_THRESHOLD,
    FLEE_THRESHOLD,
    TRADE_THRESHOLD,
    compute_affinity,
    derive_agent_tags,
    derive_sector_tags,
)
from core.simulation.grid_layer import GridLayer


class TestAffinity(unittest.TestCase):
    def test_compute_affinity_positive_pair(self):
        self.assertGreater(compute_affinity(["TRADER"], ["STATION"]), 0.0)

    def test_compute_affinity_negative_pair(self):
        self.assertLess(compute_affinity(["PIRATE"], ["MILITARY"]), 0.0)

    def test_compute_affinity_empty_inputs(self):
        self.assertEqual(compute_affinity([], []), 0.0)
        self.assertEqual(compute_affinity(["TRADER"], []), 0.0)

    def test_attack_threshold_reachable(self):
        self.assertTrue(any(v >= ATTACK_THRESHOLD for v in AFFINITY_MATRIX.values()))

    def test_thresholds_ordered(self):
        self.assertTrue(FLEE_THRESHOLD < 0 < TRADE_THRESHOLD < ATTACK_THRESHOLD)

    def test_derive_agent_tags_uses_new_condition_wealth_cargo(self):
        char = {"personality_traits": {"aggression": 0.8, "greed": 0.7}}
        agent = {
            "agent_role": "trader",
            "condition_tag": "DAMAGED",
            "wealth_tag": "BROKE",
            "cargo_tag": "LOADED",
            "dynamic_tags": ["DESPERATE"],
        }
        tags = derive_agent_tags(char, agent, has_cargo=True)
        self.assertIn("TRADER", tags)
        self.assertIn("DAMAGED", tags)
        self.assertIn("BROKE", tags)
        self.assertIn("LOADED", tags)
        self.assertIn("DESPERATE", tags)

    def test_derive_sector_tags_defaults(self):
        state = GameState()
        state.world_topology = {"s1": {"connections": [], "sector_type": "colony"}}
        state.world_hazards = {"s1": {}}
        state.grid_dominion = {"s1": {"security_level": 0.9}}
        state.sector_tags = {"s1": ["STATION"]}
        tags = derive_sector_tags("s1", state)
        self.assertIn("SECURE", tags)
        self.assertIn("MILD", tags)
        self.assertIn("RAW_ADEQUATE", tags)


class TestTagTransitionCA(unittest.TestCase):
    def setUp(self):
        self.layer = GridLayer()
        self.state = GameState()
        self.state.world_age = "PROSPERITY"
        self.state.world_topology = {
            "a": {"connections": ["b"], "sector_type": "colony"},
            "b": {"connections": ["a"], "sector_type": "colony"},
        }
        self.state.sector_tags = {
            "a": ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"],
            "b": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
        }
        self.state.grid_dominion = {"a": {}, "b": {}}
        self.state.colony_levels = {"a": "outpost", "b": "outpost"}
        self.state.colony_upgrade_progress = {"a": 0, "b": 0}
        self.state.colony_downgrade_progress = {"a": 0, "b": 0}
        self.state.security_upgrade_progress = {"a": 0, "b": 0}
        self.state.security_downgrade_progress = {"a": 0, "b": 0}
        self.state.security_change_threshold = {"a": 3, "b": 3}
        self.state.economy_upgrade_progress = {
            "a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        self.state.economy_downgrade_progress = {
            "a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        self.state.economy_change_threshold = {
            "a": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
            "b": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
        }
        self.state.hostile_infestation_progress = {"a": 0, "b": 0}
        self.state.agents = {
            "mil_1": {"current_sector_id": "a", "agent_role": "military", "is_disabled": False},
            "pir_1": {"current_sector_id": "b", "agent_role": "pirate", "is_disabled": False},
        }

    def test_economy_thresholds_vary_per_sector(self):
        state = GameState()
        state.world_seed = "seed-123"
        state.world_topology = {
            "s1": {"connections": ["s2"], "sector_type": "colony"},
            "s2": {"connections": ["s1"], "sector_type": "colony"},
        }
        state.sector_tags = {
            "s1": ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
            "s2": ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
        }

        self.layer.initialize_grid(state)

        s1 = state.economy_change_threshold["s1"]
        s2 = state.economy_change_threshold["s2"]
        self.assertTrue(all(2 <= value <= 5 for value in s1.values()))
        self.assertTrue(all(2 <= value <= 5 for value in s2.values()))
        self.assertNotEqual(s1, s2)

    def test_economy_transitions_require_sustained_pressure(self):
        self.state.world_age = "RECOVERY"
        self.state.agents["trader_1"] = {
            "current_sector_id": "a",
            "agent_role": "trader",
            "cargo_tag": "LOADED",
            "is_disabled": False,
        }

        self.layer.process_tick(self.state, {})
        self.assertIn("RAW_POOR", self.state.sector_tags["a"])

        self.layer.process_tick(self.state, {})
        self.assertIn("RAW_POOR", self.state.sector_tags["a"])

        self.layer.process_tick(self.state, {})
        a_tags = self.state.sector_tags["a"]
        self.assertIn("RAW_ADEQUATE", a_tags)
        self.assertNotIn("RAW_POOR", a_tags)

    def test_security_transitions_with_military_and_pirates(self):
        self.layer.process_tick(self.state, {})
        a_tags = self.state.sector_tags["a"]
        b_tags = self.state.sector_tags["b"]
        self.assertIn("SECURE", a_tags)
        self.assertTrue(any(tag in b_tags for tag in {"SECURE", "CONTESTED", "LAWLESS"}))
        self.assertEqual(sum(1 for tag in b_tags if tag in {"SECURE", "CONTESTED", "LAWLESS"}), 1)

    def test_environment_transitions_under_disruption(self):
        self.state.world_age = "DISRUPTION"
        self.layer.process_tick(self.state, {})
        self.assertIn(self.state.sector_tags["a"][-1] if "MILD" in self.state.sector_tags["a"] else "HARSH", {"MILD", "HARSH", "EXTREME"})

    def test_hostile_infestation_builds_gradually(self):
        self.state.world_age = "DISRUPTION"
        self.state.sector_tags["a"] = ["STATION", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
        self.state.sector_tags["b"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
        self.state.agents["mil_1"]["is_disabled"] = True

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.state.world_age = "RECOVERY"
        self.state.agents["mil_1"] = {"current_sector_id": "b", "agent_role": "military", "is_disabled": False}
        self.state.agents["pir_1"]["is_disabled"] = True
        self.state.security_change_threshold["b"] = 1
        self.state.security_upgrade_progress["b"] = 0
        self.state.security_downgrade_progress["b"] = 0

        self.layer.process_tick(self.state, {})
        self.assertIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

        self.layer.process_tick(self.state, {})
        self.assertNotIn("HOSTILE_INFESTED", self.state.sector_tags["b"])

    def test_colony_maintenance_drains_economy(self):
        state = GameState()
        state.world_seed = "maint-seed"
        state.world_age = "PROSPERITY"
        state.world_topology = {
            "hub_sector": {"connections": [], "sector_type": "hub"},
        }
        state.sector_tags = {
            "hub_sector": ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"],
        }
        state.grid_dominion = {"hub_sector": {}}
        state.colony_levels = {"hub_sector": "hub"}
        state.colony_upgrade_progress = {"hub_sector": 0}
        state.colony_downgrade_progress = {"hub_sector": 0}
        state.security_upgrade_progress = {"hub_sector": 0}
        state.security_downgrade_progress = {"hub_sector": 0}
        state.security_change_threshold = {"hub_sector": 3}
        state.economy_upgrade_progress = {"hub_sector": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}}
        state.economy_downgrade_progress = {"hub_sector": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}}
        state.economy_change_threshold = {"hub_sector": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2}}
        state.hostile_infestation_progress = {"hub_sector": 0}
        state.agents = {}

        for _ in range(10):
            self.layer.process_tick(state, {})

        tags = state.sector_tags["hub_sector"]
        self.assertNotIn("RAW_RICH", tags)
        self.assertNotIn("MANUFACTURED_RICH", tags)
        self.assertNotIn("CURRENCY_RICH", tags)


class TestPopulationEquilibrium(unittest.TestCase):
    def test_mortal_spawn_blocked_in_poor_sector(self):
        layer = AgentLayer()
        layer._rng.seed(0)

        state = GameState()
        state.world_topology = {"s1": {"connections": [], "sector_type": "colony"}}
        state.sector_tags = {
            "s1": ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"],
        }
        state.agents = {}
        state.mortal_agent_counter = 0

        with patch.object(constants, "MORTAL_SPAWN_CHANCE", 1.0):
            layer._spawn_mortal_agents(state)

        self.assertEqual(state.mortal_agent_counter, 0)
        self.assertEqual(len(state.agents), 0)

    def test_mortal_survivor_starts_broke(self):
        layer = AgentLayer()
        layer._rng.seed(0)

        state = GameState()
        state.agents = {
            "mortal_1": {
                "is_persistent": False,
                "is_disabled": True,
                "home_location_id": "s1",
                "current_sector_id": "s2",
                "condition_tag": "DESTROYED",
                "wealth_tag": "WEALTHY",
                "cargo_tag": "LOADED",
            }
        }

        with patch.object(constants, "MORTAL_SURVIVAL_CHANCE", 1.0):
            layer._cleanup_dead_mortals(state)

        survivor = state.agents["mortal_1"]
        self.assertFalse(survivor["is_disabled"])
        self.assertEqual(survivor["condition_tag"], "DAMAGED")
        self.assertEqual(survivor["wealth_tag"], "BROKE")
        self.assertEqual(survivor["cargo_tag"], "EMPTY")


class TestTopologyExploration(unittest.TestCase):
    def _build_min_state(self):
        state = GameState()
        state.world_seed = "topology-seed"
        state.sim_tick_count = 100
        state.world_topology = {
            "source": {"connections": ["n1"], "sector_type": "frontier"},
            "n1": {"connections": ["source"], "sector_type": "frontier"},
        }
        state.sector_tags = {
            "source": ["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
            "n1": ["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
        }
        state.world_hazards = {"source": {"environment": "HARSH"}, "n1": {"environment": "HARSH"}}
        state.grid_dominion = {
            "source": {"controlling_faction_id": "", "security_tag": "CONTESTED"},
            "n1": {"controlling_faction_id": "", "security_tag": "CONTESTED"},
        }
        state.colony_levels = {"source": "frontier", "n1": "frontier"}
        state.colony_upgrade_progress = {"source": 0, "n1": 0}
        state.colony_downgrade_progress = {"source": 0, "n1": 0}
        state.security_upgrade_progress = {"source": 0, "n1": 0}
        state.security_downgrade_progress = {"source": 0, "n1": 0}
        state.security_change_threshold = {"source": 3, "n1": 3}
        state.economy_upgrade_progress = {
            "source": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "n1": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        state.economy_downgrade_progress = {
            "source": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
            "n1": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
        }
        state.economy_change_threshold = {
            "source": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
            "n1": {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3},
        }
        state.hostile_infestation_progress = {"source": 0, "n1": 0}
        state.discovery_log = []
        state.discovered_sector_count = 0
        state.sector_names = {}
        return state

    def _distances(self, topology: dict, source: str) -> dict:
        dist = {source: 0}
        queue = [source]
        while queue:
            current = queue.pop(0)
            for nxt in topology.get(current, {}).get("connections", []):
                if nxt in dist:
                    continue
                dist[nxt] = dist[current] + 1
                queue.append(nxt)
        return dist

    def test_max_connections_per_sector_respected(self):
        layer = AgentLayer()
        layer._rng.seed(7)
        state = self._build_min_state()
        agent = {"wealth_tag": "COMFORTABLE", "last_discovery_tick": -999}

        with patch.object(constants, "MAX_SECTOR_COUNT", 60), \
             patch.object(constants, "EXPLORATION_COOLDOWN_TICKS", 0), \
             patch.object(constants, "EXPLORATION_SUCCESS_CHANCE", 1.0):
            for _ in range(50):
                state.sim_tick_count += 1
                layer._try_exploration(state, "explorer_1", agent, "source")

        for sid, meta in state.world_topology.items():
            self.assertLessEqual(
                len(meta.get("connections", [])),
                constants.MAX_CONNECTIONS_PER_SECTOR,
                msg=f"sector {sid} exceeded connection cap",
            )

    def test_new_sector_default_single_connection(self):
        class _MockRng:
            def __init__(self):
                self._calls = 0

            def random(self):
                self._calls += 1
                return 0.0 if self._calls == 1 else 1.0

            def choice(self, seq):
                return seq[0]

        layer = AgentLayer()
        layer._rng = _MockRng()
        state = self._build_min_state()
        agent = {"wealth_tag": "COMFORTABLE", "last_discovery_tick": -999}

        with patch.object(constants, "EXPLORATION_COOLDOWN_TICKS", 0), \
             patch.object(constants, "EXPLORATION_SUCCESS_CHANCE", 1.0):
            layer._try_exploration(state, "explorer_1", agent, "source")

        new_id = "discovered_1"
        self.assertIn(new_id, state.world_topology)
        self.assertEqual(len(state.world_topology[new_id]["connections"]), 1)

    def test_saturated_source_falls_back_to_neighbor(self):
        layer = AgentLayer()
        layer._rng.seed(1)
        state = self._build_min_state()

        state.world_topology = {
            "source": {"connections": ["n1", "n2", "n3", "n4"], "sector_type": "frontier"},
            "n1": {"connections": ["source"], "sector_type": "frontier"},
            "n2": {"connections": ["source"], "sector_type": "frontier"},
            "n3": {"connections": ["source"], "sector_type": "frontier"},
            "n4": {"connections": ["source"], "sector_type": "frontier"},
        }
        for sid in ("n2", "n3", "n4"):
            state.sector_tags[sid] = ["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
            state.world_hazards[sid] = {"environment": "HARSH"}
            state.grid_dominion[sid] = {"controlling_faction_id": "", "security_tag": "CONTESTED"}
            state.colony_levels[sid] = "frontier"
            state.colony_upgrade_progress[sid] = 0
            state.colony_downgrade_progress[sid] = 0
            state.security_upgrade_progress[sid] = 0
            state.security_downgrade_progress[sid] = 0
            state.security_change_threshold[sid] = 3
            state.economy_upgrade_progress[sid] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
            state.economy_downgrade_progress[sid] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
            state.economy_change_threshold[sid] = {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3}
            state.hostile_infestation_progress[sid] = 0

        agent = {"wealth_tag": "COMFORTABLE", "last_discovery_tick": -999}
        with patch.object(constants, "EXPLORATION_COOLDOWN_TICKS", 0), \
             patch.object(constants, "EXPLORATION_SUCCESS_CHANCE", 1.0), \
             patch.object(constants, "EXTRA_CONNECTION_1_CHANCE", 0.0):
            layer._try_exploration(state, "explorer_1", agent, "source")

        new_id = "discovered_1"
        self.assertIn(new_id, state.world_topology)
        new_connections = state.world_topology[new_id]["connections"]
        self.assertNotIn("source", new_connections)
        self.assertIn("n1", new_connections)

    def test_exploration_fails_when_region_fully_saturated(self):
        layer = AgentLayer()
        layer._rng.seed(2)
        state = self._build_min_state()

        nodes = ["source", "n1", "n2", "n3", "n4"]
        state.world_topology = {
            node: {"connections": [n for n in nodes if n != node], "sector_type": "frontier"}
            for node in nodes
        }
        for sid in nodes:
            state.sector_tags[sid] = ["FRONTIER", "CONTESTED", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
            state.world_hazards[sid] = {"environment": "HARSH"}
            state.grid_dominion[sid] = {"controlling_faction_id": "", "security_tag": "CONTESTED"}
            state.colony_levels[sid] = "frontier"
            state.colony_upgrade_progress[sid] = 0
            state.colony_downgrade_progress[sid] = 0
            state.security_upgrade_progress[sid] = 0
            state.security_downgrade_progress[sid] = 0
            state.security_change_threshold[sid] = 3
            state.economy_upgrade_progress[sid] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
            state.economy_downgrade_progress[sid] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
            state.economy_change_threshold[sid] = {"RAW": 3, "MANUFACTURED": 3, "CURRENCY": 3}
            state.hostile_infestation_progress[sid] = 0

        original_count = len(state.world_topology)
        agent = {"wealth_tag": "COMFORTABLE", "last_discovery_tick": -999}
        with patch.object(constants, "EXPLORATION_COOLDOWN_TICKS", 0), \
             patch.object(constants, "EXPLORATION_SUCCESS_CHANCE", 1.0):
            layer._try_exploration(state, "explorer_1", agent, "source")

        self.assertEqual(len(state.world_topology), original_count)
        self.assertNotIn("discovered_1", state.world_topology)

    def test_loop_candidate_respects_min_hops(self):
        layer = AgentLayer()
        state = self._build_min_state()
        state.world_seed = "loop-seed"
        state.discovered_sector_count = 3
        state.sim_tick_count = 40
        state.world_topology = {
            "s0": {"connections": ["s1"], "sector_type": "frontier"},
            "s1": {"connections": ["s0", "s2"], "sector_type": "frontier"},
            "s2": {"connections": ["s1", "s3"], "sector_type": "frontier"},
            "s3": {"connections": ["s2", "s4"], "sector_type": "frontier"},
            "s4": {"connections": ["s3"], "sector_type": "frontier"},
        }

        candidate = layer._distant_loop_candidate(state, "s0", {"s0", "s1"})
        self.assertIsNotNone(candidate)

        distances = self._distances(state.world_topology, "s0")
        self.assertGreaterEqual(distances[candidate], constants.LOOP_MIN_HOPS)


if __name__ == "__main__":
    unittest.main()
