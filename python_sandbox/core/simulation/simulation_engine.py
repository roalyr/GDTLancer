#
# PROJECT: GDTLancer
# MODULE: simulation_engine.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_11
# LOG_REF: 2026-02-21 (TASK_10)
#

"""Qualitative simulation tick orchestrator."""

from autoload.game_state import GameState
from autoload import constants
from core.simulation.agent_layer import AgentLayer
from core.simulation.bridge_systems import BridgeSystems
from core.simulation.chronicle_layer import ChronicleLayer
from core.simulation.grid_layer import GridLayer
from core.simulation.world_layer import WorldLayer


class SimulationEngine:
    def __init__(self):
        self.state = GameState()
        self.world_layer = WorldLayer()
        self.grid_layer = GridLayer()
        self.bridge_systems = BridgeSystems()
        self.agent_layer = AgentLayer()
        self.chronicle_layer = ChronicleLayer()

        self._initialized = False
        self._tick_config = {}
        self._build_tick_config()

    def initialize_simulation(self, seed_string: str) -> None:
        self.world_layer.initialize_world(self.state, seed_string)
        self.grid_layer.initialize_grid(self.state)
        self.agent_layer.initialize_agents(self.state)
        self.agent_layer.set_chronicle(self.chronicle_layer)

        self.state.world_age = constants.WORLD_AGE_CYCLE[0]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[self.state.world_age]
        self.state.world_age_cycle_count = 0
        self._apply_age_config()

        self._initialized = True

    def process_tick(self) -> None:
        if not self._initialized:
            raise RuntimeError("SimulationEngine is not initialized")

        self.state.sim_tick_count += 1
        self._advance_world_age()

        self.grid_layer.process_tick(self.state, self._tick_config)
        self.bridge_systems.process_tick(self.state, self._tick_config)
        self.agent_layer.process_tick(self.state, self._tick_config)
        self.chronicle_layer.process_tick(self.state)

    def advance_sub_ticks(self, cost: int) -> int:
        """Advance the simulation by *cost* sub-ticks.

        Sub-ticks accumulate in ``state.sub_tick_accumulator``.  Every time
        the accumulator reaches ``SUB_TICKS_PER_TICK`` a full simulation tick
        fires (economy, security, agents, chronicle, etc.).

        Args:
            cost: Number of sub-ticks to add (use the SUBTICK_COST_* constants).

        Returns:
            The number of full ticks that were processed (0, 1, or more).
        """
        if not self._initialized:
            raise RuntimeError("SimulationEngine is not initialized")

        self.state.sub_tick_accumulator += cost
        ticks_fired = 0
        threshold = constants.SUB_TICKS_PER_TICK
        while self.state.sub_tick_accumulator >= threshold:
            self.state.sub_tick_accumulator -= threshold
            self.process_tick()
            ticks_fired += 1
        return ticks_fired

    def _advance_world_age(self) -> None:
        self.state.world_age_timer -= 1
        if self.state.world_age_timer > 0:
            return

        cycle = constants.WORLD_AGE_CYCLE
        index = cycle.index(self.state.world_age)
        next_index = (index + 1) % len(cycle)

        if next_index == 0:
            self.state.world_age_cycle_count += 1

        self.state.world_age = cycle[next_index]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[self.state.world_age]
        self._apply_age_config()

        self.chronicle_layer.log_event(
            {
                "tick": self.state.sim_tick_count,
                "actor_id": "world",
                "action": "age_change",
                "sector_id": "",
                "metadata": {"new_age": self.state.world_age},
            }
        )

    def _apply_age_config(self) -> None:
        self._build_tick_config()
        self._tick_config.update(constants.WORLD_AGE_CONFIGS.get(self.state.world_age, {}))

    def _build_tick_config(self) -> None:
        self._tick_config = {
            "colony_upgrade_ticks_required": constants.COLONY_UPGRADE_TICKS_REQUIRED,
            "colony_downgrade_ticks_required": constants.COLONY_DOWNGRADE_TICKS_REQUIRED,
            "respawn_cooldown_ticks": constants.RESPAWN_COOLDOWN_TICKS,
            "catastrophe_chance_per_tick": constants.CATASTROPHE_CHANCE_PER_TICK,
            "catastrophe_disable_duration": constants.CATASTROPHE_DISABLE_DURATION,
            "mortal_global_cap": constants.MORTAL_GLOBAL_CAP,
            "mortal_spawn_required_security": list(constants.MORTAL_SPAWN_REQUIRED_SECURITY),
            "mortal_spawn_blocked_sector_tags": list(constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS),
        }

    def get_chronicle(self) -> ChronicleLayer:
        return self.chronicle_layer

    def is_initialized(self) -> bool:
        return self._initialized

    def set_config(self, key: str, value) -> None:
        self._tick_config[key] = value

    def get_config(self) -> dict:
        return dict(self._tick_config)
