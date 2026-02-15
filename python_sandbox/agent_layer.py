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
        self._chronicle = None  # Set after init via set_chronicle()
        self._rng = random.Random()  # Seeded per-tick for determinism

    def set_chronicle(self, chronicle) -> None:
        """Wire the chronicle layer so agent actions can log events."""
        self._chronicle = chronicle

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
        agent_role = agent_template.get("agent_role", "trader")
        goal_archetype = self._derive_initial_goal_from_role(agent_role)

        state.agents[agent_id] = self._create_agent_state(
            state, char_uid, start_sector, starting_credits,
            is_persistent=True, home_location_id=home_location,
            goal_archetype=goal_archetype, agent_role=agent_role,
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
        # Seed RNG per tick for determinism
        self._rng = random.Random(state.sim_tick_count)

        for agent_id in list(state.agents.keys()):
            if agent_id == "player":
                continue

            agent = state.agents[agent_id]

            if agent.get("is_disabled", False):
                self._check_respawn(state, agent_id, agent, config)
                continue

            # Cash sinks: docking fee + fuel costs
            self._apply_cash_sinks(state, agent_id, agent, config)

            # Hostile encounter check (piracy → damage)
            self._check_hostile_encounter(state, agent_id, agent, config)

            # Skip if agent was just disabled by pirates
            if agent.get("is_disabled", False):
                continue

            self._evaluate_goals(agent_id, agent, config)
            self._execute_action(state, agent_id, agent, config)

        self._update_hostile_population(state, config)

    # -----------------------------------------------------------------
    # Step 4a: Goal Evaluation (role-aware)
    # -----------------------------------------------------------------
    def _evaluate_goals(self, agent_id: str, agent: dict, config: dict) -> None:
        cash = agent.get("cash_reserves", 0.0)
        hull = agent.get("hull_integrity", 1.0)
        propellant = agent.get("propellant_reserves", 0.0)

        cash_threshold = config.get("npc_cash_low_threshold", 2000.0)
        hull_threshold = config.get("npc_hull_repair_threshold", 0.5)
        role = agent.get("agent_role", "trader")

        new_goals = []

        # --- Universal survival priorities (all roles) ---
        if hull < hull_threshold:
            new_goals.append({"type": "repair", "priority": 10})
            agent["goal_archetype"] = "repair"
        elif propellant < 10.0:
            new_goals.append({"type": "repair", "priority": 10})
            agent["goal_archetype"] = "repair"

        # --- Role-specific goals ---
        elif role == "trader":
            if cash < cash_threshold:
                new_goals.append({"type": "trade", "priority": 5})
                agent["goal_archetype"] = "trade"
            else:
                # Traders always trade even when rich
                new_goals.append({"type": "trade", "priority": 3})
                agent["goal_archetype"] = "trade"

        elif role == "prospector":
            new_goals.append({"type": "prospect", "priority": 5})
            agent["goal_archetype"] = "prospect"

        elif role == "military":
            new_goals.append({"type": "patrol", "priority": 5})
            agent["goal_archetype"] = "patrol"

        elif role == "hauler":
            new_goals.append({"type": "haul", "priority": 5})
            agent["goal_archetype"] = "haul"

        else:
            new_goals.append({"type": "idle", "priority": 1})
            agent["goal_archetype"] = "idle"

        agent["goal_queue"] = new_goals

    # -----------------------------------------------------------------
    # Step 4b: Action Execution (role-aware dispatch)
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
        elif goal_type == "prospect":
            self._action_prospect(state, agent_id, agent, config)
        elif goal_type == "patrol":
            self._action_patrol(state, agent_id, agent, config)
        elif goal_type == "haul":
            self._action_haul(state, agent_id, agent, config)
        # idle: do nothing

    def _action_trade(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Smart trade: buy cheap locally, travel to sell where expensive."""
        current_sector = agent.get("current_sector_id", "")
        cash = agent.get("cash_reserves", 0.0)
        char_uid = agent.get("char_uid", -1)
        has_cargo = self._agent_has_cargo(state, char_uid)

        if has_cargo:
            # Find the best sector to sell in (highest price delta for our cargo)
            best_sell_sector = self._find_best_sell_sector(state, agent, config)

            if best_sell_sector and best_sell_sector != current_sector:
                # Travel toward best sell location
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, best_sell_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "move", new_sector)
            else:
                # We're at the best place (or can't find better) — sell here
                self._action_sell(state, agent_id, agent, current_sector, config)
        elif cash > 0.0:
            # Find cheapest commodity across known sectors, travel there to buy
            best_buy_sector = self._find_best_buy_sector(state, agent, config)

            if best_buy_sector and best_buy_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, best_buy_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "move", new_sector)
            else:
                bought = self._action_buy(state, agent_id, agent, current_sector, config)
                if not bought:
                    # Can't buy here — move randomly
                    old_sector = current_sector
                    self._action_move_random(state, agent_id, agent)
                    new_sector = agent.get("current_sector_id", "")
                    if new_sector != old_sector:
                        self._log_event(state, agent_id, "move", new_sector)
        # else: no cash, no cargo — idle

    def _action_repair(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        home_sector = agent.get("home_location_id", "")
        repair_cost_per_point = config.get("repair_cost_per_point", 500.0)

        if current_sector == home_sector or not home_sector:
            hull = agent.get("hull_integrity", 1.0)
            if hull < 1.0:
                repair_amount = 0.1
                cost = repair_amount * repair_cost_per_point
                cash = agent.get("cash_reserves", 0.0)
                if cash >= cost:
                    agent["hull_integrity"] = min(1.0, hull + repair_amount)
                    agent["cash_reserves"] = cash - cost
                    self._log_event(state, agent_id, "repair", current_sector)
                else:
                    # Can't afford — partial repair with what we have
                    affordable_repair = cash / repair_cost_per_point
                    if affordable_repair > 0.001:
                        agent["hull_integrity"] = min(1.0, hull + affordable_repair)
                        agent["cash_reserves"] = 0.0
                        self._log_event(state, agent_id, "repair", current_sector)
            # Refuel at home
            propellant = agent.get("propellant_reserves", 0.0)
            if propellant < 100.0:
                refuel_amount = 100.0 - propellant
                fuel_cost = refuel_amount * config.get("fuel_cost_per_unit", 5.0)
                cash = agent.get("cash_reserves", 0.0)
                if cash >= fuel_cost:
                    agent["propellant_reserves"] = 100.0
                    agent["cash_reserves"] = cash - fuel_cost
        else:
            old_sector = current_sector
            self._action_move_toward(state, agent_id, agent, home_sector)
            new_sector = agent.get("current_sector_id", "")
            if new_sector != old_sector:
                self._log_event(state, agent_id, "move", new_sector)

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

        # Find cheapest commodity (most negative price delta = most oversupplied)
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

        self._log_event(state, agent_id, "buy", sector_id,
                        metadata={"commodity_id": best_commodity,
                                  "quantity": buy_amount,
                                  "total_cost": total_cost})
        return True

    def _action_sell(
        self, state: GameState, agent_id: str, agent: dict, sector_id: str,
        config: dict = None,
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

        base_price = 10.0
        if config:
            base_price = config.get("commodity_base_price", 10.0)

        total_revenue = 0.0
        for commodity_id in list(inv.keys()):
            quantity = inv[commodity_id]
            if quantity <= 0.0:
                continue

            delta = price_deltas.get(commodity_id, 0.0)
            sell_price = max(1.0, base_price + delta)
            revenue = quantity * sell_price
            total_revenue += revenue

            # Return commodities to stockpile (matter conservation)
            commodities[commodity_id] = commodities.get(commodity_id, 0.0) + quantity

            self._log_event(state, agent_id, "sell", sector_id,
                            metadata={"commodity_id": commodity_id,
                                      "quantity": quantity,
                                      "revenue": revenue})
            inv[commodity_id] = 0.0

        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + total_revenue

        # Clean up zero entries
        for commodity_id in list(inv.keys()):
            if inv[commodity_id] <= 0.0:
                del inv[commodity_id]

    # -----------------------------------------------------------------
    # Role: Prospector — travel to sectors with hidden resources, stay to prospect
    # -----------------------------------------------------------------
    def _action_prospect(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Prospectors travel to resource-rich sectors and boost discovery."""
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        move_interval = config.get("prospector_move_interval", 5)

        # Prospect at current location (presence boosts discovery via grid_layer)
        # Prospectors earn a small wage to stay alive
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + 10.0

        # Periodically move toward sector with most hidden resources
        if tick % move_interval == 0:
            best_sector = self._find_richest_hidden_sector(state, agent)
            if best_sector and best_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, best_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "prospect_move", new_sector)

    def _find_richest_hidden_sector(
        self, state: GameState, agent: dict
    ) -> str:
        """Find sector with the most hidden resources remaining."""
        best_sector = ""
        best_hidden = -1.0
        for sector_id, hidden in state.world_hidden_resources.items():
            total_hidden = hidden.get("mineral_density", 0.0) + hidden.get("propellant_sources", 0.0)
            if total_hidden > best_hidden:
                best_hidden = total_hidden
                best_sector = sector_id
        return best_sector

    # -----------------------------------------------------------------
    # Role: Military — patrol sectors, boost security, suppress piracy
    # -----------------------------------------------------------------
    def _action_patrol(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Military agents patrol and suppress piracy in their sector."""
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        patrol_interval = config.get("military_patrol_interval", 8)
        security_boost = config.get("military_security_boost", 0.02)
        piracy_suppress = config.get("military_piracy_suppress", 0.01)

        # Apply security effect at current sector
        dominion = state.grid_dominion.get(current_sector, {})
        old_security = dominion.get("security_level", 0.0)
        dominion["security_level"] = min(1.0, old_security + security_boost)

        old_piracy = dominion.get("pirate_activity", 0.0)
        dominion["pirate_activity"] = max(0.0, old_piracy - piracy_suppress)

        # Military agents earn a salary
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + 15.0

        # Periodically move toward highest-piracy sector
        if tick % patrol_interval == 0:
            worst_sector = self._find_highest_piracy_sector(state, agent)
            if worst_sector and worst_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, worst_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "patrol_move", new_sector)

    def _find_highest_piracy_sector(
        self, state: GameState, agent: dict
    ) -> str:
        """Find sector with worst piracy level."""
        best_sector = ""
        worst_piracy = -1.0
        for sector_id, dominion in state.grid_dominion.items():
            piracy = dominion.get("pirate_activity", 0.0)
            if piracy > worst_piracy:
                worst_piracy = piracy
                best_sector = sector_id
        return best_sector

    # -----------------------------------------------------------------
    # Role: Hauler — balance stockpiles between surplus/deficit sectors
    # -----------------------------------------------------------------
    def _action_haul(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Haulers move goods from surplus to deficit sectors (matter-conserving)."""
        current_sector = agent.get("current_sector_id", "")
        char_uid = agent.get("char_uid", -1)
        has_cargo = self._agent_has_cargo(state, char_uid)
        cargo_capacity = config.get("hauler_cargo_capacity", 20)

        # Haulers earn a small wage
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + 8.0

        if has_cargo:
            # Deliver to deficit sector
            deficit_sector = self._find_deficit_sector(state, agent, config)
            if deficit_sector and deficit_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, deficit_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "haul_move", new_sector)
            else:
                # At deficit sector (or nowhere to go) — unload
                self._haul_unload(state, agent_id, agent, current_sector)
        else:
            # Find surplus sector and load up
            surplus_sector = self._find_surplus_sector(state, agent, config)
            if surplus_sector and surplus_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, surplus_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "haul_move", new_sector)
            else:
                # At surplus sector — load
                self._haul_load(state, agent_id, agent, current_sector, cargo_capacity)

    def _find_surplus_sector(
        self, state: GameState, agent: dict, config: dict
    ) -> str:
        """Find sector with commodity stockpiles above average (surplus)."""
        threshold = config.get("hauler_surplus_threshold", 1.5)
        sector_totals = {}
        for sid, stockpile in state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            sector_totals[sid] = sum(float(v) for v in commodities.values())

        if not sector_totals:
            return ""
        avg = sum(sector_totals.values()) / len(sector_totals)
        if avg <= 0:
            return ""

        best_sector = ""
        best_ratio = 0.0
        for sid, total in sector_totals.items():
            ratio = total / avg
            if ratio > threshold and ratio > best_ratio:
                best_ratio = ratio
                best_sector = sid
        return best_sector

    def _find_deficit_sector(
        self, state: GameState, agent: dict, config: dict
    ) -> str:
        """Find sector with commodity stockpiles below average (deficit)."""
        threshold = config.get("hauler_deficit_threshold", 0.5)
        sector_totals = {}
        for sid, stockpile in state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            sector_totals[sid] = sum(float(v) for v in commodities.values())

        if not sector_totals:
            return ""
        avg = sum(sector_totals.values()) / len(sector_totals)
        if avg <= 0:
            return ""

        best_sector = ""
        worst_ratio = float("inf")
        for sid, total in sector_totals.items():
            ratio = total / avg
            if ratio < threshold and ratio < worst_ratio:
                worst_ratio = ratio
                best_sector = sid
        return best_sector

    def _haul_load(
        self, state: GameState, agent_id: str, agent: dict,
        sector_id: str, capacity: int,
    ) -> None:
        """Load most-available commodity from sector into hauler inventory."""
        if sector_id not in state.grid_stockpiles:
            return
        stockpiles = state.grid_stockpiles[sector_id]
        commodities = stockpiles.get("commodity_stockpiles", {})

        # Find most abundant commodity
        best_cid = ""
        best_qty = 0.0
        for cid, qty in commodities.items():
            if qty > best_qty:
                best_qty = qty
                best_cid = cid

        if not best_cid or best_qty <= 1.0:
            return

        load_amount = min(capacity, int(best_qty * 0.3))  # Take up to 30% of stock
        if load_amount <= 0:
            return

        commodities[best_cid] -= float(load_amount)

        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories:
            state.inventories[char_uid] = {}
        if 2 not in state.inventories[char_uid]:
            state.inventories[char_uid][2] = {}
        inv = state.inventories[char_uid][2]
        inv[best_cid] = inv.get(best_cid, 0.0) + float(load_amount)

        self._log_event(state, agent_id, "haul_load", sector_id,
                        metadata={"commodity_id": best_cid, "quantity": load_amount})

    def _haul_unload(
        self, state: GameState, agent_id: str, agent: dict, sector_id: str,
    ) -> None:
        """Unload all cargo into sector stockpiles (matter-conserving)."""
        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories or 2 not in state.inventories[char_uid]:
            return

        inv = state.inventories[char_uid][2]
        if not inv:
            return

        stockpiles = state.grid_stockpiles.get(sector_id, {})
        commodities = stockpiles.get("commodity_stockpiles", {})

        for cid in list(inv.keys()):
            qty = inv[cid]
            if qty <= 0.0:
                continue
            commodities[cid] = commodities.get(cid, 0.0) + qty
            self._log_event(state, agent_id, "haul_unload", sector_id,
                            metadata={"commodity_id": cid, "quantity": qty})
            inv[cid] = 0.0

        # Clean up
        for cid in list(inv.keys()):
            if inv[cid] <= 0.0:
                del inv[cid]

    # -----------------------------------------------------------------
    # Smart Trade Route Helpers
    # -----------------------------------------------------------------
    def _find_best_sell_sector(
        self, state: GameState, agent: dict, config: dict,
    ) -> str:
        """Find sector where our cargo fetches the highest price, using known state."""
        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories or 2 not in state.inventories[char_uid]:
            return ""

        inv = state.inventories[char_uid][2]
        cargo_commodities = [cid for cid, qty in inv.items() if qty > 0]
        if not cargo_commodities:
            return ""

        known_grid = agent.get("known_grid_state", {})
        base_price = config.get("commodity_base_price", 10.0)

        best_sector = ""
        best_revenue = -float("inf")

        for sector_id, known in known_grid.items():
            sector_market = known.get("market", {})
            price_deltas = sector_market.get("commodity_price_deltas", {})

            total_revenue = 0.0
            for cid in cargo_commodities:
                qty = inv[cid]
                delta = price_deltas.get(cid, 0.0)
                sell_price = max(1.0, base_price + delta)
                total_revenue += qty * sell_price

            if total_revenue > best_revenue:
                best_revenue = total_revenue
                best_sector = sector_id

        return best_sector

    def _find_best_buy_sector(
        self, state: GameState, agent: dict, config: dict,
    ) -> str:
        """Find sector with cheapest commodity (most negative price delta)."""
        known_grid = agent.get("known_grid_state", {})

        best_sector = ""
        best_delta = float("inf")

        for sector_id, known in known_grid.items():
            sector_market = known.get("market", {})
            price_deltas = sector_market.get("commodity_price_deltas", {})
            sector_stockpiles = known.get("stockpiles", {})
            commodities = sector_stockpiles.get("commodity_stockpiles", {})

            for cid, delta in price_deltas.items():
                available = commodities.get(cid, 0.0)
                if available > 1.0 and delta < best_delta:
                    best_delta = delta
                    best_sector = sector_id

        return best_sector

    def _action_move_random(
        self, state: GameState, agent_id: str, agent: dict
    ) -> None:
        current_sector = agent.get("current_sector_id", "")
        if current_sector not in state.world_topology:
            return

        connections = state.world_topology[current_sector].get("connections", [])
        if not connections:
            return

        target = self._rng.choice(connections)
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

        agent["current_sector_id"] = self._rng.choice(connections)

    # -----------------------------------------------------------------
    # Cash Sinks
    # -----------------------------------------------------------------
    def _apply_cash_sinks(
        self, state: GameState, agent_id: str, agent: dict, config: dict,
    ) -> None:
        """Apply per-tick cash drains: docking fees."""
        sector_id = agent.get("current_sector_id", "")
        topology = state.world_topology.get(sector_id, {})
        is_docked = topology.get("sector_type", "") in ("hub", "frontier")

        if is_docked:
            docking_fee = config.get("docking_fee_base", 50.0)
            maintenance = state.grid_maintenance.get(sector_id, {})
            maint_mod = maintenance.get("maintenance_cost_modifier", 1.0)
            fee = docking_fee * maint_mod
            agent["cash_reserves"] = max(0.0, agent.get("cash_reserves", 0.0) - fee)

    # -----------------------------------------------------------------
    # Hostile Encounters (piracy → damage)
    # -----------------------------------------------------------------
    def _check_hostile_encounter(
        self, state: GameState, agent_id: str, agent: dict, config: dict,
    ) -> None:
        """Check if agent encounters pirates in their sector."""
        sector_id = agent.get("current_sector_id", "")
        dominion = state.grid_dominion.get(sector_id, {})
        piracy = dominion.get("pirate_activity", 0.0)

        if piracy <= 0.0:
            return

        # Hostile count in this sector
        hostile_count = 0
        for htype, hdata in state.hostile_population_integral.items():
            hostile_count += hdata.get("sector_counts", {}).get(sector_id, 0)

        if hostile_count <= 0:
            return

        # Encounter chance scales with piracy level
        base_chance = config.get("piracy_encounter_chance", 0.3)
        encounter_chance = base_chance * piracy

        # Character combat skill reduces chance
        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})
        combat_skill = char_data.get("skills", {}).get("combat", 1)
        encounter_chance *= max(0.2, 1.0 - combat_skill * 0.1)

        if self._rng.random() > encounter_chance:
            return

        # --- Encounter happens ---
        damage_min = config.get("piracy_damage_min", 0.05)
        damage_max = config.get("piracy_damage_max", 0.25)
        damage = self._rng.uniform(damage_min, damage_max)

        hull = agent.get("hull_integrity", 1.0)
        hull -= damage
        agent["hull_integrity"] = max(0.0, hull)

        # Cargo loss (matter returns to sector stockpile — Axiom 1)
        cargo_loss_frac = config.get("piracy_cargo_loss_fraction", 0.2)
        self._lose_cargo_to_piracy(state, agent, sector_id, cargo_loss_frac)

        if hull <= 0.0:
            # Agent disabled
            agent["is_disabled"] = True
            agent["disabled_at_tick"] = state.sim_tick_count
            agent["hull_integrity"] = 0.0
            self._log_event(state, agent_id, "disabled", sector_id,
                            metadata={"cause": "piracy", "damage": damage})
        else:
            self._log_event(state, agent_id, "pirate_attack", sector_id,
                            metadata={"damage": damage,
                                      "hull_remaining": agent["hull_integrity"]})

    def _lose_cargo_to_piracy(
        self, state: GameState, agent: dict, sector_id: str, loss_fraction: float,
    ) -> None:
        """Pirates steal a fraction of cargo — matter returns to sector stockpile."""
        char_uid = agent.get("char_uid", -1)
        if char_uid not in state.inventories or 2 not in state.inventories[char_uid]:
            return

        inv = state.inventories[char_uid][2]
        stockpiles = state.grid_stockpiles.get(sector_id, {})
        commodities = stockpiles.get("commodity_stockpiles", {})

        for commodity_id in list(inv.keys()):
            qty = inv[commodity_id]
            if qty <= 0.0:
                continue
            lost = qty * loss_fraction
            inv[commodity_id] = qty - lost
            # Return to sector stockpile (matter conservation)
            commodities[commodity_id] = commodities.get(commodity_id, 0.0) + lost

        # Clean up — return dust to stockpile (matter conservation)
        for commodity_id in list(inv.keys()):
            if inv[commodity_id] <= 0.001:
                dust = inv[commodity_id]
                if dust > 0.0:
                    commodities[commodity_id] = commodities.get(commodity_id, 0.0) + dust
                del inv[commodity_id]

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
            agent["cash_reserves"] = max(agent.get("cash_reserves", 0.0), 500.0)
            agent["goal_queue"] = [{"type": "idle", "priority": 1}]
            agent["goal_archetype"] = "idle"

            self._log_event(state, agent_id, "respawn",
                            agent["current_sector_id"])

            print(
                f"AgentLayer: {agent_id} respawned at "
                f"{agent['current_sector_id']} (tick {current_tick})"
            )

    # -----------------------------------------------------------------
    # Chronicle Event Logging
    # -----------------------------------------------------------------
    def _log_event(
        self, state: GameState, agent_id: str, action: str,
        sector_id: str, metadata: dict = None,
    ) -> None:
        """Log an event to the Chronicle layer if available."""
        if self._chronicle is None:
            return

        event = {
            "actor_uid": agent_id,
            "action_id": action,
            "target_uid": "",
            "target_sector_id": sector_id,
            "tick_count": state.sim_tick_count,
            "outcome": "success",
            "metadata": metadata or {},
        }
        self._chronicle.log_event(state, event)

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
        agent_role: str = "idle",
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
            "agent_role": agent_role,
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

    def _derive_initial_goal_from_role(self, role: str) -> str:
        """Map agent role to initial goal archetype."""
        role_to_goal = {
            "trader": "trade",
            "prospector": "prospect",
            "military": "patrol",
            "hauler": "haul",
            "idle": "idle",
        }
        return role_to_goal.get(role, "idle")

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
