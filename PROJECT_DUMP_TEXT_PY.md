--- Start of ./python_sandbox/agent_layer.py ---

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
import constants


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
        """Seed drone and alien hostile populations from sector type.

        Hostiles (drones and aliens) are hive creatures — NOT pirates.
        They roam all sectors but concentrate in frontier/low-security areas.
        Their population is fed by wreck salvage and passive frontier spawning.
        Piracy is a separate system driven by pirate faction agents.
        """
        sector_counts_drones = {}
        sector_counts_aliens = {}
        total_drones = 0
        total_aliens = 0

        for sector_id, topology in state.world_topology.items():
            sector_type = topology.get("sector_type", "hub")
            # Frontier sectors start with more hostiles
            if sector_type == "frontier":
                drones_here = 3
                aliens_here = 1
            else:
                drones_here = 1
                aliens_here = 0

            sector_counts_drones[sector_id] = drones_here
            sector_counts_aliens[sector_id] = aliens_here
            total_drones += drones_here
            total_aliens += aliens_here

        global_cap = 50  # will be overridden from config at runtime

        state.hostile_population_integral["drones"] = {
            "current_count": total_drones,
            "carrying_capacity": global_cap,
            "sector_counts": sector_counts_drones,
        }
        state.hostile_population_integral["aliens"] = {
            "current_count": total_aliens,
            "carrying_capacity": global_cap,
            "sector_counts": sector_counts_aliens,
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
        # In high-security hubs, pirates barely move the needle.
        # In low-security frontiers, they dominate.
        dominion = state.grid_dominion.get(current_sector, {})
        old_piracy = dominion.get("pirate_activity", 0.0)
        security = dominion.get("security_level", 0.5)
        effective_advantage = home_advantage * (1.0 - security)  # dampened by security
        dominion["pirate_activity"] = min(1.0, old_piracy + effective_advantage)

        # Try to raid another agent in the same sector
        if self._rng.random() < raid_chance:
            self._pirate_raid(state, agent_id, agent, current_sector, steal_fraction)

        # Periodically move toward most vulnerable (low-security, high-stockpile) sector
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
        """Pirate steals cargo from a random non-pirate agent in sector.

        Stolen cargo goes to pirate's inventory (matter-conserving).
        """
        # Find targets: non-pirate, non-disabled agents in same sector
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

        # Pick a random target
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
            # Pirate earns cash equivalent
            pirate_agent["cash_reserves"] = pirate_agent.get("cash_reserves", 0.0) + total_stolen * 5.0
            self._log_event(state, pirate_agent_id, "pirate_raid", sector_id,
                            metadata={"target": target_agent_id, "stolen": total_stolen})

    def _find_vulnerable_sector(
        self, state: GameState, agent: dict,
    ) -> str:
        """Find sector with lowest security and highest stockpiles — pirate target."""
        best_sector = ""
        best_score = -float("inf")
        for sector_id, dominion in state.grid_dominion.items():
            security = dominion.get("security_level", 1.0)
            stockpiles = state.grid_stockpiles.get(sector_id, {})
            total_stock = sum(float(v) for v in stockpiles.get("commodity_stockpiles", {}).values())
            # Pirates prefer low security + high stockpiles
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
        """Explorers travel to frontier sectors and launch discovery expeditions.

        An expedition costs cash and fuel. If successful, a new sector
        is generated and connected to the current frontier sector.
        New sectors start as 'frontier' with low resources.
        NO matter is created — initial resources come from exploration_matter_pool
        (a portion of the explorer's spent fuel, Axiom 1 safe).
        """
        current_sector = agent.get("current_sector_id", "")
        tick = state.sim_tick_count
        move_interval = config.get("explorer_move_interval", 8)
        expedition_cost = config.get("explorer_expedition_cost", 500.0)
        expedition_fuel = config.get("explorer_expedition_fuel", 30.0)
        discovery_chance = config.get("explorer_discovery_chance", 0.15)
        max_sectors = config.get("explorer_max_discovered_sectors", 10)
        wage = config.get("explorer_wage", 12.0)

        # Explorers earn a wage
        agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + wage

        # Check if current sector is frontier (exploration only from frontiers)
        topology = state.world_topology.get(current_sector, {})
        is_frontier = topology.get("sector_type", "") in ("frontier", "outpost")

        if is_frontier:
            cash = agent.get("cash_reserves", 0.0)
            fuel = agent.get("propellant_reserves", 0.0)

            # Can we afford an expedition?
            if (cash >= expedition_cost and fuel >= expedition_fuel
                    and state.discovered_sector_count < max_sectors):
                # Pay expedition cost (cash is just a sink, no matter)
                agent["cash_reserves"] = cash - expedition_cost
                # Fuel consumed → hidden_resources in current sector (Axiom 1)
                agent["propellant_reserves"] = fuel - expedition_fuel
                # Route spent fuel to hidden resources (matter conservation)
                hidden = state.world_hidden_resources.get(current_sector, {})
                hidden["propellant_sources"] = (
                    hidden.get("propellant_sources", 0.0) + expedition_fuel
                )

                # Roll for discovery
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
            # Not at frontier — move toward one
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
        """Generate a new frontier sector connected to from_sector.

        Resources for the new sector come from the from_sector's hidden pool
        (Axiom 1: matter is transferred, not created).
        """
        # Generate unique sector ID
        sector_num = state.discovered_sector_count + 1
        new_sector_id = f"sector_discovered_{sector_num}"

        # Transfer matter from from_sector's hidden resources to new sector
        # (Axiom 1: no matter created, just moved)
        source_hidden = state.world_hidden_resources.get(from_sector, {})
        source_mineral = source_hidden.get("mineral_density", 0.0)
        source_propellant = source_hidden.get("propellant_sources", 0.0)

        # Take a fraction of the source's hidden resources for the new sector
        transfer_fraction = 0.05  # 5% of source hidden pool seeds new sector
        new_mineral = source_mineral * transfer_fraction
        new_propellant = source_propellant * transfer_fraction

        if new_mineral + new_propellant < 1.0:
            # Not enough matter to seed a new sector
            return ""

        # Deduct from source (Axiom 1)
        source_hidden["mineral_density"] = source_mineral - new_mineral
        source_hidden["propellant_sources"] = source_propellant - new_propellant

        # Split new sector resources: 10% discovered, 90% hidden
        disc_mineral = new_mineral * 0.1
        disc_propellant = new_propellant * 0.1
        hidden_mineral = new_mineral * 0.9
        hidden_propellant = new_propellant * 0.9

        base_capacity = config.get("new_sector_base_capacity", 600)
        base_power = config.get("new_sector_base_power", 60.0)

        # Build topology — connect bidirectionally
        state.world_topology[new_sector_id] = {
            "connections": [from_sector],
            "station_ids": [new_sector_id],
            "sector_type": "frontier",
        }
        # Add reverse connection
        if from_sector in state.world_topology:
            from_connections = state.world_topology[from_sector].get("connections", [])
            if new_sector_id not in from_connections:
                from_connections.append(new_sector_id)

        # Build world data (Axiom 1: resources come from transferred matter)
        state.world_resource_potential[new_sector_id] = {
            "mineral_density": disc_mineral,
            "energy_potential": 50.0,  # stub, not part of Axiom 1
            "propellant_sources": disc_propellant,
        }
        state.world_hidden_resources[new_sector_id] = {
            "mineral_density": hidden_mineral,
            "propellant_sources": hidden_propellant,
        }

        # Hazards — slightly more dangerous than average
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

        # Grid layer data for new sector
        state.grid_stockpiles[new_sector_id] = {
            "commodity_stockpiles": {},
            "stockpile_capacity": base_capacity,
            "extraction_rate": {},
        }

        # Faction: independent frontier
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

        # Colony level = frontier
        state.colony_levels[new_sector_id] = "frontier"
        state.colony_upgrade_progress[new_sector_id] = 0
        state.colony_downgrade_progress[new_sector_id] = 0

        # Hostile population in new sector
        for htype in ["drones", "aliens"]:
            pop_data = state.hostile_population_integral.get(htype, {})
            sector_counts = pop_data.get("sector_counts", {})
            sector_counts[new_sector_id] = 2 if htype == "drones" else 0

        state.discovered_sector_count = len(state.world_topology)

        # Log discovery
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
        """Spawn generic, non-persistent agents in prosperous sectors.

        Mortal agents are expendable — they die permanently.
        They spawn when a sector has high stockpiles + security.
        """
        spawn_chance = config.get("mortal_spawn_chance_per_tick", 0.005)
        min_stock = config.get("mortal_spawn_min_stockpile", 500.0)
        min_sec = config.get("mortal_spawn_min_security", 0.5)
        spawn_cash = config.get("mortal_spawn_cash", 800.0)
        global_cap = config.get("mortal_global_cap", 20)

        # Count current mortal agents
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

            # Check sector qualifies
            stockpiles = state.grid_stockpiles.get(sector_id, {})
            commodities = stockpiles.get("commodity_stockpiles", {})
            total_stock = sum(float(v) for v in commodities.values())
            dominion = state.grid_dominion.get(sector_id, {})
            security = dominion.get("security_level", 0.0)

            if total_stock < min_stock or security < min_sec:
                continue

            if self._rng.random() >= spawn_chance:
                continue

            # Spawn a mortal agent
            state.mortal_agent_counter += 1
            agent_num = state.mortal_agent_counter
            agent_id = f"mortal_{agent_num}"

            # Pick role from weighted pool
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
                continue  # Don't clean up the default player agent
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
            # Clean up inventory (should be empty after wreck creation, but verify)
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
        """Remove hostiles from a sector (combat kills). Drones first, then aliens.

        When hostiles die, their body mass (pool_spawn_cost per unit) becomes
        wreck matter, closing the matter cycle:
           hostile_pool → hostile body → wreck → salvage/hidden_resources
        """
        remaining = kill_count
        actually_killed = 0
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
            actually_killed += killed

        # Create wreck from hostile body mass (Axiom 1: body_mass → wreck).
        # Only create wreck from body mass that was actually funded from the pool.
        # Passively-spawned hostiles (frontier/wreck-salvage) have no body mass.
        if create_wreck and actually_killed > 0 and state.hostile_body_mass > 0:
            # Clamp to available body mass (can't create matter from nothing)
            body_mass_per_unit = constants.HOSTILE_POOL_SPAWN_COST
            max_body_mass = actually_killed * body_mass_per_unit
            body_mass = min(max_body_mass, state.hostile_body_mass)
            state.hostile_body_mass -= body_mass
            # The wreck now holds the body mass as generic "hull debris"
            if body_mass > 0.01:
                wreck_uid = f"hostile_wreck_{state.sim_tick_count}_{sector_id[-3:]}"
                # If wreck already exists at same key, merge
                if wreck_uid in state.grid_wrecks:
                    existing = state.grid_wrecks[wreck_uid]
                    existing["wreck_integrity"] = existing.get("wreck_integrity", 0) + body_mass
                else:
                    state.grid_wrecks[wreck_uid] = {
                        "sector_id": sector_id,
                        "wreck_integrity": body_mass,
                        "wreck_inventory": {},  # Body mass is hull, not cargo
                    }

    def _create_wreck_from_agent(
        self, state: GameState, agent: dict, sector_id: str,
    ) -> None:
        """When an agent is destroyed, create a wreck from remaining cargo (Axiom 1).

        Cargo is transferred from agent inventory → wreck inventory.
        """
        char_uid = agent.get("char_uid", -1)
        wreck_inventory = {}

        if char_uid in state.inventories and 2 in state.inventories[char_uid]:
            inv = state.inventories[char_uid][2]
            for commodity_id, qty in list(inv.items()):
                if qty > 0.0:
                    wreck_inventory[commodity_id] = qty
                    inv[commodity_id] = 0.0
            # Clean up
            for cid in list(inv.keys()):
                if inv[cid] <= 0.0:
                    del inv[cid]

        # Only create wreck if there's something in it
        if wreck_inventory:
            wreck_uid = f"wreck_{state.sim_tick_count}_{char_uid}"
            state.grid_wrecks[wreck_uid] = {
                "sector_id": sector_id,
                "wreck_integrity": 0.0,  # cargo debris, no hull mass (Axiom 1)
                "wreck_inventory": wreck_inventory,
            }

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

        # Disabled sectors have no services
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
                # Can't pay → accumulate debt instead of draining to zero
                shortfall = fee - cash
                agent["cash_reserves"] = 0.0
                agent["debt"] = agent.get("debt", 0.0) + shortfall

        # Debt interest (debt grows passively, capped)
        debt = agent.get("debt", 0.0)
        if debt > 0.0:
            interest_rate = config.get("debt_interest_rate", 0.0001)
            debt_cap = config.get("debt_cap", 10000.0)
            agent["debt"] = min(debt * (1.0 + interest_rate), debt_cap)

        # --- Entropy death check ---
        # Agents at hull=0 for too long become disabled and turn into wrecks.
        hull = agent.get("hull_integrity", 0.0)
        if hull <= 0.0:
            grace = config.get("entropy_death_tick_grace", 20)
            stalled_since = agent.get("hull_zero_since", 0)
            if stalled_since == 0:
                agent["hull_zero_since"] = state.sim_tick_count
            elif (state.sim_tick_count - stalled_since) >= grace:
                # Entropy death — agent is destroyed, becomes a wreck
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
        """Check if agent encounters hostile drones/aliens in their sector.

        Encounter chance scales with hostile count in sector.
        Combat skill reduces chance. Pirate-role agents are not attacked
        by hostiles (they coexist in the chaos).
        """
        # Pirates coexist with hostiles — they are not attacked
        if agent.get("agent_role", "") == "pirate":
            return

        sector_id = agent.get("current_sector_id", "")

        # Count hostiles (drones + aliens) in this sector
        hostile_count = 0
        for htype, hdata in state.hostile_population_integral.items():
            hostile_count += hdata.get("sector_counts", {}).get(sector_id, 0)

        if hostile_count <= 0:
            return

        # Encounter chance scales with hostile density
        base_chance = config.get("hostile_encounter_chance", 0.3)
        # Normalize by a reasonable hostile density
        density_factor = min(1.0, hostile_count / 10.0)
        encounter_chance = base_chance * density_factor

        # Character combat skill reduces chance
        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})
        combat_skill = char_data.get("skills", {}).get("combat", 1)
        encounter_chance *= max(0.2, 1.0 - combat_skill * 0.1)

        if self._rng.random() > encounter_chance:
            return

        # --- Encounter happens ---
        damage_min = config.get("hostile_damage_min", 0.05)
        damage_max = config.get("hostile_damage_max", 0.25)
        damage = self._rng.uniform(damage_min, damage_max)

        hull = agent.get("hull_integrity", 1.0)
        hull -= damage
        agent["hull_integrity"] = max(0.0, hull)

        # Cargo loss (matter returns to sector stockpile — Axiom 1)
        cargo_loss_frac = config.get("hostile_cargo_loss_fraction", 0.2)
        self._lose_cargo_to_piracy(state, agent, sector_id, cargo_loss_frac)

        # Hostiles take casualties in the encounter too (1 killed per encounter)
        self._kill_hostile_in_sector(state, sector_id, 1)

        if hull <= 0.0:
            # Agent disabled — create wreck from remaining inventory
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

        # Dynamic respawn cooldown: agents at max debt wait much longer
        debt = agent.get("debt", 0.0)
        debt_cap = config.get("debt_cap", 10000.0)
        cooldown_normal = config.get("respawn_cooldown_normal", 5)
        cooldown_max_debt = config.get("respawn_cooldown_max_debt", 200)

        if debt >= debt_cap * 0.9:
            # Near or at max debt → long cooldown ("bankruptcy recovery")
            respawn_ticks = cooldown_max_debt
        else:
            # Proportional: more debt = longer cooldown
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
            # Respawn with minimum operating cash but debt increases
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
        """Update drone/alien populations.

        Hostiles are decoupled from piracy — they are hive creatures, not pirates.
        Population ecology:
        - Passive spawning in frontier sectors (always-on baseline)
        - PRESSURE VALVE: hostile_pool funds spawns when pool gets large
        - Hostiles in low-security sectors consume wreck matter to spawn more
        - RAIDS: large hostile groups attack sector stockpiles → wrecks
        - Military agents kill hostiles directly
        - Hostile death → wreck (matter returns to circulation)
        - hostility_level is DRIVEN by hostile presence (updates dominion)
        """
        low_sec_threshold = config.get("hostile_low_security_threshold", 0.4)
        wreck_salvage_rate = config.get("hostile_wreck_salvage_rate", 0.1)
        spawn_cost = config.get("hostile_spawn_cost", 5.0)
        kill_per_military = config.get("hostile_kill_per_military", 0.5)
        passive_spawn_chance = config.get("hostile_passive_spawn_chance", 0.02)
        min_frontier_count = config.get("hostile_min_frontier_count", 2)
        global_cap = config.get("hostile_global_cap", 50)

        # Pressure valve constants
        pool_pressure_threshold = config.get("hostile_pool_pressure_threshold", 500.0)
        pool_spawn_cost = config.get("hostile_pool_spawn_cost", 10.0)
        pool_spawn_rate = config.get("hostile_pool_spawn_rate", 0.02)
        pool_max_spawns = config.get("hostile_pool_max_spawns_per_tick", 5)

        # Raid constants
        raid_threshold = config.get("hostile_raid_threshold", 5)
        raid_chance = config.get("hostile_raid_chance", 0.15)
        raid_stockpile_frac = config.get("hostile_raid_stockpile_fraction", 0.05)
        raid_casualties = config.get("hostile_raid_casualties", 2)

        # --- Total hostile count across all types ---
        total_hostiles = sum(
            hdata.get("current_count", 0)
            for hdata in state.hostile_population_integral.values()
        )

        # --- Passive frontier spawning (always-on, regardless of wrecks) ---
        for sector_id, topology in state.world_topology.items():
            sector_type = topology.get("sector_type", "hub")
            if sector_type != "frontier":
                continue
            if total_hostiles >= global_cap:
                break

            # Ensure minimum hostile presence in frontier sectors
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)

            if hostiles_here < min_frontier_count:
                # Force spawn to reach minimum
                shortfall = min_frontier_count - hostiles_here
                pop_data = state.hostile_population_integral.get("drones", {})
                pop_data["current_count"] = pop_data.get("current_count", 0) + shortfall
                sector_counts = pop_data.get("sector_counts", {})
                sector_counts[sector_id] = sector_counts.get(sector_id, 0) + shortfall
                total_hostiles += shortfall

            # Random passive spawn (space fauna wanders in)
            elif self._rng.random() < passive_spawn_chance:
                htype = "drones" if self._rng.random() < 0.7 else "aliens"
                pop_data = state.hostile_population_integral.get(htype, {})
                pop_data["current_count"] = pop_data.get("current_count", 0) + 1
                sector_counts = pop_data.get("sector_counts", {})
                sector_counts[sector_id] = sector_counts.get(sector_id, 0) + 1
                total_hostiles += 1

        # ---------------------------------------------------------------
        # PRESSURE VALVE: spawn hostiles from the pool when it overflows.
        # This is the critical fix — the pool must drain back into ships
        # that can die and drop wrecks, closing the matter cycle.
        # Pool matter → hostile body mass (tracked per-unit).
        # ---------------------------------------------------------------
        pool = state.hostile_matter_pool
        if pool > pool_pressure_threshold and total_hostiles < global_cap:
            excess = pool - pool_pressure_threshold
            budget_this_tick = excess * pool_spawn_rate
            max_from_budget = int(budget_this_tick / pool_spawn_cost) if pool_spawn_cost > 0 else 0
            num_spawns = min(max_from_budget, pool_max_spawns, global_cap - total_hostiles)

            if num_spawns > 0:
                cost = num_spawns * pool_spawn_cost
                state.hostile_matter_pool -= cost
                state.hostile_body_mass += cost  # Axiom 1: pool → body mass

                # Find target sectors: weight by (1 - security) and stockpile richness
                sector_scores = {}
                for sid in state.grid_dominion:
                    sec = state.grid_dominion[sid].get("security_level", 1.0)
                    stk = state.grid_stockpiles.get(sid, {})
                    stock_total = sum(float(v) for v in
                                      stk.get("commodity_stockpiles", {}).values())
                    # Prefer low-security, resource-rich sectors
                    sector_scores[sid] = max(0.01, (1.0 - sec) * (1.0 + stock_total / 500.0))
                total_score = sum(sector_scores.values())

                # Distribute spawns proportionally
                sorted_sids = sorted(sector_scores.keys())
                spawns_left = num_spawns
                for sid in sorted_sids:
                    if spawns_left <= 0:
                        break
                    share = max(1, int(num_spawns * sector_scores[sid] / total_score))
                    share = min(share, spawns_left)
                    htype = "drones" if self._rng.random() < 0.7 else "aliens"
                    pop_data = state.hostile_population_integral.get(htype, {})
                    pop_data["current_count"] = pop_data.get("current_count", 0) + share
                    sc = pop_data.get("sector_counts", {})
                    sc[sid] = sc.get(sid, 0) + share
                    total_hostiles += share
                    spawns_left -= share

        # ---------------------------------------------------------------
        # HOSTILE RAIDS: large hostile groups attack sector stockpiles.
        # Stockpile matter → wrecks (matter returns to circulation).
        # This is the second half of the cycle: hostiles SPEND their
        # presence by raiding, which creates wrecks for prospectors.
        # ---------------------------------------------------------------
        for sector_id in list(state.grid_dominion.keys()):
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)

            if hostiles_here < raid_threshold:
                continue
            if self._rng.random() > raid_chance:
                continue

            # Raid! Hostiles attack sector stockpiles
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

            # Create a wreck from raided matter (Axiom 1: stockpile → wreck)
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

            # Hostiles take casualties from defenders
            self._kill_hostile_in_sector(state, sector_id, raid_casualties)

        # --- Update hostility_level in dominion (hostiles DRIVE hostility, not piracy) ---
        for sector_id in state.grid_dominion:
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)
            # hostility_level: 0.0 = peaceful, 1.0 = swarming
            hostility = min(1.0, hostiles_here / 10.0)
            state.grid_dominion[sector_id]["hostility_level"] = hostility

        # --- Count military agents per sector ---
        military_counts = {}
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue
            if agent.get("agent_role", "") == "military":
                sid = agent.get("current_sector_id", "")
                military_counts[sid] = military_counts.get(sid, 0) + 1

        # Military kills
        for sector_id, mil_count in military_counts.items():
            kills = int(mil_count * kill_per_military)
            if kills > 0:
                self._kill_hostile_in_sector(state, sector_id, kills)

        # Hostile wreck salvage in low-security sectors → spawn new hostiles
        total_spawned = {"drones": 0, "aliens": 0}
        matter_consumed_total = 0.0

        for wreck_uid in list(state.grid_wrecks.keys()):
            wreck = state.grid_wrecks[wreck_uid]
            sector_id = wreck.get("sector_id", "")
            dominion = state.grid_dominion.get(sector_id, {})
            security = dominion.get("security_level", 1.0)

            if security >= low_sec_threshold:
                continue  # Only salvage in low-security sectors

            # Count hostiles present in this sector
            hostiles_here = 0
            for htype in ["drones", "aliens"]:
                pop_data = state.hostile_population_integral.get(htype, {})
                hostiles_here += pop_data.get("sector_counts", {}).get(sector_id, 0)

            if hostiles_here <= 0:
                continue  # No hostiles here to salvage

            # Salvage wreck matter
            inventory = wreck.get("wreck_inventory", {})
            matter_consumed = 0.0

            for item_id in list(inventory.keys()):
                qty = inventory[item_id]
                if qty <= 0.0:
                    continue
                consumed = qty * wreck_salvage_rate
                inventory[item_id] = qty - consumed
                matter_consumed += consumed

            # Also consume hull integrity (hull mass)
            integrity = wreck.get("wreck_integrity", 0.0)
            hull_consumed = min(integrity, wreck_salvage_rate)
            wreck["wreck_integrity"] = integrity - hull_consumed
            matter_consumed += hull_consumed

            # Track consumed matter in hostile_matter_pool (Axiom 1)
            state.hostile_matter_pool += matter_consumed
            matter_consumed_total += matter_consumed

            # Spawn new hostiles from consumed matter
            if matter_consumed >= spawn_cost:
                spawns = int(matter_consumed / spawn_cost)
                # 70% drones, 30% aliens
                drone_spawns = max(1, int(spawns * 0.7))
                alien_spawns = spawns - drone_spawns

                for htype, count in [("drones", drone_spawns), ("aliens", alien_spawns)]:
                    if count <= 0:
                        continue
                    pop_data = state.hostile_population_integral.get(htype, {})
                    pop_data["current_count"] = pop_data.get("current_count", 0) + count
                    sector_counts = pop_data.get("sector_counts", {})
                    sector_counts[sector_id] = sector_counts.get(sector_id, 0) + count
                    total_spawned[htype] += count

            # Clean up empty inventory items
            for item_id in list(inventory.keys()):
                if inventory[item_id] <= 0.001:
                    del inventory[item_id]

        # Update carrying capacity based on global cap
        for htype in ["drones", "aliens"]:
            pop_data = state.hostile_population_integral.get(htype, {})
            pop_data["carrying_capacity"] = global_cap

        # Redistribute hostiles toward low-security sectors with wrecks
        for htype in ["drones", "aliens"]:
            pop_data = state.hostile_population_integral.get(htype, {})
            current_count = pop_data.get("current_count", 0)
            if current_count <= 0:
                pop_data["sector_counts"] = {}
                continue

            # Weight sectors by (1 - security) * (wreck_presence + frontier_bonus)
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
                # Frontier bonus + wreck attraction, NOT piracy-driven
                frontier_bonus = 2.0 if is_frontier else 0.0
                weight = (1.0 - security) * (1.0 + wreck_count + frontier_bonus)
                sector_weights[sector_id] = max(0.01, weight)  # min weight so all sectors accessible
                total_weight += sector_weights[sector_id]

            sector_counts = {}
            if total_weight > 0.0:
                assigned = 0
                sorted_sectors = sorted(sector_weights.keys())
                for i, sector_id in enumerate(sorted_sectors):
                    if i == len(sorted_sectors) - 1:
                        # Last sector gets remainder
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
        """Check for random catastrophic events that disrupt a sector.

        Effects:
        - A fraction of stockpiles → wrecks
        - Hub disabled for N ticks
        - Security drops, hazard spikes
        """
        chance = config.get("catastrophe_chance_per_tick", 0.0005)
        if self._rng.random() > chance:
            return

        sectors = list(state.world_topology.keys())
        if not sectors:
            return

        # Pick a random sector
        target_sector = self._rng.choice(sectors)

        # Check if already disabled
        if target_sector in state.sector_disabled_until:
            if state.sim_tick_count < state.sector_disabled_until[target_sector]:
                return  # Already under catastrophe

        disable_duration = config.get("catastrophe_disable_duration", 50)
        stockpile_to_wreck = config.get("catastrophe_stockpile_to_wreck", 0.6)
        hazard_boost = config.get("catastrophe_hazard_boost", 0.15)
        security_drop = config.get("catastrophe_security_drop", 0.4)

        # 1. Convert stockpiles → wrecks (Axiom 1: matter moves stockpile → wreck)
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
                "wreck_integrity": 0.0,  # debris, no hull mass (Axiom 1)
                "wreck_inventory": wreck_inventory,
            }

        # 2. Disable hub
        state.sector_disabled_until[target_sector] = (
            state.sim_tick_count + disable_duration
        )

        # 3. Drop security, spike hazard
        dominion = state.grid_dominion.get(target_sector, {})
        old_security = dominion.get("security_level", 0.0)
        dominion["security_level"] = max(0.0, old_security - security_drop)

        hazards = state.world_hazards.get(target_sector, {})
        old_radiation = hazards.get("radiation_level", 0.0)
        hazards["radiation_level"] = min(1.0, old_radiation + hazard_boost)

        # 4. Log catastrophe
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

--- Start of ./python_sandbox/bridge_systems.py ---

"""
GDTLancer Bridge Systems — cross-layer processing (Grid → Agent).
Mirror of src/core/simulation/bridge_systems.gd.

Step 3a: Heat Sink — binary overheating check per agent
Step 3b: Entropy System — hull degradation from sector entropy rate
Step 3c: Knowledge Refresh — update agent knowledge snapshots
"""

import copy
from game_state import GameState


class BridgeSystems:
    """Cross-layer processing that connects Grid data to Agent state."""

    def process_tick(self, state: GameState, config: dict) -> None:
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue

            sector_id = agent.get("current_sector_id", "")

            self._process_heat_sink(state, agent_id, agent, sector_id, config)
            self._process_entropy(state, agent_id, agent, sector_id, config)
            self._process_knowledge_refresh(state, agent_id, agent, sector_id, config)

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

--- Start of ./python_sandbox/ca_rules.py ---

"""
GDTLancer CA Rules — pure-function cellular automata transition rules.
Mirror of src/core/simulation/ca_rules.gd.

Every function is PURE:
  - No GameState access, no side effects.
  - Inputs are plain dicts/values; outputs are new dicts.
  - Never mutates input arguments.
  - Fully deterministic.
"""

import copy
import math


# =========================================================================
# === STRATEGIC MAP CA ====================================================
# =========================================================================

def strategic_map_step(
    sector_id: str,
    sector_state: dict,
    neighbor_states: list,
    config: dict,
) -> dict:
    """Compute next dominion state for a single sector.

    Faction influence propagates from neighbors.
    Controlling faction gets an anchor bonus that resists blending.
    Pirate activity grows where security is low, decays where high.
    """
    propagation_rate = config.get("influence_propagation_rate", 0.1)
    pirate_decay = config.get("pirate_activity_decay", 0.02)
    pirate_growth = config.get("pirate_activity_growth", 0.05)
    anchor_strength = config.get("faction_anchor_strength", 0.3)

    # --- Faction Influence Propagation ---
    current_influence = dict(sector_state.get("faction_influence", {}))
    controlling_faction = sector_state.get("controlling_faction_id", "")
    neighbor_count = len(neighbor_states)

    if neighbor_count > 0:
        neighbor_avg: dict = {}
        for n_state in neighbor_states:
            n_influence = n_state.get("faction_influence", {})
            for faction_id, val in n_influence.items():
                neighbor_avg[faction_id] = neighbor_avg.get(faction_id, 0.0) + val

        for faction_id in neighbor_avg:
            neighbor_avg[faction_id] /= neighbor_count
            current_val = current_influence.get(faction_id, 0.0)
            current_influence[faction_id] = current_val + propagation_rate * (
                neighbor_avg[faction_id] - current_val
            )

    # --- Faction Anchor: controlling faction gets a boost each tick ---
    if controlling_faction and controlling_faction in current_influence:
        current_influence[controlling_faction] += anchor_strength
    elif controlling_faction:
        current_influence[controlling_faction] = anchor_strength

    # Normalize so sum = 1.0
    for fid in current_influence:
        current_influence[fid] = max(0.0, current_influence[fid])
    influence_sum = sum(current_influence.values())
    if influence_sum > 0.0:
        for fid in current_influence:
            current_influence[fid] /= influence_sum

    # --- Security Level ---
    max_faction_influence = max(current_influence.values()) if current_influence else 0.0
    new_security = max(0.0, min(1.0, max_faction_influence))

    # --- Pirate Activity ---
    current_piracy = sector_state.get("pirate_activity", 0.0)
    security_gap = 1.0 - new_security
    piracy_delta = (pirate_growth * security_gap) - (pirate_decay * new_security)
    new_piracy = max(0.0, min(1.0, current_piracy + piracy_delta))

    return {
        "faction_influence": current_influence,
        "security_level": new_security,
        "pirate_activity": new_piracy,
    }


# =========================================================================
# === SUPPLY & DEMAND CA ==================================================
# =========================================================================

def supply_demand_step(
    sector_id: str,
    stockpiles: dict,
    resource_potential: dict,
    neighbor_stockpiles: list,
    config: dict,
) -> dict:
    """Compute next stockpile state after extraction.

    Extraction pulls matter from resource_potential into stockpiles.
    Diffusion is handled separately by GridLayer (two-pass).
    """
    extraction_rate = config.get("extraction_rate_default", 0.01)

    new_stockpiles = copy.deepcopy(stockpiles)
    new_potential = copy.deepcopy(resource_potential)
    total_matter_extracted = 0.0

    commodity_map = dict(new_stockpiles.get("commodity_stockpiles", {}))
    capacity = new_stockpiles.get("stockpile_capacity", 1000)

    # --- Extract minerals → "commodity_ore" ---
    # Note: GDScript uses "ore" but templates use "commodity_ore".
    # Use "commodity_ore" to match template commodity IDs.
    mineral = new_potential.get("mineral_density", 0.0)
    mineral_extract = min(mineral, extraction_rate * mineral)
    if mineral_extract > 0.0:
        ore_key = "commodity_ore"
        current_ore = commodity_map.get(ore_key, 0.0)
        space_available = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
        mineral_extract = min(mineral_extract, space_available)
        commodity_map[ore_key] = current_ore + mineral_extract
        new_potential["mineral_density"] = mineral - mineral_extract
        total_matter_extracted += mineral_extract

    # --- Extract propellant_sources → "commodity_fuel" ---
    propellant_src = new_potential.get("propellant_sources", 0.0)
    propellant_extract = min(propellant_src, extraction_rate * propellant_src)
    if propellant_extract > 0.0:
        fuel_key = "commodity_fuel"
        current_prop = commodity_map.get(fuel_key, 0.0)
        space_available = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
        propellant_extract = min(propellant_extract, space_available)
        commodity_map[fuel_key] = current_prop + propellant_extract
        new_potential["propellant_sources"] = propellant_src - propellant_extract
        total_matter_extracted += propellant_extract

    new_stockpiles["commodity_stockpiles"] = commodity_map
    new_stockpiles["extraction_rate"] = dict(new_stockpiles.get("extraction_rate", {}))

    return {
        "new_stockpiles": new_stockpiles,
        "new_resource_potential": new_potential,
        "matter_extracted": total_matter_extracted,
    }


# =========================================================================
# === MARKET PRESSURE CA ==================================================
# =========================================================================

def market_pressure_step(
    sector_id: str,
    stockpiles: dict,
    population_density: float,
    config: dict,
) -> dict:
    """Compute commodity price deltas and service cost modifier."""
    price_sensitivity = config.get("price_sensitivity", 0.5)
    demand_base = config.get("demand_base", 0.1)

    commodities = stockpiles.get("commodity_stockpiles", {})
    capacity = stockpiles.get("stockpile_capacity", 1000)
    price_deltas = {}

    for commodity_id, supply in commodities.items():
        demand = demand_base * population_density
        normalization = max(float(capacity) * 0.5, 1.0)
        delta = price_sensitivity * (demand - supply) / normalization
        price_deltas[commodity_id] = delta

    total_supply = _sum_commodity_values(commodities)
    supply_ratio = total_supply / max(float(capacity), 1.0)
    service_modifier = 1.0 + (population_density * 0.1) - (supply_ratio * 0.2)
    service_modifier = max(0.5, min(2.0, service_modifier))

    return {
        "commodity_price_deltas": price_deltas,
        "service_cost_modifier": service_modifier,
    }


# =========================================================================
# === ENTROPY / WRECK DEGRADATION CA ======================================
# =========================================================================

def entropy_step(
    sector_id: str,
    wrecks: list,
    hazards: dict,
    config: dict,
) -> dict:
    """Compute wreck degradation and matter redistribution for a sector.

    Wrecks degrade based on environmental hazards.  All matter is conserved
    (Axiom 1) via two output channels:
      * matter_salvaged  – recoverable debris from destroyed wrecks.
                           Returned to resource_potential (accessible ore).
      * matter_to_dust   – hull erosion each tick + non-salvageable fraction
                           of destroyed wreck inventory.  Returned to
                           hidden_resources (needs prospecting to rediscover).

    salvaged + dust always equals 100 % of lost wreck mass.
    """
    base_degradation = config.get("wreck_degradation_per_tick", 0.05)
    return_fraction = config.get("wreck_debris_return_fraction", 0.8)
    radiation_mult = config.get("entropy_radiation_multiplier", 2.0)

    radiation = hazards.get("radiation_level", 0.0)
    degradation_rate = base_degradation * (1.0 + radiation * radiation_mult)

    surviving_wrecks = []
    total_matter_salvaged = 0.0
    total_matter_to_dust = 0.0

    for wreck in wrecks:
        new_wreck = copy.deepcopy(wreck)
        old_integrity = max(0.0, new_wreck.get("wreck_integrity", 0.0))
        new_integrity = old_integrity - degradation_rate
        # Hull mass lost this tick (clamped: can't lose more than existed).
        hull_lost = old_integrity - max(0.0, new_integrity)
        total_matter_to_dust += hull_lost  # eroded hull → hidden resources
        new_wreck["wreck_integrity"] = max(0.0, new_integrity)

        if new_integrity <= 0.0:
            # Wreck destroyed — split remaining inventory.
            wreck_matter = _calculate_wreck_matter(new_wreck)  # hull is 0 here
            total_matter_salvaged += wreck_matter * return_fraction
            total_matter_to_dust += wreck_matter * (1.0 - return_fraction)
        else:
            surviving_wrecks.append(new_wreck)

    return {
        "surviving_wrecks": surviving_wrecks,
        "matter_salvaged": total_matter_salvaged,
        "matter_to_dust": total_matter_to_dust,
    }


# =========================================================================
# === POWER LOAD ==========================================================
# =========================================================================

def power_load_step(station_power_output: float, station_power_draw: float) -> dict:
    """Compute power load ratio for a sector."""
    ratio = 0.0
    if station_power_output > 0.0:
        ratio = station_power_draw / station_power_output
    return {
        "power_load_ratio": max(0.0, min(2.0, ratio)),
    }


# =========================================================================
# === MAINTENANCE PRESSURE ================================================
# =========================================================================

def maintenance_pressure_step(hazards: dict, config: dict) -> dict:
    """Compute local entropy rate and maintenance cost modifier."""
    base_rate = config.get("entropy_base_rate", 0.001)
    radiation = hazards.get("radiation_level", 0.0)
    thermal = hazards.get("thermal_background_k", 300.0)
    gravity = hazards.get("gravity_well_penalty", 1.0)

    thermal_deviation = abs(thermal - 300.0) / 300.0
    entropy_rate = base_rate * (1.0 + radiation * 2.0 + thermal_deviation) * gravity

    maintenance_modifier = 1.0 + entropy_rate * 100.0
    maintenance_modifier = max(1.0, min(3.0, maintenance_modifier))

    return {
        "local_entropy_rate": entropy_rate,
        "maintenance_cost_modifier": maintenance_modifier,
    }


# =========================================================================
# === PROSPECTING (hidden → discovered resource transfer) =================
# =========================================================================

def prospecting_step(
    sector_id: str,
    hidden_resources: dict,
    resource_potential: dict,
    market_data: dict,
    dominion_data: dict,
    hazards: dict,
    config: dict,
    rng_value: float,
) -> dict:
    """Compute resource discovery from hidden pool into discovered potential.

    Resource Layers (gated accessibility):
      Hidden resources are conceptually divided into layers:
        Surface (15%) — fast extraction (3× rate)
        Deep    (35%) — moderate extraction (1× rate)
        Mantle  (50%) — slow extraction (0.3× rate)
      As the hidden pool depletes, prospecting naturally slows because
      the remaining resources are in harder-to-reach layers.

    Prospecting intensity also depends on:
      - Market scarcity: positive price deltas → higher demand → more prospecting
      - Security: high security → safer prospecting → more discovery
      - Hazards: high radiation → dangerous conditions → less prospecting

    Args:
        rng_value: A pre-generated random float in [0, 1] for deterministic
                   variance.  Passed in by the caller (seeded RNG).

    Returns dict with:
        new_hidden:      updated hidden resource dict
        new_potential:    updated discovered resource dict
        matter_discovered: total matter transferred (for bookkeeping)
    """
    base_rate = config.get("prospecting_base_rate", 0.002)
    scarcity_boost = config.get("prospecting_scarcity_boost", 2.0)
    security_factor_max = config.get("prospecting_security_factor", 1.0)
    hazard_penalty = config.get("prospecting_hazard_penalty", 0.5)
    randomness = config.get("prospecting_randomness", 0.3)

    # Resource layer definitions
    layer_fractions = config.get("resource_layer_fractions",
                                  {"surface": 0.15, "deep": 0.35, "mantle": 0.50})
    layer_rates = config.get("resource_layer_rate_multipliers",
                              {"surface": 3.0, "deep": 1.0, "mantle": 0.3})

    new_hidden = copy.deepcopy(hidden_resources)
    new_potential = copy.deepcopy(resource_potential)
    total_discovered = 0.0

    # --- Scarcity signal: average of positive price deltas ---
    price_deltas = market_data.get("commodity_price_deltas", {})
    positive_deltas = [d for d in price_deltas.values() if d > 0.0]
    scarcity_signal = 0.0
    if positive_deltas:
        scarcity_signal = sum(positive_deltas) / len(positive_deltas)
    scarcity_mult = 1.0 + min(scarcity_signal * 10.0, 1.0) * scarcity_boost

    # --- Security factor: [0.5, 1.0] based on security_level ---
    security = dominion_data.get("security_level", 0.5)
    sec_mult = 0.5 + 0.5 * security * security_factor_max

    # --- Hazard factor: [1 - penalty, 1.0] based on radiation ---
    radiation = hazards.get("radiation_level", 0.0)
    haz_mult = max(0.1, 1.0 - radiation * hazard_penalty)

    # --- Randomness ---
    rng_mult = 1.0 + (rng_value * 2.0 - 1.0) * randomness

    # --- Combined base prospecting rate ---
    rate_base = base_rate * scarcity_mult * sec_mult * haz_mult * rng_mult
    rate_base = max(0.0, rate_base)

    # --- Discover minerals (with depth layer penalty) ---
    hidden_mineral = new_hidden.get("mineral_density", 0.0)
    if hidden_mineral > 0.0:
        depth_mult = _resource_layer_multiplier(hidden_mineral, resource_potential.get("mineral_density", 0.0),
                                                 layer_fractions, layer_rates)
        effective_rate = rate_base * depth_mult
        discover_mineral = min(hidden_mineral, effective_rate * hidden_mineral)
        new_hidden["mineral_density"] = hidden_mineral - discover_mineral
        new_potential["mineral_density"] = new_potential.get("mineral_density", 0.0) + discover_mineral
        total_discovered += discover_mineral

    # --- Discover propellant (with depth layer penalty) ---
    hidden_propellant = new_hidden.get("propellant_sources", 0.0)
    if hidden_propellant > 0.0:
        depth_mult = _resource_layer_multiplier(hidden_propellant, resource_potential.get("propellant_sources", 0.0),
                                                 layer_fractions, layer_rates)
        effective_rate = rate_base * depth_mult
        discover_propellant = min(hidden_propellant, effective_rate * hidden_propellant)
        new_hidden["propellant_sources"] = hidden_propellant - discover_propellant
        new_potential["propellant_sources"] = new_potential.get("propellant_sources", 0.0) + discover_propellant
        total_discovered += discover_propellant

    return {
        "new_hidden": new_hidden,
        "new_potential": new_potential,
        "matter_discovered": total_discovered,
    }


def _resource_layer_multiplier(
    hidden_remaining: float,
    discovered_so_far: float,
    layer_fractions: dict,
    layer_rates: dict,
) -> float:
    """Compute depth-based rate multiplier for resource extraction.

    Determines which 'layer' is currently being mined based on how much
    of the original total has been extracted, and returns the corresponding
    rate multiplier.

    Layers (mined top-down):
      Surface (first 15% of original) — rate × 3.0
      Deep    (next 35%)              — rate × 1.0
      Mantle  (last 50%)              — rate × 0.3
    """
    original_total = hidden_remaining + discovered_so_far
    if original_total <= 0.0:
        return 1.0

    fraction_remaining = hidden_remaining / original_total

    # Layers are defined top-down: surface is mined first (highest fraction_remaining)
    surface_frac = layer_fractions.get("surface", 0.15)
    deep_frac = layer_fractions.get("deep", 0.35)
    # mantle = everything else

    # If more than (deep + mantle) fraction remains, we're in the surface layer
    if fraction_remaining > (1.0 - surface_frac):
        return layer_rates.get("surface", 3.0)
    # If more than mantle fraction remains, we're in the deep layer
    elif fraction_remaining > layer_fractions.get("mantle", 0.50):
        return layer_rates.get("deep", 1.0)
    else:
        return layer_rates.get("mantle", 0.3)


# =========================================================================
# === HAZARD DRIFT (space weather) ========================================
# =========================================================================

def hazard_drift_step(
    sector_id: str,
    base_hazards: dict,
    tick: int,
    sector_index: int,
    config: dict,
) -> dict:
    """Compute drifted hazard values using slow sinusoidal modulation.

    Each sector has a phase offset (sector_index * 2π/4) so sectors
    experience space weather at different times.  Gravity is NOT drifted
    (structural, not weather).

    Returns new hazards dict (does not mutate base_hazards).
    """
    period = config.get("hazard_drift_period", 200)
    rad_amp = config.get("hazard_radiation_amplitude", 0.04)
    thermal_amp = config.get("hazard_thermal_amplitude", 15.0)

    # Phase offset per sector (spread evenly across cycle)
    num_sectors = config.get("num_sectors", 5)
    phase_offset = (2.0 * math.pi * sector_index) / max(num_sectors, 1)
    theta = (2.0 * math.pi * tick / max(period, 1)) + phase_offset

    sin_val = math.sin(theta)

    base_radiation = base_hazards.get("radiation_level", 0.0)
    base_thermal = base_hazards.get("thermal_background_k", 300.0)
    base_gravity = base_hazards.get("gravity_well_penalty", 1.0)

    new_radiation = max(0.0, base_radiation + rad_amp * sin_val)
    new_thermal = max(50.0, base_thermal + thermal_amp * sin_val)

    return {
        "radiation_level": new_radiation,
        "thermal_background_k": new_thermal,
        "gravity_well_penalty": base_gravity,  # unchanged
    }


# =========================================================================
# === STOCKPILE CONSUMPTION (population sink) =============================
# =========================================================================

def stockpile_consumption_step(
    sector_id: str,
    stockpiles: dict,
    population_density: float,
    config: dict,
) -> dict:
    """Simulate population consuming commodities from stockpiles.

    Every tick, the local population burns a fraction of each commodity.
    This prevents the "Full Warehouse" problem where stations fill up
    and prices crash to the floor.

    The consumed matter is split:
      * entropy_tax_fraction → hostile_matter_pool (funds hostile ecology)
      * remainder → hidden_resources (waste recycled into the ground)

    Axiom 1: total consumed = matter_to_hostile_pool + matter_to_hidden.
    """
    base_rate = config.get("consumption_rate_per_tick", 0.001)
    entropy_tax = config.get("consumption_entropy_tax", 0.10)

    new_stockpiles = copy.deepcopy(stockpiles)
    commodities = new_stockpiles.get("commodity_stockpiles", {})

    total_consumed = 0.0
    effective_rate = base_rate * population_density

    for commodity_id in list(commodities.keys()):
        qty = commodities[commodity_id]
        if qty <= 0.0:
            continue
        consumed = qty * effective_rate
        consumed = min(consumed, qty)  # Can't consume more than exists
        commodities[commodity_id] = qty - consumed
        total_consumed += consumed

    matter_to_hostile = total_consumed * entropy_tax
    matter_to_hidden = total_consumed * (1.0 - entropy_tax)

    return {
        "new_stockpiles": new_stockpiles,
        "total_consumed": total_consumed,
        "matter_to_hostile_pool": matter_to_hostile,
        "matter_to_hidden": matter_to_hidden,
    }


# =========================================================================
# === PRIVATE HELPERS =====================================================
# =========================================================================

def _sum_commodity_values(commodities: dict) -> float:
    """Sum all values in a commodity dictionary."""
    return sum(float(v) for v in commodities.values())


def _calculate_wreck_matter(wreck: dict) -> float:
    """Estimate matter content of a wreck from its inventory + hull."""
    matter = 0.0
    inventory = wreck.get("wreck_inventory", {})
    for val in inventory.values():
        matter += float(val)
    matter += max(0.0, wreck.get("wreck_integrity", 0.0))  # hull mass = integrity
    return matter

--- Start of ./python_sandbox/chronicle_layer.py ---

"""
GDTLancer Chronicle Layer — Layer 4 (event capture + rumor generation).
Mirror of src/core/simulation/chronicle_layer.gd.

Processing (GDD Section 7, steps 5a–5e):
  5a. Collect — move staged events to chronicle_event_buffer
  5b. Tag Causality — Phase 1 stub
  5c. Significance Scores — Phase 1 stub (all = 0.5)
  5d. Rumor Engine — generate templated text
  5e. Distribute — push events to nearby agents' event_memory
"""

import copy
from game_state import GameState
from template_data import LOCATIONS


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

--- Start of ./python_sandbox/constants.py ---

"""
GDTLancer Simulation Constants.
Mirror of src/autoload/Constants.gd — simulation-relevant values only.
"""

# === Grid CA Parameters ===
CA_INFLUENCE_PROPAGATION_RATE = 0.1
CA_PIRATE_ACTIVITY_DECAY = 0.02
CA_PIRATE_ACTIVITY_GROWTH = 0.05
CA_STOCKPILE_DIFFUSION_RATE = 0.05
CA_EXTRACTION_RATE_DEFAULT = 0.01
CA_PRICE_SENSITIVITY = 0.5
CA_DEMAND_BASE = 0.1
CA_FACTION_ANCHOR_STRENGTH = 0.3  # How strongly controlling faction resists blending

# === Wreck & Entropy ===
WRECK_DEGRADATION_PER_TICK = 0.05
WRECK_DEBRIS_RETURN_FRACTION = 0.7  # Salvageable fraction; remainder → dust → hidden resources
ENTROPY_BASE_RATE = 0.001
ENTROPY_RADIATION_MULTIPLIER = 2.0
ENTROPY_FLEET_RATE_FRACTION = 0.5

# === Agent ===
AGENT_KNOWLEDGE_NOISE_FACTOR = 0.1
AGENT_RESPAWN_TICKS = 10
HOSTILE_BASE_CARRYING_CAPACITY = 5

# === Heat ===
HEAT_GENERATION_IN_SPACE = 0.01
HEAT_DISSIPATION_DOCKED = 1.0
HEAT_OVERHEAT_THRESHOLD = 0.8

# === Power ===
POWER_DRAW_PER_AGENT = 5.0
POWER_DRAW_PER_SERVICE = 10.0

# === Bridge Entropy Drains ===
ENTROPY_HULL_MULTIPLIER = 0.1
PROPELLANT_DRAIN_PER_TICK = 0.5
ENERGY_DRAIN_PER_TICK = 0.3

# === Agent Decision Thresholds ===
NPC_CASH_LOW_THRESHOLD = 2000.0
NPC_HULL_REPAIR_THRESHOLD = 0.5
COMMODITY_BASE_PRICE = 10.0
RESPAWN_TIMEOUT_SECONDS = 300.0
HOSTILE_GROWTH_RATE = 0.05

# === Hostile Encounters (drones & aliens — hive creatures, not pirates) ===
HOSTILE_ENCOUNTER_CHANCE = 0.3   # Base probability per tick in a hostile sector
HOSTILE_DAMAGE_MIN = 0.05        # Min hull damage from a hostile encounter
HOSTILE_DAMAGE_MAX = 0.25        # Max hull damage from a hostile encounter
HOSTILE_CARGO_LOSS_FRACTION = 0.2  # Fraction of cargo lost to hostile attack

# === Hostile Spawning (wreck-based ecology) ===
# Hostiles salvage wrecks in low-security sectors to spawn more units.
# spawn_rate: wreck matter consumed per tick per hostile unit → new units
HOSTILE_WRECK_SALVAGE_RATE = 0.1     # fraction of a wreck's matter consumed/tick by hostiles
HOSTILE_SPAWN_COST = 5.0             # matter cost to spawn one hostile unit
HOSTILE_LOW_SECURITY_THRESHOLD = 0.4 # security_level below this = "low security"
HOSTILE_KILL_PER_MILITARY = 0.5      # hostiles killed per military agent per tick in sector

# === Pirate Agent Role ===
PIRATE_RAID_CHANCE = 0.25        # chance per tick a pirate raids a target in same sector
PIRATE_RAID_CARGO_STEAL = 0.3   # fraction of target's cargo stolen per raid
PIRATE_MOVE_INTERVAL = 6        # ticks between pirate sector moves
PIRATE_HOME_ADVANTAGE = 0.15    # piracy_activity boost when pirate is present

# === Cash Sinks ===
REPAIR_COST_PER_POINT = 500.0    # Cash per 0.1 hull repaired
DOCKING_FEE_BASE = 10.0          # Base docking fee per tick while docked
FUEL_COST_PER_UNIT = 5.0         # Cost to refuel per unit of propellant

# === Timing ===
WORLD_TICK_INTERVAL_SECONDS = 60

# === Axiom 1 (relative tolerance: fraction of total matter budget) ===
AXIOM1_RELATIVE_TOLERANCE = 0.015  # 1.5% of total matter budget

# ═══════════════════════════════════════════════════════════════════
# === Hidden Resources & Prospecting ===
# Hidden resources are undiscovered deposits ~10× the initial discovered
# potential.  Prospectors convert hidden → discovered based on market
# scarcity, security, and hazard conditions.
# ═══════════════════════════════════════════════════════════════════

HIDDEN_RESOURCE_MULTIPLIER = 10.0   # initial hidden = discovered * this

# Prospecting: discovery_amount = base_rate * hidden_remaining
#              * scarcity_factor * security_factor * hazard_factor
PROSPECTING_BASE_RATE = 0.002       # fraction of hidden pool per tick
PROSPECTING_SCARCITY_BOOST = 2.0    # multiplier at max scarcity (positive price deltas)
PROSPECTING_SECURITY_FACTOR = 1.0   # full prospecting at security=1, halved at 0
PROSPECTING_HAZARD_PENALTY = 0.5    # at radiation=1 prospecting drops to (1 - penalty)
PROSPECTING_RANDOMNESS = 0.3        # ±30% variance per discovery event

# ═══════════════════════════════════════════════════════════════════
# === Hazard Map Morphing (Space Weather) ===
# Slow sinusoidal drift of radiation and thermal background across
# all sectors.  Each sector has a different phase offset.
# ═══════════════════════════════════════════════════════════════════

HAZARD_DRIFT_PERIOD = 200           # ticks for one full sine cycle
HAZARD_RADIATION_AMPLITUDE = 0.04   # max ± shift to radiation_level
HAZARD_THERMAL_AMPLITUDE = 15.0     # max ± shift to thermal_background_k (Kelvin)

# ═══════════════════════════════════════════════════════════════════
# === Catastrophic Events ===
# Random sector-wide disasters that break monotonous cycles.
# When triggered: stockpiles → wrecks, hub disabled, hazard spike, security drop.
# ═══════════════════════════════════════════════════════════════════

CATASTROPHE_CHANCE_PER_TICK = 0.0005   # ~1 per 2000 ticks (~23 world-age cycles)
CATASTROPHE_DISABLE_DURATION = 50      # ticks the hub is disabled (no docking/trade)
CATASTROPHE_STOCKPILE_TO_WRECK = 0.6   # fraction of stockpiles converted to wrecks
CATASTROPHE_HAZARD_BOOST = 0.15        # added to radiation_level during catastrophe
CATASTROPHE_SECURITY_DROP = 0.4        # security_level -= this on catastrophe

# === Wreck Salvage by Prospectors (high-security sectors) ===
PROSPECTOR_WRECK_SALVAGE_RATE = 0.15   # fraction of a wreck's matter salvaged per tick per prospector
PROSPECTOR_WRECK_SECURITY_THRESHOLD = 0.6  # security must be above this for prospector salvage

# === Agent Desperation / Debt ===
DESPERATION_HULL_THRESHOLD = 0.3  # hull below this AND cash=0 → desperation trade
DESPERATION_TRADE_HULL_RISK = 0.02  # extra hull damage per tick while desperation trading
DEBT_INTEREST_RATE = 0.0001  # debt grows by this fraction per tick (additive: debt += debt * rate)
DEBT_CAP = 10000.0  # maximum debt (prevents runaway; ~20× respawn cash)
RESPAWN_DEBT_PENALTY = 500.0  # debt added on respawn

# === Entropy Death (agents dying from hull failure → wrecks) ===
ENTROPY_DEATH_HULL_THRESHOLD = 0.0  # hull at or below this → disabled
ENTROPY_DEATH_TICK_GRACE = 20  # ticks at hull=0 before death

# === Hostile Global Threat Pressure (decoupled from piracy) ===
# Hostiles spawn passively in frontier sectors + from wrecks in low-sec.
# hostility_level is DRIVEN by hostile presence, not by piracy.
HOSTILE_PASSIVE_SPAWN_CHANCE = 0.02  # chance per tick per frontier sector to spawn 1 hostile
HOSTILE_MIN_FRONTIER_COUNT = 2  # minimum hostiles always present in frontier sectors
HOSTILE_GLOBAL_CAP = 50  # absolute max hostiles across all sectors

# === Hostile Pressure Valve (budget-driven spawning from pool) ===
# When the hostile pool exceeds a threshold, hostiles spawn directly from
# the pool (not just from wreck salvage). This prevents the pool from
# becoming a black hole. Spawned hostiles carry mass → wrecks on death.
HOSTILE_POOL_PRESSURE_THRESHOLD = 500.0   # pool must exceed this to trigger pressure spawning
HOSTILE_POOL_SPAWN_COST = 10.0            # matter from pool per hostile spawned
HOSTILE_POOL_SPAWN_RATE = 0.02            # fraction of pool above threshold spent per tick on spawns
HOSTILE_POOL_MAX_SPAWNS_PER_TICK = 5      # cap on pressure spawns per tick

# === Hostile Raids (large groups attack stockpiles) ===
# When hostiles in a sector exceed a threshold, they raid the sector,
# converting stockpile matter → wrecks. This is the matter return path.
HOSTILE_RAID_THRESHOLD = 5                # min hostiles in sector to trigger raid
HOSTILE_RAID_CHANCE = 0.15                # chance per tick per qualifying sector
HOSTILE_RAID_STOCKPILE_FRACTION = 0.05    # fraction of total stockpile destroyed per raid
HOSTILE_RAID_CASUALTIES = 2               # hostiles killed in the raid (defenders fight back)

# === Stockpile Consumption (population sink) ===
# Stations consume a fraction of stockpiles each tick, simulating
# population usage. Prevents "Full Warehouse" market crashes.
CONSUMPTION_RATE_PER_TICK = 0.001  # fraction of each commodity consumed/tick (scaled by pop density)
CONSUMPTION_ENTROPY_TAX = 0.03     # fraction of consumed matter → hostile_matter_pool ("crime tax")
# Remaining (1 - tax) → hidden_resources (waste → ground recycling)

# === Debt Zombie Prevention ===
# Named agents at max debt get a long respawn cooldown instead of quick return.
RESPAWN_COOLDOWN_MAX_DEBT = 200    # ticks cooldown when agent dies at DEBT_CAP (vs normal 5)
RESPAWN_COOLDOWN_NORMAL = 5        # default respawn ticks (unchanged from before)

# ═══════════════════════════════════════════════════════════════════
# === Colony Levels (sector progression) ===
# Sectors evolve: frontier → outpost → colony → hub
# Higher levels = more population, capacity, extraction, consumption.
# ═══════════════════════════════════════════════════════════════════

COLONY_LEVELS = ["frontier", "outpost", "colony", "hub"]

# Per-level modifiers: population_density, capacity_mult, extraction_mult, consumption_mult
COLONY_LEVEL_MODIFIERS = {
    "frontier": {"population_density": 0.5, "capacity_mult": 0.5, "extraction_mult": 0.6, "consumption_mult": 0.3},
    "outpost":  {"population_density": 1.0, "capacity_mult": 0.75, "extraction_mult": 0.8, "consumption_mult": 0.6},
    "colony":   {"population_density": 1.5, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.0},
    "hub":      {"population_density": 2.0, "capacity_mult": 1.0,  "extraction_mult": 1.0, "consumption_mult": 1.2},
}

# Upgrade: stockpile must exceed this fraction of capacity for N consecutive ticks
COLONY_UPGRADE_STOCKPILE_FRACTION = 0.6   # stockpile/capacity > this to upgrade
COLONY_UPGRADE_SECURITY_MIN = 0.5         # security must be above this to upgrade
COLONY_UPGRADE_TICKS_REQUIRED = 200       # consecutive qualifying ticks to level up
# Downgrade: stockpile below this fraction OR security below threshold
COLONY_DOWNGRADE_STOCKPILE_FRACTION = 0.1 # stockpile/capacity < this to downgrade
COLONY_DOWNGRADE_SECURITY_MIN = 0.2       # security below this triggers downgrade
COLONY_DOWNGRADE_TICKS_REQUIRED = 300     # consecutive qualifying ticks to level down

# ═══════════════════════════════════════════════════════════════════
# === Non-Named Mortal Agents (generic, expendable) ===
# Generic NPCs spawned by prosperous sectors. They die permanently.
# ═══════════════════════════════════════════════════════════════════

MORTAL_SPAWN_CHANCE_PER_TICK = 0.005   # chance per tick per qualifying sector
MORTAL_SPAWN_MIN_STOCKPILE = 500.0     # sector must have this much total stock
MORTAL_SPAWN_MIN_SECURITY = 0.5        # sector must have this security level
MORTAL_SPAWN_CASH = 800.0              # starting cash for mortal agents
MORTAL_GLOBAL_CAP = 20                 # max mortal agents alive at any time
MORTAL_ROLES = ["trader", "hauler", "prospector"]  # roles mortal agents can take
MORTAL_ROLE_WEIGHTS = [0.5, 0.3, 0.2]  # probability weights for role selection

# ═══════════════════════════════════════════════════════════════════
# === Explorer Role (sector discovery) ===
# Explorers travel to frontier sectors and launch expeditions to
# discover new sectors from a hidden pool.
# ═══════════════════════════════════════════════════════════════════

EXPLORER_EXPEDITION_COST = 500.0       # cash cost per expedition attempt
EXPLORER_EXPEDITION_FUEL = 30.0        # propellant consumed per expedition
EXPLORER_DISCOVERY_CHANCE = 0.15       # base probability per expedition attempt
EXPLORER_MOVE_INTERVAL = 8             # ticks between explorer moves
EXPLORER_WAGE = 12.0                   # salary per tick (explorers are specialists)
EXPLORER_MAX_DISCOVERED_SECTORS = 10   # cap on total sectors in the simulation
# New sector generation parameters
NEW_SECTOR_BASE_MINERALS = 1.5        # base mineral density (before scaling)
NEW_SECTOR_BASE_PROPELLANT = 0.8      # base propellant density
NEW_SECTOR_BASE_CAPACITY = 600        # base stockpile capacity
NEW_SECTOR_BASE_POWER = 60.0          # base station power output

# === Resource Layers (gated accessibility) ===
# Hidden resources are split into 3 layers mined sequentially.
# Surface is fastest, deep is moderate, mantle is slowest.
RESOURCE_LAYER_FRACTIONS = {"surface": 0.15, "deep": 0.35, "mantle": 0.50}
RESOURCE_LAYER_RATE_MULTIPLIERS = {"surface": 3.0, "deep": 1.0, "mantle": 0.3}
RESOURCE_LAYER_DEPLETION_THRESHOLD = 0.01  # layer considered depleted below this fraction of original

# ═══════════════════════════════════════════════════════════════════
# === Agent Roles ===
# Role-specific behavior multipliers and thresholds.
# Roles: trader, prospector, military, hauler, idle
# ═══════════════════════════════════════════════════════════════════

# Prospector: boosts local prospecting discovery when present in a sector
PROSPECTOR_DISCOVERY_MULTIPLIER = 3.0   # prospecting_base_rate × this when ≥1 prospector present
PROSPECTOR_MOVE_INTERVAL = 5            # ticks between sector moves (exploration pace)

# Military: boosts local security, suppresses piracy
MILITARY_SECURITY_BOOST = 0.02          # security_level += this per military agent per tick
MILITARY_PIRACY_SUPPRESS = 0.01        # pirate_activity -= this per military agent per tick
MILITARY_PATROL_INTERVAL = 8           # ticks between patrol moves

# Hauler: transfers goods from surplus to deficit sectors
HAULER_CARGO_CAPACITY = 20             # max units per haul trip
HAULER_SURPLUS_THRESHOLD = 1.5         # ratio above avg → surplus
HAULER_DEFICIT_THRESHOLD = 0.5         # ratio below avg → deficit

# Explorer: discovers new sectors via expeditions from frontier
EXPLORER_DISCOVERY_MULTIPLIER = 1.5    # prospecting boost when explorer is present

# ═══════════════════════════════════════════════════════════════════
# === World Age Cycle ===
# Inspired by GROWTH → CHAOS → RENEWAL oscillation pattern.
# Each age modulates CA parameters to prevent the system from settling.
# ═══════════════════════════════════════════════════════════════════

# Age cycle definition: order and duration (in ticks)
WORLD_AGE_CYCLE = ["PROSPERITY", "DISRUPTION", "RECOVERY"]
WORLD_AGE_DURATIONS = {
    "PROSPERITY": 40,    # Stable growth — factions consolidate, trade thrives
    "DISRUPTION":  20,   # Crisis — piracy surges, factions weaken, extraction stalls
    "RECOVERY":    25,   # Rebuilding — moderate piracy, resources slowly replenish
}

# Per-age config overrides (applied on top of base constants)
# Only keys that change per age are listed.
WORLD_AGE_CONFIGS = {
    "PROSPERITY": {
        "extraction_rate_default":      0.015,   # Rich extraction
        "pirate_activity_growth":       0.02,    # Low pirate pressure
        "pirate_activity_decay":        0.06,    # Security suppresses piracy
        "influence_propagation_rate":   0.08,    # Slow influence change
        "faction_anchor_strength":      0.4,     # Strong faction anchoring
        "hostile_growth_rate":          0.02,    # Few new hostiles
        "hostile_encounter_chance":     0.15,    # Rare attacks
        "docking_fee_base":             15.0,    # Cheap docking
        "stockpile_diffusion_rate":     0.08,    # Active trade diffusion
        "prospecting_base_rate":        0.003,   # Active prospecting
        "hazard_radiation_amplitude":   0.02,    # Mild space weather
        "catastrophe_chance_per_tick":  0.0002,  # Very rare catastrophes
    },
    "DISRUPTION": {
        "extraction_rate_default":      0.004,   # Extraction collapses
        "pirate_activity_growth":       0.12,    # Piracy surges
        "pirate_activity_decay":        0.01,    # Security barely holds
        "influence_propagation_rate":   0.20,    # Factions destabilize fast
        "faction_anchor_strength":      0.1,     # Weak anchoring — chaos
        "hostile_growth_rate":          0.15,    # Hostile boom
        "hostile_encounter_chance":     0.50,    # Frequent attacks
        "docking_fee_base":             40.0,    # Crisis pricing
        "stockpile_diffusion_rate":     0.02,    # Trade routes disrupted
        "prospecting_base_rate":        0.0005,  # Almost no prospecting
        "hazard_radiation_amplitude":   0.08,    # Severe space weather
        "catastrophe_chance_per_tick":  0.001,   # More frequent catastrophes
    },
    "RECOVERY": {
        "extraction_rate_default":      0.008,   # Slow rebuilding
        "pirate_activity_growth":       0.04,    # Moderate piracy
        "pirate_activity_decay":        0.04,    # Gradual cleanup
        "influence_propagation_rate":   0.12,    # Moderate influence shift
        "faction_anchor_strength":      0.25,    # Rebuilding control
        "hostile_growth_rate":          0.06,    # Some hostiles remain
        "hostile_encounter_chance":     0.30,    # Normal risk
        "docking_fee_base":             25.0,    # Recovering fees
        "stockpile_diffusion_rate":     0.05,    # Normal diffusion
        "prospecting_base_rate":        0.002,   # Normal prospecting
        "hazard_radiation_amplitude":   0.05,    # Moderate space weather
        "catastrophe_chance_per_tick":  0.0005,  # Normal catastrophe rate
    },
}

--- Start of ./python_sandbox/game_state.py ---

"""
GDTLancer Game State — central data store.
Mirror of src/autoload/GameState.gd.
All simulation systems read/write through this singleton-like object.
"""

import copy


class GameState:
    """
    Central data store for the four-layer simulation.
    Create one instance and pass it to all layers.
    """

    def __init__(self):
        # === Layer 1: World (static after init) ===
        self.world_topology: dict = {}          # sector_id → {connections, station_ids, sector_type}
        self.world_hazards: dict = {}           # sector_id → {radiation_level, thermal_background_k, gravity_well_penalty}
        self.world_hazards_base: dict = {}      # sector_id → original hazards (before drift)
        self.world_resource_potential: dict = {} # sector_id → {mineral_density, energy_potential, propellant_sources}
        self.world_hidden_resources: dict = {}  # sector_id → {mineral_density, propellant_sources}  (undiscovered)
        self.world_total_matter: float = 0.0    # Axiom 1 checksum
        self.world_seed: str = ""

        # === Layer 2: Grid (dynamic, CA-driven) ===
        self.grid_resource_availability: dict = {}  # sector_id → {propellant_supply, consumables_supply, energy_supply}
        self.grid_dominion: dict = {}               # sector_id → {faction_influence, security_level, pirate_activity}
        self.grid_market: dict = {}                 # sector_id → {commodity_price_deltas, population_density, service_cost_modifier}
        self.grid_stockpiles: dict = {}             # sector_id → {commodity_stockpiles, stockpile_capacity, extraction_rate}
        self.grid_maintenance: dict = {}            # sector_id → {local_entropy_rate, maintenance_cost_modifier}
        self.grid_power: dict = {}                  # sector_id → {station_power_output, station_power_draw, power_load_ratio}
        self.grid_wrecks: dict = {}                 # wreck_uid → {sector_id, wreck_integrity, wreck_inventory, ...}

        # === Layer 3: Agents ===
        self.characters: dict = {}              # char_uid → character data dict
        self.agents: dict = {}                  # agent_id → agent state dict
        self.inventories: dict = {}             # char_uid → {2: {commodity_id: qty}}  (2 = COMMODITY type)
        self.assets_ships: dict = {}            # ship_uid → ship data
        self.player_character_uid: int = -1
        self.hostile_population_integral: dict = {}  # hostile_type → {current_count, carrying_capacity, sector_counts}
        self.persistent_agents: dict = {}       # legacy alias
        self.sector_disabled_until: dict = {}   # sector_id → tick when hub re-enables
        self.catastrophe_log: list = []         # list of {sector_id, tick, type} for chronicle
        self.hostile_matter_pool: float = 0.0   # matter consumed by hostiles from wrecks (Axiom 1)
        self.hostile_body_mass: float = 0.0     # matter locked in living hostile bodies (Axiom 1)

        # === Colony Level Progression ===
        self.colony_levels: dict = {}           # sector_id → "frontier"/"outpost"/"colony"/"hub"
        self.colony_upgrade_progress: dict = {} # sector_id → consecutive qualifying ticks toward upgrade
        self.colony_downgrade_progress: dict = {} # sector_id → consecutive qualifying ticks toward downgrade
        self.colony_level_history: list = []    # list of {sector_id, tick, old_level, new_level}

        # === Mortal (non-named) Agents ===
        self.mortal_agent_counter: int = 0      # running counter for unique mortal agent IDs
        self.mortal_agent_deaths: list = []     # list of {agent_id, tick, sector_id, cause}

        # === Sector Discovery ===
        self.discovered_sector_count: int = 0   # how many sectors exist (including initial)
        self.discovery_log: list = []           # list of {sector_id, tick, discovered_by, from_sector}

        # === Layer 4: Chronicle ===
        self.chronicle_event_buffer: list = []
        self.chronicle_rumors: list = []

        # === Simulation Meta ===
        self.sim_tick_count: int = 0
        self.game_time_seconds: int = 0

        # === World Age Cycle ===
        self.world_age: str = ""          # Current age name (PROSPERITY, DISRUPTION, RECOVERY)
        self.world_age_timer: int = 0     # Ticks remaining in current age
        self.world_age_cycle_count: int = 0  # How many full cycles completed

        # === Scene State (stub for Python — no real scene) ===
        self.player_docked_at: str = ""

    def deep_copy_dict(self, d: dict) -> dict:
        """Utility: deep-copy a nested dictionary."""
        return copy.deepcopy(d)

--- Start of ./python_sandbox/grid_layer.py ---

"""
GDTLancer Grid Layer — Layer 2 (CA-driven stockpiles, dominion, market, power, maintenance).
Mirror of src/core/simulation/grid_layer.gd.

Processing is DOUBLE-BUFFERED: all reads come from GameState, all writes
go to local buffers, then buffers are swapped atomically at the end.
"""

import copy
import random
from game_state import GameState
from template_data import LOCATIONS, FACTIONS
import ca_rules
import constants


class GridLayer:
    """Processes all Grid-layer CA steps for one simulation tick."""

    # -----------------------------------------------------------------
    # Initialization
    # -----------------------------------------------------------------
    def initialize_grid(self, state: GameState) -> None:
        """Seed all Grid Layer state from World Layer data and templates."""
        self._seed_stockpiles(state)
        self._seed_dominion(state)
        self._seed_market(state)
        self._seed_power(state)
        self._seed_maintenance(state)
        self._seed_resource_availability(state)
        self._seed_colony_levels(state)
        state.grid_wrecks.clear()

        print(f"GridLayer: Initialized grid state for {len(state.world_topology)} sectors.")

    # -----------------------------------------------------------------
    # Tick processing
    # -----------------------------------------------------------------
    def process_tick(self, state: GameState, config: dict) -> None:
        """Process all Grid-layer CA steps for one tick."""
        matter_before = self._calculate_current_matter(state)

        # Allocate write buffers
        buf_stockpiles: dict = {}
        buf_dominion: dict = {}
        buf_market: dict = {}
        buf_power: dict = {}
        buf_maintenance: dict = {}
        buf_resource_availability: dict = {}
        buf_resource_potential: dict = {}
        buf_hidden_resources: dict = {}

        # Deep-copy resource potential
        for sector_id, pot in state.world_resource_potential.items():
            buf_resource_potential[sector_id] = copy.deepcopy(pot)

        # Deep-copy hidden resources
        for sector_id, hid in state.world_hidden_resources.items():
            buf_hidden_resources[sector_id] = copy.deepcopy(hid)

        # Deterministic RNG for prospecting variance (seeded per tick)
        tick_rng = random.Random(hash((state.world_seed, state.sim_tick_count)))

        # Sorted sector list for stable sector_index in hazard drift
        sorted_sectors = sorted(state.world_topology.keys())

        # Count prospectors per sector for discovery boost
        prospector_counts = {}
        for agent_id, agent in state.agents.items():
            if agent.get("is_disabled", False):
                continue
            if agent.get("agent_role", "") == "prospector":
                sid = agent.get("current_sector_id", "")
                prospector_counts[sid] = prospector_counts.get(sid, 0) + 1

        # --- Process each sector ---
        for sector_id in state.world_topology:
            topology = state.world_topology[sector_id]
            connections = topology.get("connections", [])
            hazards = state.world_hazards.get(sector_id, {})

            # 2a. Extraction + 2b. Supply & Demand CA
            current_stockpiles = copy.deepcopy(state.grid_stockpiles.get(sector_id, {}))
            current_potential = copy.deepcopy(buf_resource_potential.get(sector_id, {}))

            neighbor_stockpiles = []
            for conn_id in connections:
                if conn_id in state.grid_stockpiles:
                    neighbor_stockpiles.append(state.grid_stockpiles[conn_id])

            supply_result = ca_rules.supply_demand_step(
                sector_id, current_stockpiles, current_potential,
                neighbor_stockpiles, config,
            )
            buf_stockpiles[sector_id] = supply_result["new_stockpiles"]
            buf_resource_potential[sector_id] = supply_result["new_resource_potential"]

            # 2c. Strategic Map CA (dominion)
            current_dominion = copy.deepcopy(state.grid_dominion.get(sector_id, {}))
            neighbor_dominion_states = []
            for conn_id in connections:
                if conn_id in state.grid_dominion:
                    neighbor_dominion_states.append(state.grid_dominion[conn_id])

            buf_dominion[sector_id] = ca_rules.strategic_map_step(
                sector_id, current_dominion, neighbor_dominion_states, config,
            )
            # Preserve controlling_faction_id through ticks
            buf_dominion[sector_id]["controlling_faction_id"] = current_dominion.get(
                "controlling_faction_id", ""
            )

            # 2d. Power Load
            current_power = state.grid_power.get(sector_id, {})
            power_output = current_power.get("station_power_output", 100.0)

            docked_agent_count = self._count_docked_agents(state, sector_id)
            agent_power_draw = config.get("power_draw_per_agent", 5.0)
            service_power_draw = config.get("power_draw_per_service", 10.0)
            num_services = self._count_services(sector_id)
            power_draw = (float(docked_agent_count) * agent_power_draw) + (
                float(num_services) * service_power_draw
            )

            power_result = ca_rules.power_load_step(power_output, power_draw)
            buf_power[sector_id] = {
                "station_power_output": power_output,
                "station_power_draw": power_draw,
                "power_load_ratio": power_result["power_load_ratio"],
            }

            # 2e. Market Pressure
            current_market = state.grid_market.get(sector_id, {})
            # Population density driven by colony level
            colony_level = state.colony_levels.get(sector_id, "frontier")
            level_mods = constants.COLONY_LEVEL_MODIFIERS.get(colony_level, {})
            population_density = level_mods.get("population_density", 1.0)

            market_result = ca_rules.market_pressure_step(
                sector_id, buf_stockpiles[sector_id], population_density, config,
            )
            buf_market[sector_id] = {
                "commodity_price_deltas": market_result["commodity_price_deltas"],
                "population_density": population_density,
                "service_cost_modifier": market_result["service_cost_modifier"],
            }

            # 2f. Hazard Drift (space weather)
            sector_index = sorted_sectors.index(sector_id)
            base_hazards = state.world_hazards_base.get(sector_id, hazards)
            drifted_hazards = ca_rules.hazard_drift_step(
                sector_id, base_hazards, state.sim_tick_count,
                sector_index, config,
            )
            # Use drifted hazards for maintenance calculation below
            hazards = drifted_hazards

            # 2f-b. Prospecting (hidden → discovered resource transfer)
            current_hidden = copy.deepcopy(buf_hidden_resources.get(sector_id, {}))
            current_market = buf_market[sector_id]
            current_dominion = buf_dominion[sector_id]
            rng_value = tick_rng.random()

            # Prospector presence boosts discovery rate
            n_prospectors = prospector_counts.get(sector_id, 0)
            prospect_config = dict(config)
            if n_prospectors > 0:
                boost = config.get("prospector_discovery_multiplier", 3.0)
                prospect_config["prospecting_base_rate"] = (
                    config.get("prospecting_base_rate", 0.002) * boost * n_prospectors
                )

            prospect_result = ca_rules.prospecting_step(
                sector_id, current_hidden,
                buf_resource_potential[sector_id],
                current_market, current_dominion,
                hazards, prospect_config, rng_value,
            )
            buf_hidden_resources[sector_id] = prospect_result["new_hidden"]
            buf_resource_potential[sector_id] = prospect_result["new_potential"]

            # 2g. Maintenance Pressure
            buf_maintenance[sector_id] = ca_rules.maintenance_pressure_step(hazards, config)

            # Update resource availability
            potential = buf_resource_potential.get(sector_id, {})
            buf_resource_availability[sector_id] = {
                "propellant_supply": potential.get("propellant_sources", 0.0),
                "consumables_supply": buf_stockpiles[sector_id]
                    .get("commodity_stockpiles", {})
                    .get("food", 0.0),
                "energy_supply": potential.get("energy_potential", 0.0),
            }

        # 2b-post. Stockpile Diffusion (separate pass for matter conservation)
        diffusion_rate = config.get("stockpile_diffusion_rate", 0.05)
        diffusion_deltas: dict = {sid: {} for sid in buf_stockpiles}

        for sector_id in state.world_topology:
            topology = state.world_topology[sector_id]
            connections = topology.get("connections", [])
            if not connections:
                continue

            local_commodities = buf_stockpiles[sector_id].get("commodity_stockpiles", {})
            for conn_id in connections:
                if conn_id <= sector_id:
                    continue
                if conn_id not in buf_stockpiles:
                    continue

                neighbor_commodities = buf_stockpiles[conn_id].get("commodity_stockpiles", {})

                all_commodities = set(local_commodities.keys()) | set(neighbor_commodities.keys())

                for commodity_id in all_commodities:
                    local_amount = local_commodities.get(commodity_id, 0.0)
                    neighbor_amount = neighbor_commodities.get(commodity_id, 0.0)
                    diff = local_amount - neighbor_amount
                    if abs(diff) < 0.001:
                        continue

                    flow = diff * diffusion_rate * 0.5
                    diffusion_deltas[sector_id][commodity_id] = (
                        diffusion_deltas[sector_id].get(commodity_id, 0.0) - flow
                    )
                    if conn_id not in diffusion_deltas:
                        diffusion_deltas[conn_id] = {}
                    diffusion_deltas[conn_id][commodity_id] = (
                        diffusion_deltas[conn_id].get(commodity_id, 0.0) + flow
                    )

        # Apply diffusion deltas (clamp flow to available stock for Axiom 1)
        for sector_id, deltas in diffusion_deltas.items():
            if not deltas:
                continue
            commodities = buf_stockpiles[sector_id].get("commodity_stockpiles", {})
            for commodity_id, delta_val in deltas.items():
                current = commodities.get(commodity_id, 0.0)
                new_val = current + delta_val
                if new_val < 0.0:
                    # Clamp to zero and compensate: reduce inflow at receivers
                    # to conserve matter exactly.
                    overflow = -new_val
                    commodities[commodity_id] = 0.0
                    # Redistribute overflow back to connected sectors that received
                    connections = state.world_topology.get(sector_id, {}).get("connections", [])
                    receivers = [c for c in connections if c in diffusion_deltas
                                 and diffusion_deltas[c].get(commodity_id, 0.0) > 0]
                    if receivers:
                        per_recv = overflow / len(receivers)
                        remaining_overflow = 0.0
                        for recv_id in receivers:
                            recv_commodities = buf_stockpiles[recv_id].get("commodity_stockpiles", {})
                            recv_current = recv_commodities.get(commodity_id, 0.0)
                            recv_new = recv_current - per_recv
                            if recv_new < 0.0:
                                remaining_overflow += -recv_new
                                recv_commodities[commodity_id] = 0.0
                            else:
                                recv_commodities[commodity_id] = recv_new
                        # Any remaining overflow → hidden resources (Axiom 1)
                        if remaining_overflow > 0.0:
                            hidden = buf_hidden_resources.get(sector_id, {})
                            hidden["mineral_density"] = hidden.get("mineral_density", 0.0) + remaining_overflow
                    else:
                        # No receivers found — route overflow to hidden resources (Axiom 1)
                        hidden = buf_hidden_resources.get(sector_id, {})
                        hidden["mineral_density"] = hidden.get("mineral_density", 0.0) + overflow
                else:
                    commodities[commodity_id] = new_val

        # 2h. Stockpile Consumption (population sink)
        # Population consumes commodities. Consumed matter splits:
        #   entropy_tax → hostile_matter_pool (funds hostile ecology)
        #   remainder → hidden_resources (waste recycling, Axiom 1)
        for sector_id in state.world_topology:
            market = buf_market.get(sector_id, {})
            pop_density = market.get("population_density", 1.0)

            consumption_result = ca_rules.stockpile_consumption_step(
                sector_id, buf_stockpiles[sector_id], pop_density, config,
            )
            buf_stockpiles[sector_id] = consumption_result["new_stockpiles"]

            # Entropy tax → hostile_matter_pool (Axiom 1)
            state.hostile_matter_pool += consumption_result["matter_to_hostile_pool"]

            # Waste → hidden_resources (Axiom 1)
            matter_hidden = consumption_result["matter_to_hidden"]
            if matter_hidden > 0.0:
                hid = buf_hidden_resources.get(sector_id, {})
                # Split waste 50/50 to mineral and propellant hidden pools
                hid["mineral_density"] = hid.get("mineral_density", 0.0) + matter_hidden * 0.5
                hid["propellant_sources"] = hid.get("propellant_sources", 0.0) + matter_hidden * 0.5

        # 2f. Wreck & Debris
        self._process_wrecks(state, config, buf_resource_potential, buf_hidden_resources)

        # Atomic swap
        state.grid_stockpiles = buf_stockpiles
        state.grid_dominion = buf_dominion
        state.grid_market = buf_market
        state.grid_power = buf_power
        state.grid_maintenance = buf_maintenance
        state.grid_resource_availability = buf_resource_availability

        # Write back depleted resource potential
        for sector_id, pot in buf_resource_potential.items():
            state.world_resource_potential[sector_id] = pot

        # Write back hidden resources (depleted by prospecting)
        for sector_id, hid in buf_hidden_resources.items():
            state.world_hidden_resources[sector_id] = hid

        # Write back drifted hazards
        for sector_id in sorted_sectors:
            sector_index = sorted_sectors.index(sector_id)
            base_hazards = state.world_hazards_base.get(sector_id, {})
            state.world_hazards[sector_id] = ca_rules.hazard_drift_step(
                sector_id, base_hazards, state.sim_tick_count,
                sector_index, config,
            )

        # Colony level progression (upgrade/downgrade based on economy)
        self._update_colony_levels(state, config)

        # Axiom 1 assertion (relative tolerance)
        matter_after = self._calculate_current_matter(state)
        abs_drift = abs(matter_after - matter_before)
        rel_drift = abs_drift / max(matter_before, 1.0)
        rel_tolerance = config.get("axiom1_relative_tolerance", 0.005)
        if rel_drift > rel_tolerance:
            print(
                f"GridLayer: AXIOM 1 VIOLATION! Drift: {abs_drift:.4f} "
                f"({rel_drift*100:.4f}% of budget, limit={rel_tolerance*100:.2f}%) "
                f"(before: {matter_before:.2f}, after: {matter_after:.2f})"
            )

    # -----------------------------------------------------------------
    # Seeding helpers
    # -----------------------------------------------------------------
    def _seed_stockpiles(self, state: GameState) -> None:
        state.grid_stockpiles.clear()
        for location_id, loc in LOCATIONS.items():
            commodity_stockpiles = {}
            market_inv = loc.get("market_inventory", {})
            for commodity_id, entry in market_inv.items():
                commodity_stockpiles[commodity_id] = float(entry.get("quantity", 0))

            capacity = int(loc.get("stockpile_capacity", 1000))
            state.grid_stockpiles[location_id] = {
                "commodity_stockpiles": commodity_stockpiles,
                "stockpile_capacity": capacity,
                "extraction_rate": {},
            }

    def _seed_dominion(self, state: GameState) -> None:
        state.grid_dominion.clear()
        for location_id, loc in LOCATIONS.items():
            controlling_faction = loc.get("controlling_faction_id", "")
            faction_influence = {}
            for faction_id in FACTIONS:
                if faction_id == controlling_faction:
                    faction_influence[faction_id] = 0.8
                elif faction_id == "faction_pirates":
                    # Pirates start with very low influence everywhere
                    faction_influence[faction_id] = 0.02
                else:
                    faction_influence[faction_id] = 0.1

            security = 0.8 if controlling_faction else 0.2
            danger = int(loc.get("danger_level", 0))
            pirate_activity = max(0.0, min(1.0, float(danger) * 0.1))

            state.grid_dominion[location_id] = {
                "faction_influence": faction_influence,
                "security_level": security,
                "pirate_activity": pirate_activity,
                "controlling_faction_id": controlling_faction,
            }

    def _seed_market(self, state: GameState) -> None:
        state.grid_market.clear()
        for location_id, loc in LOCATIONS.items():
            price_deltas = {}
            market_inv = loc.get("market_inventory", {})
            for commodity_id in market_inv:
                price_deltas[commodity_id] = 0.0

            sector_type = loc.get("sector_type", "frontier")
            population = 2.0 if sector_type == "hub" else 1.0

            state.grid_market[location_id] = {
                "commodity_price_deltas": price_deltas,
                "population_density": population,
                "service_cost_modifier": 1.0,
            }

    def _seed_power(self, state: GameState) -> None:
        state.grid_power.clear()
        for location_id, loc in LOCATIONS.items():
            power_output = float(loc.get("station_power_output", 100.0))
            state.grid_power[location_id] = {
                "station_power_output": power_output,
                "station_power_draw": 0.0,
                "power_load_ratio": 0.0,
            }

    def _seed_maintenance(self, state: GameState) -> None:
        state.grid_maintenance.clear()
        for location_id, hazards in state.world_hazards.items():
            base_rate = 0.001
            radiation = hazards.get("radiation_level", 0.0)
            thermal = hazards.get("thermal_background_k", 300.0)
            gravity = hazards.get("gravity_well_penalty", 1.0)
            thermal_deviation = abs(thermal - 300.0) / 300.0
            entropy_rate = base_rate * (1.0 + radiation * 2.0 + thermal_deviation) * gravity

            state.grid_maintenance[location_id] = {
                "local_entropy_rate": entropy_rate,
                "maintenance_cost_modifier": max(1.0, min(3.0, 1.0 + entropy_rate * 100.0)),
            }

    def _seed_resource_availability(self, state: GameState) -> None:
        state.grid_resource_availability.clear()
        for location_id, potential in state.world_resource_potential.items():
            state.grid_resource_availability[location_id] = {
                "propellant_supply": potential.get("propellant_sources", 0.0),
                "consumables_supply": 0.0,
                "energy_supply": potential.get("energy_potential", 0.0),
            }

    # -----------------------------------------------------------------
    # Wreck processing
    # -----------------------------------------------------------------
    def _process_wrecks(
        self, state: GameState, config: dict, buf_resource_potential: dict,
        buf_hidden_resources: dict = None,
    ) -> None:
        if not state.grid_wrecks:
            return

        wrecks_by_sector: dict = {}
        for wreck_uid, wreck in state.grid_wrecks.items():
            w = copy.deepcopy(wreck)
            w["wreck_uid"] = wreck_uid
            sector_id = w.get("sector_id", "")
            wrecks_by_sector.setdefault(sector_id, []).append(w)

        new_wrecks = {}
        for sector_id, sector_wrecks in wrecks_by_sector.items():
            hazards = state.world_hazards.get(sector_id, {})
            entropy_result = ca_rules.entropy_step(sector_id, sector_wrecks, hazards, config)

            # Salvageable debris → accessible resource potential.
            matter_salvaged = entropy_result.get("matter_salvaged", 0.0)
            if matter_salvaged > 0.0:
                if sector_id in buf_resource_potential:
                    buf_resource_potential[sector_id]["mineral_density"] += matter_salvaged
                else:
                    buf_resource_potential[sector_id] = {
                        "mineral_density": matter_salvaged,
                        "energy_potential": 0.0,
                        "propellant_sources": 0.0,
                    }

            # Eroded hull + unsalvageable dust → hidden resources.
            matter_dust = entropy_result.get("matter_to_dust", 0.0)
            if matter_dust > 0.0:
                # Write to buffer (not state) so the atomic swap preserves the dust
                target = buf_hidden_resources if buf_hidden_resources is not None else state.world_hidden_resources
                if sector_id in target:
                    target[sector_id]["mineral_density"] = (
                        target[sector_id].get("mineral_density", 0.0)
                        + matter_dust
                    )
                else:
                    target[sector_id] = {"mineral_density": matter_dust, "propellant_sources": 0.0}

            for surviving_wreck in entropy_result["surviving_wrecks"]:
                uid = surviving_wreck.get("wreck_uid", 0)
                clean = copy.deepcopy(surviving_wreck)
                clean.pop("wreck_uid", None)
                new_wrecks[uid] = clean

        state.grid_wrecks = new_wrecks

    # -----------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------
    def _count_docked_agents(self, state: GameState, sector_id: str) -> int:
        count = 0
        for agent_id, agent in state.agents.items():
            if agent.get("current_sector_id", "") == sector_id:
                count += 1
        if state.player_docked_at == sector_id:
            count += 1
        return count

    def _count_services(self, sector_id: str) -> int:
        if sector_id in LOCATIONS:
            services = LOCATIONS[sector_id].get("available_services", [])
            return len(services)
        return 0

    # -----------------------------------------------------------------
    # Colony Level System
    # -----------------------------------------------------------------
    def _seed_colony_levels(self, state: GameState) -> None:
        """Initialize colony levels from template sector_type."""
        state.colony_levels.clear()
        state.colony_upgrade_progress.clear()
        state.colony_downgrade_progress.clear()
        for sector_id, topology in state.world_topology.items():
            level = topology.get("sector_type", "frontier")
            if level not in constants.COLONY_LEVELS:
                level = "frontier"
            state.colony_levels[sector_id] = level
            state.colony_upgrade_progress[sector_id] = 0
            state.colony_downgrade_progress[sector_id] = 0
        state.discovered_sector_count = len(state.world_topology)

    def _update_colony_levels(self, state: GameState, config: dict) -> None:
        """Check each sector for colony level upgrade/downgrade.

        Upgrade: stockpile fraction > threshold AND security > threshold
                 for N consecutive ticks.
        Downgrade: stockpile fraction < threshold OR security < threshold
                   for N consecutive ticks.
        Colony level changes population_density, capacity mult, etc.
        NO matter is created or destroyed — only modifiers change.
        """
        upgrade_frac = config.get("colony_upgrade_stockpile_fraction", 0.6)
        upgrade_sec = config.get("colony_upgrade_security_min", 0.5)
        upgrade_ticks = config.get("colony_upgrade_ticks_required", 200)
        downgrade_frac = config.get("colony_downgrade_stockpile_fraction", 0.1)
        downgrade_sec = config.get("colony_downgrade_security_min", 0.2)
        downgrade_ticks = config.get("colony_downgrade_ticks_required", 300)

        levels = constants.COLONY_LEVELS  # ["frontier", "outpost", "colony", "hub"]

        for sector_id in list(state.colony_levels.keys()):
            current_level = state.colony_levels[sector_id]
            current_idx = levels.index(current_level) if current_level in levels else 0

            stockpiles = state.grid_stockpiles.get(sector_id, {})
            commodities = stockpiles.get("commodity_stockpiles", {})
            total_stock = sum(float(v) for v in commodities.values())
            capacity = stockpiles.get("stockpile_capacity", 1000)
            stock_frac = total_stock / max(capacity, 1.0)

            dominion = state.grid_dominion.get(sector_id, {})
            security = dominion.get("security_level", 0.0)

            # --- Upgrade check ---
            if current_idx < len(levels) - 1:
                if stock_frac >= upgrade_frac and security >= upgrade_sec:
                    state.colony_upgrade_progress[sector_id] = (
                        state.colony_upgrade_progress.get(sector_id, 0) + 1
                    )
                else:
                    state.colony_upgrade_progress[sector_id] = 0

                if state.colony_upgrade_progress.get(sector_id, 0) >= upgrade_ticks:
                    old_level = current_level
                    new_level = levels[current_idx + 1]
                    state.colony_levels[sector_id] = new_level
                    state.colony_upgrade_progress[sector_id] = 0
                    state.colony_downgrade_progress[sector_id] = 0
                    # Update topology sector_type to match
                    if sector_id in state.world_topology:
                        state.world_topology[sector_id]["sector_type"] = new_level
                    state.colony_level_history.append({
                        "sector_id": sector_id,
                        "tick": state.sim_tick_count,
                        "old_level": old_level,
                        "new_level": new_level,
                    })

            # --- Downgrade check ---
            if current_idx > 0:
                if stock_frac < downgrade_frac or security < downgrade_sec:
                    state.colony_downgrade_progress[sector_id] = (
                        state.colony_downgrade_progress.get(sector_id, 0) + 1
                    )
                else:
                    state.colony_downgrade_progress[sector_id] = 0

                if state.colony_downgrade_progress.get(sector_id, 0) >= downgrade_ticks:
                    old_level = current_level
                    new_level = levels[current_idx - 1]
                    state.colony_levels[sector_id] = new_level
                    state.colony_upgrade_progress[sector_id] = 0
                    state.colony_downgrade_progress[sector_id] = 0
                    if sector_id in state.world_topology:
                        state.world_topology[sector_id]["sector_type"] = new_level
                    state.colony_level_history.append({
                        "sector_id": sector_id,
                        "tick": state.sim_tick_count,
                        "old_level": old_level,
                        "new_level": new_level,
                    })

    def _calculate_current_matter(self, state: GameState) -> float:
        total = 0.0

        for sector_id, potential in state.world_resource_potential.items():
            total += potential.get("mineral_density", 0.0)
            total += potential.get("propellant_sources", 0.0)

        for sector_id, hidden in state.world_hidden_resources.items():
            total += hidden.get("mineral_density", 0.0)
            total += hidden.get("propellant_sources", 0.0)

        for sector_id, stockpile in state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                total += float(qty)

        for wreck_uid, wreck in state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                total += float(qty)
            total += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        total += state.hostile_matter_pool
        total += state.hostile_body_mass

        for char_uid, inv in state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        return total

--- Start of ./python_sandbox/__init__.py ---

# GDTLancer Python Simulation Sandbox

--- Start of ./python_sandbox/main.py ---

#!/usr/bin/env python3
"""
GDTLancer Simulation Sandbox — CLI runner.

Outputs structured plain text optimized for LLM analysis.
All visualization code has been removed in favor of compact,
machine-readable state dumps.

Usage:
    python main.py                      # 10 ticks, default seed
    python main.py --ticks 50000        # 50k ticks
    python main.py --seed hello         # custom seed
    python main.py --sample-every 500   # sample metrics every N ticks
    python main.py --quiet              # final report only (no progress dots)
    python main.py --head 10            # show first N ticks in transient view
    python main.py --tail 10            # show last N ticks in transient view
"""

import argparse
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simulation_engine import SimulationEngine


# -----------------------------------------------------------------
# Suppress noisy layer prints
# -----------------------------------------------------------------
_original_print = print

def _quiet_print(*a, **kw):
    msg = " ".join(str(x) for x in a)
    prefixes = (
        "WorldLayer:", "GridLayer:", "AgentLayer:",
        "SimulationEngine:", "BridgeSystems:", "ChronicleLayer:",
        "AXIOM 1",
    )
    if any(msg.startswith(p) for p in prefixes):
        return
    _original_print(*a, **kw)


# -----------------------------------------------------------------
# Snapshot helpers (captured every tick for head/tail windows)
# -----------------------------------------------------------------
def _snapshot_agents(state):
    """Compact per-agent snapshot: name->(role,sector,hull,cash,debt,goal,disabled)"""
    snap = {}
    for agent_id in sorted(state.agents.keys()):
        a = state.agents[agent_id]
        char_uid = a.get("char_uid", -1)
        ch = state.characters.get(char_uid, {})
        name = ch.get("character_name", f"U{char_uid}")
        snap[name] = {
            "r": a.get("agent_role", "?")[:4],
            "s": a.get("current_sector_id", "?").replace("station_", "")[:3],
            "h": round(a.get("hull_integrity", 0.0), 3),
            "c": round(a.get("cash_reserves", 0.0), 1),
            "d": round(a.get("debt", 0.0), 1),
            "g": a.get("goal_archetype", "?")[:5],
            "x": 1 if a.get("is_disabled", False) else 0,
        }
    return snap


def _snapshot_sectors(state):
    """Compact per-sector snapshot."""
    snap = {}
    for sid in sorted(state.world_topology.keys()):
        short = sid.replace("station_", "").upper()[:3]
        pot = state.world_resource_potential.get(sid, {})
        hid = state.world_hidden_resources.get(sid, {})
        stock = state.grid_stockpiles.get(sid, {})
        dom = state.grid_dominion.get(sid, {})
        hz = state.world_hazards.get(sid, {})

        stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
        fi = dom.get("faction_influence", {})
        dominant = max(fi, key=fi.get).replace("faction_", "")[:4] if fi else "?"

        snap[short] = {
            "dM": round(pot.get("mineral_density", 0.0), 1),
            "dP": round(pot.get("propellant_sources", 0.0), 1),
            "hM": round(hid.get("mineral_density", 0.0), 1),
            "hP": round(hid.get("propellant_sources", 0.0), 1),
            "stk": round(stot, 1),
            "sec": round(dom.get("security_level", 0.0), 3),
            "pir": round(dom.get("pirate_activity", 0.0), 4),
            "hos": round(dom.get("hostility_level", 0.0), 4),
            "rad": round(hz.get("radiation_level", 0.0), 4),
            "dom": dominant,
        }
    return snap


def _snapshot_hostiles(state):
    """Compact hostile population snapshot."""
    snap = {}
    for htype, pop in state.hostile_population_integral.items():
        counts = pop.get("sector_counts", {})
        total = pop.get("current_count", 0)
        dist = {k.replace("station_", "")[:3]: v for k, v in sorted(counts.items())}
        snap[htype[:5]] = {"n": total, "d": dist}
    return snap


def _snapshot_wrecks(state):
    """Wreck count and total matter in wrecks."""
    count = len(state.grid_wrecks)
    matter = 0.0
    for w in state.grid_wrecks.values():
        matter += w.get("wreck_integrity", 0.0)
        for qty in w.get("wreck_inventory", {}).values():
            matter += float(qty)
    return {"count": count, "matter": round(matter, 2)}


def _snapshot_matter(engine):
    """Compact matter breakdown."""
    bd = engine._matter_breakdown()
    return {k[:6]: round(v, 2) for k, v in bd.items()}


# -----------------------------------------------------------------
# Report generation
# -----------------------------------------------------------------
def generate_report(engine, ticks_run, sample_data, age_transitions,
                    transient_head, transient_tail, head_n, tail_n):
    """Produce a single structured report after the run completes."""
    s = engine.state
    sectors = sorted(s.world_topology.keys())  # Dynamic: includes discovered sectors
    init_matter = s.world_total_matter
    actual_matter = engine._calculate_total_matter()
    drift = abs(actual_matter - init_matter)

    out = []
    out.append(f"=== Simulation Report: {ticks_run} ticks, seed='{s.world_seed}' ===")
    out.append(f"  head={head_n} tail={tail_n} sample_every={sample_data.get('sample_every', 1)}")
    out.append("")

    # == AXIOM 1 (relative drift) ==
    drifts = sample_data["axiom1_drifts"]
    max_d = max(drifts) if drifts else drift
    avg_d = sum(drifts) / len(drifts) if drifts else drift
    max_rel = max_d / max(init_matter, 1.0) * 100.0
    avg_rel = avg_d / max(init_matter, 1.0) * 100.0
    out.append(f"AXIOM_1: max_drift={max_d:.2f} ({max_rel:.4f}%) "
               f"avg_drift={avg_d:.2f} ({avg_rel:.4f}%) "
               f"budget={init_matter:.2f} final={actual_matter:.2f}")

    # == WORLD AGE ==
    out.append(f"WORLD_AGE: current={s.world_age} timer={s.world_age_timer} "
               f"cycles={s.world_age_cycle_count} transitions={len(age_transitions)}")
    if age_transitions:
        out.append(f"  first_3: {age_transitions[:3]}")
        out.append(f"  last_3:  {age_transitions[-3:]}")
    out.append("")

    # == SECTOR STATE (final) ==
    out.append("SECTOR_STATE (final):")
    out.append("  sector   |type    |disc_M    disc_P  |hidden_M hidden_P|stock  |"
               "sec  pir    hos    |dom         |rad    therm")
    out.append("  " + "-" * 110)
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        tp = s.world_topology[sid]
        stype = tp.get("sector_type", "?")[:6]
        pot = s.world_resource_potential.get(sid, {})
        hid = s.world_hidden_resources.get(sid, {})
        stk = s.grid_stockpiles.get(sid, {})
        dom = s.grid_dominion.get(sid, {})
        hz = s.world_hazards.get(sid, {})

        dm = pot.get("mineral_density", 0.0)
        dp = pot.get("propellant_sources", 0.0)
        hm = hid.get("mineral_density", 0.0)
        hp = hid.get("propellant_sources", 0.0)
        stot = sum(float(v) for v in stk.get("commodity_stockpiles", {}).values())
        sec = dom.get("security_level", 0.0)
        pir = dom.get("pirate_activity", 0.0)
        hos = dom.get("hostility_level", 0.0)
        fi = dom.get("faction_influence", {})
        dominant = max(fi, key=fi.get).replace("faction_", "") if fi else "none"
        rad = hz.get("radiation_level", 0.0)
        therm = hz.get("thermal_background_k", 0.0)

        out.append(f"  {sh:<8} {stype:<7} {dm:>8.1f} {dp:>7.1f}  "
                   f"{hm:>7.1f} {hp:>7.1f}  {stot:>6.0f}  "
                   f"{sec:.2f} {pir:.4f} {hos:.4f}  {dominant:<12} "
                   f"{rad:.4f} {therm:.0f}")
    out.append("")

    # == MATTER BREAKDOWN (final) ==
    bd = engine._matter_breakdown()
    total = sum(bd.values())
    out.append("MATTER_BREAKDOWN (final):")
    parts = "  ".join(f"{k}={v:.1f}({v/total*100:.1f}%)" for k, v in bd.items()) if total > 0 else ""
    out.append(f"  {parts}")
    out.append(f"  TOTAL={total:.2f}")
    out.append("")

    # == AGENTS (final) ==
    out.append("AGENTS (final):")
    out.append("  name         role      sector     hull  cash      debt      goal     inv")
    out.append("  " + "-" * 85)
    for agent_id in sorted(s.agents.keys()):
        a = s.agents[agent_id]
        char_uid = a.get("char_uid", -1)
        ch = s.characters.get(char_uid, {})
        name = ch.get("character_name", f"UID:{char_uid}")
        sector = a.get("current_sector_id", "?").replace("station_", "")
        hull = a.get("hull_integrity", 0.0)
        cash = a.get("cash_reserves", 0.0)
        debt = a.get("debt", 0.0)
        goal = a.get("goal_archetype", "?")
        role = a.get("agent_role", "?")
        disabled = a.get("is_disabled", False)
        inv = s.inventories.get(char_uid, {}).get(2, {})
        inv_total = sum(float(v) for v in inv.values())
        status = "DEAD" if disabled else f"{hull:.2f}"
        out.append(f"  {name:<12} {role:<9} {sector:<10} {status:<5} "
                   f"{cash:>8.0f} {debt:>8.0f}  {goal:<8} {inv_total:.0f}")
    out.append("")

    # == HOSTILES (final) ==
    out.append("HOSTILES (final):")
    total_hostiles = 0
    for htype, pop in s.hostile_population_integral.items():
        count = pop.get("current_count", 0)
        cap = pop.get("carrying_capacity", 0)
        dist = pop.get("sector_counts", {})
        dist_str = " ".join(f"{k.replace('station_','')[:3]}={v}" for k, v in sorted(dist.items()))
        out.append(f"  {htype}: {count}/{cap}  [{dist_str}]")
        total_hostiles += count
    pool = s.hostile_matter_pool
    budget = sum(engine._matter_breakdown().values())
    pool_pct = (pool / budget * 100) if budget > 0 else 0.0
    wreck_count = len(s.grid_wrecks)
    wreck_matter = sum(
        sum(float(v) for v in w.get("wreck_inventory", {}).values()) + w.get("wreck_integrity", 0.0)
        for w in s.grid_wrecks.values()
    )
    out.append(f"  hostile_matter_pool={pool:.2f} ({pool_pct:.1f}% of budget)")
    out.append(f"  total_hostiles={total_hostiles}  wrecks={wreck_count} wreck_matter={wreck_matter:.1f}")
    out.append("")

    # == RESOURCE FLOW TIMELINE ==
    init_hidden = sample_data.get("init_hidden", {})
    total_h_ts = sample_data.get("total_hidden_ts", [])
    total_d_ts = sample_data.get("total_disc_ts", [])
    total_s_ts = sample_data.get("total_stock_ts", [])
    total_w_ts = sample_data.get("total_wreck_ts", [])
    se = sample_data.get("sample_every", 1)

    out.append("RESOURCE_FLOW_TIMELINE:")
    if total_h_ts:
        def _at_tick(ts, tick):
            idx = tick // se - 1
            if idx < 0: idx = 0
            if idx >= len(ts): idx = len(ts) - 1
            return ts[idx]

        markers = [se, 100, 500, 1000, 5000, 10000, 25000, ticks_run]
        markers = sorted(set(t for t in markers if t <= ticks_run))
        parts_h = " ".join(f"t{t}={_at_tick(total_h_ts, t):.0f}" for t in markers)
        parts_d = " ".join(f"t{t}={_at_tick(total_d_ts, t):.0f}" for t in markers)
        parts_s = " ".join(f"t{t}={_at_tick(total_s_ts, t):.0f}" for t in markers)
        out.append(f"  hidden:     {parts_h}")
        out.append(f"  discovered: {parts_d}")
        out.append(f"  stockpile:  {parts_s}")
        if total_w_ts:
            parts_w = " ".join(f"t{t}={_at_tick(total_w_ts, t):.0f}" for t in markers)
            out.append(f"  wrecks:     {parts_w}")
    out.append("")

    # == DEPLETION MILESTONES ==
    hidden_m_ts = sample_data.get("hidden_mineral_ts", {})
    hidden_p_ts = sample_data.get("hidden_propellant_ts", {})
    if hidden_m_ts:
        out.append("DEPLETION_MILESTONES (<10% / <1% hidden remaining):")
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            ih = init_hidden.get(sid, {"m": 0, "p": 0})
            m1 = m10 = p1 = p10 = None
            hm_list = hidden_m_ts.get(sid, [])
            hp_list = hidden_p_ts.get(sid, [])
            for i, hm in enumerate(hm_list):
                if m10 is None and ih["m"] > 0 and hm / ih["m"] < 0.10:
                    m10 = (i + 1) * se
                if m1 is None and ih["m"] > 0 and hm / ih["m"] < 0.01:
                    m1 = (i + 1) * se
            for i, hp in enumerate(hp_list):
                if p10 is None and ih["p"] > 0 and hp / ih["p"] < 0.10:
                    p10 = (i + 1) * se
                if p1 is None and ih["p"] > 0 and hp / ih["p"] < 0.01:
                    p1 = (i + 1) * se
            out.append(f"  {sh}: mineral(<10%={m10 or 'never'} <1%={m1 or 'never'})  "
                       f"propellant(<10%={p10 or 'never'} <1%={p1 or 'never'})")
        out.append("")

    # == STOCKPILE DYNAMICS ==
    out.append("STOCKPILE_DYNAMICS:")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        ts = sample_data.get("stockpile_ts", {}).get(sid, [])
        if ts:
            mn, mx = min(ts), max(ts)
            avg = sum(ts) / len(ts)
            std = math.sqrt(sum((x - avg) ** 2 for x in ts) / len(ts)) if len(ts) > 1 else 0
            out.append(f"  {sh}: min={mn:.0f} max={mx:.0f} avg={avg:.0f} std={std:.1f}")
    out.append("")

    # == PER-COMMODITY STOCKPILE BREAKDOWN (final) ==
    out.append("STOCKPILE_COMMODITIES (final):")
    header_coms = set()
    for sid in sectors:
        cs = s.grid_stockpiles.get(sid, {}).get("commodity_stockpiles", {})
        header_coms.update(cs.keys())
    header_coms = sorted(header_coms)
    if header_coms:
        com_short = [c.replace("commodity_", "")[:4] for c in header_coms]
        out.append("  sector   " + " ".join(f"{c:>7}" for c in com_short))
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            cs = s.grid_stockpiles.get(sid, {}).get("commodity_stockpiles", {})
            vals = " ".join(f"{cs.get(c, 0.0):>7.1f}" for c in header_coms)
            out.append(f"  {sh:<8} {vals}")
    out.append("")

    # == HAZARD DRIFT ==
    if s.world_hazards_base:
        out.append("HAZARD_DRIFT:")
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            br = s.world_hazards_base[sid]["radiation_level"]
            bt = s.world_hazards_base[sid]["thermal_background_k"]
            r_ts = sample_data.get("radiation_ts", {}).get(sid, [])
            t_ts = sample_data.get("thermal_ts", {}).get(sid, [])
            if r_ts:
                out.append(f"  {sh}: rad base={br:.4f} [{min(r_ts):.4f},{max(r_ts):.4f}]  "
                           f"therm base={bt:.0f} [{min(t_ts):.0f},{max(t_ts):.0f}]")
        out.append("")

    # == MARKET PRICES (final) ==
    out.append("MARKET_PRICES (delta from base):")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        mkt = s.grid_market.get(sid, {})
        deltas = mkt.get("commodity_price_deltas", {})
        parts = " ".join(f"{k.replace('commodity_','')[:4]}{v:+.3f}" for k, v in sorted(deltas.items()))
        out.append(f"  {sh}: {parts}")
    out.append("")

    # == AGENT STATS (sampled aggregates) ==
    agent_hull_ts = sample_data.get("agent_hull_ts", {})
    agent_cash_ts = sample_data.get("agent_cash_ts", {})
    agent_debt_ts = sample_data.get("agent_debt_ts", {})
    if agent_hull_ts:
        out.append("AGENT_STATS (sampled aggregates):")
        out.append("  name         hull_avg hull_min cash_avg cash_max  debt_final")
        out.append("  " + "-" * 65)
        for name in sorted(agent_hull_ts.keys()):
            hulls = agent_hull_ts[name]
            cashes = agent_cash_ts.get(name, [0])
            debts = agent_debt_ts.get(name, [0])
            h_avg = sum(hulls) / len(hulls) if hulls else 0
            h_min = min(hulls) if hulls else 0
            c_avg = sum(cashes) / len(cashes) if cashes else 0
            c_max = max(cashes) if cashes else 0
            d_final = debts[-1] if debts else 0
            out.append(f"  {name:<12} {h_avg:>8.3f} {h_min:>8.3f} "
                       f"{c_avg:>8.0f} {c_max:>8.0f} {d_final:>10.0f}")
        out.append("")

    # == HOSTILE POPULATION TIMELINE ==
    hostile_ts = sample_data.get("hostile_total_ts", [])
    if hostile_ts and total_h_ts:
        out.append("HOSTILE_POP_TIMELINE:")
        markers2 = [se, 100, 500, 1000, 5000, 10000, 25000, ticks_run]
        markers2 = sorted(set(t for t in markers2 if t <= ticks_run))
        parts_hp = " ".join(f"t{t}={_at_tick(hostile_ts, t):.0f}" for t in markers2)
        out.append(f"  total: {parts_hp}")
        hmin = min(hostile_ts)
        hmax = max(hostile_ts)
        havg = sum(hostile_ts) / len(hostile_ts)
        out.append(f"  min={hmin} max={hmax} avg={havg:.1f}")
        out.append("")

    # == AGENT LIFECYCLE EVENTS ==
    lifecycle = sample_data.get("lifecycle_events", [])
    out.append(f"AGENT_LIFECYCLE: {len(lifecycle)} events")
    if lifecycle:
        show_n = 15
        if len(lifecycle) <= show_n * 2:
            for ev in lifecycle:
                out.append(f"  {ev}")
        else:
            for ev in lifecycle[:show_n]:
                out.append(f"  {ev}")
            out.append(f"  ... ({len(lifecycle) - show_n * 2} more)")
            for ev in lifecycle[-show_n:]:
                out.append(f"  {ev}")
    out.append("")

    # == CATASTROPHES ==
    out.append(f"CATASTROPHES: {len(s.catastrophe_log)} total")
    if s.catastrophe_log:
        show_c = min(8, len(s.catastrophe_log))
        for cat in s.catastrophe_log[-show_c:]:
            sh = cat.get("sector_id", "?").replace("station_", "").upper()
            tick = cat.get("tick", 0)
            matter = cat.get("matter_converted", 0.0)
            until = cat.get("disable_until", 0)
            out.append(f"  t={tick} {sh} matter={matter:.1f} disabled_until={until}")
    out.append("")

    # == DISABLED SECTORS ==
    active_disabled = {sid: until for sid, until in s.sector_disabled_until.items()
                       if until > s.sim_tick_count}
    if active_disabled:
        out.append("DISABLED_SECTORS:")
        for sid, until in sorted(active_disabled.items()):
            sh = sid.replace("station_", "").upper()
            out.append(f"  {sh}: until tick {until}")
        out.append("")

    # == COLONY LEVELS (final) ==
    out.append("COLONY_LEVELS (final):")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        level = s.colony_levels.get(sid, "frontier")
        up_prog = s.colony_upgrade_progress.get(sid, 0)
        dn_prog = s.colony_downgrade_progress.get(sid, 0)
        out.append(f"  {sh}: {level:<10} upgrade_prog={up_prog:>4} downgrade_prog={dn_prog:>4}")
    if s.colony_level_history:
        out.append(f"  transitions ({len(s.colony_level_history)}):")
        show_cl = min(10, len(s.colony_level_history))
        for ev in s.colony_level_history[-show_cl:]:
            out.append(f"    {ev}")
    out.append("")

    # == MORTAL AGENTS ==
    mortal_count = sum(1 for a in s.agents.values()
                       if not a.get("is_persistent", True))
    mortal_alive = sum(1 for a in s.agents.values()
                       if not a.get("is_persistent", True) and not a.get("is_disabled", False))
    out.append(f"MORTAL_AGENTS: spawned_total={s.mortal_agent_counter} "
               f"currently_alive={mortal_alive} currently_tracked={mortal_count} "
               f"deaths={len(s.mortal_agent_deaths)}")
    if s.mortal_agent_deaths:
        show_md = min(10, len(s.mortal_agent_deaths))
        for ev in s.mortal_agent_deaths[-show_md:]:
            out.append(f"  {ev}")
    out.append("")

    # == SECTOR DISCOVERY ==
    out.append(f"SECTOR_DISCOVERY: discovered={s.discovered_sector_count} "
               f"total_sectors={len(sectors)}")
    if s.discovery_log:
        for ev in s.discovery_log:
            out.append(f"  {ev}")
    out.append("")

    # == CHRONICLE ==
    out.append(f"CHRONICLE: {len(s.chronicle_rumors)} rumors, last 8:")
    for r in s.chronicle_rumors[-8:]:
        out.append(f"  {r}")
    out.append("")

    # ================================================================
    # TRANSIENT STATES  tick-by-tick snapshots for head/tail windows
    # ================================================================
    if transient_head or transient_tail:
        out.append("=" * 80)
        out.append("TRANSIENT STATES (tick-by-tick)")
        out.append("=" * 80)
        out.append("")

        all_blocks = []
        if transient_head:
            all_blocks.append(("HEAD", transient_head))
        if transient_tail:
            all_blocks.append(("TAIL", transient_tail))

        for label, snapshots in all_blocks:
            if not snapshots:
                continue
            tick_range = f"t{snapshots[0]['tick']}..t{snapshots[-1]['tick']}"
            out.append(f"-- {label} ({tick_range}) --")
            out.append("")

            sec_names = sorted(snapshots[0]["sectors"].keys())
            agent_names = sorted(snapshots[0]["agents"].keys())

            # -- Sector table: one row per tick, columns = per-sector key metrics --
            out.append(f"  SECTORS ({label}):")
            # Header: tick age | SEC1:stk/hM/sec/pir/hos | SEC2:... |
            hdr_parts = []
            for sn in sec_names:
                hdr_parts.append(f"{sn}:stk hM hP sec pir hos")
            out.append(f"  {'tick':>5} {'age':>4} | " + " | ".join(hdr_parts))
            for snap in snapshots:
                t = snap["tick"]
                age = snap["age"][:4]
                row_parts = []
                for sn in sec_names:
                    sd = snap["sectors"].get(sn, {})
                    row_parts.append(
                        f"{sn}:{sd.get('stk',0):>4.0f} "
                        f"{sd.get('hM',0):>4.0f} "
                        f"{sd.get('hP',0):>4.0f} "
                        f"{sd.get('sec',0):.2f} "
                        f"{sd.get('pir',0):.3f} "
                        f"{sd.get('hos',0):.3f}"
                    )
                out.append(f"  {t:>5} {age:>4} | " + " | ".join(row_parts))
            out.append("")

            # -- Agent state table --
            out.append(f"  AGENTS ({label}):  format= hull/cash/goal  (X=disabled)")
            hdr = f"  {'tick':>5} |"
            for n in agent_names:
                hdr += f" {n[:7]:>10} |"
            out.append(hdr)
            for snap in snapshots:
                t = snap["tick"]
                row = f"  {t:>5} |"
                for n in agent_names:
                    ad = snap["agents"].get(n, {})
                    if ad.get("x", 0):
                        cell = "DEAD"
                    else:
                        h = ad.get("h", 0)
                        c = ad.get("c", 0)
                        g = ad.get("g", "?")[:3]
                        cell = f"{h:.2f}/{c:.0f}/{g}"
                    row += f" {cell:>10} |"
                out.append(row)
            out.append("")

            # -- Agent debt table (only if any debt exists) --
            has_debt = any(
                snap["agents"].get(n, {}).get("d", 0) > 0
                for snap in snapshots for n in agent_names
            )
            if has_debt:
                out.append(f"  DEBT ({label}):")
                hdr = f"  {'tick':>5} |"
                for n in agent_names:
                    hdr += f" {n[:7]:>8} |"
                out.append(hdr)
                for snap in snapshots:
                    t = snap["tick"]
                    row = f"  {t:>5} |"
                    for n in agent_names:
                        d = snap["agents"].get(n, {}).get("d", 0)
                        row += f" {d:>8.0f} |"
                    out.append(row)
                out.append("")

            # -- Hostiles per tick --
            out.append(f"  HOSTILES ({label}):")
            htypes = sorted(snapshots[0]["hostiles"].keys())
            for snap in snapshots:
                t = snap["tick"]
                parts = []
                for ht in htypes:
                    hd = snap["hostiles"].get(ht, {})
                    n = hd.get("n", 0)
                    dist = hd.get("d", {})
                    ds = " ".join(f"{k}={v}" for k, v in sorted(dist.items()))
                    parts.append(f"{ht}={n}[{ds}]")
                out.append(f"  {t:>5}: " + "  ".join(parts))
            out.append("")

            # -- Wrecks + matter per tick --
            out.append(f"  WRECKS_MATTER ({label}):")
            out.append(f"  {'tick':>5}  wrecks wreck_matter hostile_pool agent_inv")
            for snap in snapshots:
                t = snap["tick"]
                w = snap["wrecks"]
                m = snap["matter"]
                out.append(f"  {t:>5}  {w['count']:>6} {w['matter']:>12.2f} "
                           f"{m.get('hostil', 0):>12.2f} "
                           f"{m.get('agent_', 0):>9.2f}")
            out.append("")

            # -- Axiom 1 drift per tick --
            out.append(f"  AXIOM1 ({label}):")
            for snap in snapshots:
                t = snap["tick"]
                d = snap["drift"]
                rel = d / max(init_matter, 1.0) * 100.0
                out.append(f"  {t:>5}: drift={d:.2f} ({rel:.4f}%)")
            out.append("")

    out.append("=== END REPORT ===")
    return "\n".join(out)


# -----------------------------------------------------------------
# Main
# -----------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="GDTLancer Simulation Sandbox")
    parser.add_argument("--ticks", type=int, default=10,
                        help="Number of simulation ticks (default: 10)")
    parser.add_argument("--seed", type=str, default="default_seed",
                        help="World generation seed (default: 'default_seed')")
    parser.add_argument("--sample-every", type=int, default=0,
                        help="Sample metrics every N ticks (default: auto)")
    parser.add_argument("--quiet", action="store_true",
                        help="Suppress progress dots, print only final report")
    parser.add_argument("--head", type=int, default=10,
                        help="Ticks for transient head window (default: 10)")
    parser.add_argument("--tail", type=int, default=10,
                        help="Ticks for transient tail window (default: 10)")
    args = parser.parse_args()

    head_n = args.head
    tail_n = args.tail

    # Auto sample interval: ~1000 data points max
    sample_every = args.sample_every if args.sample_every > 0 else max(1, args.ticks // 1000)

    # Suppress layer spam
    import builtins
    builtins.print = _quiet_print

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    builtins.print = _original_print

    sectors = sorted(engine.state.world_topology.keys())
    init_matter = engine.state.world_total_matter

    # Snapshot initial hidden resources
    init_hidden = {}
    for sid in sectors:
        h = engine.state.world_hidden_resources.get(sid, {})
        init_hidden[sid] = {
            "m": h.get("mineral_density", 0.0),
            "p": h.get("propellant_sources", 0.0),
        }

    # Tracking arrays (sampled at sample_every interval)
    axiom1_drifts = []
    hidden_mineral_ts = {sid: [] for sid in sectors}
    hidden_propellant_ts = {sid: [] for sid in sectors}
    total_hidden_ts = []
    total_disc_ts = []
    total_stock_ts = []
    total_wreck_ts = []
    stockpile_ts = {sid: [] for sid in sectors}
    radiation_ts = {sid: [] for sid in sectors}
    thermal_ts = {sid: [] for sid in sectors}
    age_transitions = []
    prev_age = engine.state.world_age

    # Agent time series (sampled)
    agent_hull_ts = {}
    agent_cash_ts = {}
    agent_debt_ts = {}
    hostile_total_ts = []

    # Lifecycle events
    lifecycle_events = []

    # Transient snapshots (tick-by-tick, step=1)
    transient_head = []
    transient_tail = []

    if not args.quiet:
        _original_print(f"Running {args.ticks} ticks (sample every {sample_every}, "
                        f"head={head_n}, tail={tail_n})...", end="", flush=True)

    # Suppress layer spam during tick loop
    builtins.print = _quiet_print

    for tick in range(1, args.ticks + 1):
        # Pre-tick state for lifecycle detection
        pre_disabled = {aid: a.get("is_disabled", False)
                        for aid, a in engine.state.agents.items()}

        engine.process_tick()

        # Age transitions
        if engine.state.world_age != prev_age:
            age_transitions.append((tick, prev_age, engine.state.world_age))
            prev_age = engine.state.world_age

        # Lifecycle events: disabled/respawned
        for aid, a in engine.state.agents.items():
            if aid == "player":
                continue
            was_disabled = pre_disabled.get(aid, False)
            is_disabled = a.get("is_disabled", False)
            char_uid = a.get("char_uid", -1)
            ch = engine.state.characters.get(char_uid, {})
            name = ch.get("character_name", f"U{char_uid}")
            if is_disabled and not was_disabled:
                lifecycle_events.append(
                    f"t={tick} {name} DISABLED hull={a.get('hull_integrity',0):.2f} "
                    f"cash={a.get('cash_reserves',0):.0f} debt={a.get('debt',0):.0f}")
            elif was_disabled and not is_disabled:
                lifecycle_events.append(
                    f"t={tick} {name} RESPAWNED cash={a.get('cash_reserves',0):.0f} "
                    f"debt={a.get('debt',0):.0f}")

        # Transient snapshot (every tick for head/tail windows)
        in_head = tick <= head_n
        in_tail = tick > args.ticks - tail_n

        if in_head or in_tail:
            actual = engine._calculate_total_matter()
            snap = {
                "tick": tick,
                "age": engine.state.world_age,
                "agents": _snapshot_agents(engine.state),
                "sectors": _snapshot_sectors(engine.state),
                "hostiles": _snapshot_hostiles(engine.state),
                "wrecks": _snapshot_wrecks(engine.state),
                "matter": _snapshot_matter(engine),
                "drift": abs(actual - init_matter),
            }
            if in_head:
                transient_head.append(snap)
            if in_tail:
                transient_tail.append(snap)

        # Periodic sample
        if tick % sample_every == 0:
            actual = engine._calculate_total_matter()
            axiom1_drifts.append(abs(actual - init_matter))

            total_h = total_d = total_s = 0.0
            current_sectors = sorted(engine.state.world_topology.keys())
            for sid in current_sectors:
                h = engine.state.world_hidden_resources.get(sid, {})
                p = engine.state.world_resource_potential.get(sid, {})
                hm = h.get("mineral_density", 0.0)
                hp = h.get("propellant_sources", 0.0)
                dm = p.get("mineral_density", 0.0)
                dp = p.get("propellant_sources", 0.0)
                hidden_mineral_ts.setdefault(sid, []).append(hm)
                hidden_propellant_ts.setdefault(sid, []).append(hp)
                total_h += hm + hp
                total_d += dm + dp

                stock = engine.state.grid_stockpiles.get(sid, {})
                stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
                stockpile_ts.setdefault(sid, []).append(stot)
                total_s += stot

                hazards = engine.state.world_hazards.get(sid, {})
                radiation_ts.setdefault(sid, []).append(hazards.get("radiation_level", 0.0))
                thermal_ts.setdefault(sid, []).append(hazards.get("thermal_background_k", 300.0))

            total_hidden_ts.append(total_h)
            total_disc_ts.append(total_d)
            total_stock_ts.append(total_s)

            # Wreck matter
            wreck_matter = 0.0
            for w in engine.state.grid_wrecks.values():
                wreck_matter += w.get("wreck_integrity", 0.0)
                for qty in w.get("wreck_inventory", {}).values():
                    wreck_matter += float(qty)
            total_wreck_ts.append(wreck_matter)

            # Hostile total
            htot = sum(pop.get("current_count", 0)
                       for pop in engine.state.hostile_population_integral.values())
            hostile_total_ts.append(htot)

            # Agent stats
            for aid, a in engine.state.agents.items():
                if aid == "player":
                    continue
                char_uid = a.get("char_uid", -1)
                ch = engine.state.characters.get(char_uid, {})
                name = ch.get("character_name", f"U{char_uid}")
                agent_hull_ts.setdefault(name, []).append(a.get("hull_integrity", 0.0))
                agent_cash_ts.setdefault(name, []).append(a.get("cash_reserves", 0.0))
                agent_debt_ts.setdefault(name, []).append(a.get("debt", 0.0))

            # Progress dot every 10%
            if not args.quiet and tick % max(1, args.ticks // 10) < sample_every:
                builtins.print = _original_print
                _original_print(".", end="", flush=True)
                builtins.print = _quiet_print

    builtins.print = _original_print
    if not args.quiet:
        _original_print(" done.")

    sample_data = {
        "axiom1_drifts": axiom1_drifts,
        "init_hidden": init_hidden,
        "total_hidden_ts": total_hidden_ts,
        "total_disc_ts": total_disc_ts,
        "total_stock_ts": total_stock_ts,
        "total_wreck_ts": total_wreck_ts,
        "stockpile_ts": stockpile_ts,
        "hidden_mineral_ts": hidden_mineral_ts,
        "hidden_propellant_ts": hidden_propellant_ts,
        "radiation_ts": radiation_ts,
        "thermal_ts": thermal_ts,
        "sample_every": sample_every,
        "lifecycle_events": lifecycle_events,
        "agent_hull_ts": agent_hull_ts,
        "agent_cash_ts": agent_cash_ts,
        "agent_debt_ts": agent_debt_ts,
        "hostile_total_ts": hostile_total_ts,
    }

    report = generate_report(engine, args.ticks, sample_data, age_transitions,
                             transient_head, transient_tail, head_n, tail_n)
    _original_print(report)


if __name__ == "__main__":
    main()

--- Start of ./python_sandbox/simulation_engine.py ---

"""
GDTLancer Simulation Engine — tick orchestrator.
Mirror of src/core/simulation/simulation_engine.gd.

Manages the full tick sequence:
  Step 1: World Layer — static, no per-tick processing
  Step 2: Grid Layer — CA-driven resource/dominion/market evolution
  Step 3: Bridge Systems — cross-layer heat/entropy/knowledge
  Step 4: Agent Layer — NPC goal evaluation and action execution
  Step 5: Chronicle Layer — event capture and rumor generation
  ASSERT: Conservation Axiom 1 — total matter unchanged
"""

from game_state import GameState
from world_layer import WorldLayer
from grid_layer import GridLayer
from agent_layer import AgentLayer
from bridge_systems import BridgeSystems
from chronicle_layer import ChronicleLayer
import constants


class SimulationEngine:
    """Tick orchestrator for the four-layer simulation."""

    def __init__(self):
        self.state = GameState()
        self.world_layer = WorldLayer()
        self.grid_layer = GridLayer()
        self.agent_layer = AgentLayer()
        self.bridge_systems = BridgeSystems()
        self.chronicle_layer = ChronicleLayer()

        self._initialized: bool = False
        self._tick_config: dict = {}

        self._build_tick_config()

    # -----------------------------------------------------------------
    # Initialization
    # -----------------------------------------------------------------
    def initialize_simulation(self, seed_string: str) -> None:
        """Initialize the full simulation from a seed string."""
        print(f"SimulationEngine: Initializing simulation with seed '{seed_string}'...")

        # Step 1: World Layer
        self.world_layer.initialize_world(self.state, seed_string)

        # Step 2: Grid Layer
        self.grid_layer.initialize_grid(self.state)

        # Step 3: Agent Layer
        self.agent_layer.initialize_agents(self.state)

        # Give agent layer a reference to chronicle for event logging
        self.agent_layer.set_chronicle(self.chronicle_layer)

        # Initialize World Age Cycle
        self.state.world_age = constants.WORLD_AGE_CYCLE[0]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[
            self.state.world_age
        ]
        self.state.world_age_cycle_count = 0
        self._apply_age_config()  # Apply initial age overrides

        # Dynamic sector count for hazard phase calculation
        self._tick_config["num_sectors"] = len(self.state.world_topology)

        # Recalculate total matter for definitive Axiom 1 checksum
        self.world_layer.recalculate_total_matter(self.state)

        self._initialized = True

        print(
            f"SimulationEngine: Initialization complete. "
            f"Matter budget: {self.state.world_total_matter:.2f}, "
            f"Tick: {self.state.sim_tick_count}"
        )

    # -----------------------------------------------------------------
    # Tick Processing
    # -----------------------------------------------------------------
    def process_tick(self) -> None:
        """Process one full simulation tick through all layers."""
        self.state.sim_tick_count += 1
        tick = self.state.sim_tick_count

        # World Age Cycle — advance age timer, transition on expiry
        self._advance_world_age()

        # Step 1: World Layer (static — no processing)
        # Step 2: Grid Layer
        self.grid_layer.process_tick(self.state, self._tick_config)

        # Step 3: Bridge Systems
        self.bridge_systems.process_tick(self.state, self._tick_config)

        # Step 4: Agent Layer
        self.agent_layer.process_tick(self.state, self._tick_config)

        # Step 5: Chronicle Layer
        self.chronicle_layer.process_tick(self.state)

        # ASSERT: Conservation Axiom 1
        is_conserved = self.verify_matter_conservation()
        if not is_conserved:
            print(f"SimulationEngine: AXIOM 1 VIOLATION at tick {tick}!")

    # -----------------------------------------------------------------
    # Conservation Axiom 1
    # -----------------------------------------------------------------
    def verify_matter_conservation(self) -> bool:
        """Verify total matter stays within relative tolerance of initial budget."""
        expected = self.state.world_total_matter
        actual = self._calculate_total_matter()
        rel_tolerance = self._tick_config.get("axiom1_relative_tolerance", 0.005)
        abs_drift = abs(actual - expected)
        rel_drift = abs_drift / max(expected, 1.0)

        if rel_drift > rel_tolerance:
            breakdown = self._matter_breakdown()
            print(
                f"AXIOM 1 DRIFT: {abs_drift:.4f} ({rel_drift*100:.4f}% of budget, "
                f"limit={rel_tolerance*100:.2f}%)\n"
                f"  expected: {expected:.2f}, actual: {actual:.2f}\n"
                f"  Resource potential: {breakdown['resource_potential']:.2f}\n"
                f"  Hidden resources: {breakdown['hidden_resources']:.2f}\n"
                f"  Grid stockpiles: {breakdown['grid_stockpiles']:.2f}\n"
                f"  Wrecks: {breakdown['wrecks']:.2f}\n"
                f"  Hostile pool: {breakdown['hostile_pool']:.2f}\n"
                f"  Hostile bodies: {breakdown['hostile_bodies']:.2f}\n"
                f"  Agent inventories: {breakdown['agent_inventories']:.2f}"
            )
            return False
        return True

    def _calculate_total_matter(self) -> float:
        total = 0.0

        # Layer 1: Resource potential
        for sector_id, potential in self.state.world_resource_potential.items():
            total += potential.get("mineral_density", 0.0)
            total += potential.get("propellant_sources", 0.0)

        # Layer 1: Hidden resources
        for sector_id, hidden in self.state.world_hidden_resources.items():
            total += hidden.get("mineral_density", 0.0)
            total += hidden.get("propellant_sources", 0.0)

        # Layer 2: Grid stockpiles
        for sector_id, stockpile in self.state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                total += float(qty)

        # Layer 2: Wrecks
        for wreck_uid, wreck in self.state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                total += float(qty)
            total += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        # Hostile matter pool (matter consumed by hostiles from wrecks)
        total += self.state.hostile_matter_pool

        # Hostile body mass (matter locked in living hostile bodies)
        total += self.state.hostile_body_mass

        # Layer 3: Agent inventories
        for char_uid, inv in self.state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        return total

    def _matter_breakdown(self) -> dict:
        resource_potential = 0.0
        for sector_id, potential in self.state.world_resource_potential.items():
            resource_potential += potential.get("mineral_density", 0.0)
            resource_potential += potential.get("propellant_sources", 0.0)

        hidden_resources = 0.0
        for sector_id, hidden in self.state.world_hidden_resources.items():
            hidden_resources += hidden.get("mineral_density", 0.0)
            hidden_resources += hidden.get("propellant_sources", 0.0)

        grid_stockpiles = 0.0
        for sector_id, stockpile in self.state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                grid_stockpiles += float(qty)

        wrecks = 0.0
        for wreck_uid, wreck in self.state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                wrecks += float(qty)
            wrecks += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        hostile_pool = self.state.hostile_matter_pool

        agent_inventories = 0.0
        for char_uid, inv in self.state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    agent_inventories += float(qty)

        hostile_bodies = self.state.hostile_body_mass

        return {
            "resource_potential": resource_potential,
            "hidden_resources": hidden_resources,
            "grid_stockpiles": grid_stockpiles,
            "wrecks": wrecks,
            "hostile_pool": hostile_pool,
            "hostile_bodies": hostile_bodies,
            "agent_inventories": agent_inventories,
        }

    # -----------------------------------------------------------------
    # World Age Cycle
    # -----------------------------------------------------------------
    def _advance_world_age(self) -> None:
        """Cycle through world ages: PROSPERITY → DISRUPTION → RECOVERY → ..."""
        self.state.world_age_timer -= 1
        if self.state.world_age_timer <= 0:
            cycle = constants.WORLD_AGE_CYCLE
            current_idx = cycle.index(self.state.world_age)
            next_idx = (current_idx + 1) % len(cycle)

            if next_idx == 0:
                self.state.world_age_cycle_count += 1

            self.state.world_age = cycle[next_idx]
            self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[
                self.state.world_age
            ]
            self._apply_age_config()

            # Log the transition as a chronicle event
            if self.chronicle_layer:
                event = {
                    "actor_uid": "world",
                    "action_id": "age_change",
                    "target_uid": "",
                    "target_sector_id": "",
                    "tick_count": self.state.sim_tick_count,
                    "outcome": "success",
                    "metadata": {"new_age": self.state.world_age},
                }
                self.chronicle_layer.log_event(self.state, event)

    def _apply_age_config(self) -> None:
        """Rebuild tick config with base values, then overlay current age overrides."""
        self._build_tick_config()  # Reset to base
        age_overrides = constants.WORLD_AGE_CONFIGS.get(self.state.world_age, {})
        self._tick_config.update(age_overrides)

    # -----------------------------------------------------------------
    # Config
    # -----------------------------------------------------------------
    def _build_tick_config(self) -> None:
        self._tick_config = {
            # Grid CA
            "influence_propagation_rate": constants.CA_INFLUENCE_PROPAGATION_RATE,
            "pirate_activity_decay": constants.CA_PIRATE_ACTIVITY_DECAY,
            "pirate_activity_growth": constants.CA_PIRATE_ACTIVITY_GROWTH,
            "stockpile_diffusion_rate": constants.CA_STOCKPILE_DIFFUSION_RATE,
            "extraction_rate_default": constants.CA_EXTRACTION_RATE_DEFAULT,
            "price_sensitivity": constants.CA_PRICE_SENSITIVITY,
            "demand_base": constants.CA_DEMAND_BASE,
            # Wreck / Entropy
            "wreck_degradation_per_tick": constants.WRECK_DEGRADATION_PER_TICK,
            "wreck_debris_return_fraction": constants.WRECK_DEBRIS_RETURN_FRACTION,
            "entropy_radiation_multiplier": constants.ENTROPY_RADIATION_MULTIPLIER,
            "entropy_base_rate": constants.ENTROPY_BASE_RATE,
            # Power
            "power_draw_per_agent": constants.POWER_DRAW_PER_AGENT,
            "power_draw_per_service": constants.POWER_DRAW_PER_SERVICE,
            # Bridge Systems
            "heat_generation_in_space": constants.HEAT_GENERATION_IN_SPACE,
            "heat_dissipation_base": constants.HEAT_DISSIPATION_DOCKED,
            "heat_overheat_threshold": constants.HEAT_OVERHEAT_THRESHOLD,
            "entropy_hull_multiplier": constants.ENTROPY_HULL_MULTIPLIER,
            "fleet_entropy_reduction": constants.ENTROPY_FLEET_RATE_FRACTION,
            "propellant_drain_per_tick": constants.PROPELLANT_DRAIN_PER_TICK,
            "energy_drain_per_tick": constants.ENERGY_DRAIN_PER_TICK,
            "knowledge_noise_factor": constants.AGENT_KNOWLEDGE_NOISE_FACTOR,
            # Agent
            "npc_cash_low_threshold": constants.NPC_CASH_LOW_THRESHOLD,
            "npc_hull_repair_threshold": constants.NPC_HULL_REPAIR_THRESHOLD,
            "commodity_base_price": constants.COMMODITY_BASE_PRICE,
            "world_tick_interval_seconds": float(constants.WORLD_TICK_INTERVAL_SECONDS),
            "respawn_timeout_seconds": constants.RESPAWN_TIMEOUT_SECONDS,
            "hostile_growth_rate": constants.HOSTILE_GROWTH_RATE,
            # Hostile encounters (drones & aliens)
            "hostile_encounter_chance": constants.HOSTILE_ENCOUNTER_CHANCE,
            "hostile_damage_min": constants.HOSTILE_DAMAGE_MIN,
            "hostile_damage_max": constants.HOSTILE_DAMAGE_MAX,
            "hostile_cargo_loss_fraction": constants.HOSTILE_CARGO_LOSS_FRACTION,
            # Hostile spawning ecology
            "hostile_wreck_salvage_rate": constants.HOSTILE_WRECK_SALVAGE_RATE,
            "hostile_spawn_cost": constants.HOSTILE_SPAWN_COST,
            "hostile_low_security_threshold": constants.HOSTILE_LOW_SECURITY_THRESHOLD,
            "hostile_kill_per_military": constants.HOSTILE_KILL_PER_MILITARY,
            # Pirate role
            "pirate_raid_chance": constants.PIRATE_RAID_CHANCE,
            "pirate_raid_cargo_steal": constants.PIRATE_RAID_CARGO_STEAL,
            "pirate_move_interval": constants.PIRATE_MOVE_INTERVAL,
            "pirate_home_advantage": constants.PIRATE_HOME_ADVANTAGE,
            # Catastrophic events
            "catastrophe_chance_per_tick": constants.CATASTROPHE_CHANCE_PER_TICK,
            "catastrophe_disable_duration": constants.CATASTROPHE_DISABLE_DURATION,
            "catastrophe_stockpile_to_wreck": constants.CATASTROPHE_STOCKPILE_TO_WRECK,
            "catastrophe_hazard_boost": constants.CATASTROPHE_HAZARD_BOOST,
            "catastrophe_security_drop": constants.CATASTROPHE_SECURITY_DROP,
            # Prospector wreck salvage
            "prospector_wreck_salvage_rate": constants.PROSPECTOR_WRECK_SALVAGE_RATE,
            "prospector_wreck_security_threshold": constants.PROSPECTOR_WRECK_SECURITY_THRESHOLD,
            # Cash sinks
            "repair_cost_per_point": constants.REPAIR_COST_PER_POINT,
            "docking_fee_base": constants.DOCKING_FEE_BASE,
            "fuel_cost_per_unit": constants.FUEL_COST_PER_UNIT,
            # Faction anchoring
            "faction_anchor_strength": constants.CA_FACTION_ANCHOR_STRENGTH,
            # Axiom 1 (relative: fraction of total matter budget)
            "axiom1_relative_tolerance": constants.AXIOM1_RELATIVE_TOLERANCE,
            # Prospecting
            "prospecting_base_rate": constants.PROSPECTING_BASE_RATE,
            "prospecting_scarcity_boost": constants.PROSPECTING_SCARCITY_BOOST,
            "prospecting_security_factor": constants.PROSPECTING_SECURITY_FACTOR,
            "prospecting_hazard_penalty": constants.PROSPECTING_HAZARD_PENALTY,
            "prospecting_randomness": constants.PROSPECTING_RANDOMNESS,
            # Hazard drift (space weather)
            "hazard_drift_period": constants.HAZARD_DRIFT_PERIOD,
            "hazard_radiation_amplitude": constants.HAZARD_RADIATION_AMPLITUDE,
            "hazard_thermal_amplitude": constants.HAZARD_THERMAL_AMPLITUDE,
            # Roles
            "prospector_discovery_multiplier": constants.PROSPECTOR_DISCOVERY_MULTIPLIER,
            "prospector_move_interval": constants.PROSPECTOR_MOVE_INTERVAL,
            "military_security_boost": constants.MILITARY_SECURITY_BOOST,
            "military_piracy_suppress": constants.MILITARY_PIRACY_SUPPRESS,
            "military_patrol_interval": constants.MILITARY_PATROL_INTERVAL,
            "hauler_cargo_capacity": constants.HAULER_CARGO_CAPACITY,
            "hauler_surplus_threshold": constants.HAULER_SURPLUS_THRESHOLD,
            "hauler_deficit_threshold": constants.HAULER_DEFICIT_THRESHOLD,
            # Agent desperation / debt
            "desperation_hull_threshold": constants.DESPERATION_HULL_THRESHOLD,
            "desperation_trade_hull_risk": constants.DESPERATION_TRADE_HULL_RISK,
            "debt_interest_rate": constants.DEBT_INTEREST_RATE,
            "debt_cap": constants.DEBT_CAP,
            "respawn_debt_penalty": constants.RESPAWN_DEBT_PENALTY,
            # Entropy death
            "entropy_death_hull_threshold": constants.ENTROPY_DEATH_HULL_THRESHOLD,
            "entropy_death_tick_grace": constants.ENTROPY_DEATH_TICK_GRACE,
            # Hostile global threat (decoupled from piracy)
            "hostile_passive_spawn_chance": constants.HOSTILE_PASSIVE_SPAWN_CHANCE,
            "hostile_min_frontier_count": constants.HOSTILE_MIN_FRONTIER_COUNT,
            "hostile_global_cap": constants.HOSTILE_GLOBAL_CAP,
            # Hostile pressure valve (pool → hostiles → wrecks)
            "hostile_pool_pressure_threshold": constants.HOSTILE_POOL_PRESSURE_THRESHOLD,
            "hostile_pool_spawn_cost": constants.HOSTILE_POOL_SPAWN_COST,
            "hostile_pool_spawn_rate": constants.HOSTILE_POOL_SPAWN_RATE,
            "hostile_pool_max_spawns_per_tick": constants.HOSTILE_POOL_MAX_SPAWNS_PER_TICK,
            # Hostile raids on stockpiles
            "hostile_raid_threshold": constants.HOSTILE_RAID_THRESHOLD,
            "hostile_raid_chance": constants.HOSTILE_RAID_CHANCE,
            "hostile_raid_stockpile_fraction": constants.HOSTILE_RAID_STOCKPILE_FRACTION,
            "hostile_raid_casualties": constants.HOSTILE_RAID_CASUALTIES,
            # Resource layers (prospecting depth gating)
            "resource_layer_fractions": constants.RESOURCE_LAYER_FRACTIONS,
            "resource_layer_rate_multipliers": constants.RESOURCE_LAYER_RATE_MULTIPLIERS,
            "resource_layer_depletion_threshold": constants.RESOURCE_LAYER_DEPLETION_THRESHOLD,
            # Stockpile consumption (population sink)
            "consumption_rate_per_tick": constants.CONSUMPTION_RATE_PER_TICK,
            "consumption_entropy_tax": constants.CONSUMPTION_ENTROPY_TAX,
            # Respawn cooldown
            "respawn_cooldown_max_debt": constants.RESPAWN_COOLDOWN_MAX_DEBT,
            "respawn_cooldown_normal": constants.RESPAWN_COOLDOWN_NORMAL,
            # Colony levels
            "colony_upgrade_stockpile_fraction": constants.COLONY_UPGRADE_STOCKPILE_FRACTION,
            "colony_upgrade_security_min": constants.COLONY_UPGRADE_SECURITY_MIN,
            "colony_upgrade_ticks_required": constants.COLONY_UPGRADE_TICKS_REQUIRED,
            "colony_downgrade_stockpile_fraction": constants.COLONY_DOWNGRADE_STOCKPILE_FRACTION,
            "colony_downgrade_security_min": constants.COLONY_DOWNGRADE_SECURITY_MIN,
            "colony_downgrade_ticks_required": constants.COLONY_DOWNGRADE_TICKS_REQUIRED,
            # Mortal agents
            "mortal_spawn_chance_per_tick": constants.MORTAL_SPAWN_CHANCE_PER_TICK,
            "mortal_spawn_min_stockpile": constants.MORTAL_SPAWN_MIN_STOCKPILE,
            "mortal_spawn_min_security": constants.MORTAL_SPAWN_MIN_SECURITY,
            "mortal_spawn_cash": constants.MORTAL_SPAWN_CASH,
            "mortal_global_cap": constants.MORTAL_GLOBAL_CAP,
            # Explorer role
            "explorer_expedition_cost": constants.EXPLORER_EXPEDITION_COST,
            "explorer_expedition_fuel": constants.EXPLORER_EXPEDITION_FUEL,
            "explorer_discovery_chance": constants.EXPLORER_DISCOVERY_CHANCE,
            "explorer_move_interval": constants.EXPLORER_MOVE_INTERVAL,
            "explorer_wage": constants.EXPLORER_WAGE,
            "explorer_max_discovered_sectors": constants.EXPLORER_MAX_DISCOVERED_SECTORS,
            "new_sector_base_capacity": constants.NEW_SECTOR_BASE_CAPACITY,
            "new_sector_base_power": constants.NEW_SECTOR_BASE_POWER,
            "explorer_discovery_multiplier": constants.EXPLORER_DISCOVERY_MULTIPLIER,
        }

    # -----------------------------------------------------------------
    # Public utility
    # -----------------------------------------------------------------
    def get_chronicle(self) -> ChronicleLayer:
        return self.chronicle_layer

    def is_initialized(self) -> bool:
        return self._initialized

    def set_config(self, key: str, value) -> None:
        self._tick_config[key] = value

    def get_config(self) -> dict:
        return self._tick_config

--- Start of ./python_sandbox/template_data.py ---

"""
GDTLancer Template Data.
Hardcoded data that mirrors the .tres registry files in database/registry/.
Replaces TemplateDatabase autoload from Godot.
"""

# =========================================================================
# === LOCATIONS ===========================================================
# =========================================================================

LOCATIONS = {
    "station_alpha": {
        "location_name": "Station Alpha - Mining Hub",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_delta"],
        "sector_type": "hub",
        "radiation_level": 0.05,
        "thermal_background_k": 280.0,
        "gravity_well_penalty": 1.2,
        "mineral_density": 20.0,
        "propellant_sources": 10.3,
        "station_power_output": 150.0,
        "stockpile_capacity": 1500,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 8,  "sell_price": 6,  "quantity": 200},
            "commodity_food":   {"buy_price": 30, "sell_price": 25, "quantity": 40},
            "commodity_tech":   {"buy_price": 80, "sell_price": 65, "quantity": 15},
            "commodity_fuel":   {"buy_price": 25, "sell_price": 20, "quantity": 100},
        },
        "available_services": ["trade", "contracts", "repair"],
        "controlling_faction_id": "faction_miners",
        "danger_level": 1,
    },
    "station_beta": {
        "location_name": "Station Beta - Trade Post",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "hub",
        "radiation_level": 0.01,
        "thermal_background_k": 310.0,
        "gravity_well_penalty": 1.0,
        "mineral_density": 0.3,
        "propellant_sources": 0.8,
        "station_power_output": 120.0,
        "stockpile_capacity": 1200,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 15, "sell_price": 12, "quantity": 30},
            "commodity_food":   {"buy_price": 22, "sell_price": 18, "quantity": 80},
            "commodity_tech":   {"buy_price": 70, "sell_price": 55, "quantity": 50},
            "commodity_fuel":   {"buy_price": 30, "sell_price": 25, "quantity": 60},
            "commodity_luxury": {"buy_price": 90, "sell_price": 75, "quantity": 20},
        },
        "available_services": ["trade", "contracts"],
        "controlling_faction_id": "faction_traders",
        "danger_level": 2,
    },
    "station_gamma": {
        "location_name": "Freeport Gamma",
        "location_type": "station",
        "connections": ["station_alpha", "station_delta"],
        "sector_type": "frontier",
        "radiation_level": 0.15,
        "thermal_background_k": 250.0,
        "gravity_well_penalty": 1.5,
        "mineral_density": 0.8,
        "propellant_sources": 1.2,
        "station_power_output": 80.0,
        "stockpile_capacity": 800,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 12, "sell_price": 10, "quantity": 80},
            "commodity_food":   {"buy_price": 25, "sell_price": 20, "quantity": 60},
            "commodity_tech":   {"buy_price": 55, "sell_price": 45, "quantity": 30},
            "commodity_fuel":   {"buy_price": 20, "sell_price": 15, "quantity": 150},
            "commodity_luxury": {"buy_price": 120, "sell_price": 100, "quantity": 10},
        },
        "available_services": ["trade", "contracts", "black_market"],
        "controlling_faction_id": "faction_independents",
        "danger_level": 4,
    },
    "station_delta": {
        "location_name": "Outpost Delta - Military Garrison",
        "location_type": "station",
        "connections": ["station_beta", "station_gamma", "station_alpha"],
        "sector_type": "hub",
        "radiation_level": 0.02,
        "thermal_background_k": 295.0,
        "gravity_well_penalty": 1.1,
        "mineral_density": 5.0,
        "propellant_sources": 15.0,
        "station_power_output": 200.0,
        "stockpile_capacity": 1000,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 18, "sell_price": 14, "quantity": 50},
            "commodity_food":   {"buy_price": 20, "sell_price": 16, "quantity": 100},
            "commodity_tech":   {"buy_price": 60, "sell_price": 50, "quantity": 80},
            "commodity_fuel":   {"buy_price": 15, "sell_price": 12, "quantity": 120},
        },
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_military",
        "danger_level": 1,
    },
    "station_epsilon": {
        "location_name": "Epsilon Refinery Complex",
        "location_type": "station",
        "connections": ["station_alpha", "station_beta", "station_gamma"],
        "sector_type": "hub",
        "radiation_level": 0.08,
        "thermal_background_k": 340.0,
        "gravity_well_penalty": 0.9,
        "mineral_density": 12.0,
        "propellant_sources": 6.0,
        "station_power_output": 180.0,
        "stockpile_capacity": 1300,
        "market_inventory": {
            "commodity_ore":    {"buy_price": 10, "sell_price":  8, "quantity": 120},
            "commodity_food":   {"buy_price": 28, "sell_price": 22, "quantity":  50},
            "commodity_tech":   {"buy_price": 75, "sell_price": 60, "quantity":  25},
            "commodity_fuel":   {"buy_price": 22, "sell_price": 18, "quantity":  90},
            "commodity_luxury": {"buy_price": 100, "sell_price": 85, "quantity": 15},
        },
        "available_services": ["trade", "repair", "contracts"],
        "controlling_faction_id": "faction_miners",
        "danger_level": 2,
    },
}


# =========================================================================
# === FACTIONS ============================================================
# =========================================================================

FACTIONS = {
    "faction_miners": {
        "display_name": "Miners Guild",
        "description": "A collective of independent miners and ore processors.",
        "default_standing": 0,
    },
    "faction_traders": {
        "display_name": "Trade Alliance",
        "description": "The dominant commercial entity in the sector.",
        "default_standing": 0,
    },
    "faction_independents": {
        "display_name": "Independent Captains",
        "description": "Unaffiliated pilots operating on their own terms.",
        "default_standing": 0,
    },
    "faction_military": {
        "display_name": "Military Corps",
        "description": "A disciplined military force maintaining order.",
        "default_standing": 0,
    },
    "faction_pirates": {
        "display_name": "Pirate Syndicate",
        "description": "Opportunistic raiders who thrive in chaos and lawless sectors.",
        "default_standing": -50,
    },
}


# =========================================================================
# === CHARACTERS ==========================================================
# =========================================================================

CHARACTERS = {
    "character_default": {
        "character_name": "Unnamed",
        "faction_id": "faction_default",
        "credits": 10000,
        "skills": {"piloting": 2, "combat": 1, "trading": 3},
        "age": 30,
        "reputation": 0,
        "personality_traits": {},
        "description": "",
    },
    "character_vera": {
        "character_name": "Vera",
        "faction_id": "faction_traders",
        "credits": 5000,
        "skills": {"piloting": 3, "combat": 1, "trading": 5},
        "age": 40,
        "reputation": 60,
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.5},
        "description": "Merchant captain, cautious.",
    },
    "character_ada": {
        "character_name": "Ada",
        "faction_id": "faction_independents",
        "credits": 1200,
        "skills": {"piloting": 3, "combat": 2, "trading": 2},
        "age": 32,
        "reputation": 40,
        "personality_traits": {"risk_tolerance": 0.5, "aggression": 0.1},
        "description": "Salvager, resourceful.",
    },
    "character_juno": {
        "character_name": "Juno",
        "faction_id": "faction_miners",
        "credits": 500,
        "skills": {"piloting": 2, "combat": 1, "trading": 1},
        "age": 22,
        "reputation": 10,
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.7},
        "description": "Young prospector, ambitious.",
    },
    "character_kai": {
        "character_name": "Kai",
        "faction_id": "faction_miners",
        "credits": 1500,
        "skills": {"piloting": 4, "combat": 2, "trading": 1},
        "age": 45,
        "reputation": 50,
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8},
        "description": "Veteran miner, pragmatic.",
    },
    "character_milo": {
        "character_name": "Milo",
        "faction_id": "faction_traders",
        "credits": 2000,
        "skills": {"piloting": 3, "combat": 2, "trading": 3},
        "age": 35,
        "reputation": 30,
        "personality_traits": {"greed": 0.7, "aggression": 0.2},
        "description": "Cargo hauler, opportunistic.",
    },
    "character_rex": {
        "character_name": "Rex",
        "faction_id": "faction_independents",
        "credits": 800,
        "skills": {"piloting": 5, "combat": 4, "trading": 1},
        "age": 28,
        "reputation": 20,
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.2},
        "description": "Freelancer pilot, risky.",
    },
    "character_siv": {
        "character_name": "Siv",
        "faction_id": "faction_military",
        "credits": 3000,
        "skills": {"piloting": 4, "combat": 5, "trading": 2},
        "age": 38,
        "reputation": 70,
        "personality_traits": {"risk_tolerance": 0.4, "loyalty": 0.9, "greed": 0.6},
        "description": "Military supply officer, disciplined.",
    },
    "character_zara": {
        "character_name": "Zara",
        "faction_id": "faction_miners",
        "credits": 900,
        "skills": {"piloting": 3, "combat": 1, "trading": 2},
        "age": 29,
        "reputation": 25,
        "personality_traits": {"risk_tolerance": 0.7, "greed": 0.4},
        "description": "Survey specialist, maps deposits.",
    },
    "character_nyx": {
        "character_name": "Nyx",
        "faction_id": "faction_military",
        "credits": 2500,
        "skills": {"piloting": 5, "combat": 4, "trading": 1},
        "age": 34,
        "reputation": 55,
        "personality_traits": {"risk_tolerance": 0.3, "loyalty": 0.8, "aggression": 0.4},
        "description": "Patrol officer, keeps order.",
    },
    "character_orin": {
        "character_name": "Orin",
        "faction_id": "faction_traders",
        "credits": 1800,
        "skills": {"piloting": 4, "combat": 1, "trading": 4},
        "age": 42,
        "reputation": 45,
        "personality_traits": {"risk_tolerance": 0.2, "greed": 0.3, "loyalty": 0.6},
        "description": "Bulk cargo hauler, reliable.",
    },
    "character_crow": {
        "character_name": "Crow",
        "faction_id": "faction_pirates",
        "credits": 2200,
        "skills": {"piloting": 4, "combat": 4, "trading": 2},
        "age": 36,
        "reputation": -30,
        "personality_traits": {"risk_tolerance": 0.9, "greed": 0.8, "aggression": 0.7},
        "description": "Ruthless raider, exploits disruption.",
    },
    "character_vex": {
        "character_name": "Vex",
        "faction_id": "faction_pirates",
        "credits": 1600,
        "skills": {"piloting": 5, "combat": 3, "trading": 3},
        "age": 27,
        "reputation": -20,
        "personality_traits": {"risk_tolerance": 0.8, "greed": 0.9, "aggression": 0.5},
        "description": "Cunning smuggler turned pirate.",
    },
    "character_nova": {
        "character_name": "Nova",
        "faction_id": "faction_independents",
        "credits": 2000,
        "skills": {"piloting": 5, "combat": 2, "trading": 2},
        "age": 31,
        "reputation": 35,
        "personality_traits": {"risk_tolerance": 0.9, "loyalty": 0.3},
        "description": "Deep-space explorer, restless.",
    },
}


# =========================================================================
# === AGENTS ==============================================================
# =========================================================================

AGENTS = {
    "agent_player_default": {
        "agent_type": "player",
        "is_persistent": False,
        "home_location_id": "",
        "character_template_id": "",
        "agent_role": "idle",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Traders (buy low, sell high) ---
    "persistent_vera": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_vera",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_milo": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_beta",
        "character_template_id": "character_milo",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Prospectors (explore, discover hidden resources) ---
    "persistent_juno": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_juno",
        "agent_role": "prospector",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_zara": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_epsilon",
        "character_template_id": "character_zara",
        "agent_role": "prospector",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Military (patrol, suppress piracy, boost security) ---
    "persistent_siv": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_delta",
        "character_template_id": "character_siv",
        "agent_role": "military",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_nyx": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_delta",
        "character_template_id": "character_nyx",
        "agent_role": "military",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Haulers (move goods to balance stockpiles) ---
    "persistent_kai": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_alpha",
        "character_template_id": "character_kai",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_orin": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_epsilon",
        "character_template_id": "character_orin",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Freelancers (trade + salvage, flexible) ---
    "persistent_ada": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_ada",
        "agent_role": "trader",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_rex": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_rex",
        "agent_role": "hauler",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Pirates (raid cargo, exploit disruption) ---
    "persistent_crow": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_crow",
        "agent_role": "pirate",
        "respawn_timeout_seconds": 300.0,
    },
    "persistent_vex": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_vex",
        "agent_role": "pirate",
        "respawn_timeout_seconds": 300.0,
    },
    # --- Explorers (discover new sectors from frontiers) ---
    "persistent_nova": {
        "agent_type": "npc",
        "is_persistent": True,
        "home_location_id": "station_gamma",
        "character_template_id": "character_nova",
        "agent_role": "explorer",
        "respawn_timeout_seconds": 300.0,
    },
}

--- Start of ./python_sandbox/test_ca_rules.py ---

"""
Unit tests for ca_rules.py — pure-function cellular automata transition rules.

Tests verify:
  - strategic_map_step: influence propagation, faction anchoring, security, piracy
  - supply_demand_step: extraction from resource_potential, capacity limits
  - market_pressure_step: price deltas from supply vs demand, service cost modifier
  - entropy_step: wreck degradation, matter return
  - power_load_step: power ratio clamping
  - maintenance_pressure_step: entropy rate, maintenance modifier
"""

import copy
import unittest
import ca_rules


class TestStrategicMapStep(unittest.TestCase):
    """Tests for ca_rules.strategic_map_step()."""

    def _make_sector_state(
        self,
        faction_influence=None,
        pirate_activity=0.0,
        controlling_faction_id="",
    ):
        return {
            "faction_influence": faction_influence or {},
            "pirate_activity": pirate_activity,
            "controlling_faction_id": controlling_faction_id,
        }

    def _default_config(self, **overrides):
        cfg = {
            "influence_propagation_rate": 0.1,
            "pirate_activity_decay": 0.02,
            "pirate_activity_growth": 0.05,
            "faction_anchor_strength": 0.3,
        }
        cfg.update(overrides)
        return cfg

    # --- Pure output tests ---
    def test_returns_required_keys(self):
        result = ca_rules.strategic_map_step(
            "sector_a",
            self._make_sector_state({"f1": 0.5, "f2": 0.5}),
            [],
            self._default_config(),
        )
        self.assertIn("faction_influence", result)
        self.assertIn("security_level", result)
        self.assertIn("pirate_activity", result)

    def test_no_mutation_of_input(self):
        sector = self._make_sector_state({"f1": 0.6, "f2": 0.4})
        original = copy.deepcopy(sector)
        ca_rules.strategic_map_step("s1", sector, [], self._default_config())
        self.assertEqual(sector, original)

    # --- Influence normalization ---
    def test_influence_sums_to_one(self):
        sector = self._make_sector_state({"f1": 0.3, "f2": 0.3, "f3": 0.4})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        total = sum(result["faction_influence"].values())
        self.assertAlmostEqual(total, 1.0, places=6)

    def test_influence_no_negatives(self):
        sector = self._make_sector_state({"f1": 0.01, "f2": 0.99})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        for val in result["faction_influence"].values():
            self.assertGreaterEqual(val, 0.0)

    # --- Faction anchoring ---
    def test_anchor_boosts_controlling_faction(self):
        """Controlling faction should hold higher influence than without anchor."""
        sector_anchored = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id="f1"
        )
        sector_no_anchor = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id=""
        )
        result_anchored = ca_rules.strategic_map_step(
            "s1", sector_anchored, [], self._default_config()
        )
        result_plain = ca_rules.strategic_map_step(
            "s1", sector_no_anchor, [], self._default_config()
        )
        self.assertGreater(
            result_anchored["faction_influence"]["f1"],
            result_plain["faction_influence"]["f1"],
        )

    def test_anchor_strength_zero_equals_no_anchor(self):
        """With anchor_strength=0 the result is the same as no controlling faction."""
        sector = self._make_sector_state(
            {"f1": 0.5, "f2": 0.5}, controlling_faction_id="f1"
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        # Without anchor boost, both factions should remain equal
        self.assertAlmostEqual(
            result["faction_influence"]["f1"],
            result["faction_influence"]["f2"],
            places=5,
        )

    # --- Neighbor propagation ---
    def test_neighbor_influence_propagates(self):
        """Faction present only in neighbor should appear in result."""
        sector = self._make_sector_state({"f1": 1.0})
        neighbor = {"faction_influence": {"f1": 0.2, "f2": 0.8}}
        result = ca_rules.strategic_map_step(
            "s1", sector, [neighbor], self._default_config(faction_anchor_strength=0.0)
        )
        self.assertIn("f2", result["faction_influence"])
        self.assertGreater(result["faction_influence"]["f2"], 0.0)

    def test_isolated_sector_no_propagation(self):
        """With no neighbors, only anchor changes influence."""
        sector = self._make_sector_state({"f1": 0.7, "f2": 0.3})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        # Should stay the same (no propagation source, no anchor)
        self.assertAlmostEqual(
            result["faction_influence"]["f1"], 0.7, places=5
        )

    # --- Security level ---
    def test_security_matches_max_influence(self):
        sector = self._make_sector_state(
            {"f1": 0.8, "f2": 0.2}, controlling_faction_id=""
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        max_inf = max(result["faction_influence"].values())
        self.assertAlmostEqual(result["security_level"], max_inf, places=5)

    def test_security_clamped_0_to_1(self):
        sector = self._make_sector_state({"f1": 1.0})
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertGreaterEqual(result["security_level"], 0.0)
        self.assertLessEqual(result["security_level"], 1.0)

    # --- Piracy ---
    def test_piracy_grows_when_security_low(self):
        sector = self._make_sector_state(
            {"f1": 0.2, "f2": 0.2}, pirate_activity=0.3
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config(faction_anchor_strength=0.0)
        )
        self.assertGreater(result["pirate_activity"], 0.3)

    def test_piracy_decays_when_security_high(self):
        sector = self._make_sector_state(
            {"f1": 0.95}, pirate_activity=0.5, controlling_faction_id="f1"
        )
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertLess(result["pirate_activity"], 0.5)

    def test_piracy_clamped_to_0_1(self):
        sector = self._make_sector_state({"f1": 0.01}, pirate_activity=1.0)
        result = ca_rules.strategic_map_step(
            "s1", sector, [], self._default_config()
        )
        self.assertLessEqual(result["pirate_activity"], 1.0)
        self.assertGreaterEqual(result["pirate_activity"], 0.0)


class TestSupplyDemandStep(unittest.TestCase):
    """Tests for ca_rules.supply_demand_step()."""

    def _make_stockpiles(self, commodities=None, capacity=1000):
        return {
            "commodity_stockpiles": commodities or {},
            "stockpile_capacity": capacity,
            "extraction_rate": {},
        }

    def _make_potential(self, mineral=100.0, propellant=50.0):
        return {
            "mineral_density": mineral,
            "propellant_sources": propellant,
        }

    def _default_config(self, **overrides):
        cfg = {"extraction_rate_default": 0.01}
        cfg.update(overrides)
        return cfg

    # --- Extraction ---
    def test_extraction_moves_matter_from_potential_to_stockpile(self):
        stockpiles = self._make_stockpiles()
        potential = self._make_potential(mineral=100.0, propellant=50.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        new_stock = result["new_stockpiles"]["commodity_stockpiles"]
        new_pot = result["new_resource_potential"]

        # Ore should appear in stockpile
        self.assertGreater(new_stock.get("commodity_ore", 0.0), 0.0)
        # Fuel should appear
        self.assertGreater(new_stock.get("commodity_fuel", 0.0), 0.0)
        # Potential should decrease
        self.assertLess(new_pot["mineral_density"], 100.0)
        self.assertLess(new_pot["propellant_sources"], 50.0)

    def test_extraction_conserves_matter(self):
        """Extracted amount equals potential decrease (Axiom 1)."""
        stockpiles = self._make_stockpiles({"commodity_ore": 10.0})
        potential = self._make_potential(mineral=100.0, propellant=50.0)

        stock_before = 10.0
        pot_before = 100.0 + 50.0

        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        new_stock = result["new_stockpiles"]["commodity_stockpiles"]
        new_pot = result["new_resource_potential"]

        stock_after = sum(new_stock.values())
        pot_after = new_pot["mineral_density"] + new_pot["propellant_sources"]

        self.assertAlmostEqual(
            stock_before + pot_before,
            stock_after + pot_after,
            places=8,
            msg="Matter must be conserved during extraction",
        )

    def test_no_extraction_when_potential_zero(self):
        stockpiles = self._make_stockpiles()
        potential = self._make_potential(mineral=0.0, propellant=0.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        self.assertEqual(result["matter_extracted"], 0.0)

    def test_extraction_respects_capacity(self):
        """Stockpile should not exceed capacity."""
        stockpiles = self._make_stockpiles(
            {"commodity_ore": 990.0}, capacity=1000
        )
        potential = self._make_potential(mineral=10000.0, propellant=0.0)
        result = ca_rules.supply_demand_step(
            "s1", stockpiles, potential, [], self._default_config()
        )
        total = sum(result["new_stockpiles"]["commodity_stockpiles"].values())
        self.assertLessEqual(total, 1000.0)

    def test_no_mutation_of_inputs(self):
        stockpiles = self._make_stockpiles({"commodity_ore": 50.0})
        potential = self._make_potential()
        orig_stock = copy.deepcopy(stockpiles)
        orig_pot = copy.deepcopy(potential)
        ca_rules.supply_demand_step("s1", stockpiles, potential, [], self._default_config())
        self.assertEqual(stockpiles, orig_stock)
        self.assertEqual(potential, orig_pot)


class TestMarketPressureStep(unittest.TestCase):
    """Tests for ca_rules.market_pressure_step()."""

    def _default_config(self, **overrides):
        cfg = {"price_sensitivity": 0.5, "demand_base": 0.1}
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        stockpiles = {"commodity_stockpiles": {"ore": 100}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step("s1", stockpiles, 1.0, self._default_config())
        self.assertIn("commodity_price_deltas", result)
        self.assertIn("service_cost_modifier", result)

    def test_high_supply_gives_negative_delta(self):
        """Oversupply should push price delta negative."""
        stockpiles = {"commodity_stockpiles": {"ore": 500}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 0.1, self._default_config()
        )
        self.assertLess(result["commodity_price_deltas"]["ore"], 0.0)

    def test_zero_supply_gives_positive_delta(self):
        """No supply with some demand should push price delta positive."""
        stockpiles = {"commodity_stockpiles": {"ore": 0.0}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 1.0, self._default_config()
        )
        self.assertGreater(result["commodity_price_deltas"]["ore"], 0.0)

    def test_service_modifier_clamped(self):
        stockpiles = {"commodity_stockpiles": {}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 100.0, self._default_config()
        )
        self.assertGreaterEqual(result["service_cost_modifier"], 0.5)
        self.assertLessEqual(result["service_cost_modifier"], 2.0)

    def test_empty_commodities_returns_empty_deltas(self):
        stockpiles = {"commodity_stockpiles": {}, "stockpile_capacity": 1000}
        result = ca_rules.market_pressure_step(
            "s1", stockpiles, 1.0, self._default_config()
        )
        self.assertEqual(result["commodity_price_deltas"], {})


class TestEntropyStep(unittest.TestCase):
    """Tests for ca_rules.entropy_step()."""

    def _default_config(self, **overrides):
        cfg = {
            "wreck_degradation_per_tick": 0.05,
            "wreck_debris_return_fraction": 0.8,
            "entropy_radiation_multiplier": 2.0,
        }
        cfg.update(overrides)
        return cfg

    def test_wreck_degrades_over_time(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(len(result["surviving_wrecks"]), 1)
        self.assertLess(
            result["surviving_wrecks"][0]["wreck_integrity"], 0.5
        )

    def test_surviving_wreck_hull_dust_conserved(self):
        """Hull erosion on a surviving wreck must appear as dust (Axiom 1)."""
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {"ore": 3.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        surviving = result["surviving_wrecks"]
        self.assertEqual(len(surviving), 1)
        new_integrity = surviving[0]["wreck_integrity"]
        hull_lost = 0.5 - new_integrity
        # Dust must equal the hull mass lost (inventory untouched on surviving wrecks).
        self.assertAlmostEqual(result["matter_to_dust"], hull_lost, places=6)
        # Salvaged is 0 — wreck didn't die.
        self.assertEqual(result["matter_salvaged"], 0.0)
        # Total matter = surviving hull + inventory + dust = original 3.5
        total = new_integrity + 3.0 + result["matter_to_dust"]
        self.assertAlmostEqual(total, 3.5, places=6)

    def test_wreck_destroyed_when_integrity_zero(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(len(result["surviving_wrecks"]), 0)
        total = result["matter_salvaged"] + result["matter_to_dust"]
        self.assertGreater(total, 0.0)

    def test_matter_returned_fraction(self):
        wrecks = [{"wreck_integrity": 0.01, "wreck_inventory": {"ore": 10.0}}]
        result = ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        # Hull 0.01 degrades fully → 0.01 dust.
        # Inventory 10.0: salvaged = 10.0 * 0.8 = 8.0, dust = 10.0 * 0.2 = 2.0.
        # Total dust = 0.01 + 2.0 = 2.01.
        self.assertAlmostEqual(result["matter_salvaged"], 8.0, places=2)
        self.assertAlmostEqual(result["matter_to_dust"], 2.01, places=2)
        # Axiom 1: salvaged + dust = original wreck matter (10.01)
        total = result["matter_salvaged"] + result["matter_to_dust"]
        self.assertAlmostEqual(total, 10.01, places=2)

    def test_radiation_increases_degradation(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {}}]
        hazards_clean = {"radiation_level": 0.0}
        hazards_hot = {"radiation_level": 1.0}

        result_clean = ca_rules.entropy_step("s1", wrecks, hazards_clean, self._default_config())
        result_hot = ca_rules.entropy_step("s1", copy.deepcopy(wrecks), hazards_hot, self._default_config())

        # Higher radiation → more degradation → lower integrity
        self.assertLess(
            result_hot["surviving_wrecks"][0]["wreck_integrity"],
            result_clean["surviving_wrecks"][0]["wreck_integrity"],
        )

    def test_no_wrecks_returns_empty(self):
        result = ca_rules.entropy_step("s1", [], {}, self._default_config())
        self.assertEqual(result["surviving_wrecks"], [])
        self.assertEqual(result["matter_salvaged"], 0.0)
        self.assertEqual(result["matter_to_dust"], 0.0)

    def test_no_mutation_of_input(self):
        wrecks = [{"wreck_integrity": 0.5, "wreck_inventory": {"ore": 5.0}}]
        original = copy.deepcopy(wrecks)
        ca_rules.entropy_step("s1", wrecks, {}, self._default_config())
        self.assertEqual(wrecks, original)


class TestPowerLoadStep(unittest.TestCase):
    """Tests for ca_rules.power_load_step()."""

    def test_zero_output_returns_zero_ratio(self):
        result = ca_rules.power_load_step(0.0, 50.0)
        self.assertEqual(result["power_load_ratio"], 0.0)

    def test_half_load(self):
        result = ca_rules.power_load_step(100.0, 50.0)
        self.assertAlmostEqual(result["power_load_ratio"], 0.5)

    def test_full_load(self):
        result = ca_rules.power_load_step(100.0, 100.0)
        self.assertAlmostEqual(result["power_load_ratio"], 1.0)

    def test_overload_clamped_to_2(self):
        result = ca_rules.power_load_step(100.0, 500.0)
        self.assertAlmostEqual(result["power_load_ratio"], 2.0)


class TestMaintenancePressureStep(unittest.TestCase):
    """Tests for ca_rules.maintenance_pressure_step()."""

    def _default_config(self):
        return {"entropy_base_rate": 0.001}

    def test_returns_required_keys(self):
        result = ca_rules.maintenance_pressure_step({}, self._default_config())
        self.assertIn("local_entropy_rate", result)
        self.assertIn("maintenance_cost_modifier", result)

    def test_higher_radiation_increases_entropy(self):
        low_rad = ca_rules.maintenance_pressure_step(
            {"radiation_level": 0.0}, self._default_config()
        )
        high_rad = ca_rules.maintenance_pressure_step(
            {"radiation_level": 1.0}, self._default_config()
        )
        self.assertGreater(
            high_rad["local_entropy_rate"],
            low_rad["local_entropy_rate"],
        )

    def test_modifier_clamped_1_to_3(self):
        result = ca_rules.maintenance_pressure_step(
            {"radiation_level": 100.0, "thermal_background_k": 50000.0,
             "gravity_well_penalty": 10.0},
            self._default_config(),
        )
        self.assertGreaterEqual(result["maintenance_cost_modifier"], 1.0)
        self.assertLessEqual(result["maintenance_cost_modifier"], 3.0)

    def test_benign_environment_low_modifier(self):
        result = ca_rules.maintenance_pressure_step(
            {"radiation_level": 0.0, "thermal_background_k": 300.0,
             "gravity_well_penalty": 1.0},
            self._default_config(),
        )
        self.assertAlmostEqual(result["maintenance_cost_modifier"], 1.1, places=1)


class TestProspectingStep(unittest.TestCase):
    """Tests for ca_rules.prospecting_step()."""

    def _make_hidden(self, mineral=1000.0, propellant=500.0):
        return {"mineral_density": mineral, "propellant_sources": propellant}

    def _make_potential(self, mineral=50.0, propellant=30.0):
        return {"mineral_density": mineral, "propellant_sources": propellant}

    def _make_market(self, deltas=None):
        return {"commodity_price_deltas": deltas or {}}

    def _make_dominion(self, security=0.8):
        return {"security_level": security}

    def _make_hazards(self, radiation=0.05):
        return {"radiation_level": radiation}

    def _default_config(self, **overrides):
        cfg = {
            "prospecting_base_rate": 0.002,
            "prospecting_scarcity_boost": 2.0,
            "prospecting_security_factor": 1.0,
            "prospecting_hazard_penalty": 0.5,
            "prospecting_randomness": 0.3,
            "resource_layer_fractions": {"surface": 0.15, "deep": 0.35, "mantle": 0.50},
            "resource_layer_rate_multipliers": {"surface": 3.0, "deep": 1.0, "mantle": 0.3},
            "resource_layer_depletion_threshold": 0.01,
        }
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertIn("new_hidden", result)
        self.assertIn("new_potential", result)
        self.assertIn("matter_discovered", result)

    def test_matter_conservation(self):
        """Hidden → discovered transfer must conserve matter."""
        hidden = self._make_hidden(1000.0, 500.0)
        potential = self._make_potential(50.0, 30.0)
        before = 1000.0 + 500.0 + 50.0 + 30.0

        result = ca_rules.prospecting_step(
            "s1", hidden, potential,
            self._make_market({"ore": 0.1}), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        nh = result["new_hidden"]
        np_ = result["new_potential"]
        after = (nh["mineral_density"] + nh["propellant_sources"]
                 + np_["mineral_density"] + np_["propellant_sources"])
        self.assertAlmostEqual(before, after, places=8,
                               msg="Prospecting must conserve matter")

    def test_no_mutation_of_inputs(self):
        hidden = self._make_hidden()
        potential = self._make_potential()
        orig_h = copy.deepcopy(hidden)
        orig_p = copy.deepcopy(potential)
        ca_rules.prospecting_step(
            "s1", hidden, potential,
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertEqual(hidden, orig_h)
        self.assertEqual(potential, orig_p)

    def test_discovery_increases_potential(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(1000.0, 500.0), self._make_potential(50.0, 30.0),
            self._make_market({"ore": 0.1}), self._make_dominion(0.8),
            self._make_hazards(0.05), self._default_config(), 0.5,
        )
        self.assertGreater(result["new_potential"]["mineral_density"], 50.0)
        self.assertGreater(result["new_potential"]["propellant_sources"], 30.0)

    def test_discovery_decreases_hidden(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(1000.0, 500.0), self._make_potential(50.0, 30.0),
            self._make_market({"ore": 0.1}), self._make_dominion(0.8),
            self._make_hazards(0.05), self._default_config(), 0.5,
        )
        self.assertLess(result["new_hidden"]["mineral_density"], 1000.0)
        self.assertLess(result["new_hidden"]["propellant_sources"], 500.0)

    def test_no_hidden_no_discovery(self):
        result = ca_rules.prospecting_step(
            "s1", self._make_hidden(0.0, 0.0), self._make_potential(50.0, 30.0),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertEqual(result["matter_discovered"], 0.0)

    def test_scarcity_boosts_discovery(self):
        """Higher scarcity (positive price deltas) should increase discovery rate."""
        market_low = self._make_market({})
        market_high = self._make_market({"ore": 0.5, "fuel": 0.3})

        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            market_low, self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            market_high, self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_high["matter_discovered"],
            result_low["matter_discovered"],
        )

    def test_high_security_boosts_discovery(self):
        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(0.1),
            self._make_hazards(), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(1.0),
            self._make_hazards(), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_high["matter_discovered"],
            result_low["matter_discovered"],
        )

    def test_high_radiation_reduces_discovery(self):
        result_low = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(0.0), self._default_config(), 0.5,
        )
        result_high = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(1.0), self._default_config(), 0.5,
        )
        self.assertGreater(
            result_low["matter_discovered"],
            result_high["matter_discovered"],
        )

    def test_randomness_variance(self):
        """Different rng values should produce different amounts."""
        r1 = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 0.0,
        )
        r2 = ca_rules.prospecting_step(
            "s1", self._make_hidden(), self._make_potential(),
            self._make_market(), self._make_dominion(),
            self._make_hazards(), self._default_config(), 1.0,
        )
        self.assertNotAlmostEqual(
            r1["matter_discovered"], r2["matter_discovered"], places=6,
        )


class TestHazardDriftStep(unittest.TestCase):
    """Tests for ca_rules.hazard_drift_step()."""

    def _base_hazards(self, rad=0.05, thermal=280.0, gravity=1.2):
        return {
            "radiation_level": rad,
            "thermal_background_k": thermal,
            "gravity_well_penalty": gravity,
        }

    def _default_config(self, **overrides):
        cfg = {
            "hazard_drift_period": 200,
            "hazard_radiation_amplitude": 0.04,
            "hazard_thermal_amplitude": 15.0,
        }
        cfg.update(overrides)
        return cfg

    def test_returns_required_keys(self):
        result = ca_rules.hazard_drift_step(
            "s1", self._base_hazards(), 0, 0, self._default_config(),
        )
        self.assertIn("radiation_level", result)
        self.assertIn("thermal_background_k", result)
        self.assertIn("gravity_well_penalty", result)

    def test_gravity_unchanged(self):
        """Gravity should never be affected by space weather."""
        base = self._base_hazards(gravity=1.5)
        result = ca_rules.hazard_drift_step(
            "s1", base, 100, 0, self._default_config(),
        )
        self.assertEqual(result["gravity_well_penalty"], 1.5)

    def test_no_mutation_of_input(self):
        base = self._base_hazards()
        original = copy.deepcopy(base)
        ca_rules.hazard_drift_step("s1", base, 50, 0, self._default_config())
        self.assertEqual(base, original)

    def test_radiation_drifts_from_base(self):
        """At non-zero tick, radiation should differ from base (unless at sin=0)."""
        base = self._base_hazards(rad=0.1)
        # tick 50 with period 200 → θ = π/2 → sin = 1.0, so drift = amplitude
        result = ca_rules.hazard_drift_step(
            "s1", base, 50, 0, self._default_config(),
        )
        self.assertNotAlmostEqual(result["radiation_level"], 0.1, places=3)

    def test_thermal_drifts_from_base(self):
        base = self._base_hazards(thermal=300.0)
        result = ca_rules.hazard_drift_step(
            "s1", base, 50, 0, self._default_config(),
        )
        self.assertNotAlmostEqual(result["thermal_background_k"], 300.0, places=0)

    def test_radiation_clamped_non_negative(self):
        """Even with large amplitude, radiation should never go negative."""
        base = self._base_hazards(rad=0.01)
        cfg = self._default_config(hazard_radiation_amplitude=1.0)
        # Test many ticks
        for tick in range(300):
            result = ca_rules.hazard_drift_step("s1", base, tick, 0, cfg)
            self.assertGreaterEqual(result["radiation_level"], 0.0)

    def test_thermal_clamped_above_minimum(self):
        """Thermal should never drop below 50K."""
        base = self._base_hazards(thermal=60.0)
        cfg = self._default_config(hazard_thermal_amplitude=100.0)
        for tick in range(300):
            result = ca_rules.hazard_drift_step("s1", base, tick, 0, cfg)
            self.assertGreaterEqual(result["thermal_background_k"], 50.0)

    def test_different_sectors_different_phase(self):
        """Different sector indices should produce different hazard values at same tick."""
        base = self._base_hazards()
        # Use tick 50 where sin values diverge clearly across phase offsets
        r0 = ca_rules.hazard_drift_step("s1", base, 50, 0, self._default_config())
        r1 = ca_rules.hazard_drift_step("s2", base, 50, 1, self._default_config())
        # At least one value should differ
        self.assertNotAlmostEqual(
            r0["radiation_level"], r1["radiation_level"], places=4
        )

    def test_periodic_returns_to_base(self):
        """After one full period, values should return close to base."""
        base = self._base_hazards(rad=0.1, thermal=300.0)
        period = 200
        result = ca_rules.hazard_drift_step(
            "s1", base, period, 0, self._default_config(hazard_drift_period=period),
        )
        # sin(2π) = 0 → drift = 0
        self.assertAlmostEqual(result["radiation_level"], 0.1, places=6)
        self.assertAlmostEqual(result["thermal_background_k"], 300.0, places=4)

    def test_zero_amplitude_no_drift(self):
        base = self._base_hazards(rad=0.1, thermal=300.0)
        cfg = self._default_config(hazard_radiation_amplitude=0.0, hazard_thermal_amplitude=0.0)
        result = ca_rules.hazard_drift_step("s1", base, 99, 2, cfg)
        self.assertAlmostEqual(result["radiation_level"], 0.1, places=8)
        self.assertAlmostEqual(result["thermal_background_k"], 300.0, places=8)


if __name__ == "__main__":
    unittest.main()

--- Start of ./python_sandbox/world_layer.py ---

"""
GDTLancer World Layer — Layer 1 (static topology, hazards, resource potential).
Mirror of src/core/simulation/world_layer.gd.

The World Layer is STATIC after initialization — read-only at runtime.
Defines: topology (sector graph), hazards, finite resource potential.
"""

import random
import copy
from game_state import GameState
from template_data import LOCATIONS, FACTIONS
import constants


class WorldLayer:
    """Initializes Layer 1 data in GameState from template data."""

    def initialize_world(self, state: GameState, seed_string: str) -> None:
        """Initialize all World Layer data from template data."""
        state.world_seed = seed_string

        # Seed the RNG deterministically
        rng = random.Random(hash(seed_string))

        self._build_topology(state)
        self._build_hazards(state)
        self._build_resource_potential(state, rng)
        self._build_hidden_resources(state, rng)
        self._calculate_total_matter(state)

        print(
            f"WorldLayer: Initialized {len(state.world_topology)} sectors. "
            f"Total matter budget: {state.world_total_matter:.2f}"
        )

    # -----------------------------------------------------------------
    # Topology
    # -----------------------------------------------------------------
    def _build_topology(self, state: GameState) -> None:
        state.world_topology.clear()

        for location_id, loc in LOCATIONS.items():
            connections = list(loc.get("connections", []))
            station_ids = [location_id]
            sector_type = loc.get("sector_type", "frontier")

            state.world_topology[location_id] = {
                "connections": connections,
                "station_ids": station_ids,
                "sector_type": sector_type,
            }

    # -----------------------------------------------------------------
    # Hazards
    # -----------------------------------------------------------------
    def _build_hazards(self, state: GameState) -> None:
        state.world_hazards.clear()

        for location_id, loc in LOCATIONS.items():
            state.world_hazards[location_id] = {
                "radiation_level": float(loc.get("radiation_level", 0.0)),
                "thermal_background_k": float(loc.get("thermal_background_k", 300.0)),
                "gravity_well_penalty": float(loc.get("gravity_well_penalty", 1.0)),
            }

        # Store an immutable copy of base hazards for drift calculations
        state.world_hazards_base = copy.deepcopy(state.world_hazards)

    # -----------------------------------------------------------------
    # Resource Potential
    # -----------------------------------------------------------------
    def _build_resource_potential(self, state: GameState, rng: random.Random) -> None:
        state.world_resource_potential.clear()

        for location_id, loc in LOCATIONS.items():
            base_mineral = float(loc.get("mineral_density", 0.5))
            base_propellant = float(loc.get("propellant_sources", 0.5))

            mineral_variance = base_mineral * rng.uniform(-0.1, 0.1)
            propellant_variance = base_propellant * rng.uniform(-0.1, 0.1)

            scale_factor = 100.0

            state.world_resource_potential[location_id] = {
                "mineral_density": max(0.0, (base_mineral + mineral_variance) * scale_factor),
                "energy_potential": 50.0,  # Phase 1 stub
                "propellant_sources": max(0.0, (base_propellant + propellant_variance) * scale_factor),
            }

    # -----------------------------------------------------------------
    # Hidden Resources (undiscovered deposits, ~10× discovered)
    # -----------------------------------------------------------------
    def _build_hidden_resources(self, state: GameState, rng: random.Random) -> None:
        """Initialize hidden resource pools from discovered potential × multiplier."""
        state.world_hidden_resources.clear()
        multiplier = constants.HIDDEN_RESOURCE_MULTIPLIER

        for location_id, potential in state.world_resource_potential.items():
            discovered_mineral = potential.get("mineral_density", 0.0)
            discovered_propellant = potential.get("propellant_sources", 0.0)

            # Apply ±20% variance so hidden deposits aren't perfectly proportional
            mineral_var = rng.uniform(0.8, 1.2)
            propellant_var = rng.uniform(0.8, 1.2)

            state.world_hidden_resources[location_id] = {
                "mineral_density": discovered_mineral * multiplier * mineral_var,
                "propellant_sources": discovered_propellant * multiplier * propellant_var,
            }

    # -----------------------------------------------------------------
    # Matter conservation checksum
    # -----------------------------------------------------------------
    def _calculate_total_matter(self, state: GameState) -> None:
        total = 0.0
        for sector_id, potential in state.world_resource_potential.items():
            total += potential.get("mineral_density", 0.0)
            total += potential.get("propellant_sources", 0.0)
        # Hidden resources are also matter
        for sector_id, hidden in state.world_hidden_resources.items():
            total += hidden.get("mineral_density", 0.0)
            total += hidden.get("propellant_sources", 0.0)
        state.world_total_matter = total

    # -----------------------------------------------------------------
    # Public utilities
    # -----------------------------------------------------------------
    def get_neighbors(self, state: GameState, sector_id: str) -> list:
        if sector_id in state.world_topology:
            return state.world_topology[sector_id].get("connections", [])
        return []

    def get_hazards(self, state: GameState, sector_id: str) -> dict:
        if sector_id in state.world_hazards:
            return state.world_hazards[sector_id]
        return {"radiation_level": 0.0, "thermal_background_k": 300.0, "gravity_well_penalty": 1.0}

    def get_resource_potential(self, state: GameState, sector_id: str) -> dict:
        if sector_id in state.world_resource_potential:
            return state.world_resource_potential[sector_id]
        return {"mineral_density": 0.0, "energy_potential": 0.0, "propellant_sources": 0.0}

    def recalculate_total_matter(self, state: GameState) -> None:
        """Recalculate world_total_matter from ALL matter sources across all layers.

        Called after Grid and Agent layers are initialized to set the
        definitive Axiom 1 checksum.
        """
        total = 0.0

        # Layer 1: Resource potential
        for sector_id, potential in state.world_resource_potential.items():
            total += potential.get("mineral_density", 0.0)
            total += potential.get("propellant_sources", 0.0)

        # Layer 1: Hidden resources (undiscovered matter)
        for sector_id, hidden in state.world_hidden_resources.items():
            total += hidden.get("mineral_density", 0.0)
            total += hidden.get("propellant_sources", 0.0)

        # Layer 2: Grid stockpiles
        for sector_id, stockpile in state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                total += float(qty)

        # Layer 2: Wrecks
        for wreck_uid, wreck in state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                total += float(qty)
            total += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        # Layer 3: Agent inventories
        for char_uid, inv in state.inventories.items():
            if 2 in inv:  # InventoryType.COMMODITY
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        state.world_total_matter = total
        print(f"WorldLayer: Total matter recalculated: {total:.2f}")
