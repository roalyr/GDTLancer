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

--- Start of ./python_sandbox/tools/universe_generator_legacy/palettes.py ---

# http://www.zonums.com/online/color_ramp/

spectrum_palette  = [
(200,0,200), #C800C8
(181,13,205), #B50DCD
(163,27,210), #A31BD2
(145,40,215), #9128D7
(127,54,220), #7F36DC
(109,68,225), #6D44E1
(90,81,230), #5A51E6
(72,95,235), #485FEB
(54,109,240), #366DF0
(36,122,245), #247AF5
(18,136,250), #1288FA
(0,150,255), #0096FF
(0,155,255), #009BFF
(0,160,255), #00A0FF
(0,165,255), #00A5FF
(0,170,255), #00AAFF
(0,175,255), #00AFFF
(0,180,255), #00B4FF
(0,185,255), #00B9FF
(0,190,255), #00BEFF
(0,195,255), #00C3FF
(0,200,255), #00C8FF
(0,205,255), #00CDFF
(0,210,255), #00D2FF
(0,215,255), #00D7FF
(0,220,255), #00DCFF
(0,225,255), #00E1FF
(0,230,255), #00E6FF
(0,235,255), #00EBFF
(0,240,255), #00F0FF
(0,245,255), #00F5FF
(0,250,255), #00FAFF
(0,255,255), #00FFFF
(13,255,231), #0DFFE7
(27,255,208), #1BFFD0
(40,255,185), #28FFB9
(54,255,162), #36FFA2
(68,255,139), #44FF8B
(81,255,115), #51FF73
(95,255,92), #5FFF5C
(109,255,69), #6DFF45
(122,255,46), #7AFF2E
(136,255,23), #88FF17
(150, 255, 0), #96FF00
(155,255,0), #9BFF00
(160,255,0), #A0FF00
(165,255,0), #A5FF00
(170,255,0), #AAFF00
(175,255,0), #AFFF00
(180,255,0), #B4FF00
(185,255,0), #B9FF00
(190,255,0), #BEFF00
(195,255,0), #C3FF00
(200,255,0), #C8FF00
(205,255,0), #CDFF00
(210,255,0), #D2FF00
(215,255,0), #D7FF00
(220,255,0), #DCFF00
(225,255,0), #E1FF00
(230,255,0), #E6FF00
(235,255,0), #EBFF00
(240,255,0), #F0FF00
(245,255,0), #F5FF00
(250,255,0), #FAFF00
(255, 255, 0), #FFFF00
(255,248,0), #FFF800
(255,242,0), #FFF200
(255,236,0), #FFEC00
(255,230,0), #FFE600
(255,223,0), #FFDF00
(255,217,0), #FFD900
(255,211,0), #FFD300
(255,205,0), #FFCD00
(255,199,0), #FFC700
(255,192,0), #FFC000
(255,186,0), #FFBA00
(255,180,0), #FFB400
(255,174,0), #FFAE00
(255,167,0), #FFA700
(255,161,0), #FFA100
(255,155,0), #FF9B00
(255,149,0), #FF9500
(255,143,0), #FF8F00
(255,136,0), #FF8800
(255,130,0), #FF8200
(255,124,0), #FF7C00
(255,118,0), #FF7600
(255,111,0), #FF6F00
(255,105,0), #FF6900
(255,99,0), #FF6300
(255,93,0), #FF5D00
(255,87,0), #FF5700
(255,80,0), #FF5000
(255,74,0), #FF4A00
(255,68,0), #FF4400
(255,62,0), #FF3E00
(255,55,0), #FF3700
(255,49,0), #FF3100
(255,43,0), #FF2B00
(255,37,0), #FF2500
(255,31,0), #FF1F00
(255,24,0), #FF1800
(255,18,0), #FF1200
(255,12,0), #FF0C00
(255,6,0), #FF0600
(255, 0, 0), #FF0000
(252,0,0), #FC0000
(249,0,0), #F90000
(247,0,0), #F70000
(244,0,0), #F40000
(242,0,0), #F20000
(239,0,0), #EF0000
(237,0,0), #ED0000
(234,0,0), #EA0000
(231,0,0), #E70000
(229,0,0), #E50000
(226,0,0), #E20000
(224,0,0), #E00000
(221,0,0), #DD0000
(219,0,0), #DB0000
(216,0,0), #D80000
(214,0,0), #D60000
(211,0,0), #D30000
(208,0,0), #D00000
(206,0,0), #CE0000
(203,0,0), #CB0000
(201,0,0), #C90000
(198,0,0), #C60000
(196,0,0), #C40000
(193,0,0), #C10000
(190,0,0), #BE0000
(188,0,0), #BC0000
(185,0,0), #B90000
(183,0,0), #B70000
(180,0,0), #B40000
(178,0,0), #B20000
(175,0,0), #AF0000
(173,0,0), #AD0000
(170,0,0), #AA0000
(167,0,0), #A70000
(165,0,0), #A50000
(162,0,0), #A20000
(160,0,0), #A00000
(157,0,0), #9D0000
(155,0,0), #9B0000
(152,0,0), #980000
(150, 0, 0), #960000
]

--- Start of ./python_sandbox/tools/universe_generator_legacy/universe_generator.py ---

############### PARAMETERS ###############
seed = "GDTLancer"

# GODOT engine parameters.
star_zone_size_factor = 50 # Multiplied by star size.
star_zone_size_by_death_zone_factor = 10 # If star zone is less than death zone.
star_death_zone_min_factor = 1.5 # If death zone is too small.
star_detail_decay_distance_factor = 40 # Distance factor at which star core turns white.
star_autopilot_factor = 2.0 # Multiplied by death zone size.
star_flare_factor = 1.0 # Multiplied by star zone size. Acts like an indicatort.
system_zone_size_min = 1e13 # Threshold to prevent jitter.

planet_zone_size_factor = 20 # Multiplied by planet size.
planet_death_zone_factor = 1.05 # Planet death zone (atmosphere or gravitation pull?)
planet_autopilot_factor = 2.0 # Multiplied by death zone size.

# Companion stars for the main star.
num_stars_min = 0
num_stars_max = 5

# Planets for each star type.
star_o_num_planets_min = 1
star_o_num_planets_max = 5

star_b_num_planets_min = 1
star_b_num_planets_max = 15

star_a_num_planets_min = 1
star_a_num_planets_max = 20

star_f_num_planets_min = 1
star_f_num_planets_max = 15

star_g_num_planets_min = 0
star_g_num_planets_max = 10

star_k_num_planets_min = 0
star_k_num_planets_max = 7

star_m_num_planets_min = 0
star_m_num_planets_max = 5









############### IMPORTS ################

import universe_presets
import universe_test_presets
import palettes

# Using multiple random instances to not to affect different states.
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char
import operator

import os
import png
import math












######### CONSTANTS: FUNCTIONS ##########

# Formatting mini-functions.
def e(x):
	return  "{:.2e}".format(x)

def rgb_to_hex(rgb):
	return '%02x%02x%02x' % rgb

def clamp(n, min, max):
	if n < min:
		return min
	elif n > max:
		return max
	else:
		return n

# Make additional folders.
cwd = os.path.normpath(os.getcwd())

try:
	os.mkdir(cwd + "/Doc/Universe/")
except:
	pass

try:
	os.mkdir(cwd + "/Doc/Universe/Colors")
except:
	pass

# Prepare colors from palettes.
# https://stackoverflow.com/questions/8554282/creating-a-png-file-in-python
width = 19
height = 19

for color in palettes.spectrum_palette:
	img = []
	for y in range(height):
		t = pow(math.sin(y/height*math.pi),1.2)
		row = []
		for x in range(width):
			s = pow(math.sin(x/width*math.pi),1.2)
			row.append(int(color[0]*s*t))
			row.append(int(color[1]*s*t))
			row.append(int(color[2]*s*t))
		img.append(row)
		
	name = rgb_to_hex(color) + ".png"
	with open(cwd + "/Doc/Universe/Colors/" + name, 'wb') as f:
		w = png.Writer(width, height, greyscale=False)
		w.write(f, img)
		
# Make a blank image.
img = []
for y in range(height):
	row = ()
	for x in range(width):
		row = (0, 0, 0)*width
	img.append(row)
	
name = rgb_to_hex((0, 0, 0)) + ".png"
with open(cwd + "/Doc/Universe/Colors/" + name, 'wb') as f:
	w = png.Writer(width, height, greyscale=False)
	w.write(f, img)














######### CONSTANTS: STARS ##########

# Sun data for reference
sun_diameter = 1.39e9
sun_density = 1408 # kg / m3
sun_distance_au = 149597870700 #m
sun_luminosity = 3.827e+26 # Watts
sun_luminosity_visible = 0.47 * sun_luminosity # ~1.8e+26 Watts
sun_temperature = 5771.8 # K
sun_mass = 1.99e30 # kg

# GODOT omni light
# Omni light formula: range = (luminocity/4)^(1/2)
# Omni energy = 2, omni attenuation = 10.
star_omni_ratio = 4 
sun_omni_didstance = 1e13 # For reference.
sun_omni_energy = 2.0
sun_omni_attenuation = 10.0 

# f = L / (4 * pi * d²).
# d² = L / (4 * pi * f), d = (L / (4 * pi * f))^(1/2)
# https://www.astronomy.ohio-state.edu/weinberg.21/Intro/lec2.html#:~:text=More%20generally%2C%20the%20luminosity%2C%20apparent,is%20an%20important%20intrinsic%20property.
# L = intrinsic luminosity of the source
# d = distance of the source
# f = apparent brightness (flux) of the source
#
# Luminocity formula
# https://www.quora.com/What-is-the-formula-between-the-temperature-and-luminosity-of-a-main-sequence-star
# L = (7.12560265e-7 Wm⁻²K⁻⁴) R²T⁴
c_lum = 7.12560265e-7

# Wavelength constant. nm*K
c_wien = 2897771.9 

# Set those margins respectively.
# W/m^2 at respective star distance.
flux_dust_melting  = 225000 # Derived above.
flux_hot_zone  = 34000
flux_warm_zone  = 2800
flux_temperate_zone  = 1400
flux_cold_zone  = 600
# https://en.m.wikipedia.org/wiki/Frost_line_(astrophysics)
# Distinction between terran and jovian planet formation regions.
# Water ice formation flux.
flux_frost_line  = 170 # Ice sublimation.

# Spectrum margins. In nanometers.
# X-ray. https://en.m.wikipedia.org/wiki/X-ray
wl_xray_min = 0.01
# Ultraviolet. https://en.m.wikipedia.org/wiki/Ultraviolet
wl_euv_min = 10
wl_fuv_min = 122
wl_muv_min = 200
wl_nuv_min = 300
# Visible. https://en.m.wikipedia.org/wiki/Light
wl_visible_min = 400
# Infrared. https://en.m.wikipedia.org/wiki/Infrared#Regions_within_the_infrared
wl_nir_min = 700
wl_swir_min = 1400
wl_mwir_min = 3000
wl_lwir_min = 8000
wl_fir_min = 15000


# Star type parameters
# https://en.m.wikipedia.org/wiki/Stellar_classification

star_temp_max = 100000
star_temp_min = 2400
star_primary_wl_min = c_wien / star_temp_min
star_primary_wl_max = c_wien / star_temp_max

star_o_size_min = 6.6 * sun_diameter
star_o_size_max = 10 * sun_diameter
star_o_temp_min = 30000
star_o_temp_max = star_temp_max
star_o_mass_min = 16
star_o_mass_max = 90
# Abundance is tweaked for gameplay purposes.
star_o_abundance = 0.02 # use 0.002

star_b_size_min = 1.8 * sun_diameter
star_b_size_max = 6.6 * sun_diameter
star_b_temp_min = 10000
star_b_temp_max = 30000
star_b_mass_min = 2.1
star_b_mass_max = 16
# Abundance is tweaked for gameplay purposes.
star_b_abundance = 0.05 # use 0.02

star_a_size_min = 1.4 * sun_diameter
star_a_size_max = 1.8 * sun_diameter
star_a_temp_min = 7500
star_a_temp_max = 10000
star_a_mass_min = 1.4
star_a_mass_max = 2.1
# Abundance is tweaked for gameplay purposes.
star_a_abundance = 0.1 # use 0.06

star_f_size_min = 1.15 * sun_diameter
star_f_size_max = 1.4 * sun_diameter
star_f_temp_min = 6000
star_f_temp_max = 7500
star_f_mass_min = 1.04
star_f_mass_max = 1.4
# Abundance is tweaked for gameplay purposes.
star_f_abundance = 0.2 # use 0.1

star_g_size_min = 0.96 * sun_diameter
star_g_size_max = 1.15 * sun_diameter
star_g_temp_min = 5200
star_g_temp_max = 6000
star_g_mass_min = 0.8
star_g_mass_max = 1.04
# Abundance is tweaked for gameplay purposes.
star_g_abundance = 0.3 # use 0.2

star_k_size_min = 0.7 * sun_diameter
star_k_size_max = 0.96 * sun_diameter
star_k_temp_min = 3700
star_k_temp_max = 5200
star_k_mass_min = 0.45
star_k_mass_max = 0.8
# Abundance is tweaked for gameplay purposes.
star_k_abundance = 0.5 # use 0.3

star_m_size_min = 0.1 * sun_diameter
star_m_size_max = 0.7 * sun_diameter
star_m_temp_min = star_temp_min
star_m_temp_max = 3700
star_m_mass_min = 0.08
star_m_mass_max = 0.45
# Abundance is tweaked for gameplay purposes.
star_m_abundance = 1.0 #use 0.8 when giants and white dwarfs are implemented.









######### CONSTANTS: PLANETS ##########
earth_mass = 5.972e24 #kg
earth_radius =  6.3781e6 #m

# Protoplanetary disks
# https://www.researchgate.net/publication/311106398_The_Gas_Disk_Evolution_and_Chemistry
# Total amount of planetaty systems which are at protoplanetary stage.
protoplanetary_disks_fraction = 0.05

# Total number of protoplanetary systems which are moderately young.
# have acctetion and jets. Uniform consistent disks?
protoplanetary_disks_with_accretion_fraction = 0.2 

# Amount of gas mass in protoplanetary systems which are more mature.
# Here we assume that some of it was scattered away.
protoplanetaty_disk_gas_debris_ratio_max = 1.0
protoplanetaty_disk_gas_debris_ratio_min = 0.1

# Protoplanetary disk mass according to central star mass ratio.
# https://www.researchgate.net/figure/Scattering-of-protoplanetary-disk-masses-according-to-the-mass-of-the-central-star_fig5_330576670
protoplanetaty_disk_mass_ratio_max = 1.0
protoplanetaty_disk_mass_ratio_min = 0.01

# Zoning of a disk as a function of a star flux (W/m2).
# Flux at which ice begins to form.
protoplanetaty_disk_snow_line_flux = flux_frost_line



# A next stage in modelling after a protoplanetagy disk will be young planetary system.
# Total number of young planetary systems.
young_planetary_systems_fraction = 0.2

# The amount of mass distributed as debris and dust(?).
young_planetary_system_debris_ratio_max = 0.4
young_planetary_system_debris_ratio_min = 0.05

# Large planetary objects.
young_planetary_system_planets_min  = 0
# young_planetary_system_planets_max  = ???

# Small planetary objects.
young_planetary_system_planetoid_min  = 0
# young_planetary_system_planetoid_max  = ???


# Planetary resonanse factors.
resonance_ratio_list = [1.33, 1.5, 2.0]

# Safe gravitational zone threshild multiplier for beighbor planets.
hill_radii_stability_multiplier = 2

# Multiplier for frost line.
gas_giant_spawn_distance_factor = 10

# Type of planet  Earth units		R = M^f
planet_rocky_radius_factor = 0.28

#  M min  M max  R min  R max  f
# Sub-dwarf  0.000002  0.00002  0.025  0.048  0.28
planet_sD_mass_min = 0.000002
planet_sD_mass_max = 0.00002

# Dwarf  0.00002  0.0002  0.048  0.092  0.28
planet_D_mass_min = 0.00002
planet_D_mass_max = 0.0002

# Super-dwarf  0.0002  0.002  0.092  0.176  0.28
planet_SD_mass_min = 0.0002
planet_SD_mass_max = 0.002
		   
# Sub-terrestrial  0.002  0.02  0.176  0.334  0.28
planet_sT_mass_min = 0.002
planet_sT_mass_max = 0.02

# Terrestrial  0.02  0.2  0.334  0.637  0.28
planet_T_mass_min = 0.02
planet_T_mass_max = 0.2

# Super-terrestrial  0.2  2  0.637  1.214  0.28
planet_ST_mass_min = 0.2
planet_ST_mass_max = 2

# Sub-giant  2  130  1.505  17.670  0.59
planet_sub_giant_radius_factor = 0.59

planet_sG_mass_min = 2
planet_sG_mass_max = 130

# Giant  130  300  9.000  20.000  -
planet_G_mass_min = 130
planet_G_mass_max = 300

# Super-giant  300  3000  9.000  20.000  -
planet_SG_mass_min = 300
planet_SG_mass_max = 3000

planet_G_radius_min = 9
planet_G_radius_max = 20













################# TESTING ###############
# Habitable zone margins for sun (lax).
# https://en.m.wikipedia.org/wiki/Circumstellar_habitable_zone
# 0.2 a.u. from Sun (hot zone).
sun_hot_zone = sun_distance_au * 0.2 
sun_hot_zone_flux = sun_luminosity / (4 * 3.14 * sun_hot_zone * sun_hot_zone)
# Venus (warm zone).
sun_warm_zone = sun_distance_au * 0.7
sun_warm_zone_flux = sun_luminosity / (4 * 3.14 * sun_warm_zone * sun_warm_zone)
# Earth (reference value).
sun_temperate_zone = sun_distance_au * 1.0
sun_temperate_zone_flux = sun_luminosity / (4 * 3.14 * sun_temperate_zone * sun_temperate_zone)
# Mars (cold zone).
sun_cold_zone = sun_distance_au * 1.5
sun_cold_zone_flux = sun_luminosity / (4 * 3.14 * sun_cold_zone * sun_cold_zone)

# Sun snow line.
# T = (L / (2.85e-6 * R^2))^(1/4)
# T^4 = L / (2.85e-6 * R^2); R = (L / (T^4 * 2.85e-6))^(1/2)
# flux = sigma * T^4
SB_sigma = 5.670373e-8 # Stefan-Boltzman c.
sun_frost_line_dust_temp = 170
sun_frost_line_distance = pow(sun_luminosity / (2.85e-6 * pow(sun_frost_line_dust_temp, 4)), 0.5)
sun_frost_line_flux = sun_luminosity / (4 * 3.14 * sun_frost_line_distance * sun_frost_line_distance)

# Silicate particles melting distance.
dust_melting_temp = 1000
sun_dust_melting_distance = pow(sun_luminosity / (2.85e-6 * pow(dust_melting_temp, 4)), 0.5)
sun_dust_melting_flux = sun_luminosity / (4 * 3.14 * sun_dust_melting_distance * sun_dust_melting_distance)

# Values for ship default flux resistence. Affects the distance you can be at around star.
melting_temp = 900
material_albedo = 0.9
melting_flux_worst =  SB_sigma * pow(melting_temp, 4) / (1 - material_albedo)
melting_flux_average = melting_flux_worst * 2

# Testing.
melting_distance_average_O0 =  pow( 2e33 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_B9 =  pow( 1.85e+29 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_G5 =  pow( 4.5e26 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_M9 =  pow( 2.94e+23 / (4 * 3.14 * melting_flux_average), 0.5)


print("Value testing")
print("-----------")
print("Melting flux at 0.9 albedo (W/m2) worst ", e(melting_flux_worst))
print("Melting flux at 0.9 albedo (W/m2) avg ", e(melting_flux_average))
print("Melting distance avg O0 star (rel) ", e(melting_distance_average_O0/1.1e10))
print("Melting distance avg B9 star (rel) ", e(melting_distance_average_B9/7.85e+09))
print("Melting distance avg G5 star (rel) ", e(melting_distance_average_G5/1.6e9))
print("Melting distance avg M9 star (rel) ", e(melting_distance_average_M9/2.13e+08))
print("-----------")
print("Assumed dust melting temperature (K)", dust_melting_temp)
print("Sun dust melting flux (W/m2)", round(sun_dust_melting_flux, 1), " at ", round(sun_dust_melting_distance/sun_distance_au, 2), "AU" ) # ~34000
print()
print("Sun hot zone flux (W/m2)", round(sun_hot_zone_flux, 1), " at ", round(sun_hot_zone/sun_distance_au, 2), "AU" ) # ~34000
print("Sun warm zone flux (W/m2)", round(sun_warm_zone_flux, 1), " at ", round(sun_warm_zone/sun_distance_au, 2), "AU" ) # ~2800
print("Sun temperate zone flux (W/m2)", round(sun_temperate_zone_flux, 1), " at ", round(sun_temperate_zone/sun_distance_au, 2), "AU" ) # ~1400
print("Sun cold zone flux (W/m2)", round(sun_cold_zone_flux, 1), " at ", round(sun_cold_zone/sun_distance_au, 2), "AU" ) # ~600
print()
print("Sun frost line flux (W/m2)", round(sun_frost_line_flux, 1), " at ", round(sun_frost_line_distance/sun_distance_au, 2), "AU" ) # ~190
print("Sun frost line dust temp (K)", round(sun_frost_line_dust_temp, 1)) # 170
print("-----------")













############### FUNCTIONS ###############

random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')

output = ''

generated_systems_random = []
generated_systems_preset = []
used_names = []

total_number_o_stars = 0
total_number_b_stars = 0
total_number_a_stars = 0
total_number_f_stars = 0
total_number_g_stars = 0
total_number_k_stars = 0
total_number_m_stars = 0
total_number_other_stars = 0
total_number_all_stars = 0








############ SYSTEM GENERATION ###########

def system_generation(star_id, system, cluster_name):
	
	global output
	
	main_star = {}
	star_type = ''
	secondary_stars_num = 0
	planets_num = 0
	star_name = ''
	p = ''
	p_secondary_stars = ''
	star_list = []
	planet_list = []
	orbit_list = []
	planetary_data = []
	star_color_list = []
	
	# Get the star if it was defined. Second argument is for secondary stars, thus empty.
	if "main_star" in system:
		main_star = make_star(system["main_star"], ())
		star_type = system["main_star"]
	else:
		# Generate a stat.
		main_star = make_star('', ())
		star_type = main_star["type"]
	
	# Generate a systems and main star name if not defined.
	if "name" in system:
		star_name = system["name"]
		# Track user-defined names too.
		used_names.append(star_name)
	else:
		star_name = random_system_name(4, 7) 
	
	# Index 0 in the end takes the text + color sample image, 1 - only returns image.
	primary_star = formatting_star_data(star_id, True, main_star, star_name + " A")
	
	
	# Whether there are secondary stars (user defined).
	if "companion_stars" in system:
		secondary_stars_num = len(system["companion_stars"])
		if secondary_stars_num > 0:
			
			# Make from preset and store.
			for secondary_star_type in system["companion_stars"]:
				secondary_star = make_star(secondary_star_type, main_star["type"])
				star_list.append(secondary_star)
	
	# Randomly generate secondary stars otherwise.
	else:
		secondary_stars_num = random_star_number()
		if secondary_stars_num > 0:
			
			# Generate and store.
			for _ in range(secondary_stars_num):
				secondary_star = make_star('', main_star["type"])
				star_list.append(secondary_star)
					
	# Sort and output.
	star_list.sort(key = lambda x: (-x["temperature"]) )
	i = 0
	for secondary_star in star_list:
		i += 1
		s = formatting_star_data(
			str(star_id) + "_" + str(i), 
			False, # Not primary
			secondary_star, 
			star_name + " " + ABC[i])
		p_secondary_stars += s[0]
		star_color_list.append(s[1])
		
	# Generate planets.
	if "total_planets" in system:
		planets_num = len(system["total_planets"])
		if planets_num > 0:
			
			# Make from preset and store.
			for planet_type in system["total_planets"]:
				planet = make_planet(planet_type, main_star["type"])
				planet_list.append(planet)
	else:
		planets_num = random_planet_number(star_type[0])
		if planets_num > 0:
			
			# Generate and store.
			for _ in range(planets_num):
				planet = make_planet('', main_star["type"])
				planet_list.append(planet)

	# Split planetary system into orbits.
	# Initial ranges.
	Lmin = main_star["zone_margins"][5]*random_planet_val.uniform(1, 10)  # Minimum distance from star
	Lmax = main_star["zone_margins"][0]*random_planet_val.uniform(0.9, 1.2)  # Maximum distance from star
	if "closest_orbit" in system:
		Lmin = clamp(system["closest_orbit"], main_star["zone_margins"][5], main_star["omni_range"])
	if "furthest_orbit" in system:
		Lmax = clamp(system["furthest_orbit"], main_star["zone_margins"][5], main_star["omni_range"])
	
	N = len(planet_list)
	resonance_ratio = random_planet_val.choice(resonance_ratio_list)
	if "orbit_ratio" in system:
		if system["orbit_ratio"] in resonance_ratio_list:
			resonance_ratio = system["orbit_ratio"]
	
	if N > 1:
		orbit_list = generate_semi_major_axes(N, Lmin, Lmax, resonance_ratio)
	elif N == 1:
		orbit_list = [random_planet_val.uniform(Lmin, Lmax)]
	else:
		orbit_list = []
		
	# Check planet list and sort out unlikely sequences.
	# Calculate Hill radii of each star-planet pair.
	planet_list = sort_orbits(planet_list, orbit_list, main_star, Lmax)
	
	# Determine temperature range and combine data.
	temperature_list = get_planet_temperature_list(orbit_list, planet_list, main_star)
	
	# TODO
	# Determine atmosphere.
	atmosphere_list = get_planet_atmosphere(planet_list, temperature_list)
	
	# Determine albedo.
	
	
	# Combine data previously received.
	for i in range(len(planet_list)):
		planetary_data.append(planet_list[i])
		planetary_data[i]["orbit"] = orbit_list[i]
		planetary_data[i]["temperature_type"] = temperature_list[i][0]
		planetary_data[i]["temperature"] = temperature_list[i][1]

	
	# Write down the text for the main star and the system.
	p += formatting_system_data(star_id, system, main_star, star_name)
	p += primary_star[0]
	p += p_secondary_stars
	p += formatting_planet_data(star_name, star_type, planetary_data)
	
	# Add star color samples in the end of star block.
	p += " " + primary_star[1] + ' '
	for sec_star_color in star_color_list:
		p += sec_star_color + ' '
	p += "  \n"
	p += "\n---  \n"

	# Write down to the global output.
	output += p
	
	
	
	
	
	
	
###### PLANET FUNCTIONS #######

def random_planet_number(star_type):
	num = 0
	if star_type == "O":
		num = int(random_planet_num.uniform(star_o_num_planets_min, star_o_num_planets_max))
	elif star_type == "B":
		num = int(random_planet_num.uniform(star_b_num_planets_min, star_b_num_planets_max))
	elif star_type == "A":
		num = int(random_planet_num.uniform(star_a_num_planets_min, star_a_num_planets_max))
	elif star_type == "F":
		num = int(random_planet_num.uniform(star_f_num_planets_min, star_f_num_planets_max))
	elif star_type == "G":
		num = int(random_planet_num.uniform(star_g_num_planets_min, star_g_num_planets_max))
	elif star_type == "K":
		num = int(random_planet_num.uniform(star_k_num_planets_min, star_k_num_planets_max))
	elif star_type == "M":
		num = int(random_planet_num.uniform(star_m_num_planets_min, star_m_num_planets_max))
		
	return num


def make_planet(user_defined_type, primary_star_type):
	planet_type = ""
	planet_size = 0
	planet_zone_margins = 0
	
	if user_defined_type:
		# Process planet data according to type.
		if user_defined_type == "SD":
			planet_type = "sub dwarf"
		elif user_defined_type == "D":
			planet_type = "dwarf"
		elif user_defined_type == "LD":
			planet_type = "super dwarf"
			
		elif user_defined_type == "ST":
			planet_type = "sub terrestrial"
		elif user_defined_type == "T":
			planet_type = "terrestrial"
		elif user_defined_type == "LT":
			planet_type = "super terrestrial"
			
		elif user_defined_type == "SG":
			planet_type = "sub giant"
		elif user_defined_type == "G":
			planet_type = "giant"
		elif user_defined_type == "LG":
			planet_type = "super giant"
		
		else:
			planet_type = "other"
			
	else:
		# Make a random type first.
		planet_type_list  = [
			"sub dwarf",
			"dwarf",
			"super dwarf",
			"sub terrestrial",
			"terrestrial",
			"super terrestrial",
			"sub giant",
			"giant",
			"super giant",
		]
		planet_type = random_planet_val.choice(planet_type_list)

	
	planet_mass = get_planet_mass(planet_type)
	planet_size = get_planet_size(planet_type, planet_mass)
	
	# Define zones.
	planet_zone_size = planet_size * planet_zone_size_factor
	planet_death_zone = planet_size * planet_death_zone_factor
	
	planet_zone_margins = [planet_zone_size, planet_death_zone]
	
	planet = {
		"type" : planet_type,
		"size" : planet_size,
		"mass" : planet_mass,
		"zone_margins": planet_zone_margins,
	}
	
	return planet


def get_planet_mass(planet_type):
	planet_mass = 0
	
	if planet_type == "sub dwarf":
		planet_mass = random_planet_val.uniform(planet_sD_mass_min, planet_sD_mass_max)
	elif planet_type == "dwarf":
		planet_mass = random_planet_val.uniform(planet_D_mass_min, planet_D_mass_max)
	elif planet_type == "super dwarf":
		planet_mass = random_planet_val.uniform(planet_SD_mass_min, planet_SD_mass_max)

	elif planet_type == "sub terrestrial":
		planet_mass = random_planet_val.uniform(planet_sT_mass_min, planet_sT_mass_max)
	elif planet_type == "terrestrial":
		planet_mass = random_planet_val.uniform(planet_T_mass_min, planet_T_mass_max)
	elif planet_type == "super terrestrial":
		planet_mass = random_planet_val.uniform(planet_ST_mass_min, planet_ST_mass_max)
		
	elif planet_type == "sub giant":
		planet_mass = random_planet_val.uniform(planet_sG_mass_min, planet_sG_mass_max)
	elif planet_type == "giant":
		planet_mass = random_planet_val.uniform(planet_G_mass_min, planet_G_mass_max)
	elif planet_type == "super giant":
		planet_mass = random_planet_val.uniform(planet_SG_mass_min, planet_SG_mass_max)

	else:
		print("Unknown planet type: ", planet_type)

	planet_mass *= earth_mass
	return planet_mass
	

def get_planet_size(planet_type, planet_mass):
	planet_size = 0

	planet_mass /= earth_mass

	if planet_type == "sub dwarf" or \
		planet_type == "dwarf" or \
		planet_type == "super dwarf" or \
		planet_type == "sub terrestrial" or \
		planet_type == "terrestrial" or \
		planet_type == "super terrestrial":
			
		planet_size = pow(planet_mass, planet_rocky_radius_factor) * earth_radius * 2

	elif planet_type == "sub giant":
		planet_size = pow(planet_mass, planet_sub_giant_radius_factor) * earth_radius * 2

	elif planet_type == "giant" or \
		planet_type == "super giant":

		planet_size = random_planet_val.uniform(planet_G_radius_min, planet_G_radius_max) * earth_radius * 2
	
	else:
		print("Unknown planet type: ", planet_type)
	
	return planet_size


def sort_orbits(planet_list, orbit_list, main_star, Lmax):
	# Hill radii.
	hill_radii_list = []
	for i in range(len(orbit_list)):
		planet = planet_list[i]
		orbit = orbit_list[i]
		hr = orbit * pow((planet["mass"] / 3 / (planet["mass"] + main_star["mass"])), (1/3))
		hill_radii_list.append(hr)
	
	# Remove gas giants past some threshold by changung its type.
	threshold = main_star["zone_margins"][0] * gas_giant_spawn_distance_factor
	for i in range(len(orbit_list)):
		planet = planet_list[i]
		orbit = orbit_list[i]
		if orbit >= threshold:
			if planet["type"] == "sub giant" or \
				planet["type"] == "giant" or \
				planet["type"] == "super giant": 
					
					# Change gas planet for tge dwarf planet.
					planet_list[i]["type"] = random_planet_val.choice(["sub dwarf", "dwarf", "super dwarf"])
					planet_list[i]["mass"] = get_planet_mass(planet_list[i]["type"])
					planet_list[i]["size"] = get_planet_size(planet_list[i]["type"], planet_list[i]["mass"])
					#print("Changing planet type past threshold at:", e(threshold), planet_list[i]["type"])
	
	# Remove small planets between giants.
	i = 0
	while i < len(planet_list)-2:
		if planet_list[i+1]["type"] == "sub dwarf" or \
		planet_list[i+1]["type"] == "dwarf" or \
		planet_list[i+1]["type"] == "super dwarf" or \
		planet_list[i+1]["type"] == "sub terrestrial" or \
		planet_list[i+1]["type"] == "terrestrial" or \
		planet_list[i+1]["type"] == "super terrestrial":
			
			if planet_list[i]["type"] == "sub giant" or \
			planet_list[i]["type"] == "giant" or \
			planet_list[i]["type"] == "super giant":
				if planet_list[i+2]["type"] == "sub giant" or \
				planet_list[i+2]["type"] == "giant" or \
				planet_list[i+2]["type"] == "super giant":
					
					#print("removing:", planet_list[i+1]["type"], "between:", planet_list[i]["type"], "and", planet_list[i+2]["type"])
					planet_list[i+1]["type"] = "- empty orbit -"
					planet_list[i+1]["mass"] = 0
					planet_list[i+1]["size"] = 0
					hill_radii_list[i+1] = 0
					i = 0
			
		i += 1
	
	# Remove small planets between hot-cold giants and frost line (migration).
	for i in range(len(orbit_list)):
		if orbit_list[i] < main_star["zone_margins"][0]:
			if planet_list[i]["type"] == "sub giant" or \
			planet_list[i]["type"] == "giant" or \
			planet_list[i]["type"] == "super giant":
				
				k = i + 1# start checking planets ahead of i.
				k_max = len(orbit_list) - 1
				if k < k_max - i - 1:
					while orbit_list[k] < main_star["zone_margins"][0] and k < k_max:
						# Remove all the small planets.
						if planet_list[k]["type"] == "sub dwarf" or \
						planet_list[k]["type"] == "dwarf" or \
						planet_list[k]["type"] == "super dwarf" or \
						planet_list[k]["type"] == "sub terrestrial" or \
						planet_list[k]["type"] == "terrestrial" or \
						planet_list[k]["type"] == "super terrestrial": 
							
							planet_list[k]["type"] = "- empty orbit -"
							planet_list[k]["mass"] = 0
							planet_list[k]["size"] = 0
							hill_radii_list[k] = 0
							
						k += 1
					
	# Check for intersecting HR.
	for i in range(len(orbit_list)-1):
		# Find the distance between neighbiring orbits.
		orbit_distance = orbit_list[i+1] - orbit_list[i]
		# Get respective Hill radii.
		hr1 = hill_radii_list[i]
		hr2 = hill_radii_list[i+1]
		# Check if Hill radii overlap within said orbits.
		if (hill_radii_stability_multiplier*hr1 + hill_radii_stability_multiplier*hr2) > orbit_distance:
			# print("Hill radii overlap:", planet_list[i]["type"], planet_list[i+1]["type"], e(hr1), e(hr2), e(orbit_distance))
			# Eject smaller planet.
			if planet_list[i]["mass"] < planet_list[i+1]["mass"]:
				planet_list[i]["type"] = "- empty orbit -"
				planet_list[i]["mass"] = 0
				planet_list[i]["size"] = 0
				hill_radii_list[i] = 0
			else:
				planet_list[i+1]["type"] = "- empty orbit -"
				planet_list[i+1]["mass"] = 0
				planet_list[i+1]["size"] = 0
				hill_radii_list[i+1] = 0
	
	return planet_list


def generate_semi_major_axes(N, Lmin, Lmax, resonance_ratio):
	semi_major_axes = [Lmin]  # Start with the minimum distance as the first orbit
	
	# print("Initial orbit ranges:", "Lmin:", round(Lmin/sun_distance_au, 3), "Lmax", round(Lmax/sun_distance_au, 3), "AU")

	for i in range(1, N):
		prev_axis = semi_major_axes[i-1]
		semi_major_axis = prev_axis * resonance_ratio
		semi_major_axes.append(semi_major_axis)

	# Scale the semi-major axes to fit within the desired range (Lmin to Lmax)
	range_span = Lmax - Lmin
	axes_span = max(semi_major_axes) - min(semi_major_axes)
	scaling_factor = range_span / axes_span
	if scaling_factor < 1.0:
		scaling_factor = 1.0
	semi_major_axes = [axis * scaling_factor for axis in semi_major_axes]

	return semi_major_axes
	

def get_planet_temperature_list(orbit_list, planet_list, main_star):
	# flux = sigma * T^4
	# T = (flux / sigma)^(1/4)
	# zones : type
	#	> star_frost_line		:	icy
	#	< star_frost_line		:	cold
	#	< star_temperate_zone	:	temperate
	#	< star_warm_zone		:	warm
	#	< star_hot_zone			:	hot
	#	< star_dust_melting		:	very hot
	#	< star_death_zone		:	evaporated
	
	temperature_list = []
	temperature_type = ""
	
	
	for i in range(len(orbit_list)):
		current_orbit = orbit_list[i]
		# Get the flux and temperature at said orbit.
		orbit_flux = main_star["luminosity"] / (4 * 3.14 * current_orbit * current_orbit)
		orbit_temperature = round(pow((orbit_flux / SB_sigma), 0.25), 2)
		orbit_temperature_c = round(orbit_temperature - 273.15, 2)
		
		if current_orbit < main_star["zone_margins"][5]:
			temperature_type = "evaporated"
		elif current_orbit < main_star["zone_margins"][4]:
			temperature_type = "very hot"	
		elif current_orbit < main_star["zone_margins"][3]:
			temperature_type = "hot"	
		elif current_orbit < main_star["zone_margins"][2]:
			temperature_type = "warm"	
		elif current_orbit < main_star["zone_margins"][1]:
			temperature_type = "temperate"	
		elif current_orbit < main_star["zone_margins"][0]:
			temperature_type = "cold"	
		elif current_orbit > main_star["zone_margins"][0]:
			temperature_type = "icy"

		# print(planet_list[i]["type"],temperature_type, round(current_orbit/sun_distance_au, 3), "AU,", "t.:", orbit_temperature, "K,", orbit_temperature_c, "C")

		temperature_list.append((temperature_type, orbit_temperature))

	return temperature_list


def get_planet_atmosphere(planet_list, temperature_list):
	return
	#for i in range(len(planet_list)):
		#if temperature_list[0][i] == 






########### STAR GENERATION #############

def make_star(user_defined_type, primary_star_type):
	global total_number_o_stars
	global total_number_b_stars
	global total_number_a_stars
	global total_number_f_stars
	global total_number_g_stars
	global total_number_k_stars
	global total_number_m_stars
	global total_number_other_stars
	global total_number_all_stars
	
	star_type = ''
	star_type_temp = -1
	star_type_id = -1 # For further sorting.
	star_size = 0
	star_lum = 0
	star_temp = 0
	star_temp_norm = 0
	
	# If the star is secondary - limit its class according to primary star.
	r = random_star_abundance.random()
	if user_defined_type :
		star_type = user_defined_type[0]
		star_type_temp = user_defined_type[1]
	else:
		# For secondary stars (if primary exists).
		if primary_star_type:
			if r < star_o_abundance and primary_star_type[0] == 'O' and primary_star_type[1] > 0:
				star_type = ("O")
				star_type_id = 6
			elif r < star_b_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or (primary_star_type[0] == 'B' and primary_star_type[1] > 0)):
				star_type = ("B")
				star_type_id = 5
			elif r < star_a_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or (primary_star_type[0] == 'A' and primary_star_type[1] > 0)):
				star_type = ("A")
				star_type_id = 4
			elif r < star_f_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or (primary_star_type[0] == 'F' and primary_star_type[1] > 0)):
				star_type = ("F")
				star_type_id = 3
			elif r < star_g_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or (primary_star_type[0] == 'G' and primary_star_type[1] > 0)):
				star_type = ("G")
				star_type_id = 2
			elif r < star_k_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or primary_star_type[0] == 'G' or (primary_star_type[0] == 'K' and primary_star_type[1] > 0)):
				star_type = ("K")
				star_type_id = 1
			elif r <= star_m_abundance  and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or primary_star_type[0] == 'G' or primary_star_type[0] == 'K' \
					or primary_star_type[0] == 'M'): # Allows M9 star systems.
				star_type = ("M")
				star_type_id = 0
			else:
				star_type = ("Other")
				star_type_id = -1
		
		# For primary stars:
		else:
			if r < star_o_abundance :
				star_type = ("O")
				star_type_id = 6
			elif r < star_b_abundance :
				star_type = ("B")
				star_type_id = 5
			elif r < star_a_abundance :
				star_type = ("A")
				star_type_id = 4
			elif r < star_f_abundance :
				star_type = ("F")
				star_type_id = 3
			elif r < star_g_abundance :
				star_type = ("G")
				star_type_id = 2
			elif r < star_k_abundance :
				star_type = ("K")
				star_type_id = 1
			elif r <= star_m_abundance  :
				star_type = ("M")
				star_type_id = 0
			else:
				star_type = ("Other")
				star_type_id = -1
		
	# Make sure that if the star is secondary - it is less or equally bright than primary if in the same class.
	if primary_star_type and (star_type == primary_star_type[0]):
		star_type_temp = random_star_val.randint(int(primary_star_type[1]), 9)
		
	if star_type == "O":
		total_number_o_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_o_size_min), int(star_o_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_o_temp_min), int(star_o_temp_max))
		else:
			star_o_temp_min_type = (star_o_temp_max - star_o_temp_min) / 10 * (9-star_type_temp) + star_o_temp_min
			star_o_temp_max_type = (star_o_temp_max - star_o_temp_min) / 10 * (9-star_type_temp + 1) + star_o_temp_min
			star_temp = random_star_val.randrange(int(star_o_temp_min_type), int(star_o_temp_max_type))
		star_temp_norm = (star_temp - star_o_temp_min) / (star_o_temp_max - star_o_temp_min)
	elif star_type == "B":
		total_number_b_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_b_size_min), int(star_b_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_b_temp_min), int(star_b_temp_max))
		else:
			star_b_temp_min_type = (star_b_temp_max - star_b_temp_min) / 10 * (9-star_type_temp) + star_b_temp_min
			star_b_temp_max_type = (star_b_temp_max - star_b_temp_min) / 10 * (9-star_type_temp + 1) + star_b_temp_min
			star_temp = random_star_val.randrange(int(star_b_temp_min_type), int(star_b_temp_max_type))
		star_temp_norm = (star_temp - star_b_temp_min) / (star_b_temp_max - star_b_temp_min)
	elif star_type == "A":
		total_number_a_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_a_size_min), int(star_a_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_a_temp_min), int(star_a_temp_max))
		else:
			star_a_temp_min_type = (star_a_temp_max - star_a_temp_min) / 10 * (9-star_type_temp) + star_a_temp_min
			star_a_temp_max_type = (star_a_temp_max - star_a_temp_min) / 10 * (9-star_type_temp + 1) + star_a_temp_min
			star_temp = random_star_val.randrange(int(star_a_temp_min_type), int(star_a_temp_max_type))
		star_temp_norm = (star_temp - star_a_temp_min) / (star_a_temp_max - star_a_temp_min)
	elif star_type == "F":
		total_number_f_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_f_size_min), int(star_f_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_f_temp_min), int(star_f_temp_max))
		else:
			star_f_temp_min_type = (star_f_temp_max - star_f_temp_min) / 10 * (9-star_type_temp) + star_f_temp_min
			star_f_temp_max_type = (star_f_temp_max - star_f_temp_min) / 10 * (9-star_type_temp + 1) + star_f_temp_min
			star_temp = random_star_val.randrange(int(star_f_temp_min_type), int(star_f_temp_max_type))
		star_temp_norm = (star_temp - star_f_temp_min) / (star_f_temp_max - star_f_temp_min)
	elif star_type == "G":
		total_number_g_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_g_size_min), int(star_g_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_g_temp_min), int(star_g_temp_max))
		else:
			star_g_temp_min_type = (star_g_temp_max - star_g_temp_min) / 10 * (9-star_type_temp) + star_g_temp_min
			star_g_temp_max_type = (star_g_temp_max - star_g_temp_min) / 10 * (9-star_type_temp + 1) + star_g_temp_min
			star_temp = random_star_val.randrange(int(star_g_temp_min_type), int(star_g_temp_max_type))
		star_temp_norm = (star_temp - star_g_temp_min) / (star_g_temp_max - star_g_temp_min)
	elif star_type == "K":
		total_number_k_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_k_size_min), int(star_k_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_k_temp_min), int(star_k_temp_max))
		else:
			star_k_temp_min_type = (star_k_temp_max - star_k_temp_min) / 10 * (9-star_type_temp) + star_k_temp_min
			star_k_temp_max_type = (star_k_temp_max - star_k_temp_min) / 10 * (9-star_type_temp + 1) + star_k_temp_min
			star_temp = random_star_val.randrange(int(star_k_temp_min_type), int(star_k_temp_max_type))
		star_temp_norm = (star_temp - star_k_temp_min) / (star_k_temp_max - star_k_temp_min)
	elif star_type == "M":
		total_number_m_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_m_size_min), int(star_m_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_m_temp_min), int(star_m_temp_max))
		else:
			star_m_temp_min_type = (star_m_temp_max - star_m_temp_min) / 10 * (9-star_type_temp) + star_m_temp_min
			star_m_temp_max_type = (star_m_temp_max - star_m_temp_min) / 10 * (9-star_type_temp + 1) + star_m_temp_min
			star_temp = random_star_val.randrange(int(star_m_temp_min_type), int(star_m_temp_max_type))
		star_temp_norm = (star_temp - star_m_temp_min) / (star_m_temp_max - star_m_temp_min)
	else:
		total_number_other_stars += 1
		total_number_all_stars += 1
	
	star_type_temp = 9 - int(star_temp_norm*10)
	star_lum = get_strar_lum(star_size, star_temp)
	star_peak_wavelength = get_strar_peak_wavelength(star_temp)
	star_mass = get_star_mass(star_type, star_type_temp)
	
	# Godot parameters.
	star_omni_range = pow(star_lum/star_omni_ratio, 0.5)
	star_zone_margins = get_star_zone_margins(star_lum)
	
	star = {
		"type" : (star_type, star_type_temp, star_type_id),
		"size" : star_size,
		"mass" : star_mass,
		"luminosity" : star_lum,
		"temperature" : star_temp,
		"peak_wavelength":  star_peak_wavelength[0],
		"peak_wavelength_type":  star_peak_wavelength[1],
		"peak_wavelength_colorcode":  star_peak_wavelength[2],
		"omni_range": star_omni_range,
		"zone_margins": star_zone_margins,
	}
	
	return star

def get_star_zone_margins(star_lum):
	# Star death zone corresponds to  afistance where ship with coating should start to melt.
	star_death_zone =  pow(star_lum / (4 * 3.14 * melting_flux_average), 0.5)
	star_hot_zone = pow(star_lum /(4 * 3.14 * flux_hot_zone), 0.5)
	star_warm_zone = pow(star_lum /(4 * 3.14 * flux_warm_zone), 0.5)
	star_temperate_zone = pow(star_lum /(4 * 3.14 * flux_temperate_zone), 0.5)
	star_cold_zone = pow(star_lum /(4 * 3.14 * flux_cold_zone), 0.5)
	star_frost_line = pow(star_lum /(4 * 3.14 * flux_frost_line), 0.5)
	star_dust_melting = pow(star_lum /(4 * 3.14 * flux_dust_melting), 0.5)
	return (star_frost_line, star_cold_zone, star_temperate_zone, star_warm_zone, star_hot_zone, star_dust_melting, star_death_zone)
	
def get_strar_lum(star_size, star_temp):
	lum = c_lum * pow((star_size/2), 2) * pow(star_temp, 4)
	return lum
	
	
def get_strar_peak_wavelength(star_temp):
	peak_wavelength = 0
	peak_wavelength_type = ''
	peak_wavelength_colorcode = (0, 0, 0)
	
	if star_temp > 0:
		peak_wavelength = c_wien / star_temp
	
	if peak_wavelength < wl_xray_min:
		peak_wavelength_type  = "gamma"
	elif peak_wavelength >= wl_xray_min and peak_wavelength < wl_euv_min:
		peak_wavelength_type  = "x-ray"
	elif peak_wavelength >= wl_euv_min and peak_wavelength < wl_fuv_min:
		peak_wavelength_type  = "extreme UV"
	elif peak_wavelength >= wl_fuv_min and peak_wavelength < wl_muv_min:
		peak_wavelength_type  = "far UV"
	elif peak_wavelength >= wl_muv_min and peak_wavelength < wl_nuv_min:
		peak_wavelength_type  = "medium UV"
	elif peak_wavelength >= wl_nuv_min and peak_wavelength < wl_visible_min:
		peak_wavelength_type  = "near UV"
	elif peak_wavelength >= wl_visible_min and peak_wavelength < wl_nir_min:
		peak_wavelength_type  = "visible"
	elif peak_wavelength >= wl_nir_min and peak_wavelength < wl_swir_min:
		peak_wavelength_type  = "near IR"
	elif peak_wavelength >= wl_swir_min and peak_wavelength < wl_mwir_min:
		peak_wavelength_type  = "short IR"
	elif peak_wavelength >= wl_mwir_min and peak_wavelength < wl_lwir_min:
		peak_wavelength_type  = "medium IR"
	elif peak_wavelength >= wl_lwir_min and peak_wavelength < wl_fir_min:
		peak_wavelength_type  = "long IR"
	elif peak_wavelength >= wl_fir_min:
		peak_wavelength_type  = "far IR"
	elif peak_wavelength == 0:
		peak_wavelength_type  = " -- "
		
	# Get proper RGB from palette.
	if peak_wavelength > 0:
		wl_norm = (peak_wavelength - star_primary_wl_min) / (star_primary_wl_max - star_primary_wl_min)
		palette_index = (len(palettes.spectrum_palette)-1) - int(wl_norm*(len(palettes.spectrum_palette)-1)) # reverse spectrum.
		peak_wavelength_colorcode = palettes.spectrum_palette[palette_index]
		
	return (peak_wavelength, peak_wavelength_type, peak_wavelength_colorcode)


def random_star_number():
	num = int(
		pow(random_star_num.random(), 1.5) \
		* random_star_num.randint(num_stars_min, num_stars_max))
	return num

def get_star_mass(star_type, star_type_temp):
	star_mass = 0
	if star_type == "O":
		star_o_mass_min_type = (star_o_mass_max - star_o_mass_min) / 10 * (9-star_type_temp) + star_o_mass_min
		star_o_mass_max_type = (star_o_mass_max - star_o_mass_min) / 10 * (9-star_type_temp + 1) + star_o_mass_min
		star_mass = random_star_val.uniform((star_o_mass_min_type), (star_o_mass_max_type))
	elif star_type == "B":
		star_b_mass_min_type = (star_b_mass_max - star_b_mass_min) / 10 * (9-star_type_temp) + star_b_mass_min
		star_b_mass_max_type = (star_b_mass_max - star_b_mass_min) / 10 * (9-star_type_temp + 1) + star_b_mass_min
		star_mass = random_star_val.uniform((star_b_mass_min_type), (star_b_mass_max_type))
	elif star_type == "A":
		star_a_mass_min_type = (star_a_mass_max - star_a_mass_min) / 10 * (9-star_type_temp) + star_a_mass_min
		star_a_mass_max_type = (star_a_mass_max - star_a_mass_min) / 10 * (9-star_type_temp + 1) + star_a_mass_min
		star_mass = random_star_val.uniform((star_a_mass_min_type), (star_a_mass_max_type))
	elif star_type == "F":
		star_f_mass_min_type = (star_f_mass_max - star_f_mass_min) / 10 * (9-star_type_temp) + star_f_mass_min
		star_f_mass_max_type = (star_f_mass_max - star_f_mass_min) / 10 * (9-star_type_temp + 1) + star_f_mass_min
		star_mass = random_star_val.uniform((star_f_mass_min_type), (star_f_mass_max_type))
	elif star_type == "G":
		star_g_mass_min_type = (star_g_mass_max - star_g_mass_min) / 10 * (9-star_type_temp) + star_g_mass_min
		star_g_mass_max_type = (star_g_mass_max - star_g_mass_min) / 10 * (9-star_type_temp + 1) + star_g_mass_min
		star_mass = random_star_val.uniform((star_g_mass_min_type), (star_g_mass_max_type))
	elif star_type == "K":
		star_k_mass_min_type = (star_k_mass_max - star_k_mass_min) / 10 * (9-star_type_temp) + star_k_mass_min
		star_k_mass_max_type = (star_k_mass_max - star_k_mass_min) / 10 * (9-star_type_temp + 1) + star_k_mass_min
		star_mass = random_star_val.uniform((star_k_mass_min_type), (star_k_mass_max_type))
	elif star_type == "M":
		star_m_mass_min_type = (star_m_mass_max - star_m_mass_min) / 10 * (9-star_type_temp) + star_m_mass_min
		star_m_mass_max_type = (star_m_mass_max - star_m_mass_min) / 10 * (9-star_type_temp + 1) + star_m_mass_min
		star_mass = random_star_val.uniform((star_m_mass_min_type), (star_m_mass_max_type))

	return star_mass*sun_mass



######## NAME GENERATOR ##########

# Quantity according to frequency
# https://www3.nd.edu/~busiforc/handouts/cryptography/letterfrequencies.html
chars_low_v = "y"+"u"*2+"oi"*4+"a"*5+"e"*6
chars_low_c = "qjzx"+"vk"*5+"w"*7+"f"*9+"b"*11\
	+"g"*12+"hm"*15+"p"*16+"d"*17+"c"*23+"l"*28\
	+"s"*29+"n"*34+"t"*35+"r"*39

chars_low_c = ''.join(random_char.sample(chars_low_c,len(chars_low_c)))
chars_low_v = ''.join(random_char.sample(chars_low_v,len(chars_low_v)))

ABC = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']


def random_system_name(min, max):
	system_name = random_name(min, max)
	if not system_name in used_names:
		used_names.append(system_name)
	else:
		print("duplicate name: ", system_name)
		while system_name in used_names:
			system_name = random_name(min, max)
	return system_name

def random_name(length_max, length_min):
	length = random_char.randint(length_max, length_min)
	vowel_ratio = 0.5
	r = random_char.random()
	max_vowels_consequtive = 0
	max_cosonants_consequiteve = 0
	if r < 0.3:
		max_vowels_consequtive = 1
		max_cosonants_consequiteve = 2
	elif r > 0.3 and r < 0.6:
		max_vowels_consequtive = 2
		max_cosonants_consequiteve = 2
	else:
		max_vowels_consequtive = 1
		max_cosonants_consequiteve = 1
		length += 1
		
	num_v = 0
	num_c = 0
	str = ''
	for ch in range(length):
		r = random_char.random()
		if r < vowel_ratio:
			if num_v < max_vowels_consequtive:
				str += ''.join(random_char.choices(chars_low_v, k=1))
				num_v += 1
				num_c = 0
			else:
				str += ''.join(random_char.choices(chars_low_c, k=1))
				num_v = 0
				num_c += 1
		else:
			if num_c < max_cosonants_consequiteve:
				str += ''.join(random_char.choices(chars_low_c, k=1))
				num_c += 1
				num_v = 0
			else:
				str += ''.join(random_char.choices(chars_low_v, k=1))
				num_c = 0
				num_v += 1
	
	#str = str.replace("rs", "ras")
	if (str[0] in chars_low_c and str[1] in chars_low_c):
		str = str[1:]
	
	if  str[0] == 'x':
		str = str[1:]
		
	if  str[len(str)-1] == 'x':
		str = str[:len(str)-1]
		
	if  str[len(str)-1] == 'y':
		str = str[:len(str)-1]
	
	return str.capitalize()









######### FORMATTING FUNCTIONS ############

def formatting_system_data(star_id, system, main_star, star_name):
	star_type = main_star["type"]
	system_zone_size = e(main_star["omni_range"]) # use omni range instead.
	if float(system_zone_size) < system_zone_size_min:
		system_zone_size = e(system_zone_size_min)
		
	system_autopilot_range = system_zone_size
	
	# Temperature zoning.
	star_zone_margins = main_star["zone_margins"]
	star_dust_melting = round(star_zone_margins[5] / sun_distance_au, 3)
	star_hot_zone = round(star_zone_margins[4] / sun_distance_au, 3)
	star_warm_zone = round(star_zone_margins[3] / sun_distance_au, 3)
	star_temperate_zone = round(star_zone_margins[2] / sun_distance_au, 3)
	star_cold_zone = round(star_zone_margins[1] / sun_distance_au, 3)
	star_frost_line = round(star_zone_margins[0] / sun_distance_au, 3)
	
	p = ''
	p += "# System: " + star_name + "  \n"
	
	p += "<details><summary>" \
		+ "System data" \
		+  "</summary>" + "  \n\n"
		
	p += "#### System Infocard data"+ "  \n"
		
	p += "```" + "  \n"
	
	p += "Temperature zone data by main star:"+ "\n"
	p += "* Mineral melting line:"+ " < " + str(star_dust_melting) + " AU" + "\n"
	p += "* Hot zone   :"+ "   " + str(star_dust_melting) + " ... " + str(star_hot_zone) + " AU" + "\n"
	p += "* Warm zone  :"+ "   " + str(star_hot_zone) + " ... " + str(star_warm_zone) + " AU" + "\n"
	p += "* Temp. zone :"+ "   " + str(star_warm_zone) + " ... " + str(star_temperate_zone) + " AU" + "\n"
	p += "* Cold zone  :"+ "   " + str(star_temperate_zone) + " ... " + str(star_frost_line) + " AU" + "\n"
	p += "* Frost line :" + " > " + str(star_frost_line) + " AU" + "\n"
	p += "```" + "  \n"
	
	p += "```" + "  \n"
	p += "Дані температурного зонування відносно основної зірки:"+ "\n"
	p += "* Межа плавлення мінералів:"+ " < " + str(star_dust_melting) + " а.о." + "\n"
	p += "* Гаряча зона  :"+ "   " + str(star_dust_melting) + " ... " + str(star_hot_zone) + " а.о." + "\n"
	p += "* Тепла зона   :"+ "   " + str(star_hot_zone) + " ... " + str(star_warm_zone) + " а.о." + "\n"
	p += "* Помірна зона :"+ "   " + str(star_warm_zone) + " ... " + str(star_temperate_zone) + " а.о." + "\n"
	p += "* Холодна зона :"+ "   " + str(star_temperate_zone) + " ... " + str(star_cold_zone) + " а.о." + "\n"
	p += "* Межа кригоутворення :" + " > " + str(star_frost_line) + " а.о." + "\n"
	
	p += "```" + "  \n"
	
	p += "#### GODOT data"+ "  \n"
	
	p += "```" + "  \n"
	p += "* System ID: " + str(star_id) + "\n"
	
	if "cluster" in system:
		p += "* Star cluster: " + system["cluster"] + "\n"
	else:
		p += "* Star cluster: unspecified" + "\n"
	
	p += "* System zone codename: " + "STAR_" + str(star_id) + "_SYSTEM_ZONE" + "\n"
	p += "* System codename: " + "STAR_" +  str(star_id) + "_SYSTEM" + "\n"
	p += "* System translation name codename: " + "NAME_STAR_" + str(star_id) + "_SYSTEM" + "\n"
	p += "* System translation description codename: " + "DESC_STAR_" + str(star_id) + "_SYSTEM" + "\n"
	p += "* System name: " + star_name  + "\n"
	p += "* System description: see above. Optionally add lore." + "\n"
	p += "* System zone size: " + str(system_zone_size) + "\n"
	p += "* System autopilot range: " + str(system_autopilot_range) + "\n"

	p += "```" + "\n"
	p += "\n </details>" + "  \n"
	
	p += "\n---  \n"
	
	return p



def formatting_star_data(star_id, primary, main_star, star_name):
	p = ''
	
	if primary:
		star_in_system_hierarchy = "Primary star"
	else:
		star_in_system_hierarchy = "Secondary star"
	
	star_type = main_star["type"]
	# Format star size.
	star_size = e(main_star["size"])
	star_size_rel = round(main_star["size"] / sun_diameter, 3)
	
	star_mass = e(main_star["mass"])
	star_mass_rel = round(main_star["mass"] / sun_mass, 3)
	
	
	# Format the number back to proper range.
	star_lum = e(main_star["luminosity"])
	star_lum_rel = main_star["luminosity"] / sun_luminosity
	if star_lum_rel < 1:
		star_lum_rel = round(star_lum_rel, 3)
	elif star_lum_rel < 10:
		star_lum_rel = round(star_lum_rel, 2)
	elif star_lum_rel < 100:
		star_lum_rel = round(star_lum_rel, 1)
	else:
		star_lum_rel = round(star_lum_rel)
		
	# temperature values.
	star_temp = round(main_star["temperature"])
	star_temp_rel = round(main_star["temperature"] / sun_temperature, 2)
	star_zone_margins = main_star["zone_margins"]
	star_death_zone_size = star_zone_margins[6]

	# If star death zone is too small, tweak it.
	if star_death_zone_size < (star_death_zone_min_factor * float(star_size)):
		star_death_zone_size = star_death_zone_min_factor * float(star_size)
	
	# Death zone values.
	star_death_zone = round(star_death_zone_size / sun_distance_au, 3)
	star_death_zone_meters = e(star_death_zone_size)
	
	# Make zone size larger than death zone, if it is smaller.
	star_zone_size = e(star_zone_size_factor * float(star_size))
	if (star_zone_size_factor * float(star_size)) < star_death_zone_size:
		star_zone_size = e(star_death_zone_size * star_zone_size_by_death_zone_factor)
	
	# Auopilot approach range, limited by death zone + comfortable margin.
	star_autopilot_range = e(star_death_zone_size  * star_autopilot_factor)
	
	# Sprite flare distance, handy to depict the entrance to star zone.
	star_flare_distance = e(float(star_zone_size)  * star_flare_factor)
	
	
	
	# Wavelength data.
	star_peak_wavelength = round(main_star["peak_wavelength"], 0)
	star_peak_wavelength_type = main_star["peak_wavelength_type"]
	star_peak_wavelength_colorcode = main_star["peak_wavelength_colorcode"]
	star_peak_wavelength_colorcode_hex = rgb_to_hex(star_peak_wavelength_colorcode)
	star_omni_range = e(main_star["omni_range"])
	
	
	color_sample = "![" + str(star_peak_wavelength_colorcode_hex)  + "]" \
		+ "(Colors/" + str(star_peak_wavelength_colorcode_hex)  + ".png)"
		
	p += "<details><summary>" \
		+ star_in_system_hierarchy  + " : " \
		+ star_name + ", type: " \
		+ star_type[0] + str(star_type[1]) \
		+  "</summary>" + "  \n\n"
	
	p += "#### Star pseudo-color" + "  \n"

	p += color_sample + "  \n"
	
	p += "#### Star Infocard data"+ "  \n"
	
	p += "```" + "  \n"
	
	p += "Absolute units:" + "\n"
	p += "* Size: " + str(star_size) + " m" + "\n"
	p += "* Mass: " + str(star_mass) + " kg" + "\n"
	p += "* Temperature: " + str(star_temp) + " K" + "\n"
	p += "* Luminosity: " + str(star_lum) + " W" + "\n"*2
	
	p += "Sun-relative units:" + "\n"
	p += "* Size: " + str(star_size_rel) + " D" + "\n"
	p += "* Mass: " + str(star_mass_rel) + " M" + "\n"
	p += "* Temperature: " + str(star_temp_rel) + " T" + "\n"
	p += "* Luminosity: " + str(star_lum_rel) + " L" + "\n"*2
	
	p += "Spectral data:"+ "\n"
	p += "* Type: " + star_type[0] + str(star_type[1]) + "\n"
	p += "* Peak wavelength: " + str(star_peak_wavelength) + " nm"+ "\n"
	p += "* Peak wavelength type: " + star_peak_wavelength_type + "\n"*2
	p += "```" + "  \n"
	
	
	p += "```" + "  \n"
	p += "Абсолютні величини:" + "\n"
	p += "* Розмір: " + str(star_size) + " м" + "\n"
	p += "* Маса: " + str(star_mass) + " кг" + "\n"
	p += "* Температура: " + str(star_temp) + " К" + "\n"
	p += "* Світність: " + str(star_lum) + " Вт" + "\n"*2
	
	p += "Величини відносно Сонця:" + "\n"
	p += "* Розмір: " + str(star_size_rel) + " D" + "\n"
	p += "* Маса: " + str(star_mass_rel) + " M" + "\n"
	p += "* Температура: " + str(star_temp_rel) + " T" + "\n"
	p += "* Світність: " + str(star_lum_rel) + " L" + "\n"*2
	
	p += "Спектральні дані:"+ "\n"
	p += "* Тип: " + star_type[0] + str(star_type[1]) + "\n"
	p += "* Пікова довжина хвилі: " + str(star_peak_wavelength) + " нм"+ "\n"
	p += "* Тип пікового випромінювання: " + star_peak_wavelength_type + "\n"*2
	
	p += "```" + "  \n"
	
	p += "#### GODOT data"+ "  \n"
	
	p += "```" + "  \n"
	
	p += "* Star zone codename: " + "STAR_" + str(star_id) + "_ZONE" + "\n"
	p += "* Star codename: " + "STAR_" + str(star_id)  + "\n"
	p += "* Star translation name codename: " + "NAME_STAR_" + str(star_id)  + "\n"
	p += "* Star translation description codename: " + "DESC_STAR_" +  str(star_id) + "\n"
	p += "* Star name: " + star_name  + "\n"
	p += "* Star description: see above." + "\n"
	p += "* Star zone size: " + str(star_zone_size) + "\n"
	p += "* Star death zone size: " + str(star_death_zone_meters) + "\n"
	p += "* Star size: " + str(star_size) + "\n"
	p += "* Star flare distance: " + str(star_flare_distance) + "\n"
	p += "* Star autopilot range: " + str(star_autopilot_range) + "\n"
	
	p += "\n"
	
	p += "* Omni range: " + str(star_omni_range) + "\n"
	p += "* Omni attenuation: " + str(sun_omni_attenuation) + "\n"
	p += "* Omni energy: " + str(sun_omni_energy) + "\n"
	p += "* Surface color (Peak w.l. color code):" + "\n"
	p += " - rgb: " + str(star_peak_wavelength_colorcode) + "\n"
	p += " - hex: #" + str(star_peak_wavelength_colorcode_hex) + "\n"
	
	p += "```" + "  \n"
	
	p += "\n </details>" + "  \n"
	
	p += "\n---  \n"
	
	return (p, color_sample)


def formatting_planet_data(star_name, star_type, planetary_data):
	p =""
	
	for i in range(len(planetary_data)):
		planet = planetary_data[i]
		planet_order_letter = ABC[i].lower()
		
		#"type"
		#"size"
		#"mass"
		#"zone_margins" [planet_zone_size, planet_death_zone]
		#"orbit"
		#"temperature_type"
		#"temperature" [temperature_type, orbit_temperature]
		
		# Re-assigning those for the sake of tweking the terminology.
		planet_type = planet["type"]
		planet_type_ua = ""
		if planet_type == "sub dwarf":
			planet_type_ua = "мала карликова планета"
		elif planet_type == "dwarf":
			planet_type_ua = "карликова планета"
		elif planet_type == "super dwarf":
			planet_type_ua = "велика карликова планета"
		elif planet_type == "sub terrestrial":
			planet_type_ua = "мала землеподібна планета"
		elif planet_type == "terrestrial":
			planet_type_ua = "землеподібна планета"
		elif planet_type == "super terrestrial":
			planet_type_ua = "велика землеподібна планета"
		elif planet_type == "sub giant":
			planet_type_ua = "планета малий гігант"
		elif planet_type == "giant":
			planet_type_ua = "планета гігант"
		elif planet_type == "super giant":
			planet_type_ua = "планета великий гігант"
			
		planet_type_en = ""
		if planet_type == "sub dwarf":
			planet_type_en = "small dwarf planet"
		elif planet_type == "dwarf":
			planet_type_en = "dwarf planet"
		elif planet_type == "super dwarf":
			planet_type_en = "large dwarf planet"
		elif planet_type == "sub terrestrial":
			planet_type_en = "small terrestrial planet"
		elif planet_type == "terrestrial":
			planet_type_en = "terrestrial planet"
		elif planet_type == "super terrestrial":
			planet_type_en = "large terrestrial planet"
		elif planet_type == "sub giant":
			planet_type_en = "small giant planet"
		elif planet_type == "giant":
			planet_type_en = "giant planet"
		elif planet_type == "super giant":
			planet_type_en = "large giant planet"
			
		planet_temperature_type = planet["temperature_type"]
		if planet_temperature_type == "evaporated":
			planet_temperature_type_ua = "планета, що випаровується"
		elif planet_temperature_type == "very hot":
			planet_temperature_type_ua = "дуже гаряча"
		elif planet_temperature_type == "hot":
			planet_temperature_type_ua = "гаряча"
		elif planet_temperature_type == "warm":	
			planet_temperature_type_ua = "тепла"
		elif planet_temperature_type == "temperate":	
			planet_temperature_type_ua = "помірна"
		elif planet_temperature_type == "cold":	
			planet_temperature_type_ua = "холодна"
		elif planet_temperature_type == "icy":
			planet_temperature_type_ua = "льодяна"
		
				
		planet_orbit = e(planet["orbit"])
		planet_orbit_au = round(planet["orbit"] / sun_distance_au, 3)
		planet_temperature_abs = round(planet["temperature"], 2)
		planet_temperature_celsius =  round(planet["temperature"] - 273.15, 2)
		# Size is diameter.
		planet_size = e(planet["size"])
		planet_size_earth = round(planet["size"] / (earth_radius * 2), 3)
		planet_mass = e(planet["mass"])
		planet_mass_earth = round(planet["mass"] / earth_mass, 5)
		# Godot data
		planet_zone_size = e(planet["zone_margins"][0])
		planet_death_zone = e(planet["zone_margins"][1])
		planet_autopilot_range = e(planet_autopilot_factor*planet["zone_margins"][1])

		p += "<details><summary>" \
			+ "Planet " \
			+ star_name + " " + planet_order_letter \
			+ " (" + str(planet_temperature_type) + " " + str(planet_type_en) + ")" \
			+  "</summary>" + "  \n\n"
		
		p += "#### Planet albedo" + "  \n"
	
		p += "WIP" + "  \n"
		
		p += "#### Planet Infocard data"+ "  \n"
		
		p += "```" + "  \n"
		p += "Planet type: " + str(planet_temperature_type + " " + planet_type_en) + "\n"*2
		
		p += "Absolute units:" + "\n"
		p += "* Size: " + str(planet_size) + " m" + "\n"
		p += "* Mass: " + str(planet_mass) + " kg" + "\n"
		p += "* Temperature: " + str(planet_temperature_abs) + " K" + "\n"
		p += "* Orbit semi-major axis: " + str(planet_orbit) + " m" + "\n"*2
		
		p += "Earth-relative units:" + "\n"
		p += "* Size: " + str(planet_size_earth) + " D" + "\n"
		p += "* Mass: " + str(planet_mass_earth) + " M" + "\n"
		p += "* Temperature: " + str(planet_temperature_celsius) + " C" + "\n"
		p += "* Orbit semi-major axis: " + str(planet_orbit_au) + " AU" + "\n"*2
		p += "```" + "  \n"
		
		p += "```" + "  \n"
		p += "Тип планети: " + str(planet_temperature_type_ua + " " + planet_type_ua) + "\n"*2
		
		p += "Абсолютні величини:" + "\n"
		p += "* Розмір: " + str(planet_size) + " м" + "\n"
		p += "* Маса: " + str(planet_mass) + " кг" + "\n"
		p += "* Температура: " + str(planet_temperature_abs) + " К" + "\n"
		p += "* Велика піввісь орбіти: " + str(planet_orbit) + " м" + "\n"*2
		
		p += "Величини відносно Землі:" + "\n"
		p += "* Розмір: " + str(planet_size_earth) + " D" + "\n"
		p += "* Маса: " + str(planet_mass_earth) + " M" + "\n"
		p += "* Температура: " + str(planet_temperature_celsius) + " C" + "\n"
		p += "* Велика піввісь орбіти: " + str(planet_orbit_au) + " а.о." + "\n"*2
		p += "```" + "  \n"
		
		p += "#### GODOT data"+ "  \n"
		
		p += "```" + "  \n"
		
		p += "* Planet zone codename: " + "STAR_" + str(star_id) + "_PLANET_" + str(i) + "_ZONE" + "\n"
		p += "* Planet codename: " + "STAR_"  + str(star_id)  + "_PLANET_" + str(i) + "\n"
		p += "* Planet translation name codename: " + "NAME_STAR_" + str(star_id)  + "_PLANET_" + str(i) + "\n"
		p += "* Planet translation description codename: " + "DESC_STAR_" + str(star_id) + "_PLANET_" + str(i)  + "\n"
		p += "* Planet name: " + star_name + " " + planet_order_letter + "\n"
		p += "* Planet description: see above." + "\n"
		p += "* Planet zone size: " + str(planet_zone_size) + "\n"
		p += "* Planet death zone size: " + str(planet_death_zone) + "\n"
		p += "* Planet size: " + str(planet_size) + "\n"
		p += "* Planet autopilot range: " + str(planet_autopilot_range) + "\n"
		p += "* Planet semi-major axis: " + str(planet_orbit) + "\n"		

		p += "\n"
		
		p += "* Surface color (albedo):" + "\n"
		p += " - rgb: " + "WIP" + "\n"
		p += " - hex: #" + "WIP" + "\n"
		
		p += "```" + "  \n"
		
		p += "\n </details>" + "  \n"
		
		p += "\n---  \n"
	

	return p

















################### GENERATE TEST ####################
print("Generation begin: FROM TEST PRESET")
for star_id in range(len(universe_test_presets.systems)):
	system_generation(star_id, universe_test_presets.systems[star_id], '')
			
print("Total number of stars:")
print("O - ", total_number_o_stars)
print("B - ", total_number_b_stars)
print("A - ", total_number_a_stars)
print("F - ", total_number_f_stars)
print("G - ", total_number_g_stars)
print("K - ", total_number_k_stars)
print("M - ", total_number_m_stars)
print("Other - ", total_number_other_stars)
print("All - ", total_number_all_stars)
print("Generation done: Universe/Universe_test.md")
print()


f = open(cwd + "/Doc/Universe/Universe_test.md", "w")
f.write(output)
f.close()
#print(output)
	


################### GENERATE PRESET ###################
# Reset generators in order to not to affect new entities.
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char


random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')


output = ''

total_number_o_stars = 0
total_number_b_stars = 0
total_number_a_stars = 0
total_number_f_stars = 0
total_number_g_stars = 0
total_number_k_stars = 0
total_number_m_stars = 0
total_number_other_stars = 0
total_number_all_stars = 0

print("Generation begin: FROM PRESET")
for star_id in range(len(universe_presets.systems)):
	system_generation(star_id, universe_presets.systems[star_id], '')
			
print("Total number of stars:")
print("O - ", total_number_o_stars)
print("B - ", total_number_b_stars)
print("A - ", total_number_a_stars)
print("F - ", total_number_f_stars)
print("G - ", total_number_g_stars)
print("K - ", total_number_k_stars)
print("M - ", total_number_m_stars)
print("Other - ", total_number_other_stars)
print("All - ", total_number_all_stars)
print("Generation done: Universe/Universe_user_defined.md")
print()


f = open(cwd + "/Doc/Universe/Universe_user_defined.md", "w")
f.write(output)
f.close()
#print(output)



###################### GENERATE RANDOM ####################
# Reset generators in order to not to affect new entities.
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char


random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')


output = ''

total_number_o_stars = 0
total_number_b_stars = 0
total_number_a_stars = 0
total_number_f_stars = 0
total_number_g_stars = 0
total_number_k_stars = 0
total_number_m_stars = 0
total_number_other_stars = 0
total_number_all_stars = 0

print("Generation begin: RANDOM")
for cluster in universe_presets.clusters:
	generated_stars = 0
	cluster_name = cluster[0]
	cluster_stars = cluster[1]
	while generated_stars < cluster_stars:
		star_id = generated_stars
		system_generation(star_id, {}, cluster_name)
		generated_stars += 1
	
print("Total number of stars:")
print("O - ", total_number_o_stars)
print("B - ", total_number_b_stars)
print("A - ", total_number_a_stars)
print("F - ", total_number_f_stars)
print("G - ", total_number_g_stars)
print("K - ", total_number_k_stars)
print("M - ", total_number_m_stars)
print("Other - ", total_number_other_stars)
print("All - ", total_number_all_stars)
print("Generation done: Universe/Universe_random_reference.md")


f = open(cwd + "/Doc/Universe/Universe_random_reference.md", "w")
f.write(output)
f.close()
#print(output)

--- Start of ./python_sandbox/tools/universe_generator_legacy/universe_presets.py ---

######################################
# Editable section - presets.
######################################


# Specify the cluster and a number of systems in it.
# Those systems will be written in Universe/Universe_random.md
clusters = [
	("Moirai", 200),
]

# If user_defined stars and planets are set - they will be written to
# Universe/Universe_preset.md
systems = [

	{
		"cluster" : "Moirai",
		"name" : "Victory",
		"main_star" : ("B", 7),
		"companion_stars" : [("G", 8),],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Equberan",
		"main_star" : ("A", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Selk'nam", # Make reference-trubute to a tribe.
		"main_star" : ("M", 9), # Try brown dwarf later on.
		"companion_stars" : [],
		# Asteroid belt and debris instead of planets.
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Valeri",
		"main_star" : ("A", 9),
		"companion_stars" : [("M", 9),], # Change Valeri B to white dwarf.
	},
	
	{
		"cluster" : "Global nebula",
		"name" : "Viakata", # A starting point in the game, give info as such.
		"main_star" : ("M", 2),
		"companion_stars" : [],
		"total_planets" : ["SD", "D", "ST", "D", ],
		"closest_orbit" : 0,
		"furthest_orbit" : 3e10,
		"orbit_ratio" : 2.0 # 1.33 | 1.5 | 2.0
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Glory",
		"main_star" : ("G", 9),
		"companion_stars" : [],
		"total_planets" : [],
	},
	
	{
		"cluster" : "", # Most likely outside of Moirai.
		"name" : "Hilicele", # In lore this will be the system where X are first found.
		"main_star" : ("F", 7),
		"companion_stars" : [],
	},
	
]

--- Start of ./python_sandbox/tools/universe_generator_legacy/universe_test_presets.py ---

######################################
# Editable section - presets. TEST.
######################################

systems = [

	###### TYPE O ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("O", 9),
		"companion_stars" : [],
	},
	
	###### TYPE B ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("B", 9),
		"companion_stars" : [],
	},
	
	###### TYPE A ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("A", 9),
		"companion_stars" : [],
	},
	
	
	###### TYPE F ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("F", 9),
		"companion_stars" : [],
	},
	
	###### TYPE G ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("G", 9),
		"companion_stars" : [],
	},
	
	
	###### TYPE K ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("K", 9),
		"companion_stars" : [],
	},
	
	###### TYPE M ######
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 0),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 1),
		"companion_stars" : [],
	},

	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 3),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 4),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 5),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 6),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 8),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Test",
		"main_star" : ("M", 9),
		"companion_stars" : [],
	},
	
]
