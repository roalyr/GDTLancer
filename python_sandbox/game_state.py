"""
GDTLancer Game State — central data store.
Mirror of src/autoload/GameState.gd.
All simulation systems read/write through this singleton-like object.
"""

import copy


class GameState:
    """
    Central data store for the four-layer simulation.
    Create one instance and pass it to all layers.
    """

    def __init__(self):
        # === Layer 1: World (static after init) ===
        self.world_topology: dict = {}          # sector_id → {connections, station_ids, sector_type}
        self.world_hazards: dict = {}           # sector_id → {radiation_level, thermal_background_k, gravity_well_penalty}
        self.world_hazards_base: dict = {}      # sector_id → original hazards (before drift)
        self.world_resource_potential: dict = {} # sector_id → {mineral_density, energy_potential, propellant_sources}
        self.world_hidden_resources: dict = {}  # sector_id → {mineral_density, propellant_sources}  (undiscovered)
        self.world_total_matter: float = 0.0    # Axiom 1 checksum
        self.world_seed: str = ""

        # === Layer 2: Grid (dynamic, CA-driven) ===
        self.grid_resource_availability: dict = {}  # sector_id → {propellant_supply, consumables_supply, energy_supply}
        self.grid_dominion: dict = {}               # sector_id → {faction_influence, security_level, pirate_activity}
        self.grid_market: dict = {}                 # sector_id → {commodity_price_deltas, population_density, service_cost_modifier}
        self.grid_stockpiles: dict = {}             # sector_id → {commodity_stockpiles, stockpile_capacity, extraction_rate}
        self.grid_maintenance: dict = {}            # sector_id → {local_entropy_rate, maintenance_cost_modifier}
        self.grid_power: dict = {}                  # sector_id → {station_power_output, station_power_draw, power_load_ratio}
        self.grid_wrecks: dict = {}                 # wreck_uid → {sector_id, wreck_integrity, wreck_inventory, ...}

        # === Layer 3: Agents ===
        self.characters: dict = {}              # char_uid → character data dict
        self.agents: dict = {}                  # agent_id → agent state dict
        self.inventories: dict = {}             # char_uid → {2: {commodity_id: qty}}  (2 = COMMODITY type)
        self.assets_ships: dict = {}            # ship_uid → ship data
        self.player_character_uid: int = -1
        self.hostile_population_integral: dict = {}  # hostile_type → {current_count, carrying_capacity, sector_counts}
        self.persistent_agents: dict = {}       # legacy alias
        self.sector_disabled_until: dict = {}   # sector_id → tick when hub re-enables
        self.catastrophe_log: list = []         # list of {sector_id, tick, type} for chronicle
        self.hostile_matter_pool: float = 0.0   # matter consumed by hostiles from wrecks (Axiom 1)

        # === Layer 4: Chronicle ===
        self.chronicle_event_buffer: list = []
        self.chronicle_rumors: list = []

        # === Simulation Meta ===
        self.sim_tick_count: int = 0
        self.game_time_seconds: int = 0

        # === World Age Cycle ===
        self.world_age: str = ""          # Current age name (PROSPERITY, DISRUPTION, RECOVERY)
        self.world_age_timer: int = 0     # Ticks remaining in current age
        self.world_age_cycle_count: int = 0  # How many full cycles completed

        # === Scene State (stub for Python — no real scene) ===
        self.player_docked_at: str = ""

    def deep_copy_dict(self, d: dict) -> dict:
        """Utility: deep-copy a nested dictionary."""
        return copy.deepcopy(d)
