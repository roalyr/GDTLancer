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
WRECK_DEBRIS_RETURN_FRACTION = 0.7  # Salvageable fraction; remainder → dust → hidden resources
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

# === Bridge Entropy Drains ===
ENTROPY_HULL_MULTIPLIER = 0.1
PROPELLANT_DRAIN_PER_TICK = 0.5
ENERGY_DRAIN_PER_TICK = 0.3

# === Agent Decision Thresholds ===
NPC_CASH_LOW_THRESHOLD = 2000.0
NPC_HULL_REPAIR_THRESHOLD = 0.5
COMMODITY_BASE_PRICE = 10.0
RESPAWN_TIMEOUT_SECONDS = 300.0

# === Hostile Encounters (drones & aliens — hive creatures, not pirates) ===
HOSTILE_ENCOUNTER_CHANCE = 0.3   # Base probability per tick in a hostile sector
HOSTILE_DAMAGE_MIN = 0.05        # Min hull damage from a hostile encounter
HOSTILE_DAMAGE_MAX = 0.25        # Max hull damage from a hostile encounter
HOSTILE_CARGO_LOSS_FRACTION = 0.2  # Fraction of cargo lost to hostile attack

# === Hostile Spawning (strict pool-in / pool-out ecology) ===
# All hostile spawns are funded from per-type matter pools (drone_pool, alien_pool).
# Pools are fed by: consumption entropy tax, wreck salvage in low-sec sectors.
# NO passive/free spawning — if a pool is empty, no hostiles spawn.
HOSTILE_WRECK_SALVAGE_RATE = 0.1     # fraction of a wreck's matter consumed/tick by hostiles
HOSTILE_SPAWN_COST = 10.0            # matter from pool per hostile spawned (pool → body_mass)
HOSTILE_LOW_SECURITY_THRESHOLD = 0.4 # security_level below this = "low security"
HOSTILE_KILL_PER_MILITARY = 0.5      # hostiles killed per military agent per tick in sector

# === Pirate Agent Role ===
PIRATE_RAID_CHANCE = 0.25        # chance per tick a pirate raids a target in same sector
PIRATE_RAID_CARGO_STEAL = 0.3   # fraction of target's cargo stolen per raid
PIRATE_MOVE_INTERVAL = 6        # ticks between pirate sector moves
PIRATE_HOME_ADVANTAGE = 0.15    # piracy_activity boost when pirate is present

# === Cash Sinks ===
REPAIR_COST_PER_POINT = 500.0    # Cash per 0.1 hull repaired
DOCKING_FEE_BASE = 10.0          # Base docking fee per tick while docked
FUEL_COST_PER_UNIT = 5.0         # Cost to refuel per unit of propellant

# === Timing ===
WORLD_TICK_INTERVAL_SECONDS = 60

# === Axiom 1 (relative tolerance: fraction of total matter budget) ===
AXIOM1_RELATIVE_TOLERANCE = 0.015  # 1.5% of total matter budget

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
# === Catastrophic Events ===
# Random sector-wide disasters that break monotonous cycles.
# When triggered: stockpiles → wrecks, hub disabled, hazard spike, security drop.
# ═══════════════════════════════════════════════════════════════════

CATASTROPHE_CHANCE_PER_TICK = 0.0005   # ~1 per 2000 ticks (~23 world-age cycles)
CATASTROPHE_DISABLE_DURATION = 50      # ticks the hub is disabled (no docking/trade)
CATASTROPHE_STOCKPILE_TO_WRECK = 0.6   # fraction of stockpiles converted to wrecks
CATASTROPHE_HAZARD_BOOST = 0.15        # added to radiation_level during catastrophe
CATASTROPHE_SECURITY_DROP = 0.4        # security_level -= this on catastrophe

# === Wreck Salvage by Prospectors (high-security sectors) ===
PROSPECTOR_WRECK_SALVAGE_RATE = 0.15   # fraction of a wreck's matter salvaged per tick per prospector
PROSPECTOR_WRECK_SECURITY_THRESHOLD = 0.6  # security must be above this for prospector salvage

# === Agent Desperation / Debt ===
DESPERATION_HULL_THRESHOLD = 0.3  # hull below this AND cash=0 → desperation trade
DESPERATION_TRADE_HULL_RISK = 0.02  # extra hull damage per tick while desperation trading
DEBT_INTEREST_RATE = 0.0001  # debt grows by this fraction per tick (additive: debt += debt * rate)
DEBT_CAP = 10000.0  # maximum debt (prevents runaway; ~20× respawn cash)
RESPAWN_DEBT_PENALTY = 500.0  # debt added on respawn

# === Entropy Death (agents dying from hull failure → wrecks) ===
ENTROPY_DEATH_HULL_THRESHOLD = 0.0  # hull at or below this → disabled
ENTROPY_DEATH_TICK_GRACE = 20  # ticks at hull=0 before death

# === Hostile Global Threat (decoupled from piracy) ===
# hostility_level is DRIVEN by hostile presence, not by piracy.
# All spawning is pool-funded. No passive/free spawning.
HOSTILE_GLOBAL_CAP = 100  # sanity cap per type (memory safety, not simulation constraint)

# === Hostile Pool Spawning (pool → body_mass → wrecks → salvage cycle) ===
# Both wreck-salvage AND pressure-valve spawns use the same cost.
# Pressure valve: when reserve > threshold, accelerate spawning.
HOSTILE_POOL_PRESSURE_THRESHOLD = 500.0   # reserve must exceed this to trigger pressure spawning
HOSTILE_POOL_SPAWN_RATE = 0.02            # fraction of reserve above threshold spent per tick
HOSTILE_POOL_MAX_SPAWNS_PER_TICK = 5      # cap on pressure spawns per tick

# === Hostile Raids (large groups attack stockpiles) ===
# When hostiles in a sector exceed a threshold, they raid the sector,
# converting stockpile matter → wrecks. This is the matter return path.
HOSTILE_RAID_THRESHOLD = 5                # min hostiles in sector to trigger raid
HOSTILE_RAID_CHANCE = 0.15                # chance per tick per qualifying sector
HOSTILE_RAID_STOCKPILE_FRACTION = 0.05    # fraction of total stockpile destroyed per raid
HOSTILE_RAID_CASUALTIES = 2               # hostiles killed in the raid (defenders fight back)

# === Stockpile Consumption (population sink) ===
# Stations consume a fraction of stockpiles each tick, simulating
# population usage. Prevents "Full Warehouse" market crashes.
CONSUMPTION_RATE_PER_TICK = 0.001  # fraction of each commodity consumed/tick (scaled by pop density)
CONSUMPTION_ENTROPY_TAX = 0.03     # fraction of consumed matter → per-type hostile pools ("crime tax")
# Remaining (1 - tax) → hidden_resources (waste → ground recycling)

# === Debt Zombie Prevention ===
# Named agents at max debt get a long respawn cooldown instead of quick return.
RESPAWN_COOLDOWN_MAX_DEBT = 200    # ticks cooldown when agent dies at DEBT_CAP (vs normal 5)
RESPAWN_COOLDOWN_NORMAL = 5        # default respawn ticks (unchanged from before)

# ═══════════════════════════════════════════════════════════════════
# === Colony Levels (sector progression) ===
# Sectors evolve: frontier → outpost → colony → hub
# Higher levels = more population, capacity, extraction, consumption.
# ═══════════════════════════════════════════════════════════════════

COLONY_LEVELS = ["frontier", "outpost", "colony", "hub"]

# Per-level modifiers: population_density, capacity_mult, extraction_mult, consumption_mult
COLONY_LEVEL_MODIFIERS = {
    "frontier": {"population_density": 0.5, "capacity_mult": 0.5, "extraction_mult": 0.6, "consumption_mult": 0.3},
    "outpost":  {"population_density": 1.0, "capacity_mult": 0.75, "extraction_mult": 0.8, "consumption_mult": 0.6},
    "colony":   {"population_density": 1.5, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.0},
    "hub":      {"population_density": 2.0, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.2},
}

# Upgrade: stockpile must exceed this fraction of capacity for N consecutive ticks
COLONY_UPGRADE_STOCKPILE_FRACTION = 0.6   # stockpile/capacity > this to upgrade
COLONY_UPGRADE_SECURITY_MIN = 0.5         # security must be above this to upgrade
COLONY_UPGRADE_TICKS_REQUIRED = 200       # consecutive qualifying ticks to level up
# Downgrade: stockpile below this fraction OR security below threshold
COLONY_DOWNGRADE_STOCKPILE_FRACTION = 0.1 # stockpile/capacity < this to downgrade
COLONY_DOWNGRADE_SECURITY_MIN = 0.2       # security below this triggers downgrade
COLONY_DOWNGRADE_TICKS_REQUIRED = 300     # consecutive qualifying ticks to level down

# ═══════════════════════════════════════════════════════════════════
# === Non-Named Mortal Agents (generic, expendable) ===
# Generic NPCs spawned by prosperous sectors. They die permanently.
# ═══════════════════════════════════════════════════════════════════

MORTAL_SPAWN_CHANCE_PER_TICK = 0.005   # chance per tick per qualifying sector
MORTAL_SPAWN_MIN_STOCKPILE = 500.0     # sector must have this much total stock
MORTAL_SPAWN_MIN_SECURITY = 0.5        # sector must have this security level
MORTAL_SPAWN_CASH = 800.0              # starting cash for mortal agents
MORTAL_GLOBAL_CAP = 20                 # max mortal agents alive at any time
MORTAL_ROLES = ["trader", "hauler", "prospector"]  # roles mortal agents can take
MORTAL_ROLE_WEIGHTS = [0.5, 0.3, 0.2]  # probability weights for role selection

# ═══════════════════════════════════════════════════════════════════
# === Explorer Role (sector discovery) ===
# Explorers travel to frontier sectors and launch expeditions to
# discover new sectors from a hidden pool.
# ═══════════════════════════════════════════════════════════════════

EXPLORER_EXPEDITION_COST = 500.0       # cash cost per expedition attempt
EXPLORER_EXPEDITION_FUEL = 30.0        # propellant consumed per expedition
EXPLORER_DISCOVERY_CHANCE = 0.15       # base probability per expedition attempt
EXPLORER_MOVE_INTERVAL = 8             # ticks between explorer moves
EXPLORER_WAGE = 12.0                   # salary per tick (explorers are specialists)
EXPLORER_MAX_DISCOVERED_SECTORS = 10   # cap on total sectors in the simulation
# New sector generation parameters
NEW_SECTOR_BASE_MINERALS = 1.5        # base mineral density (before scaling)
NEW_SECTOR_BASE_PROPELLANT = 0.8      # base propellant density
NEW_SECTOR_BASE_CAPACITY = 600        # base stockpile capacity
NEW_SECTOR_BASE_POWER = 60.0          # base station power output

# === Resource Layers (gated accessibility) ===
# Hidden resources are split into 3 layers mined sequentially.
# Surface is fastest, deep is moderate, mantle is slowest.
RESOURCE_LAYER_FRACTIONS = {"surface": 0.15, "deep": 0.35, "mantle": 0.50}
RESOURCE_LAYER_RATE_MULTIPLIERS = {"surface": 3.0, "deep": 1.0, "mantle": 0.3}
RESOURCE_LAYER_DEPLETION_THRESHOLD = 0.01  # layer considered depleted below this fraction of original

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

# Explorer: discovers new sectors via expeditions from frontier
EXPLORER_DISCOVERY_MULTIPLIER = 1.5    # prospecting boost when explorer is present

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
        "hostile_encounter_chance":     0.15,    # Rare attacks
        "docking_fee_base":             15.0,    # Cheap docking
        "stockpile_diffusion_rate":     0.08,    # Active trade diffusion
        "prospecting_base_rate":        0.003,   # Active prospecting
        "hazard_radiation_amplitude":   0.02,    # Mild space weather
        "catastrophe_chance_per_tick":  0.0002,  # Very rare catastrophes
    },
    "DISRUPTION": {
        "extraction_rate_default":      0.004,   # Extraction collapses
        "pirate_activity_growth":       0.12,    # Piracy surges
        "pirate_activity_decay":        0.01,    # Security barely holds
        "influence_propagation_rate":   0.20,    # Factions destabilize fast
        "faction_anchor_strength":      0.1,     # Weak anchoring — chaos
        "hostile_encounter_chance":     0.50,    # Frequent attacks
        "docking_fee_base":             40.0,    # Crisis pricing
        "stockpile_diffusion_rate":     0.02,    # Trade routes disrupted
        "prospecting_base_rate":        0.0005,  # Almost no prospecting
        "hazard_radiation_amplitude":   0.08,    # Severe space weather
        "catastrophe_chance_per_tick":  0.001,   # More frequent catastrophes
    },
    "RECOVERY": {
        "extraction_rate_default":      0.008,   # Slow rebuilding
        "pirate_activity_growth":       0.04,    # Moderate piracy
        "pirate_activity_decay":        0.04,    # Gradual cleanup
        "influence_propagation_rate":   0.12,    # Moderate influence shift
        "faction_anchor_strength":      0.25,    # Rebuilding control
        "hostile_encounter_chance":     0.30,    # Normal risk
        "docking_fee_base":             25.0,    # Recovering fees
        "stockpile_diffusion_rate":     0.05,    # Normal diffusion
        "prospecting_base_rate":        0.002,   # Normal prospecting
        "hazard_radiation_amplitude":   0.05,    # Moderate space weather
        "catastrophe_chance_per_tick":  0.0005,  # Normal catastrophe rate
    },
}
