"""
GDTLancer Simulation Constants.
Mirror of src/autoload/Constants.gd — simulation-relevant values only.

PROJECT: GDTLancer
MODULE: autoload/constants.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Appendix A: Constants Cross-Reference)
"""

# === Grid CA Parameters ===
CA_INFLUENCE_PROPAGATION_RATE = 0.1
CA_PIRATE_ACTIVITY_DECAY = 0.02
CA_PIRATE_ACTIVITY_GROWTH = 0.05
CA_STOCKPILE_DIFFUSION_RATE = 0.05
CA_EXTRACTION_RATE_DEFAULT = 0.003
CA_PRICE_SENSITIVITY = 0.5
CA_DEMAND_BASE = 0.1
CA_FACTION_ANCHOR_STRENGTH = 0.05

# === Wreck & Entropy ===
WRECK_DEGRADATION_PER_TICK = 0.05
WRECK_DEBRIS_RETURN_FRACTION = 0.7   # Salvageable fraction
WRECK_SLAG_FRACTION = 0.3            # Permanently irreversible waste (TRUTH_SIMULATION-GRAPH §1)
ENTROPY_BASE_RATE = 0.001
ENTROPY_RADIATION_MULTIPLIER = 2.0
ENTROPY_FLEET_RATE_FRACTION = 0.5

# === Agent ===
AGENT_KNOWLEDGE_NOISE_FACTOR = 0.1
AGENT_RESPAWN_TICKS = 10

# === Heat ===
HEAT_GENERATION_IN_SPACE = 0.01
HEAT_DISSIPATION_DOCKED = 1.0
HEAT_OVERHEAT_THRESHOLD = 0.8

# === Power ===
POWER_DRAW_PER_AGENT = 5.0
POWER_DRAW_PER_SERVICE = 10.0

# === Bridge Entropy Drains (Mass Displacement — TRUTH_SIMULATION-GRAPH §1 Law 4) ===
ENTROPY_HULL_MULTIPLIER = 0.1
PROPELLANT_DRAIN_PER_TICK = 0.2
ENERGY_DRAIN_PER_TICK = 0.3

# === Agent Decision Thresholds ===
NPC_CASH_LOW_THRESHOLD = 2000.0
NPC_HULL_REPAIR_THRESHOLD = 0.5
COMMODITY_BASE_PRICE = 10.0
RESPAWN_TIMEOUT_SECONDS = 300.0

# === Hostile Encounters (drones & aliens — hive creatures, not pirates) ===
HOSTILE_ENCOUNTER_CHANCE = 0.3
HOSTILE_DAMAGE_MIN = 0.05
HOSTILE_DAMAGE_MAX = 0.25
HOSTILE_CARGO_LOSS_FRACTION = 0.2

# === Hostile Spawning (strict pool-in / pool-out ecology) ===
HOSTILE_WRECK_SALVAGE_RATE = 0.1
HOSTILE_SPAWN_COST = 5.0
HOSTILE_LOW_SECURITY_THRESHOLD = 0.4
HOSTILE_KILL_PER_MILITARY = 0.5

# === Pirate Agent Role ===
PIRATE_RAID_CHANCE = 0.25
PIRATE_RAID_CARGO_STEAL = 0.3
PIRATE_MOVE_INTERVAL = 6
PIRATE_HOME_ADVANTAGE = 0.15

# === Cash Sinks (Specie-denominated — TRUTH_SIMULATION-GRAPH §8.1) ===
REPAIR_COST_PER_POINT = 500.0
DOCKING_FEE_BASE = 10.0
FUEL_COST_PER_UNIT = 5.0

# === Timing ===
WORLD_TICK_INTERVAL_SECONDS = 60

# === Axiom 1 (relative tolerance: fraction of total matter budget) ===
AXIOM1_RELATIVE_TOLERANCE = 0.50  # 50% — relaxed for affinity prototyping

# === Commodities (TRUTH_SIMULATION-GRAPH §2) ===
COMMODITY_IDS = [
    "commodity_ore",
    "commodity_food",
    "commodity_tech",
    "commodity_fuel",
    "commodity_luxury",
    "commodity_specie",  # Physical currency — coins/bars (TRUTH_SIMULATION-GRAPH §8.1)
]

# === Specie Injection (TRUTH_SIMULATION-GRAPH §8.1 — Initial Liquidity Fix) ===
# Every station MUST spawn with baseline commodity_specie reserve to prevent
# deadlock: miners can't sell ore if station has no money.
# Constraint: min_station_specie > (avg_miner_cargo_capacity * avg_ore_price)
#   avg_miner_cargo_capacity ≈ 10, avg_ore_price ≈ 10 → min = 100
#   We use 200 as comfortable baseline.
STATION_INITIAL_SPECIE = 200.0       # Minimum commodity_specie per station at init
SPECIE_SOURCE = "hidden_resources"   # Where initial specie is debited from (Axiom 1)

# === Hidden Resources & Prospecting ===
HIDDEN_RESOURCE_MULTIPLIER = 10.0

PROSPECTING_BASE_RATE = 0.002
PROSPECTING_SCARCITY_BOOST = 2.0
PROSPECTING_SECURITY_FACTOR = 1.0
PROSPECTING_HAZARD_PENALTY = 0.5
PROSPECTING_RANDOMNESS = 0.3

# === Hazard Map Morphing (Space Weather) ===
HAZARD_DRIFT_PERIOD = 200
HAZARD_RADIATION_AMPLITUDE = 0.04
HAZARD_THERMAL_AMPLITUDE = 15.0

# === Catastrophic Events ===
CATASTROPHE_CHANCE_PER_TICK = 0.0005
CATASTROPHE_DISABLE_DURATION = 50
CATASTROPHE_STOCKPILE_TO_WRECK = 0.6
CATASTROPHE_HAZARD_BOOST = 0.15
CATASTROPHE_SECURITY_DROP = 0.4

# === Wreck Salvage by Prospectors (high-security sectors) ===
PROSPECTOR_WRECK_SALVAGE_RATE = 0.15
PROSPECTOR_WRECK_SECURITY_THRESHOLD = 0.6

# === Agent Desperation / Debt ===
DESPERATION_HULL_THRESHOLD = 0.3
DESPERATION_TRADE_HULL_RISK = 0.02
DEBT_INTEREST_RATE = 0.0001
DEBT_CAP = 10000.0
RESPAWN_DEBT_PENALTY = 500.0

# === Entropy Death ===
ENTROPY_DEATH_HULL_THRESHOLD = 0.0
ENTROPY_DEATH_TICK_GRACE = 20

# === Hostile Global Threat ===
HOSTILE_GLOBAL_CAP = 100

# === Hostile Pool Spawning ===
HOSTILE_POOL_PRESSURE_THRESHOLD = 200.0
HOSTILE_POOL_SPAWN_RATE = 0.02
HOSTILE_POOL_MAX_SPAWNS_PER_TICK = 5

# === Hostile Raids ===
HOSTILE_RAID_THRESHOLD = 5
HOSTILE_RAID_CHANCE = 0.15
HOSTILE_RAID_STOCKPILE_FRACTION = 0.05
HOSTILE_RAID_CASUALTIES = 2

# === Stockpile Consumption (population sink) ===
CONSUMPTION_RATE_PER_TICK = 0.003
CONSUMPTION_ENTROPY_TAX = 0.03

# === Debt Zombie Prevention ===
RESPAWN_COOLDOWN_MAX_DEBT = 200
RESPAWN_COOLDOWN_NORMAL = 5

# === Colony Levels (TRUTH_SIMULATION-GRAPH §3.4) ===
COLONY_LEVELS = ["frontier", "outpost", "colony", "hub"]

COLONY_LEVEL_MODIFIERS = {
    "frontier": {"population_density": 0.5, "capacity_mult": 0.5, "extraction_mult": 0.6, "consumption_mult": 0.3},
    "outpost":  {"population_density": 1.0, "capacity_mult": 0.75, "extraction_mult": 0.8, "consumption_mult": 0.6},
    "colony":   {"population_density": 1.5, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.0},
    "hub":      {"population_density": 2.0, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.2},
}

COLONY_UPGRADE_STOCKPILE_FRACTION = 0.6
COLONY_UPGRADE_SECURITY_MIN = 0.5
COLONY_UPGRADE_TICKS_REQUIRED = 250
COLONY_DOWNGRADE_STOCKPILE_FRACTION = 0.30
COLONY_DOWNGRADE_SECURITY_MIN = 0.4
COLONY_DOWNGRADE_TICKS_REQUIRED = 150

# === Non-Named Mortal Agents ===
MORTAL_SPAWN_CHANCE_PER_TICK = 0.005
MORTAL_SPAWN_MIN_STOCKPILE = 500.0
MORTAL_SPAWN_MIN_SECURITY = 0.5
MORTAL_SPAWN_CASH = 800.0
MORTAL_GLOBAL_CAP = 20
MORTAL_ROLES = ["trader", "hauler", "prospector", "explorer", "pirate"]
MORTAL_ROLE_WEIGHTS = [0.35, 0.25, 0.15, 0.10, 0.15]

# === Agent Wages (per-tick income by role) ===
TRADER_WAGE = 20.0
HAULER_WAGE = 30.0
PROSPECTOR_WAGE = 35.0
MILITARY_SALARY = 35.0

# === Explorer Role ===
EXPLORER_EXPEDITION_COST = 500.0
EXPLORER_EXPEDITION_FUEL = 30.0
EXPLORER_DISCOVERY_CHANCE = 0.04
EXPLORER_MOVE_INTERVAL = 8
EXPLORER_WAGE = 40.0
EXPLORER_MAX_DISCOVERED_SECTORS = 10
NEW_SECTOR_BASE_MINERALS = 1.5
NEW_SECTOR_BASE_PROPELLANT = 0.8
NEW_SECTOR_BASE_CAPACITY = 600
NEW_SECTOR_BASE_POWER = 60.0

# === Resource Layers (gated accessibility) ===
RESOURCE_LAYER_FRACTIONS = {"surface": 0.15, "deep": 0.35, "mantle": 0.50}
RESOURCE_LAYER_RATE_MULTIPLIERS = {"surface": 3.0, "deep": 1.0, "mantle": 0.3}
RESOURCE_LAYER_DEPLETION_THRESHOLD = 0.01

# === Agent Roles ===
PROSPECTOR_DISCOVERY_MULTIPLIER = 3.0
PROSPECTOR_MOVE_INTERVAL = 5

MILITARY_SECURITY_BOOST = 0.02
MILITARY_PIRACY_SUPPRESS = 0.01
MILITARY_PATROL_INTERVAL = 8

HAULER_CARGO_CAPACITY = 20
HAULER_SURPLUS_THRESHOLD = 1.5
HAULER_DEFICIT_THRESHOLD = 0.5

EXPLORER_DISCOVERY_MULTIPLIER = 1.5

# === World Age Cycle ===
WORLD_AGE_CYCLE = ["PROSPERITY", "DISRUPTION", "RECOVERY"]
WORLD_AGE_DURATIONS = {
    "PROSPERITY": 420,
    "DISRUPTION":  210,
    "RECOVERY":    270,
}

WORLD_AGE_CONFIGS = {
    "PROSPERITY": {
        "extraction_rate_default":      0.005,
        "pirate_activity_growth":       0.02,
        "pirate_activity_decay":        0.06,
        "influence_propagation_rate":   0.08,
        "faction_anchor_strength":      0.08,
        "hostile_encounter_chance":     0.15,
        "docking_fee_base":             15.0,
        "stockpile_diffusion_rate":     0.08,
        "prospecting_base_rate":        0.003,
        "hazard_radiation_amplitude":   0.02,
        "catastrophe_chance_per_tick":  0.0002,
    },
    "DISRUPTION": {
        "extraction_rate_default":      0.0013,
        "pirate_activity_growth":       0.12,
        "pirate_activity_decay":        0.01,
        "influence_propagation_rate":   0.20,
        "faction_anchor_strength":      0.02,
        "hostile_encounter_chance":     0.50,
        "docking_fee_base":             40.0,
        "stockpile_diffusion_rate":     0.02,
        "prospecting_base_rate":        0.0005,
        "hazard_radiation_amplitude":   0.08,
        "catastrophe_chance_per_tick":  0.001,
    },
    "RECOVERY": {
        "extraction_rate_default":      0.0027,
        "pirate_activity_growth":       0.04,
        "pirate_activity_decay":        0.04,
        "influence_propagation_rate":   0.12,
        "faction_anchor_strength":      0.05,
        "hostile_encounter_chance":     0.30,
        "docking_fee_base":             25.0,
        "stockpile_diffusion_rate":     0.05,
        "prospecting_base_rate":        0.002,
        "hazard_radiation_amplitude":   0.05,
        "catastrophe_chance_per_tick":  0.0005,
    },
}

# === Slag & Universe Constants (TRUTH_SIMULATION-GRAPH §1 Law 5) ===
# slag_total and UNDISCOVERED_MATTER_POOL are state variables, not constants.
# They are initialized at runtime and tracked in GameState.
# UNIVERSE_CONSTANT = TOTAL_MATTER + UNDISCOVERED_MATTER_POOL + slag_total
# (set at initialization, never changes)

# === Affinity System Tuning (Concept_injection.md) ===
# Mechanical outcome magnitudes for the unified tag-affinity dispatch.
AFFINITY_ATTACK_DAMAGE_FACTOR = 0.15     # Hull damage per encounter = score × this
AFFINITY_LOOT_FRACTION = 0.3             # Fraction of cargo looted on attack
AFFINITY_TRADE_SELL_AMOUNT = 10          # Max commodities sold per dock
AFFINITY_TRADE_BUY_AMOUNT = 10           # Max commodities bought per dock
AFFINITY_REPAIR_AMOUNT = 0.1             # Hull repaired per dock visit
AFFINITY_HARVEST_RATE = 0.05             # Fraction of hidden resources harvested
AFFINITY_SECURITY_BOOST = 0.02           # Security boost per military tick
AFFINITY_PIRACY_SUPPRESS = 0.01          # Piracy reduction per military tick
AFFINITY_PIRACY_BOOST = 0.05             # Piracy boost per pirate tick
AFFINITY_WAGE_PER_TICK = 20.0            # Flat income for working agents
