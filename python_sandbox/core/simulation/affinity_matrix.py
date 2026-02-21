"""
GDTLancer Affinity Matrix — tag-based "chemical" reactive decision layer.

Entities (agents AND sectors) carry qualitative tags derived from their
properties. A global AFFINITY_MATRIX defines numeric attraction/repulsion
scores between specific tag pairs. Agents scan their environment, compute
aggregate affinity scores, and act on the highest-magnitude result.

This replaces role-based hardcoded if/elif goal evaluation with a unified
score → action-type → simple-mechanical-handler pipeline.

Design principles (from Concept_injection.md):
  - Linear development complexity: new behaviors = new matrix rows
  - Low overhead: basic arithmetic + local scanning
  - Emergent narrative: behaviors emerge from overlapping tag affinities

PROJECT: GDTLancer
MODULE: core/simulation/affinity_matrix.py
STATUS: Level 2 - Implementation
TRUTH_LINK: Concept_injection.md
"""

from autoload.game_state import GameState

# =========================================================================
# AFFINITY MATRIX
# =========================================================================
# Key: (actor_tag, target_tag) → float score
# Positive = attracted / wants to engage
# Negative = repelled / wants to flee
#
# Score magnitudes determine action type:
#   |score| >= ATTACK_THRESHOLD  → ATTACK (agent) or HARVEST (resource)
#   TRADE_THRESHOLD <= score < ATTACK_THRESHOLD → TRADE / DOCK
#   score <= FLEE_THRESHOLD → FLEE
#   |score| < TRADE_THRESHOLD → IDLE / wander

AFFINITY_MATRIX = {
    # --- Pirate behaviors ---
    ("PIRATE", "TRADER"):           0.8,    # Pirates hunt traders
    ("PIRATE", "HAULER"):           0.7,    # Pirates hunt haulers
    ("PIRATE", "WEALTHY"):          1.0,    # Pirates love wealthy targets
    ("PIRATE", "LOADED"):           1.2,    # Pirates love cargo-laden targets
    ("PIRATE", "WEAK"):             0.8,    # Pirates prey on the weak
    ("PIRATE", "MILITARY"):        -1.2,    # Pirates avoid military
    ("PIRATE", "SECURE"):          -0.8,    # Pirates avoid secure sectors
    ("PIRATE", "DANGEROUS"):       -0.3,    # Pirates wary of hostile-infested areas
    ("PIRATE", "STATION"):          0.3,    # Pirates linger near stations for prey
    ("PIRATE", "LOW_SECURITY"):     0.9,    # Pirates gravitate to lawless sectors

    # --- Aggressive behaviors ---
    ("AGGRESSIVE", "WEAK"):         1.0,    # Aggressive entities target the weak
    ("AGGRESSIVE", "LOADED"):       0.6,    # Aggressive entities want loaded targets
    ("AGGRESSIVE", "MILITARY"):    -0.4,    # Even aggressors respect military

    # --- Greedy behaviors ---
    ("GREEDY", "WEALTHY"):          0.9,    # Greedy entities pursue wealth
    ("GREEDY", "MARKET_HUB"):       0.7,    # Greedy entities want trade centers
    ("GREEDY", "LOADED"):           0.6,    # Greedy entities eye cargo

    # --- Trader behaviors ---
    ("TRADER", "STATION"):          0.8,    # Traders want stations
    ("TRADER", "MARKET_HUB"):       1.0,    # Traders love trade hubs
    ("TRADER", "DANGEROUS"):       -1.0,    # Traders avoid danger
    ("TRADER", "LOW_SECURITY"):    -0.6,    # Traders prefer safety
    ("TRADER", "PIRATE"):          -1.2,    # Traders flee pirates
    ("TRADER", "RESOURCE_RICH"):    0.4,    # Traders seek resource-rich areas (cheap goods)

    # --- Hauler behaviors ---
    ("HAULER", "SURPLUS"):          1.0,    # Haulers seek surplus sectors
    ("HAULER", "DEFICIT"):          0.8,    # Haulers deliver to deficit sectors
    ("HAULER", "STATION"):          0.5,    # Haulers dock at stations
    ("HAULER", "DANGEROUS"):       -0.8,    # Haulers avoid danger
    ("HAULER", "PIRATE"):          -1.0,    # Haulers flee pirates

    # --- Prospector behaviors ---
    ("PROSPECTOR", "RESOURCE_RICH"):  1.5,  # Prospectors love resources
    ("PROSPECTOR", "FRONTIER"):       0.8,  # Prospectors like frontiers
    ("PROSPECTOR", "HAS_WRECKS"):     0.7,  # Prospectors salvage wrecks
    ("PROSPECTOR", "DANGEROUS"):     -0.6,  # Prospectors cautious of danger
    ("PROSPECTOR", "SECURE"):         0.4,  # Prospectors prefer security for salvage

    # --- Military / Patrol behaviors ---
    ("MILITARY", "DANGEROUS"):       1.5,   # Military drawn to danger
    ("MILITARY", "PIRATE_ACTIVITY"):  1.5,  # Military hunts piracy
    ("MILITARY", "HOSTILE_INFESTED"): 1.2,  # Military fights hostiles
    ("MILITARY", "LOW_SECURITY"):     1.0,  # Military patrols lawless areas
    ("MILITARY", "SECURE"):          -0.3,  # Military less interested in safe areas
    ("MILITARY", "PIRATE"):           1.5,  # Military attacks pirates

    # --- Explorer behaviors ---
    ("EXPLORER", "FRONTIER"):         1.5,  # Explorers love frontiers
    ("EXPLORER", "RESOURCE_RICH"):    0.5,  # Explorers interested in resources
    ("EXPLORER", "SECURE"):          -0.3,  # Explorers bored by safety
    ("EXPLORER", "DANGEROUS"):        0.3,  # Explorers tolerate danger

    # --- Coward behaviors ---
    ("COWARD", "DANGEROUS"):         -1.5,  # Cowards flee danger
    ("COWARD", "PIRATE"):            -1.5,  # Cowards flee pirates
    ("COWARD", "HOSTILE_INFESTED"):  -1.2,  # Cowards flee hostiles
    ("COWARD", "SECURE"):             0.5,  # Cowards seek safety
    ("COWARD", "STATION"):            0.6,  # Cowards hide at stations

    # --- Station/sector interactions ---
    ("DESPERATE", "STATION"):         1.5,  # Desperate agents rush to stations
    ("DESPERATE", "SECURE"):          0.8,  # Desperate agents seek safety
    ("WEAK", "STATION"):              0.6,  # Weak agents gravitate to stations
    ("WEAK", "SECURE"):               0.4,  # Weak agents seek safety

    # --- Scavenger behaviors ---
    ("SCAVENGER", "HAS_WRECKS"):      1.5,  # Scavengers hunt wrecks
    ("SCAVENGER", "DANGEROUS"):      -0.5,  # Scavengers wary of danger

    # --- Loyalty/faction ---
    ("LOYAL", "STATION"):             0.4,  # Loyal agents prefer their stations
    ("LOYAL", "MILITARY"):            0.3,  # Loyal like military presence
}


# =========================================================================
# SCORE THRESHOLDS — determine action type from aggregate score
# =========================================================================
ATTACK_THRESHOLD = 1.5    # score >= this → ATTACK (agent) or HARVEST (resource)
TRADE_THRESHOLD = 0.5     # score >= this → TRADE/DOCK
FLEE_THRESHOLD = -1.0     # score <= this → FLEE
# |score| < TRADE_THRESHOLD → IDLE / wander


# =========================================================================
# TAG DERIVATION: personality traits → static tags
# =========================================================================
# Each entry: (trait_name, threshold_op, threshold_value, tag)
# threshold_op: ">" means trait > value → assign tag; "<" means trait < value

TAG_TRAIT_RULES = [
    ("greed",           ">",  0.6,  "GREEDY"),
    ("aggression",      ">",  0.5,  "AGGRESSIVE"),
    ("risk_tolerance",  "<",  0.3,  "COWARD"),
    ("risk_tolerance",  ">",  0.7,  "BOLD"),
    ("loyalty",         ">",  0.6,  "LOYAL"),
]


# =========================================================================
# ROLE → TAG mapping (every agent gets a tag from its role)
# =========================================================================
ROLE_TAGS = {
    "trader":     "TRADER",
    "prospector": "PROSPECTOR",
    "military":   "MILITARY",
    "hauler":     "HAULER",
    "pirate":     "PIRATE",
    "explorer":   "EXPLORER",
    "idle":       "IDLE",
}


# =========================================================================
# DYNAMIC AGENT TAG RULES — derived from runtime state each tick
# =========================================================================
# Each entry: (field, op, threshold, tag)
# Fields are dot-paths into the agent dict or char_data.

DYNAMIC_AGENT_RULES = [
    # (field_name, operator, threshold, tag)
    ("hull_integrity",        "<",  0.3,   "WEAK"),
    ("hull_integrity",        "<",  0.5,   "DAMAGED"),
    ("cash_reserves",         ">",  5000,  "WEALTHY"),
    ("cash_reserves",         "<",  100,   "BROKE"),
    ("_has_cargo",            "==", True,  "LOADED"),       # special: computed
    ("_desperation",          "==", True,  "DESPERATE"),    # special: hull < 0.3 AND cash <= 0
]


# =========================================================================
# SECTOR TAG RULES — derived from sector state each tick
# =========================================================================
# Thresholds for sector property → tag derivation

SECTOR_TAG_RULES = {
    # Always present for any sector with a station
    "STATION": True,

    # Security-based tags
    "SECURE":         ("security_level",    ">",  0.6),
    "LOW_SECURITY":   ("security_level",    "<",  0.4),

    # Piracy
    "PIRATE_ACTIVITY": ("pirate_activity",  ">",  0.3),

    # Hostile presence
    "HOSTILE_INFESTED": ("hostile_count",   ">",  3),
    "DANGEROUS":        ("danger_composite", ">",  0.5),

    # Economy
    "MARKET_HUB":     ("total_stockpile",   ">",  500),
    "WEALTHY":        ("total_stockpile",   ">",  1000),
    "SURPLUS":        ("stockpile_ratio",   ">",  1.5),
    "DEFICIT":        ("stockpile_ratio",   "<",  0.5),

    # Resources
    "RESOURCE_RICH":  ("hidden_total",      ">",  50),

    # Frontier
    "FRONTIER":       ("sector_type",       "==", "frontier"),

    # Wrecks
    "HAS_WRECKS":     ("wreck_count",       ">",  0),
}


# =========================================================================
# CORE FUNCTIONS
# =========================================================================

def compute_affinity(actor_tags: list, target_tags: list) -> float:
    """Compute aggregate affinity score between two tag-sets.

    This is the core scoring function — O(|actor_tags| × |target_tags|).
    Returns sum of all matching (actor_tag, target_tag) pairs in the matrix.
    """
    score = 0.0
    for a_tag in actor_tags:
        for t_tag in target_tags:
            score += AFFINITY_MATRIX.get((a_tag, t_tag), 0.0)
    return score


def derive_agent_tags(
    character_data: dict,
    agent_state: dict,
    has_cargo: bool = False,
) -> list:
    """Derive the full tag set for an agent.

    Combines:
    1. Role tag (from agent_role)
    2. Personality tags (from character personality_traits)
    3. Dynamic state tags (from runtime values)

    Args:
        character_data: Character template dict (has personality_traits, skills).
        agent_state: Agent runtime dict (has hull_integrity, cash_reserves, etc.).
        has_cargo: Whether the agent currently carries cargo.

    Returns:
        List of uppercase tag strings.
    """
    tags = []

    # 1. Role tag
    role = agent_state.get("agent_role", "idle")
    role_tag = ROLE_TAGS.get(role, "IDLE")
    tags.append(role_tag)

    # 2. Personality-derived tags (static per character)
    traits = character_data.get("personality_traits", {})
    for trait_name, op, threshold, tag in TAG_TRAIT_RULES:
        value = traits.get(trait_name, 0.5)  # default 0.5 if missing
        if op == ">" and value > threshold:
            tags.append(tag)
        elif op == "<" and value < threshold:
            tags.append(tag)

    # 3. Dynamic state tags
    hull = agent_state.get("hull_integrity", 1.0)
    cash = agent_state.get("cash_reserves", 0.0)

    for field, op, threshold, tag in DYNAMIC_AGENT_RULES:
        if field == "_has_cargo":
            if has_cargo == threshold:
                tags.append(tag)
        elif field == "_desperation":
            if hull < 0.3 and cash <= 0:
                tags.append(tag)
        else:
            value = agent_state.get(field, 0.0)
            if op == "<" and value < threshold:
                tags.append(tag)
            elif op == ">" and value > threshold:
                tags.append(tag)
            elif op == "==" and value == threshold:
                tags.append(tag)

    return tags


def derive_sector_tags(
    sector_id: str,
    state: GameState,
) -> list:
    """Derive the full tag set for a sector from its current state.

    Reads from grid_dominion, grid_stockpiles, world_hidden_resources,
    world_topology, grid_wrecks, hostile_population_integral.

    Args:
        sector_id: The sector identifier.
        state: Full GameState.

    Returns:
        List of uppercase tag strings.
    """
    tags = ["STATION"]  # All sectors in this sim have stations

    dominion = state.grid_dominion.get(sector_id, {})
    stockpiles = state.grid_stockpiles.get(sector_id, {})
    topology = state.world_topology.get(sector_id, {})
    hidden = state.world_hidden_resources.get(sector_id, {})
    hazards = state.world_hazards.get(sector_id, {})

    # Computed properties
    security = dominion.get("security_level", 0.0)
    piracy = dominion.get("pirate_activity", 0.0)
    commodities = stockpiles.get("commodity_stockpiles", {})
    total_stockpile = sum(float(v) for v in commodities.values())
    hidden_total = hidden.get("mineral_density", 0.0) + hidden.get("propellant_sources", 0.0)
    sector_type = topology.get("sector_type", "")
    radiation = hazards.get("radiation_level", 0.0)

    # Hostile count
    hostile_count = 0
    for htype_data in state.hostile_population_integral.values():
        hostile_count += htype_data.get("sector_counts", {}).get(sector_id, 0)

    # Danger composite: combines radiation + hostile density + piracy
    danger_composite = min(1.0, radiation + hostile_count / 10.0 + piracy * 0.5)

    # Wreck count
    wreck_count = sum(
        1 for w in state.grid_wrecks.values()
        if w.get("sector_id", "") == sector_id
    )

    # Average stockpile for ratio (SURPLUS / DEFICIT)
    all_sector_totals = []
    for sid, sp in state.grid_stockpiles.items():
        c = sp.get("commodity_stockpiles", {})
        all_sector_totals.append(sum(float(v) for v in c.values()))
    avg_stockpile = (sum(all_sector_totals) / len(all_sector_totals)) if all_sector_totals else 1.0
    stockpile_ratio = total_stockpile / max(avg_stockpile, 1.0)

    # Build lookup for rule evaluation
    props = {
        "security_level": security,
        "pirate_activity": piracy,
        "hostile_count": hostile_count,
        "danger_composite": danger_composite,
        "total_stockpile": total_stockpile,
        "stockpile_ratio": stockpile_ratio,
        "hidden_total": hidden_total,
        "sector_type": sector_type,
        "wreck_count": wreck_count,
    }

    for tag, rule in SECTOR_TAG_RULES.items():
        if tag == "STATION":
            continue  # Already added
        if isinstance(rule, tuple):
            prop_name, op, threshold = rule
            value = props.get(prop_name, 0.0)
            if op == ">" and value > threshold:
                tags.append(tag)
            elif op == "<" and value < threshold:
                tags.append(tag)
            elif op == "==" and value == threshold:
                tags.append(tag)

    return tags
