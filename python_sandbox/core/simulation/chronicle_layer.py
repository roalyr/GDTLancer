"""
GDTLancer Chronicle Layer — Layer 4 (event capture + rumor generation).
Mirror of src/core/simulation/chronicle_layer.gd.

Processing (GDD Section 7, steps 5a–5e):
  5a. Collect — move staged events to chronicle_event_buffer
  5b. Tag Causality — Phase 1 stub
  5c. Significance Scores — Phase 1 stub (all = 0.5)
  5d. Rumor Engine — generate templated text
  5e. Distribute — push events to nearby agents' event_memory

PROJECT: GDTLancer
MODULE: core/simulation/chronicle_layer.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 6: Chronicle Layer)
"""

import copy
from autoload.game_state import GameState
from database.registry.template_data import LOCATIONS


class ChronicleLayer:
    """Event capture and rumor generation."""

    def __init__(self):
        self._staging_buffer: list = []
        self._max_buffer_size: int = 200
        self._max_rumors: int = 50
        self._max_agent_memory: int = 20

    # -----------------------------------------------------------------
    # Public API
    # -----------------------------------------------------------------
    def log_event(self, state: GameState, event_packet: dict) -> None:
        """Log a notable event for processing in the next tick."""
        if "tick_count" not in event_packet:
            event_packet["tick_count"] = state.sim_tick_count
        if "outcome" not in event_packet:
            event_packet["outcome"] = "success"
        if "metadata" not in event_packet:
            event_packet["metadata"] = {}
        self._staging_buffer.append(event_packet)

    def process_tick(self, state: GameState) -> None:
        if not self._staging_buffer:
            return

        new_events = self._collect_events(state)
        self._tag_causality(new_events)
        self._score_significance(new_events)
        new_rumors = self._generate_rumors(state, new_events)
        self._distribute_events(state, new_events)

        state.chronicle_rumors.extend(new_rumors)
        while len(state.chronicle_rumors) > self._max_rumors:
            state.chronicle_rumors.pop(0)

    # -----------------------------------------------------------------
    # 5a. Collect
    # -----------------------------------------------------------------
    def _collect_events(self, state: GameState) -> list:
        batch = list(self._staging_buffer)
        self._staging_buffer.clear()

        state.chronicle_event_buffer.extend(batch)
        while len(state.chronicle_event_buffer) > self._max_buffer_size:
            state.chronicle_event_buffer.pop(0)

        return batch

    # -----------------------------------------------------------------
    # 5b. Tag Causality (stub)
    # -----------------------------------------------------------------
    def _tag_causality(self, events: list) -> None:
        for event in events:
            event["causality_chain"] = []
            event["is_root_cause"] = True

    # -----------------------------------------------------------------
    # 5c. Significance Scores (stub)
    # -----------------------------------------------------------------
    def _score_significance(self, events: list) -> None:
        for event in events:
            event["significance"] = 0.5

    # -----------------------------------------------------------------
    # 5d. Rumor Engine
    # -----------------------------------------------------------------
    def _generate_rumors(self, state: GameState, events: list) -> list:
        rumors = []
        for event in events:
            rumor = self._format_rumor(state, event)
            if rumor:
                rumors.append(rumor)
        return rumors

    def _format_rumor(self, state: GameState, event: dict) -> str:
        actor_name = self._resolve_actor_name(state, event.get("actor_uid", ""))
        action = self._humanize_action(event.get("action_id", "unknown"))
        location_name = self._resolve_location_name(event.get("target_sector_id", ""))

        if not actor_name or not location_name:
            return ""

        detail = ""
        metadata = event.get("metadata", {})
        if "commodity_id" in metadata:
            detail = " " + self._humanize_id(metadata["commodity_id"])
        if "quantity" in metadata:
            detail += f" (x{int(metadata['quantity'])})"

        outcome = event.get("outcome", "success")
        if outcome != "success":
            return f"{actor_name} tried to {action}{detail} at {location_name}, but failed."

        return f"{actor_name} {action}{detail} at {location_name}."

    # -----------------------------------------------------------------
    # 5e. Distribute
    # -----------------------------------------------------------------
    def _distribute_events(self, state: GameState, events: list) -> None:
        for event in events:
            event_sector = event.get("target_sector_id", "")
            if not event_sector:
                continue

            relevant_sectors = [event_sector]
            if event_sector in state.world_topology:
                connections = state.world_topology[event_sector].get("connections", [])
                relevant_sectors.extend(connections)

            for agent_id, agent in state.agents.items():
                if agent.get("is_disabled", False):
                    continue
                agent_sector = agent.get("current_sector_id", "")
                if agent_sector in relevant_sectors:
                    memory = agent.get("event_memory", [])
                    memory.append(event)
                    while len(memory) > self._max_agent_memory:
                        memory.pop(0)
                    agent["event_memory"] = memory

    # -----------------------------------------------------------------
    # Name resolution helpers
    # -----------------------------------------------------------------
    def _resolve_actor_name(self, state: GameState, actor_uid) -> str:
        if isinstance(actor_uid, str):
            if actor_uid == "player":
                return "You"
            if actor_uid in state.agents:
                agent = state.agents[actor_uid]
                char_uid = agent.get("char_uid", -1)
                if char_uid in state.characters:
                    char_data = state.characters[char_uid]
                    return char_data.get("character_name", "Someone")
            return self._humanize_id(actor_uid)

        if isinstance(actor_uid, int) and actor_uid in state.characters:
            char_data = state.characters[actor_uid]
            return char_data.get("character_name", "Someone")

        return "Someone"

    def _resolve_location_name(self, sector_id: str) -> str:
        if not sector_id:
            return ""
        if sector_id in LOCATIONS:
            return LOCATIONS[sector_id].get("location_name", self._humanize_id(sector_id))
        return self._humanize_id(sector_id)

    def _humanize_action(self, action_id: str) -> str:
        action_map = {
            "buy": "bought",
            "sell": "sold",
            "move": "arrived",
            "repair": "repaired their ship",
            "dock": "docked",
            "undock": "departed",
            "destroy": "destroyed a target",
            "disabled": "was disabled",
            "trade": "traded",
            "respawn": "returned",
        }
        return action_map.get(action_id, action_id)

    def _humanize_id(self, id_str: str) -> str:
        stripped = id_str
        for prefix in ("commodity_", "persistent_", "character_", "faction_"):
            if stripped.startswith(prefix):
                stripped = stripped[len(prefix):]
                break
        parts = stripped.split("_")
        return " ".join(p.capitalize() for p in parts if p)
