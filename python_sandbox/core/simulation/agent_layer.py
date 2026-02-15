"""
GDTLancer Agent Layer — Layer 3 (NPC goal evaluation + action execution).
Mirror of src/core/simulation/agent_layer.gd.

Processing (GDD Section 7, steps 4a–4c):
  4a. NPC Goal Evaluation — re-evaluate goals from known_grid_state
  4b. NPC Action Selection — execute highest-priority feasible action
  4c. Player — skip (player acts in real-time)

PROJECT: GDTLancer
MODULE: core/simulation/agent_layer.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 4: Agent Layer)
"""

import copy
import random
from autoload.game_state import GameState
from database.registry.template_data import AGENTS, CHARACTERS
from autoload import constants


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
        """Initialize hostile population tracking structures (empty).

        Hostiles (drones and aliens) are hive creatures — NOT pirates.
        They emerge ONLY when per-type matter pools can fund them.
        Pools are fed by consumption entropy tax and wreck salvage.
        No free spawning — strict pool-in / pool-out (Axiom 1).
        """
        for htype in ["drones", "aliens"]:
            state.hostile_population_integral[htype] = {
                "current_count": 0,
                "sector_counts": {},
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
        self._check_catastrophe(state, config)
        self._spawn_mortal_agents(state, config)
        self._cleanup_dead_mortals(state)

    # -----------------------------------------------------------------
    # Step 4a: Goal Evaluation (role-aware)
    # -----------------------------------------------------------------
    def _evaluate_goals(self, agent_id: str, agent: dict, config: dict) -> None:
        cash = agent.get("cash_reserves", 0.0)
        hull = agent.get("hull_integrity", 1.0)
        propellant = agent.get("propellant_reserves", 0.0)

        cash_threshold = config.get("npc_cash_low_threshold", 2000.0)
        hull_threshold = config.get("npc_hull_repair_threshold", 0.5)
        desperation_hull = config.get("desperation_hull_threshold", 0.3)
        role = agent.get("agent_role", "trader")

        new_goals = []

        # --- Desperation check: broke AND broken → risk trade ---
        if hull < hull_threshold and cash <= 0.0:
            # Can't repair without cash, can't earn cash while stuck on repair.
            # Break the deadlock: allow desperation trading at hull risk.
            new_goals.append({"type": "trade", "priority": 15})
            agent["goal_archetype"] = "trade"

        # --- Normal survival priorities ---
        elif hull < hull_threshold:
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

        elif role == "pirate":
            new_goals.append({"type": "raid", "priority": 5})
            agent["goal_archetype"] = "raid"

        elif role == "explorer":
            new_goals.append({"type": "explore", "priority": 5})
            agent["goal_archetype"] = "explore"

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
        elif goal_type == "raid":
            self._action_pirate(state, agent_id, agent, config)
        elif goal_type == "explore":
            self._action_explore(state, agent_id, agent, config)
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
        """Prospectors travel to resource-rich sectors, boost discovery,
        and salvage wrecks in high-security sectors → matter to stockpiles (Axiom 1)."""
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        move_interval = config.get("prospector_move_interval", 5)

        # Prospect at current location (presence boosts discovery via grid_layer)
        # Prospectors earn a small wage to stay alive
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + 10.0

        # --- Wreck salvage in high-security sectors ---
        security_threshold = config.get(
            "prospector_wreck_security_threshold", 0.6
        )
        salvage_rate = config.get("prospector_wreck_salvage_rate", 0.15)
        dominion = state.grid_dominion.get(current_sector, {})
        security = dominion.get("security_level", 0.0)

        if security >= security_threshold and state.grid_wrecks:
            # Find wrecks in this sector and salvage them
            sector_wrecks = [
                (uid, w) for uid, w in state.grid_wrecks.items()
                if w.get("sector_id", "") == current_sector
            ]
            for wreck_uid, wreck in sector_wrecks:
                inventory = wreck.get("wreck_inventory", {})
                stockpiles = state.grid_stockpiles.get(current_sector, {})
                commodities = stockpiles.get("commodity_stockpiles", {})

                # Salvage a fraction of each inventory item → stockpiles
                salvaged_total = 0.0
                for item_id in list(inventory.keys()):
                    qty = inventory[item_id]
                    if qty <= 0.0:
                        continue
                    salvaged = qty * salvage_rate
                    inventory[item_id] = qty - salvaged
                    # Map wreck items to commodity stockpile
                    # Use commodity_ore as default for generic wreck matter
                    target_commodity = item_id if item_id.startswith("commodity_") else "commodity_ore"
                    commodities[target_commodity] = commodities.get(target_commodity, 0.0) + salvaged
                    salvaged_total += salvaged

                # Salvage hull mass fraction too (integrity IS the hull mass now)
                integrity = wreck.get("wreck_integrity", 0.0)
                hull_salvage = min(integrity, salvage_rate * integrity)
                if hull_salvage > 0.0:
                    wreck["wreck_integrity"] = integrity - hull_salvage
                    commodities["commodity_ore"] = commodities.get("commodity_ore", 0.0) + hull_salvage
                    salvaged_total += hull_salvage

                if salvaged_total > 0.0:
                    self._log_event(state, agent_id, "wreck_salvage", current_sector,
                                    metadata={"wreck_uid": wreck_uid, "matter": salvaged_total})

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
    # Role: Pirate — raid cargo from other agents, exploit disruption
    # -----------------------------------------------------------------
    def _action_pirate(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Pirates travel to vulnerable sectors and steal cargo from agents."""
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        move_interval = config.get("pirate_move_interval", 6)
        raid_chance = config.get("pirate_raid_chance", 0.25)
        steal_fraction = config.get("pirate_raid_cargo_steal", 0.3)
        home_advantage = config.get("pirate_home_advantage", 0.15)

        # Pirates boost piracy — dampened by local security
        dominion = state.grid_dominion.get(current_sector, {})
        old_piracy = dominion.get("pirate_activity", 0.0)
        security = dominion.get("security_level", 0.5)
        effective_advantage = home_advantage * (1.0 - security)
        dominion["pirate_activity"] = min(1.0, old_piracy + effective_advantage)

        # Try to raid another agent in the same sector
        if self._rng.random() < raid_chance:
            self._pirate_raid(state, agent_id, agent, current_sector, steal_fraction)

        # Periodically move toward most vulnerable sector
        if tick % move_interval == 0:
            target_sector = self._find_vulnerable_sector(state, agent)
            if target_sector and target_sector != current_sector:
                old_sector = current_sector
                self._action_move_toward(state, agent_id, agent, target_sector)
                new_sector = agent.get("current_sector_id", "")
                if new_sector != old_sector:
                    self._log_event(state, agent_id, "pirate_move", new_sector)

    def _pirate_raid(
        self, state: GameState, pirate_agent_id: str, pirate_agent: dict,
        sector_id: str, steal_fraction: float,
    ) -> None:
        """Pirate steals cargo from a random non-pirate agent in sector."""
        targets = []
        for agent_id, agent in state.agents.items():
            if agent_id == pirate_agent_id:
                continue
            if agent.get("is_disabled", False):
                continue
            if agent.get("current_sector_id", "") != sector_id:
                continue
            if agent.get("agent_role", "") == "pirate":
                continue
            char_uid = agent.get("char_uid", -1)
            if self._agent_has_cargo(state, char_uid):
                targets.append((agent_id, agent))

        if not targets:
            return

        target_agent_id, target_agent = self._rng.choice(targets)
        target_char_uid = target_agent.get("char_uid", -1)
        pirate_char_uid = pirate_agent.get("char_uid", -1)

        if target_char_uid not in state.inventories or 2 not in state.inventories[target_char_uid]:
            return

        target_inv = state.inventories[target_char_uid][2]
        if pirate_char_uid not in state.inventories:
            state.inventories[pirate_char_uid] = {}
        if 2 not in state.inventories[pirate_char_uid]:
            state.inventories[pirate_char_uid][2] = {}
        pirate_inv = state.inventories[pirate_char_uid][2]

        total_stolen = 0.0
        for commodity_id in list(target_inv.keys()):
            qty = target_inv[commodity_id]
            if qty <= 0.0:
                continue
            stolen = qty * steal_fraction
            target_inv[commodity_id] = qty - stolen
            pirate_inv[commodity_id] = pirate_inv.get(commodity_id, 0.0) + stolen
            total_stolen += stolen

        # Clean up dust
        for commodity_id in list(target_inv.keys()):
            if target_inv[commodity_id] <= 0.001:
                dust = target_inv[commodity_id]
                if dust > 0.0:
                    pirate_inv[commodity_id] = pirate_inv.get(commodity_id, 0.0) + dust
                del target_inv[commodity_id]

        if total_stolen > 0.0:
            pirate_agent["cash_reserves"] = pirate_agent.get("cash_reserves", 0.0) + total_stolen * 5.0
            self._log_event(state, pirate_agent_id, "pirate_raid", sector_id,
                            metadata={"target": target_agent_id, "stolen": total_stolen})

    def _find_vulnerable_sector(
        self, state: GameState, agent: dict,
    ) -> str:
        """Find sector with lowest security and highest stockpiles."""
        best_sector = ""
        best_score = -float("inf")
        for sector_id, dominion in state.grid_dominion.items():
            security = dominion.get("security_level", 1.0)
            stockpiles = state.grid_stockpiles.get(sector_id, {})
            total_stock = sum(float(v) for v in stockpiles.get("commodity_stockpiles", {}).values())
            score = total_stock * (1.0 - security)
            if score > best_score:
                best_score = score
                best_sector = sector_id
        return best_sector

    # -----------------------------------------------------------------
    # Role: Explorer — discover new sectors via expeditions
    # -----------------------------------------------------------------
    def _action_explore(
        self, state: GameState, agent_id: str, agent: dict, config: dict
    ) -> None:
        """Explorers travel to frontier sectors and launch discovery expeditions."""
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        move_interval = config.get("explorer_move_interval", 8)
        expedition_cost = config.get("explorer_expedition_cost", 500.0)
        expedition_fuel = config.get("explorer_expedition_fuel", 30.0)
        discovery_chance = config.get("explorer_discovery_chance", 0.15)
        max_sectors = config.get("explorer_max_discovered_sectors", 10)
        wage = config.get("explorer_wage", 12.0)

        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + wage

        topology = state.world_topology.get(current_sector, {})
        is_frontier = topology.get("sector_type", "") in ("frontier", "outpost")

        if is_frontier:
            cash = agent.get("cash_reserves", 0.0)
            fuel = agent.get("propellant_reserves", 0.0)

            if (cash >= expedition_cost and fuel >= expedition_fuel
                    and state.discovered_sector_count < max_sectors):
                agent["cash_reserves"] = cash - expedition_cost
                agent["propellant_reserves"] = fuel - expedition_fuel
                hidden = state.world_hidden_resources.get(current_sector, {})
                hidden["propellant_sources"] = (
                    hidden.get("propellant_sources", 0.0) + expedition_fuel
                )

                if self._rng.random() < discovery_chance:
                    new_sector_id = self._discover_new_sector(
                        state, current_sector, agent_id, config
                    )
                    if new_sector_id:
                        self._log_event(state, agent_id, "sector_discovered",
                                        current_sector,
                                        metadata={"new_sector": new_sector_id})
                else:
                    self._log_event(state, agent_id, "expedition_failed",
                                    current_sector)
        else:
            if tick % move_interval == 0:
                target = self._find_frontier_sector(state, agent)
                if target and target != current_sector:
                    old_sector = current_sector
                    self._action_move_toward(state, agent_id, agent, target)
                    new_sector = agent.get("current_sector_id", "")
                    if new_sector != old_sector:
                        self._log_event(state, agent_id, "explore_move", new_sector)

    def _find_frontier_sector(self, state: GameState, agent: dict) -> str:
        """Find a frontier/outpost sector to explore from."""
        best = ""
        best_hidden = -1.0
        for sid, topology in state.world_topology.items():
            stype = topology.get("sector_type", "")
            if stype in ("frontier", "outpost"):
                hidden = state.world_hidden_resources.get(sid, {})
                total = hidden.get("mineral_density", 0.0) + hidden.get("propellant_sources", 0.0)
                if total > best_hidden:
                    best_hidden = total
                    best = sid
        return best

    def _discover_new_sector(
        self, state: GameState, from_sector: str, agent_id: str, config: dict
    ) -> str:
        """Generate a new frontier sector connected to from_sector."""
        sector_num = state.discovered_sector_count + 1
        new_sector_id = f"sector_discovered_{sector_num}"

        source_hidden = state.world_hidden_resources.get(from_sector, {})
        source_mineral = source_hidden.get("mineral_density", 0.0)
        source_propellant = source_hidden.get("propellant_sources", 0.0)

        transfer_fraction = 0.05
        new_mineral = source_mineral * transfer_fraction
        new_propellant = source_propellant * transfer_fraction

        if new_mineral + new_propellant < 1.0:
            return ""

        source_hidden["mineral_density"] = source_mineral - new_mineral
        source_hidden["propellant_sources"] = source_propellant - new_propellant

        disc_mineral = new_mineral * 0.1
        disc_propellant = new_propellant * 0.1
        hidden_mineral = new_mineral * 0.9
        hidden_propellant = new_propellant * 0.9

        base_capacity = config.get("new_sector_base_capacity", 600)
        base_power = config.get("new_sector_base_power", 60.0)

        state.world_topology[new_sector_id] = {
            "connections": [from_sector],
            "station_ids": [new_sector_id],
            "sector_type": "frontier",
        }
        if from_sector in state.world_topology:
            from_connections = state.world_topology[from_sector].get("connections", [])
            if new_sector_id not in from_connections:
                from_connections.append(new_sector_id)

        state.world_resource_potential[new_sector_id] = {
            "mineral_density": disc_mineral,
            "energy_potential": 50.0,
            "propellant_sources": disc_propellant,
        }
        state.world_hidden_resources[new_sector_id] = {
            "mineral_density": hidden_mineral,
            "propellant_sources": hidden_propellant,
        }

        radiation = 0.10 + self._rng.uniform(0.0, 0.10)
        thermal = 250.0 + self._rng.uniform(-30.0, 60.0)
        gravity = 1.0 + self._rng.uniform(0.0, 0.5)

        state.world_hazards[new_sector_id] = {
            "radiation_level": radiation,
            "thermal_background_k": thermal,
            "gravity_well_penalty": gravity,
        }
        state.world_hazards_base[new_sector_id] = copy.deepcopy(
            state.world_hazards[new_sector_id]
        )

        state.grid_stockpiles[new_sector_id] = {
            "commodity_stockpiles": {},
            "stockpile_capacity": base_capacity,
            "extraction_rate": {},
        }

        faction_influence = {}
        for fid in state.grid_dominion.get(from_sector, {}).get("faction_influence", {}).keys():
            faction_influence[fid] = 0.1
        faction_influence["faction_independents"] = 0.5

        state.grid_dominion[new_sector_id] = {
            "faction_influence": faction_influence,
            "security_level": 0.2,
            "pirate_activity": 0.3,
            "controlling_faction_id": "faction_independents",
            "hostility_level": 0.3,
        }
        state.grid_market[new_sector_id] = {
            "commodity_price_deltas": {},
            "population_density": 0.5,
            "service_cost_modifier": 1.5,
        }
        state.grid_power[new_sector_id] = {
            "station_power_output": base_power,
            "station_power_draw": 0.0,
            "power_load_ratio": 0.0,
        }
        state.grid_maintenance[new_sector_id] = {
            "local_entropy_rate": 0.002,
            "maintenance_cost_modifier": 1.5,
        }
        state.grid_resource_availability[new_sector_id] = {
            "propellant_supply": disc_propellant,
            "consumables_supply": 0.0,
            "energy_supply": 0.0,
        }

        state.colony_levels[new_sector_id] = "frontier"
        state.colony_upgrade_progress[new_sector_id] = 0
        state.colony_downgrade_progress[new_sector_id] = 0

        for htype in ["drones", "aliens"]:
            pop_data = state.hostile_population_integral.get(htype, {})
            sector_counts = pop_data.get("sector_counts", {})
            sector_counts[new_sector_id] = 2 if htype == "drones" else 0

        state.discovered_sector_count = len(state.world_topology)

        state.discovery_log.append({
            "sector_id": new_sector_id,
            "tick": state.sim_tick_count,
            "discovered_by": agent_id,
            "from_sector": from_sector,
            "matter_transferred": new_mineral + new_propellant,
        })

        return new_sector_id

    # -----------------------------------------------------------------
    # Mortal (non-named) Agent System
    # -----------------------------------------------------------------
    def _spawn_mortal_agents(self, state: GameState, config: dict) -> None:
        """Spawn generic, non-persistent agents in prosperous sectors."""
        spawn_chance = config.get("mortal_spawn_chance_per_tick", 0.005)
        min_stock = config.get("mortal_spawn_min_stockpile", 500.0)
        min_sec = config.get("mortal_spawn_min_security", 0.5)
        spawn_cash = config.get("mortal_spawn_cash", 800.0)
        global_cap = config.get("mortal_global_cap", 20)

        mortal_count = sum(
            1 for a in state.agents.values()
            if not a.get("is_persistent", True) and a.get("agent_role", "") != "idle"
            and not a.get("is_disabled", False)
        )
        if mortal_count >= global_cap:
            return

        for sector_id in state.world_topology:
            if mortal_count >= global_cap:
                break

            stockpiles = state.grid_stockpiles.get(sector_id, {})
            commodities = stockpiles.get("commodity_stockpiles", {})
            total_stock = sum(float(v) for v in commodities.values())
            dominion = state.grid_dominion.get(sector_id, {})
            security = dominion.get("security_level", 0.0)

            if total_stock < min_stock or security < min_sec:
                continue

            if self._rng.random() >= spawn_chance:
                continue

            state.mortal_agent_counter += 1
            agent_num = state.mortal_agent_counter
            agent_id = f"mortal_{agent_num}"

            roles = constants.MORTAL_ROLES
            weights = constants.MORTAL_ROLE_WEIGHTS
            role = self._rng.choices(roles, weights=weights, k=1)[0]

            char_uid = self._generate_uid()
            char_name = f"Crew-{agent_num}"
            state.characters[char_uid] = {
                "character_name": char_name,
                "faction_id": "faction_independents",
                "credits": spawn_cash,
                "skills": {"piloting": 2, "combat": 1, "trading": 2},
                "age": self._rng.randint(20, 50),
                "reputation": 0,
                "personality_traits": {},
                "description": f"Generic {role} #{agent_num}",
            }

            goal = self._derive_initial_goal_from_role(role)
            state.agents[agent_id] = self._create_agent_state(
                state, char_uid, sector_id, spawn_cash,
                is_persistent=False, home_location_id=sector_id,
                goal_archetype=goal, agent_role=role,
            )
            state.inventories[char_uid] = {}
            mortal_count += 1

            self._log_event(state, agent_id, "mortal_spawn", sector_id,
                            metadata={"role": role, "name": char_name})

    def _cleanup_dead_mortals(self, state: GameState) -> None:
        """Permanently remove disabled mortal agents (they don't respawn)."""
        to_remove = []
        for agent_id, agent in state.agents.items():
            if agent_id == "player":
                continue
            if agent.get("is_persistent", True):
                continue
            if agent.get("agent_role", "") == "idle":
                continue
            if agent.get("is_disabled", False):
                to_remove.append(agent_id)

        for agent_id in to_remove:
            agent = state.agents[agent_id]
            sector_id = agent.get("current_sector_id", "")
            state.mortal_agent_deaths.append({
                "agent_id": agent_id,
                "tick": state.sim_tick_count,
                "sector_id": sector_id,
                "cause": "death",
            })
            char_uid = agent.get("char_uid", -1)
            if char_uid in state.inventories:
                del state.inventories[char_uid]
            if char_uid in state.characters:
                del state.characters[char_uid]
            del state.agents[agent_id]

    # -----------------------------------------------------------------
    # Hostile Management Helpers
    # -----------------------------------------------------------------
    def _kill_hostile_in_sector(
        self, state: GameState, sector_id: str, kill_count: int,
        create_wreck: bool = True,
    ) -> None:
        """Remove hostiles from a sector (combat kills)."""
        spawn_cost = constants.HOSTILE_SPAWN_COST
        remaining = kill_count
        total_body_mass_released = 0.0

        for htype in ["drones", "aliens"]:
            if remaining <= 0:
                break
            pop_data = state.hostile_population_integral.get(htype, {})
            sector_counts = pop_data.get("sector_counts", {})
            count_here = sector_counts.get(sector_id, 0)
            if count_here <= 0:
                continue
            killed = min(count_here, remaining)
            sector_counts[sector_id] = count_here - killed
            pop_data["current_count"] = max(0, pop_data.get("current_count", 0) - killed)
            remaining -= killed

            pool = state.hostile_pools.get(htype, {"reserve": 0.0, "body_mass": 0.0})
            body_release = min(killed * spawn_cost, pool["body_mass"])
            pool["body_mass"] -= body_release
            total_body_mass_released += body_release

        if create_wreck and total_body_mass_released > 0.01:
            wreck_uid = f"hostile_wreck_{state.sim_tick_count}_{sector_id[-3:]}"
            if wreck_uid in state.grid_wrecks:
                existing = state.grid_wrecks[wreck_uid]
                existing["wreck_integrity"] = existing.get("wreck_integrity", 0) + total_body_mass_released
            else:
                state.grid_wrecks[wreck_uid] = {
                    "sector_id": sector_id,
                    "wreck_integrity": total_body_mass_released,
                    "wreck_inventory": {},
                }

    def _create_wreck_from_agent(
        self, state: GameState, agent: dict, sector_id: str,
    ) -> None:
        """When an agent is destroyed, create a wreck from remaining cargo (Axiom 1)."""
        char_uid = agent.get("char_uid", -1)
        wreck_inventory = {}

        if char_uid in state.inventories and 2 in state.inventories[char_uid]:
            inv = state.inventories[char_uid][2]
            for commodity_id, qty in list(inv.items()):
                if qty > 0.0:
                    wreck_inventory[commodity_id] = qty
                    inv[commodity_id] = 0.0
            for cid in list(inv.keys()):
                if inv[cid] <= 0.0:
                    del inv[cid]

        if wreck_inventory:
            wreck_uid = f"wreck_{state.sim_tick_count}_{char_uid}"
            state.grid_wrecks[wreck_uid] = {
                "sector_id": sector_id,
                "wreck_integrity": 0.0,
                "wreck_inventory": wreck_inventory,
            }

    # -----------------------------------------------------------------
    # Smart Trade Route Helpers
    # -----------------------------------------------------------------
    def _find_best_sell_sector(
        self, state: GameState, agent: dict, config: dict,
    ) -> str:
        """Find sector where our cargo fetches the highest price."""
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

        if sector_id in state.sector_disabled_until:
            if state.sim_tick_count < state.sector_disabled_until[sector_id]:
                is_docked = False

        if is_docked:
            docking_fee = config.get("docking_fee_base", 50.0)
            maintenance = state.grid_maintenance.get(sector_id, {})
            maint_mod = maintenance.get("maintenance_cost_modifier", 1.0)
            fee = docking_fee * maint_mod
            cash = agent.get("cash_reserves", 0.0)
            if cash >= fee:
                agent["cash_reserves"] = cash - fee
            else:
                shortfall = fee - cash
                agent["cash_reserves"] = 0.0
                agent["debt"] = agent.get("debt", 0.0) + shortfall

        debt = agent.get("debt", 0.0)
        if debt > 0.0:
            interest_rate = config.get("debt_interest_rate", 0.0001)
            debt_cap = config.get("debt_cap", 10000.0)
            agent["debt"] = min(debt * (1.0 + interest_rate), debt_cap)

        # --- Entropy death check ---
        hull = agent.get("hull_integrity", 0.0)
        if hull <= 0.0:
            grace = config.get("entropy_death_tick_grace", 20)
            stalled_since = agent.get("hull_zero_since", 0)
            if stalled_since == 0:
                agent["hull_zero_since"] = state.sim_tick_count
            elif (state.sim_tick_count - stalled_since) >= grace:
                agent["is_disabled"] = True
                agent["disabled_at_tick"] = state.sim_tick_count
                agent["hull_zero_since"] = 0
                self._create_wreck_from_agent(state, agent, sector_id)
                self._log_event(state, agent_id, "disabled", sector_id,
                                metadata={"cause": "entropy_death"})
        else:
            agent["hull_zero_since"] = 0

    # -----------------------------------------------------------------
    # Hostile Encounters (piracy → damage)
    # -----------------------------------------------------------------
    def _check_hostile_encounter(
        self, state: GameState, agent_id: str, agent: dict, config: dict,
    ) -> None:
        """Check if agent encounters hostile drones/aliens in their sector."""
        if agent.get("agent_role", "") == "pirate":
            return

        sector_id = agent.get("current_sector_id", "")

        hostile_count = 0
        for htype, hdata in state.hostile_population_integral.items():
            hostile_count += hdata.get("sector_counts", {}).get(sector_id, 0)

        if hostile_count <= 0:
            return

        base_chance = config.get("hostile_encounter_chance", 0.3)
        density_factor = min(1.0, hostile_count / 10.0)
        encounter_chance = base_chance * density_factor

        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})
        combat_skill = char_data.get("skills", {}).get("combat", 1)
        encounter_chance *= max(0.2, 1.0 - combat_skill * 0.1)

        if self._rng.random() > encounter_chance:
            return

        damage_min = config.get("hostile_damage_min", 0.05)
        damage_max = config.get("hostile_damage_max", 0.25)
        damage = self._rng.uniform(damage_min, damage_max)

        hull = agent.get("hull_integrity", 1.0)
        hull -= damage
        agent["hull_integrity"] = max(0.0, hull)

        cargo_loss_frac = config.get("hostile_cargo_loss_fraction", 0.2)
        self._lose_cargo_to_piracy(state, agent, sector_id, cargo_loss_frac)

        self._kill_hostile_in_sector(state, sector_id, 1)

        if hull <= 0.0:
            agent["is_disabled"] = True
            agent["disabled_at_tick"] = state.sim_tick_count
            agent["hull_integrity"] = 0.0
            self._create_wreck_from_agent(state, agent, sector_id)
            self._log_event(state, agent_id, "disabled", sector_id,
                            metadata={"cause": "hostile_attack", "damage": damage})
        else:
            self._log_event(state, agent_id, "hostile_attack", sector_id,
                            metadata={"damage": damage,
                                      "hull_remaining": agent["hull_integrity"],
                                      "hostiles_in_sector": hostile_count})

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
            commodities[commodity_id] = commodities.get(commodity_id, 0.0) + lost

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

        debt = agent.get("debt", 0.0)
        debt_cap = config.get("debt_cap", 10000.0)
        cooldown_normal = config.get("respawn_cooldown_normal", 5)
        cooldown_max_debt = config.get("respawn_cooldown_max_debt", 200)

        if debt >= debt_cap * 0.9:
            respawn_ticks = cooldown_max_debt
        else:
            debt_ratio = debt / max(debt_cap, 1.0)
            respawn_ticks = int(cooldown_normal + (cooldown_max_debt - cooldown_normal) * debt_ratio)

        if (current_tick - disabled_at) >= respawn_ticks:
            agent["is_disabled"] = False
            agent["disabled_at_tick"] = 0
            agent["hull_integrity"] = 1.0
            agent["current_sector_id"] = agent.get("home_location_id", "")
            agent["propellant_reserves"] = 100.0
            agent["energy_reserves"] = 100.0
            agent["consumables_reserves"] = 100.0
            agent["hull_zero_since"] = 0
            respawn_debt = config.get("respawn_debt_penalty", 500.0)
            agent["debt"] = agent.get("debt", 0.0) + respawn_debt
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
        """Update drone/alien populations — strict pool-in / pool-out (Axiom 1)."""
        low_sec_threshold = config.get("hostile_low_security_threshold", 0.4)
        wreck_salvage_rate = config.get("hostile_wreck_salvage_rate", 0.1)
        spawn_cost = config.get("hostile_spawn_cost", 10.0)
        kill_per_military = config.get("hostile_kill_per_military", 0.5)
        global_cap = config.get("hostile_global_cap", 100)

        pool_pressure_threshold = config.get("hostile_pool_pressure_threshold", 500.0)
        pool_spawn_rate = config.get("hostile_pool_spawn_rate", 0.02)
        pool_max_spawns = config.get("hostile_pool_max_spawns_per_tick", 5)

        raid_threshold = config.get("hostile_raid_threshold", 5)
        raid_chance = config.get("hostile_raid_chance", 0.15)
        raid_stockpile_frac = config.get("hostile_raid_stockpile_fraction", 0.05)
        raid_casualties = config.get("hostile_raid_casualties", 2)

        # PRESSURE VALVE
        for htype in ["drones", "aliens"]:
            pool = state.hostile_pools.get(htype, {"reserve": 0.0, "body_mass": 0.0})
            pop_data = state.hostile_population_integral.get(htype, {})
            current_count = pop_data.get("current_count", 0)

            if current_count >= global_cap:
                continue

            reserve = pool["reserve"]
            if reserve <= pool_pressure_threshold:
                continue

            excess = reserve - pool_pressure_threshold
            budget_this_tick = excess * pool_spawn_rate
            max_from_budget = int(budget_this_tick / spawn_cost) if spawn_cost > 0 else 0
            num_spawns = min(max_from_budget, pool_max_spawns, global_cap - current_count)

            if num_spawns <= 0:
                continue

            cost = num_spawns * spawn_cost
            pool["reserve"] -= cost
            pool["body_mass"] += cost

            sector_scores = {}
            for sid in state.grid_dominion:
                sec = state.grid_dominion[sid].get("security_level", 1.0)
                stk = state.grid_stockpiles.get(sid, {})
                stock_total = sum(float(v) for v in
                                  stk.get("commodity_stockpiles", {}).values())
                sector_scores[sid] = max(0.01, (1.0 - sec) * (1.0 + stock_total / 500.0))
            total_score = sum(sector_scores.values())

            sorted_sids = sorted(sector_scores.keys())
            spawns_left = num_spawns
            for sid in sorted_sids:
                if spawns_left <= 0:
                    break
                share = max(1, int(num_spawns * sector_scores[sid] / total_score))
                share = min(share, spawns_left)
                sc = pop_data.get("sector_counts", {})
                sc[sid] = sc.get(sid, 0) + share
                pop_data["sector_counts"] = sc
                pop_data["current_count"] = pop_data.get("current_count", 0) + share
                spawns_left -= share

        # HOSTILE RAIDS
        for sector_id in list(state.grid_dominion.keys()):
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)

            if hostiles_here < raid_threshold:
                continue
            if self._rng.random() > raid_chance:
                continue

            stockpiles = state.grid_stockpiles.get(sector_id, {})
            commodities = stockpiles.get("commodity_stockpiles", {})
            raid_inventory = {}
            total_raided = 0.0

            for cid in list(commodities.keys()):
                qty = commodities[cid]
                if qty <= 0.0:
                    continue
                taken = qty * raid_stockpile_frac
                commodities[cid] = qty - taken
                raid_inventory[cid] = taken
                total_raided += taken

            if total_raided > 0.5:
                wreck_uid = f"raid_wreck_{state.sim_tick_count}_{sector_id[-3:]}"
                state.grid_wrecks[wreck_uid] = {
                    "sector_id": sector_id,
                    "wreck_integrity": min(total_raided * 0.1, 5.0),
                    "wreck_inventory": raid_inventory,
                }

                self._log_event(state, "hostile_swarm", "raid", sector_id,
                                metadata={"matter_raided": round(total_raided, 1),
                                          "hostiles": hostiles_here})

            self._kill_hostile_in_sector(state, sector_id, raid_casualties)

        # Update hostility_level in dominion
        for sector_id in state.grid_dominion:
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)
            hostility = min(1.0, hostiles_here / 10.0)
            state.grid_dominion[sector_id]["hostility_level"] = hostility

        # Military kills
        military_counts = {}
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue
            if agent.get("agent_role", "") == "military":
                sid = agent.get("current_sector_id", "")
                military_counts[sid] = military_counts.get(sid, 0) + 1

        for sector_id, mil_count in military_counts.items():
            kills = int(mil_count * kill_per_military)
            if kills > 0:
                self._kill_hostile_in_sector(state, sector_id, kills)

        # Wreck salvage in low-security sectors → per-type pool reserves
        for wreck_uid in list(state.grid_wrecks.keys()):
            wreck = state.grid_wrecks[wreck_uid]
            sector_id = wreck.get("sector_id", "")
            dominion = state.grid_dominion.get(sector_id, {})
            security = dominion.get("security_level", 1.0)

            if security >= low_sec_threshold:
                continue

            type_counts = {}
            total_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                c = pop_data.get("sector_counts", {}).get(sector_id, 0)
                type_counts[htype] = c
                total_here += c

            if total_here <= 0:
                continue

            inventory = wreck.get("wreck_inventory", {})
            matter_consumed = 0.0

            for item_id in list(inventory.keys()):
                qty = inventory[item_id]
                if qty <= 0.0:
                    continue
                consumed = qty * wreck_salvage_rate
                inventory[item_id] = qty - consumed
                matter_consumed += consumed

            integrity = wreck.get("wreck_integrity", 0.0)
            hull_consumed = min(integrity, wreck_salvage_rate)
            wreck["wreck_integrity"] = integrity - hull_consumed
            matter_consumed += hull_consumed

            if matter_consumed > 0.0:
                for htype in ["drones", "aliens"]:
                    share = matter_consumed * (type_counts[htype] / total_here)
                    state.hostile_pools[htype]["reserve"] += share

            for item_id in list(inventory.keys()):
                if inventory[item_id] <= 0.001:
                    del inventory[item_id]

        # Redistribute hostiles toward low-security sectors with wrecks
        for htype in ["drones", "aliens"]:
            pop_data = state.hostile_population_integral.get(htype, {})
            current_count = pop_data.get("current_count", 0)
            if current_count <= 0:
                pop_data["sector_counts"] = {}
                continue

            sector_weights = {}
            total_weight = 0.0
            for sector_id in state.grid_dominion:
                dominion = state.grid_dominion[sector_id]
                security = dominion.get("security_level", 1.0)
                topology = state.world_topology.get(sector_id, {})
                is_frontier = topology.get("sector_type", "") == "frontier"
                wreck_count = sum(
                    1 for w in state.grid_wrecks.values()
                    if w.get("sector_id", "") == sector_id
                )
                frontier_bonus = 2.0 if is_frontier else 0.0
                weight = (1.0 - security) * (1.0 + wreck_count + frontier_bonus)
                sector_weights[sector_id] = max(0.01, weight)
                total_weight += sector_weights[sector_id]

            sector_counts = {}
            if total_weight > 0.0:
                assigned = 0
                sorted_sectors = sorted(sector_weights.keys())
                for i, sector_id in enumerate(sorted_sectors):
                    if i == len(sorted_sectors) - 1:
                        sector_counts[sector_id] = current_count - assigned
                    else:
                        share = int(float(current_count) * (sector_weights[sector_id] / total_weight))
                        if share > 0:
                            sector_counts[sector_id] = share
                            assigned += share
            pop_data["sector_counts"] = sector_counts

    # -----------------------------------------------------------------
    # Catastrophic Events
    # -----------------------------------------------------------------
    def _check_catastrophe(self, state: GameState, config: dict) -> None:
        """Check for random catastrophic events that disrupt a sector."""
        chance = config.get("catastrophe_chance_per_tick", 0.0005)
        if self._rng.random() > chance:
            return

        sectors = list(state.world_topology.keys())
        if not sectors:
            return

        target_sector = self._rng.choice(sectors)

        if target_sector in state.sector_disabled_until:
            if state.sim_tick_count < state.sector_disabled_until[target_sector]:
                return

        disable_duration = config.get("catastrophe_disable_duration", 50)
        stockpile_to_wreck = config.get("catastrophe_stockpile_to_wreck", 0.6)
        hazard_boost = config.get("catastrophe_hazard_boost", 0.15)
        security_drop = config.get("catastrophe_security_drop", 0.4)

        stockpiles = state.grid_stockpiles.get(target_sector, {})
        commodities = stockpiles.get("commodity_stockpiles", {})
        wreck_inventory = {}
        total_converted = 0.0

        for commodity_id in list(commodities.keys()):
            qty = commodities[commodity_id]
            if qty <= 0.0:
                continue
            converted = qty * stockpile_to_wreck
            commodities[commodity_id] = qty - converted
            wreck_inventory[commodity_id] = converted
            total_converted += converted

        if wreck_inventory:
            wreck_uid = f"catastrophe_wreck_{state.sim_tick_count}_{target_sector}"
            state.grid_wrecks[wreck_uid] = {
                "sector_id": target_sector,
                "wreck_integrity": 0.0,
                "wreck_inventory": wreck_inventory,
            }

        state.sector_disabled_until[target_sector] = (
            state.sim_tick_count + disable_duration
        )

        dominion = state.grid_dominion.get(target_sector, {})
        old_security = dominion.get("security_level", 0.0)
        dominion["security_level"] = max(0.0, old_security - security_drop)

        hazards = state.world_hazards.get(target_sector, {})
        old_radiation = hazards.get("radiation_level", 0.0)
        hazards["radiation_level"] = min(1.0, old_radiation + hazard_boost)

        state.catastrophe_log.append({
            "sector_id": target_sector,
            "tick": state.sim_tick_count,
            "matter_converted": total_converted,
            "disable_until": state.sector_disabled_until[target_sector],
        })

        self._log_event(state, "world", "catastrophe", target_sector,
                        metadata={
                            "matter_to_wrecks": total_converted,
                            "disable_duration": disable_duration,
                        })

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
            "debt": 0.0,
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
            "pirate": "raid",
            "explorer": "explore",
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
