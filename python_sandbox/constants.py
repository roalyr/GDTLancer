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
DOCKING_FEE_BASE = 50.0          # Base docking fee per tick while docked
FUEL_COST_PER_UNIT = 5.0         # Cost to refuel per unit of propellant

# === Timing ===
WORLD_TICK_INTERVAL_SECONDS = 60

# === Axiom 1 ===
AXIOM1_TOLERANCE = 0.01
