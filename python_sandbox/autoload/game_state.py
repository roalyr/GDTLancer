"""
GDTLancer Game State — central data store.
Mirror of src/autoload/GameState.gd.
All simulation systems read/write through this singleton-like object.

PROJECT: GDTLancer
MODULE: autoload/game_state.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 2: Entity Graph — Nodes)
"""

import copy


class GameState:
    """
    Central data store for the four-layer simulation.
    Create one instance and pass it to all layers.
    """

    def __init__(self):
        # === Layer 1: World (static after init) ===
        self.world_topology: dict = {}
        self.world_hazards: dict = {}
        self.world_hazards_base: dict = {}
        self.world_resource_potential: dict = {}
        self.world_hidden_resources: dict = {}
        self.world_total_matter: float = 0.0
        self.world_seed: str = ""

        # === Layer 2: Grid (dynamic, CA-driven) ===
        self.grid_resource_availability: dict = {}
        self.grid_dominion: dict = {}
        self.grid_market: dict = {}
        self.grid_stockpiles: dict = {}
        self.grid_maintenance: dict = {}
        self.grid_power: dict = {}
        self.grid_wrecks: dict = {}

        # === Layer 3: Agents ===
        self.characters: dict = {}
        self.agents: dict = {}
        self.inventories: dict = {}
        self.assets_ships: dict = {}
        self.player_character_uid: int = -1
        self.hostile_population_integral: dict = {}
        self.persistent_agents: dict = {}
        self.sector_disabled_until: dict = {}
        self.catastrophe_log: list = []
        # Per-type hostile matter pools (strict pool-in / pool-out, Axiom 1)
        self.hostile_pools: dict = {
            "drones": {"reserve": 0.0, "body_mass": 0.0},
            "aliens": {"reserve": 0.0, "body_mass": 0.0},
        }

        # === Colony Level Progression ===
        self.colony_levels: dict = {}
        self.colony_upgrade_progress: dict = {}
        self.colony_downgrade_progress: dict = {}
        self.colony_level_history: list = []

        # === Mortal (non-named) Agents ===
        self.mortal_agent_counter: int = 0
        self.mortal_agent_deaths: list = []

        # === Sector Discovery ===
        self.discovered_sector_count: int = 0
        self.discovery_log: list = []

        # === Slag & Universe Conservation (TRUTH_SIMULATION-GRAPH §1 Law 5) ===
        self.slag_total: float = 0.0                 # Permanently irreversible waste
        self.undiscovered_matter_pool: float = 0.0    # Matter beyond the frontier
        self.universe_constant: float = 0.0           # TOTAL_MATTER + undiscovered + slag (set at init)

        # === Layer 4: Chronicle ===
        self.chronicle_event_buffer: list = []
        self.chronicle_rumors: list = []

        # === Simulation Meta ===
        self.sim_tick_count: int = 0
        self.game_time_seconds: int = 0

        # === World Age Cycle ===
        self.world_age: str = ""
        self.world_age_timer: int = 0
        self.world_age_cycle_count: int = 0

        # === Scene State (stub for Python — no real scene) ===
        self.player_docked_at: str = ""

    def deep_copy_dict(self, d: dict) -> dict:
        """Utility: deep-copy a nested dictionary."""
        return copy.deepcopy(d)
