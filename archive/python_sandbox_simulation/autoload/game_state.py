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
