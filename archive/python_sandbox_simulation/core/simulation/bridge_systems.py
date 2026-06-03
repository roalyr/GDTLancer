#
# PROJECT: GDTLancer
# MODULE: bridge_systems.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_9
# LOG_REF: 2026-02-21 (TASK_8)
#

"""Bridge systems: derive and refresh qualitative tags across layers."""

from core.simulation.affinity_matrix import derive_agent_tags, derive_sector_tags


class BridgeSystems:
    """Cross-layer tag refresh only (agent, sector, world)."""

    def process_tick(self, state, config: dict) -> None:
        self._refresh_sector_tags(state)
        self._refresh_agent_tags(state)
        self._refresh_world_tags(state)

    def _refresh_agent_tags(self, state) -> None:
        state.agent_tags = state.agent_tags or {}
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue
            character_id = agent.get("character_id", "")
            char_data = state.characters.get(character_id, {})
            has_cargo = "LOADED" in agent.get("initial_tags", []) or agent.get("cargo_tag") == "LOADED"
            tags = derive_agent_tags(char_data, agent, has_cargo=has_cargo)
            state.agent_tags[agent_id] = tags
            agent["sentiment_tags"] = tags

    def _refresh_sector_tags(self, state) -> None:
        for sector_id in state.world_topology:
            state.sector_tags[sector_id] = derive_sector_tags(sector_id, state)

    def _refresh_world_tags(self, state) -> None:
        age = state.world_age or "PROSPERITY"
        mapping = {
            "PROSPERITY": ["ABUNDANT", "STABLE"],
            "DISRUPTION": ["SCARCE", "VOLATILE"],
            "RECOVERY": ["RECOVERING"],
        }
        state.world_tags = mapping.get(age, ["STABLE"])
