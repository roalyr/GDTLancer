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
