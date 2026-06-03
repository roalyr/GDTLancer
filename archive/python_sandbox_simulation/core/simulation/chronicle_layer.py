#
# PROJECT: GDTLancer
# MODULE: chronicle_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_12
# LOG_REF: 2026-02-21 (TASK_11)
#

"""Chronicle layer: capture events, generate rumors, distribute memory."""

from database.registry.template_data import LOCATIONS


class ChronicleLayer:
    def __init__(self):
        self._staging_buffer = []
        self._max_events = 200
        self._max_rumors = 50
        self._max_agent_memory = 20

    def log_event(self, event_packet: dict) -> None:
        packet = dict(event_packet)
        packet.setdefault("tick", 0)
        packet.setdefault("actor_id", "unknown")
        packet.setdefault("action", "unknown")
        packet.setdefault("sector_id", "")
        packet.setdefault("metadata", {})
        self._staging_buffer.append(packet)

    def process_tick(self, state) -> None:
        if not self._staging_buffer:
            return

        events = self._collect_events(state)
        rumors = self._generate_rumors(state, events)
        self._distribute_events(state, events)

        state.chronicle_rumors.extend(rumors)
        if len(state.chronicle_rumors) > self._max_rumors:
            state.chronicle_rumors = state.chronicle_rumors[-self._max_rumors :]

    def _collect_events(self, state) -> list:
        events = list(self._staging_buffer)
        self._staging_buffer.clear()
        state.chronicle_events.extend(events)
        if len(state.chronicle_events) > self._max_events:
            state.chronicle_events = state.chronicle_events[-self._max_events :]
        return events

    def _generate_rumors(self, state, events: list) -> list:
        rumors = []
        for event in events:
            rumor = self._format_rumor(state, event)
            if rumor:
                rumors.append(rumor)
        return rumors

    def _format_rumor(self, state, event: dict) -> str:
        actor = self._resolve_actor_name(state, event.get("actor_id", ""))
        action = self._humanize_action(event.get("action", "unknown"))
        sector = self._resolve_location_name(event.get("sector_id", ""), state)
        if not actor or not sector:
            return ""
        return f"{actor} {action} at {sector}."

    def _distribute_events(self, state, events: list) -> None:
        for event in events:
            sector_id = event.get("sector_id", "")
            if not sector_id:
                continue
            visible = [sector_id] + state.world_topology.get(sector_id, {}).get("connections", [])
            for agent in state.agents.values():
                if agent.get("is_disabled"):
                    continue
                if agent.get("current_sector_id") not in visible:
                    continue
                memory = list(agent.get("event_memory", []))
                memory.append(event)
                if len(memory) > self._max_agent_memory:
                    memory = memory[-self._max_agent_memory :]
                agent["event_memory"] = memory

    def _resolve_actor_name(self, state, actor_id: str) -> str:
        if actor_id == "player":
            return "You"
        if actor_id in state.agents:
            character_id = state.agents[actor_id].get("character_id", "")
            if character_id in state.characters:
                return state.characters[character_id].get("character_name", actor_id)
        return str(actor_id)

    def _resolve_location_name(self, sector_id: str, state=None) -> str:
        if sector_id in LOCATIONS:
            return LOCATIONS[sector_id].get("location_name", sector_id)
        if state and hasattr(state, "sector_names"):
            return state.sector_names.get(sector_id, sector_id)
        return sector_id

    def _humanize_action(self, action: str) -> str:
        labels = {
            "move": "moved",
            "attack": "attacked",
            "agent_trade": "traded",
            "dock": "docked",
            "harvest": "harvested salvage",
            "load_cargo": "loaded cargo",
            "flee": "fled",
            "exploration": "explored",
            "sector_discovered": "discovered a new sector",
            "spawn": "appeared",
            "respawn": "returned",
            "survived": "narrowly survived destruction",
            "perma_death": "was permanently lost",
            "catastrophe": "witnessed catastrophe",
            "age_change": "reported a world-age shift",
        }
        return labels.get(action, action)
