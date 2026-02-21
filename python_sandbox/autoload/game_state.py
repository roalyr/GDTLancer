#
# PROJECT: GDTLancer
# MODULE: game_state.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-02-21 (TASK_3)
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

        # === Catastrophe + lifecycle ===
        self.catastrophe_log: list = []
        self.sector_disabled_until: dict = {}
        self.mortal_agent_counter: int = 0
        self.mortal_agent_deaths: list = []

        # === Discovery ===
        self.discovered_sector_count: int = 0
        self.discovery_log: list = []

        # === Chronicle ===
        self.chronicle_events: list = []
        self.chronicle_rumors: list = []

        # === Simulation meta ===
        self.sim_tick_count: int = 0
        self.world_age: str = ""
        self.world_age_timer: int = 0
        self.world_age_cycle_count: int = 0

        # === Scene/player state ===
        self.player_docked_at: str = ""

    def deep_copy_dict(self, data: dict) -> dict:
        return copy.deepcopy(data)
