"""
GDTLancer Agent Layer — Layer 3 (NPC goal evaluation + action execution).
Mirror of src/core/simulation/agent_layer.gd.

Processing (GDD Section 7, steps 4a–4c):
  4a. NPC Goal Evaluation — re-evaluate goals from known_grid_state
  4b. NPC Action Selection — execute highest-priority feasible action
  4c. Player — skip (player acts in real-time)
"""

import copy
import random
from game_state import GameState
from template_data import AGENTS, CHARACTERS


class AgentLayer:
    """Processes all Agent-layer logic for one simulation tick."""

    def __init__(self):
        self._next_uid: int = 1000

    # -----------------------------------------------------------------
    # Initialization
    # -----------------------------------------------------------------
    def initialize_agents(self, state: GameState) -> None:
        """Seed all Agent Layer state from template data."""
        state.agents.clear()
        state.characters.clear()
        state.inventories.clear()
        state.assets_ships.clear()
        state.hostile_population_integral.clear()

        self._initialize_player(state)

        for agent_id, agent_template in AGENTS.items():
            if agent_template["agent_type"] == "player":
                continue
            if agent_template.get("is_persistent", False):
                self._initialize_persistent_agent(state, agent_id, agent_template)

        self._initialize_hostile_population(state)

        print(
            f"AgentLayer: Initialized {len(state.agents)} agents "
            f"({len(state.agents) - 1} persistent NPCs + player)."
        )

    def _initialize_player(self, state: GameState) -> None:
        char_uid = self._generate_uid()
        state.player_character_uid = char_uid

        char_data = CHARACTERS.get("character_default", {})
        state.characters[char_uid] = copy.deepcopy(char_data)

        # Find starting hub sector
        start_sector = ""
        for sector_id, topology in state.world_topology.items():
            if topology.get("sector_type", "") == "hub":
                start_sector = sector_id
                break
        if not start_sector and state.world_topology:
            start_sector = next(iter(state.world_topology))

        starting_credits = char_data.get("credits", 10000)

        state.agents["player"] = self._create_agent_state(
            state, char_uid, start_sector, starting_credits,
            is_persistent=False, home_location_id="", goal_archetype="idle",
        )
        state.inventories[char_uid] = {}

    def _initialize_persistent_agent(
        self, state: GameState, agent_id: str, agent_template: dict
    ) -> None:
        char_uid = self._generate_uid()

        char_template_id = agent_template.get("character_template_id", "")
        char_data = CHARACTERS.get(char_template_id, {})
        state.characters[char_uid] = copy.deepcopy(char_data)

        home_location = agent_template.get("home_location_id", "")
        start_sector = home_location if home_location in state.world_topology else ""
        if not start_sector and state.world_topology:
            start_sector = next(iter(state.world_topology))

        starting_credits = char_data.get("credits", 5000)
        goal_archetype = self._derive_initial_goal(char_data)

        state.agents[agent_id] = self._create_agent_state(
            state, char_uid, start_sector, starting_credits,
            is_persistent=True, home_location_id=home_location,
            goal_archetype=goal_archetype,
        )
        state.inventories[char_uid] = {}
        state.persistent_agents[agent_id] = state.agents[agent_id]

    def _initialize_hostile_population(self, state: GameState) -> None:
        total_piracy = 0.0
        sector_counts = {}

        for sector_id, dominion in state.grid_dominion.items():
            piracy = dominion.get("pirate_activity", 0.0)
            total_piracy += piracy
            sector_counts[sector_id] = int(piracy * 10.0)

        carrying_capacity = max(5, int(total_piracy * 20.0))

        state.hostile_population_integral["pirates"] = {
            "current_count": int(total_piracy * 10.0),
            "carrying_capacity": carrying_capacity,
            "sector_counts": sector_counts,
        }

    # -----------------------------------------------------------------
    # Tick processing
    # -----------------------------------------------------------------
    def process_tick(self, state: GameState, config: dict) -> None:
        for agent_id in list(state.agents.keys()):
            if agent_id == "player":
                continue

            agent = state.agents[agent_id]

            if agent.get("is_disabled", False):
                self._check_respawn(state, agent_id, agent, config)
                continue

            self._evaluate_goals(agent_id, agent, config)
            self._execute_action(state, agent_id, agent, config)

        self._update_hostile_population(state, config)

    # -----------------------------------------------------------------
    # Step 4a: Goal Evaluation
    # -----------------------------------------------------------------
    def _evaluate_goals(self, agent_id: str, agent: dict, config: dict) -> None:
        cash = agent.get("cash_reserves", 0.0)
        hull = agent.get("hull_integrity", 1.0)

        cash_threshold = config.get("npc_cash_low_threshold", 2000.0)
        hull_threshold = config.get("npc_hull_repair_threshold", 0.5)

        new_goals = []

        if hull < hull_threshold:
            new_goals.append({"type": "repair", "priority": 3})
            agent["goal_archetype"] = "repair"
        elif cash < cash_threshold:
            new_goals.append({"type": "trade", "priority": 2})
            agent["goal_archetype"] = "trade"
        else:
            new_goals.append({"type": "idle", "priority": 1})
            agent["goal_archetype"] = "idle"

        agent["goal_queue"] = new_goals

    # -----------------------------------------------------------------
    # Step 4b: Action Execution
    # -----------------------------------------------------------------
    def _execute_action(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        goal_queue = agent.get("goal_queue", [])
        if not goal_queue:
            return

        current_goal = goal_queue[0]
        goal_type = current_goal.get("type", "idle")

        if goal_type == "trade":
            self._action_trade(state, agent_id, agent, config)
        elif goal_type == "repair":
            self._action_repair(state, agent_id, agent, config)
        # idle: do nothing

    def _action_trade(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        cash = agent.get("cash_reserves", 0.0)
        char_uid = agent.get("char_uid", -1)
        has_cargo = self._agent_has_cargo(state, char_uid)

        if has_cargo:
            self._action_sell(state, agent_id, agent, current_sector)
        elif cash > 0.0:
            bought = self._action_buy(state, agent_id, agent, current_sector, config)
            if not bought:
                self._action_move_random(state, agent_id, agent)
        # else: no cash, no cargo — idle

    def _action_repair(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        home_sector = agent.get("home_location_id", "")

        if current_sector == home_sector or not home_sector:
            repair_amount = 0.1
            agent["hull_integrity"] = min(1.0, agent.get("hull_integrity", 1.0) + repair_amount)
        else:
            self._action_move_toward(state, agent_id, agent, home_sector)

    def _action_buy(
        self, state: GameState, agent_id: str, agent: dict,
        sector_id: str, config: dict,
    ) -> bool:
        if sector_id not in state.grid_stockpiles:
            return False

        stockpiles = state.grid_stockpiles[sector_id]
        commodities = stockpiles.get("commodity_stockpiles", {})
        market = state.grid_market.get(sector_id, {})
        price_deltas = market.get("commodity_price_deltas", {})

        # Find cheapest commodity
        best_commodity = ""
        best_delta = float("inf")
        for commodity_id, qty in commodities.items():
            if qty <= 0.0:
                continue
            delta = price_deltas.get(commodity_id, 0.0)
            if delta < best_delta:
                best_delta = delta
                best_commodity = commodity_id

        if not best_commodity:
            return False

        base_price = config.get("commodity_base_price", 10.0)
        actual_price = max(1.0, base_price + best_delta)
        affordable = int(agent.get("cash_reserves", 0.0) / actual_price)
        available = int(commodities[best_commodity])
        buy_amount = min(affordable, available, 10)

        if buy_amount <= 0:
            return False

        total_cost = float(buy_amount) * actual_price
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) - total_cost
        commodities[best_commodity] -= float(buy_amount)

        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories:
            state.inventories[char_uid] = {}
        if 2 not in state.inventories[char_uid]:
            state.inventories[char_uid][2] = {}
        inv = state.inventories[char_uid][2]
        inv[best_commodity] = inv.get(best_commodity, 0.0) + float(buy_amount)

        return True

    def _action_sell(
        self, state: GameState, agent_id: str, agent: dict, sector_id: str
    ) -> None:
        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories:
            return
        if 2 not in state.inventories[char_uid]:
            return

        inv = state.inventories[char_uid][2]
        if not inv:
            return

        market = state.grid_market.get(sector_id, {})
        price_deltas = market.get("commodity_price_deltas", {})
        stockpiles = state.grid_stockpiles.get(sector_id, {})
        commodities = stockpiles.get("commodity_stockpiles", {})

        total_revenue = 0.0
        for commodity_id in list(inv.keys()):
            quantity = inv[commodity_id]
            if quantity <= 0.0:
                continue

            base_price = 10.0
            delta = price_deltas.get(commodity_id, 0.0)
            sell_price = max(1.0, base_price + delta)
            total_revenue += quantity * sell_price

            # Return commodities to stockpile (matter conservation)
            commodities[commodity_id] = commodities.get(commodity_id, 0.0) + quantity
            inv[commodity_id] = 0.0

        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + total_revenue

        # Clean up zero entries
        for commodity_id in list(inv.keys()):
            if inv[commodity_id] <= 0.0:
                del inv[commodity_id]

    def _action_move_random(
        self, state: GameState, agent_id: str, agent: dict
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        if current_sector not in state.world_topology:
            return

        connections = state.world_topology[current_sector].get("connections", [])
        if not connections:
            return

        target = random.choice(connections)
        agent["current_sector_id"] = target

    def _action_move_toward(
        self, state: GameState, agent_id: str, agent: dict, target_sector: str
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        if current_sector == target_sector:
            return
        if current_sector not in state.world_topology:
            return

        connections = state.world_topology[current_sector].get("connections", [])
        if not connections:
            return

        if target_sector in connections:
            agent["current_sector_id"] = target_sector
            return

        agent["current_sector_id"] = random.choice(connections)

    # -----------------------------------------------------------------
    # Respawn
    # -----------------------------------------------------------------
    def _check_respawn(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        if not agent.get("is_persistent", False):
            return

        disabled_at = agent.get("disabled_at_tick", 0)
        current_tick = state.sim_tick_count

        tick_interval = config.get("world_tick_interval_seconds", 60.0)
        respawn_timeout = config.get("respawn_timeout_seconds", 300.0)
        respawn_ticks = int(respawn_timeout / tick_interval) if tick_interval > 0.0 else 5

        if (current_tick - disabled_at) >= respawn_ticks:
            agent["is_disabled"] = False
            agent["disabled_at_tick"] = 0
            agent["hull_integrity"] = 1.0
            agent["current_sector_id"] = agent.get("home_location_id", "")
            agent["propellant_reserves"] = 100.0
            agent["energy_reserves"] = 100.0
            agent["consumables_reserves"] = 100.0
            agent["goal_queue"] = [{"type": "idle", "priority": 1}]
            agent["goal_archetype"] = "idle"

            print(
                f"AgentLayer: {agent_id} respawned at "
                f"{agent['current_sector_id']} (tick {current_tick})"
            )

    # -----------------------------------------------------------------
    # Hostile Population
    # -----------------------------------------------------------------
    def _update_hostile_population(self, state: GameState, config: dict) -> None:
        growth_rate = config.get("hostile_growth_rate", 0.05)

        for hostile_type, pop_data in state.hostile_population_integral.items():
            current_count = pop_data.get("current_count", 0)
            sector_counts = pop_data.get("sector_counts", {})

            total_piracy = 0.0
            for sector_id, dominion in state.grid_dominion.items():
                piracy = dominion.get("pirate_activity", 0.0)
                total_piracy += piracy

            carrying_capacity = max(5, int(total_piracy * 20.0))
            pop_data["carrying_capacity"] = carrying_capacity

            # Logistic growth
            delta = growth_rate * float(current_count) * (
                1.0 - float(current_count) / float(max(carrying_capacity, 1))
            )
            new_count = max(0, current_count + int(round(delta)))
            pop_data["current_count"] = new_count

            # Distribute across sectors
            sector_counts.clear()
            if total_piracy > 0.0 and new_count > 0:
                for sector_id, dominion in state.grid_dominion.items():
                    piracy = dominion.get("pirate_activity", 0.0)
                    sector_share = int(float(new_count) * (piracy / total_piracy))
                    if sector_share > 0:
                        sector_counts[sector_id] = sector_share
            pop_data["sector_counts"] = sector_counts

    # -----------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------
    def _create_agent_state(
        self,
        state: GameState,
        char_uid: int,
        sector_id: str,
        cash: float,
        is_persistent: bool,
        home_location_id: str,
        goal_archetype: str,
    ) -> dict:
        return {
            "char_uid": char_uid,
            "current_sector_id": sector_id,
            "hull_integrity": 1.0,
            "propellant_reserves": 100.0,
            "energy_reserves": 100.0,
            "consumables_reserves": 100.0,
            "cash_reserves": cash,
            "fleet_ships": [],
            "current_heat_level": 0.0,
            "is_persistent": is_persistent,
            "home_location_id": home_location_id,
            "is_disabled": False,
            "disabled_at_tick": 0,
            "known_grid_state": self._snapshot_grid_state(state),
            "knowledge_timestamps": self._create_knowledge_timestamps(state),
            "goal_queue": [{"type": goal_archetype, "priority": 1}],
            "goal_archetype": goal_archetype,
            "event_memory": [],
            "faction_standings": {},
            "character_standings": {},
            "sentiment_tags": [],
        }

    def _snapshot_grid_state(self, state: GameState) -> dict:
        snapshot = {}
        for sector_id in state.grid_dominion:
            snapshot[sector_id] = {
                "dominion": copy.deepcopy(state.grid_dominion.get(sector_id, {})),
                "market": copy.deepcopy(state.grid_market.get(sector_id, {})),
                "stockpiles": copy.deepcopy(state.grid_stockpiles.get(sector_id, {})),
            }
        return snapshot

    def _create_knowledge_timestamps(self, state: GameState) -> dict:
        return {sector_id: state.sim_tick_count for sector_id in state.world_topology}

    def _derive_initial_goal(self, char_data: dict) -> str:
        traits = char_data.get("personality_traits", {})
        greed = traits.get("greed", 0.5)
        if greed >= 0.5:
            return "trade"
        return "idle"

    def _agent_has_cargo(self, state: GameState, char_uid: int) -> bool:
        if char_uid not in state.inventories:
            return False
        if 2 not in state.inventories[char_uid]:
            return False
        inv = state.inventories[char_uid][2]
        return any(float(qty) > 0.0 for qty in inv.values())

    def _generate_uid(self) -> int:
        uid = self._next_uid
        self._next_uid += 1
        return uid
