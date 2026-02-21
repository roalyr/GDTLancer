"""
GDTLancer Bridge Systems — cross-layer processing (Grid → Agent).
Mirror of src/core/simulation/bridge_systems.gd.

Step 3a: Heat Sink — binary overheating check per agent
Step 3b: Entropy System — hull degradation from sector entropy rate
Step 3c: Knowledge Refresh — update agent knowledge snapshots

PROJECT: GDTLancer
MODULE: core/simulation/bridge_systems.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 5: Bridge Systems)
"""

import copy
from autoload.game_state import GameState
from core.simulation.affinity_matrix import derive_agent_tags, derive_sector_tags


class BridgeSystems:
    """Cross-layer processing that connects Grid data to Agent state."""

    def process_tick(self, state: GameState, config: dict) -> None:
        # --- Refresh sector tags (used by affinity system) ---
        self._refresh_sector_tags(state)

        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue

            sector_id = agent.get("current_sector_id", "")

            self._process_heat_sink(state, agent_id, agent, sector_id, config)
            self._process_entropy(state, agent_id, agent, sector_id, config)
            self._process_knowledge_refresh(state, agent_id, agent, sector_id, config)
            self._refresh_agent_tags(state, agent_id, agent)

    # -----------------------------------------------------------------
    # Step 3a: Heat Sink
    # -----------------------------------------------------------------
    def _process_heat_sink(
        self,
        state: GameState,
        agent_id: str,
        agent: dict,
        sector_id: str,
        config: dict,
    ) -> None:
        heat_generation_in_space = config.get("heat_generation_in_space", 0.5)
        heat_dissipation_base = config.get("heat_dissipation_base", 1.0)
        heat_overheat_threshold = config.get("heat_overheat_threshold", 100.0)

        # Docked check
        if agent_id == "player":
            is_docked = state.player_docked_at != ""
        else:
            topology = state.world_topology.get(sector_id, {})
            is_docked = topology.get("sector_type", "") in ("hub", "frontier")

        heat_generated = 0.0 if is_docked else heat_generation_in_space

        # Cooling
        hazards = state.world_hazards.get(sector_id, {})
        thermal_k = hazards.get("thermal_background_k", 300.0)
        cooling_factor = max(0.1, (300.0 - thermal_k) / 300.0 + 1.0)
        dissipation = heat_dissipation_base * cooling_factor

        current_heat = agent.get("current_heat_level", 0.0)
        current_heat = max(0.0, current_heat + heat_generated - dissipation)
        agent["current_heat_level"] = current_heat

    # -----------------------------------------------------------------
    # Step 3b: Entropy System
    # -----------------------------------------------------------------
    def _process_entropy(
        self,
        state: GameState,
        agent_id: str,
        agent: dict,
        sector_id: str,
        config: dict,
    ) -> None:
        entropy_hull_multiplier = config.get("entropy_hull_multiplier", 0.1)

        maintenance = state.grid_maintenance.get(sector_id, {})
        entropy_rate = maintenance.get("local_entropy_rate", 0.001)

        hull = agent.get("hull_integrity", 1.0)
        degradation = entropy_rate * entropy_hull_multiplier
        hull = max(0.0, hull - degradation)
        agent["hull_integrity"] = hull

        # Consume propellant/energy if not docked
        if agent_id == "player":
            is_docked = state.player_docked_at != ""
        else:
            topology = state.world_topology.get(sector_id, {})
            is_docked = topology.get("sector_type", "") in ("hub", "frontier")

        if not is_docked:
            propellant_drain = config.get("propellant_drain_per_tick", 0.5)
            energy_drain = config.get("energy_drain_per_tick", 0.3)
            agent["propellant_reserves"] = max(
                0.0, agent.get("propellant_reserves", 0.0) - propellant_drain
            )
            agent["energy_reserves"] = max(
                0.0, agent.get("energy_reserves", 0.0) - energy_drain
            )

    # -----------------------------------------------------------------
    # Step 3c: Knowledge Refresh
    # -----------------------------------------------------------------
    def _process_knowledge_refresh(
        self,
        state: GameState,
        agent_id: str,
        agent: dict,
        sector_id: str,
        config: dict,
    ) -> None:
        known_grid = agent.get("known_grid_state", {})
        timestamps = agent.get("knowledge_timestamps", {})

        # Current sector: refresh with exact data
        if sector_id:
            known_grid[sector_id] = {
                "dominion": copy.deepcopy(state.grid_dominion.get(sector_id, {})),
                "market": copy.deepcopy(state.grid_market.get(sector_id, {})),
                "stockpiles": copy.deepcopy(state.grid_stockpiles.get(sector_id, {})),
            }
            timestamps[sector_id] = state.sim_tick_count

        agent["known_grid_state"] = known_grid
        agent["knowledge_timestamps"] = timestamps

    # -----------------------------------------------------------------
    # Tag Refresh (Affinity System)
    # -----------------------------------------------------------------
    def _refresh_agent_tags(
        self,
        state: GameState,
        agent_id: str,
        agent: dict,
    ) -> None:
        """Derive and store agent tags from character traits + runtime state."""
        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})

        # Check cargo
        has_cargo = False
        if char_uid in state.inventories and 2 in state.inventories[char_uid]:
            inv = state.inventories[char_uid][2]
            has_cargo = any(float(qty) > 0.0 for qty in inv.values())

        tags = derive_agent_tags(char_data, agent, has_cargo=has_cargo)
        agent["sentiment_tags"] = tags

    def _refresh_sector_tags(self, state: GameState) -> None:
        """Derive and store tags for every sector."""
        for sector_id in state.world_topology:
            state.grid_sector_tags[sector_id] = derive_sector_tags(sector_id, state)
