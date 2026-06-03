#
# PROJECT: GDTLancer
# MODULE: world_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_7
# LOG_REF: 2026-02-21 (TASK_6)
#

"""World layer: initialize topology and initial sector tags from templates."""

from autoload.game_state import GameState
from database.registry.template_data import LOCATIONS


class WorldLayer:
    """Initializes static world topology and sector tag state."""

    def initialize_world(self, state: GameState, seed_string: str) -> None:
        state.world_seed = seed_string
        state.world_topology.clear()
        state.world_hazards.clear()
        state.sector_tags.clear()

        for location_id, location in LOCATIONS.items():
            state.world_topology[location_id] = {
                "connections": list(location.get("connections", [])),
                "station_ids": [location_id],
                "sector_type": location.get("sector_type", "frontier"),
            }
            state.world_hazards[location_id] = {
                "environment": self._derive_environment(location.get("initial_sector_tags", []))
            }
            state.sector_tags[location_id] = list(location.get("initial_sector_tags", []))

    def get_neighbors(self, state: GameState, sector_id: str) -> list:
        return list(state.world_topology.get(sector_id, {}).get("connections", []))

    def get_hazards(self, state: GameState, sector_id: str) -> dict:
        return dict(state.world_hazards.get(sector_id, {"environment": "MILD"}))

    def _derive_environment(self, sector_tags: list) -> str:
        if "EXTREME" in sector_tags:
            return "EXTREME"
        if "HARSH" in sector_tags:
            return "HARSH"
        return "MILD"
