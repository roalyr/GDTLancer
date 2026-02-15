"""
GDTLancer Simulation Constants.
Mirror of src/autoload/Constants.gd — simulation-relevant values only.
"""

# === Grid CA Parameters ===
CA_INFLUENCE_PROPAGATION_RATE = 0.1
CA_PIRATE_ACTIVITY_DECAY = 0.02
CA_PIRATE_ACTIVITY_GROWTH = 0.05
CA_STOCKPILE_DIFFUSION_RATE = 0.05
CA_EXTRACTION_RATE_DEFAULT = 0.01
CA_PRICE_SENSITIVITY = 0.5
CA_DEMAND_BASE = 0.1
CA_FACTION_ANCHOR_STRENGTH = 0.3  # How strongly controlling faction resists blending

# === Wreck & Entropy ===
WRECK_DEGRADATION_PER_TICK = 0.05
WRECK_DEBRIS_RETURN_FRACTION = 0.8
ENTROPY_BASE_RATE = 0.001
ENTROPY_RADIATION_MULTIPLIER = 2.0
ENTROPY_FLEET_RATE_FRACTION = 0.5

# === Agent ===
AGENT_KNOWLEDGE_NOISE_FACTOR = 0.1
AGENT_RESPAWN_TICKS = 10
HOSTILE_BASE_CARRYING_CAPACITY = 5

# === Heat ===
HEAT_GENERATION_IN_SPACE = 0.01
HEAT_DISSIPATION_DOCKED = 1.0
HEAT_OVERHEAT_THRESHOLD = 0.8

# === Power ===
POWER_DRAW_PER_AGENT = 5.0
POWER_DRAW_PER_SERVICE = 10.0

# === Bridge Entropy Drains ===
ENTROPY_HULL_MULTIPLIER = 0.1
PROPELLANT_DRAIN_PER_TICK = 0.5
ENERGY_DRAIN_PER_TICK = 0.3

# === Agent Decision Thresholds ===
NPC_CASH_LOW_THRESHOLD = 2000.0
NPC_HULL_REPAIR_THRESHOLD = 0.5
COMMODITY_BASE_PRICE = 10.0
RESPAWN_TIMEOUT_SECONDS = 300.0
HOSTILE_GROWTH_RATE = 0.05

# === Hostile Encounters ===
PIRACY_ENCOUNTER_CHANCE = 0.3    # Base probability per tick in a pirate sector
PIRACY_DAMAGE_MIN = 0.05         # Min hull damage from a pirate encounter
PIRACY_DAMAGE_MAX = 0.25         # Max hull damage from a pirate encounter
PIRACY_CARGO_LOSS_FRACTION = 0.2 # Fraction of cargo lost to pirate raid

# === Cash Sinks ===
REPAIR_COST_PER_POINT = 500.0    # Cash per 0.1 hull repaired
DOCKING_FEE_BASE = 20.0          # Base docking fee per tick while docked
FUEL_COST_PER_UNIT = 5.0         # Cost to refuel per unit of propellant

# === Timing ===
WORLD_TICK_INTERVAL_SECONDS = 60

# === Axiom 1 ===
AXIOM1_TOLERANCE = 0.01

# ═══════════════════════════════════════════════════════════════════
# === Hidden Resources & Prospecting ===
# Hidden resources are undiscovered deposits ~10× the initial discovered
# potential.  Prospectors convert hidden → discovered based on market
# scarcity, security, and hazard conditions.
# ═══════════════════════════════════════════════════════════════════

HIDDEN_RESOURCE_MULTIPLIER = 10.0   # initial hidden = discovered * this

# Prospecting: discovery_amount = base_rate * hidden_remaining
#              * scarcity_factor * security_factor * hazard_factor
PROSPECTING_BASE_RATE = 0.002       # fraction of hidden pool per tick
PROSPECTING_SCARCITY_BOOST = 2.0    # multiplier at max scarcity (positive price deltas)
PROSPECTING_SECURITY_FACTOR = 1.0   # full prospecting at security=1, halved at 0
PROSPECTING_HAZARD_PENALTY = 0.5    # at radiation=1 prospecting drops to (1 - penalty)
PROSPECTING_RANDOMNESS = 0.3        # ±30% variance per discovery event

# ═══════════════════════════════════════════════════════════════════
# === Hazard Map Morphing (Space Weather) ===
# Slow sinusoidal drift of radiation and thermal background across
# all sectors.  Each sector has a different phase offset.
# ═══════════════════════════════════════════════════════════════════

HAZARD_DRIFT_PERIOD = 200           # ticks for one full sine cycle
HAZARD_RADIATION_AMPLITUDE = 0.04   # max ± shift to radiation_level
HAZARD_THERMAL_AMPLITUDE = 15.0     # max ± shift to thermal_background_k (Kelvin)

# ═══════════════════════════════════════════════════════════════════
# === Agent Roles ===
# Role-specific behavior multipliers and thresholds.
# Roles: trader, prospector, military, hauler, idle
# ═══════════════════════════════════════════════════════════════════

# Prospector: boosts local prospecting discovery when present in a sector
PROSPECTOR_DISCOVERY_MULTIPLIER = 3.0   # prospecting_base_rate × this when ≥1 prospector present
PROSPECTOR_MOVE_INTERVAL = 5            # ticks between sector moves (exploration pace)

# Military: boosts local security, suppresses piracy
MILITARY_SECURITY_BOOST = 0.02          # security_level += this per military agent per tick
MILITARY_PIRACY_SUPPRESS = 0.01        # pirate_activity -= this per military agent per tick
MILITARY_PATROL_INTERVAL = 8           # ticks between patrol moves

# Hauler: transfers goods from surplus to deficit sectors
HAULER_CARGO_CAPACITY = 20             # max units per haul trip
HAULER_SURPLUS_THRESHOLD = 1.5         # ratio above avg → surplus
HAULER_DEFICIT_THRESHOLD = 0.5         # ratio below avg → deficit

# ═══════════════════════════════════════════════════════════════════
# === World Age Cycle ===
# Inspired by GROWTH → CHAOS → RENEWAL oscillation pattern.
# Each age modulates CA parameters to prevent the system from settling.
# ═══════════════════════════════════════════════════════════════════

# Age cycle definition: order and duration (in ticks)
WORLD_AGE_CYCLE = ["PROSPERITY", "DISRUPTION", "RECOVERY"]
WORLD_AGE_DURATIONS = {
    "PROSPERITY": 40,    # Stable growth — factions consolidate, trade thrives
    "DISRUPTION":  20,   # Crisis — piracy surges, factions weaken, extraction stalls
    "RECOVERY":    25,   # Rebuilding — moderate piracy, resources slowly replenish
}

# Per-age config overrides (applied on top of base constants)
# Only keys that change per age are listed.
WORLD_AGE_CONFIGS = {
    "PROSPERITY": {
        "extraction_rate_default":      0.015,   # Rich extraction
        "pirate_activity_growth":       0.02,    # Low pirate pressure
        "pirate_activity_decay":        0.06,    # Security suppresses piracy
        "influence_propagation_rate":   0.08,    # Slow influence change
        "faction_anchor_strength":      0.4,     # Strong faction anchoring
        "hostile_growth_rate":          0.02,    # Few new hostiles
        "piracy_encounter_chance":      0.15,    # Rare attacks
        "docking_fee_base":             15.0,    # Cheap docking
        "stockpile_diffusion_rate":     0.08,    # Active trade diffusion
        "prospecting_base_rate":        0.003,   # Active prospecting
        "hazard_radiation_amplitude":   0.02,    # Mild space weather
    },
    "DISRUPTION": {
        "extraction_rate_default":      0.004,   # Extraction collapses
        "pirate_activity_growth":       0.12,    # Piracy surges
        "pirate_activity_decay":        0.01,    # Security barely holds
        "influence_propagation_rate":   0.20,    # Factions destabilize fast
        "faction_anchor_strength":      0.1,     # Weak anchoring — chaos
        "hostile_growth_rate":          0.15,    # Hostile boom
        "piracy_encounter_chance":      0.50,    # Frequent attacks
        "docking_fee_base":             40.0,    # Crisis pricing
        "stockpile_diffusion_rate":     0.02,    # Trade routes disrupted
        "prospecting_base_rate":        0.0005,  # Almost no prospecting
        "hazard_radiation_amplitude":   0.08,    # Severe space weather
    },
    "RECOVERY": {
        "extraction_rate_default":      0.008,   # Slow rebuilding
        "pirate_activity_growth":       0.04,    # Moderate piracy
        "pirate_activity_decay":        0.04,    # Gradual cleanup
        "influence_propagation_rate":   0.12,    # Moderate influence shift
        "faction_anchor_strength":      0.25,    # Rebuilding control
        "hostile_growth_rate":          0.06,    # Some hostiles remain
        "piracy_encounter_chance":      0.30,    # Normal risk
        "docking_fee_base":             25.0,    # Recovering fees
        "stockpile_diffusion_rate":     0.05,    # Normal diffusion
        "prospecting_base_rate":        0.002,   # Normal prospecting
        "hazard_radiation_amplitude":   0.05,    # Moderate space weather
    },
}
