"""
GDTLancer Grid Layer — Layer 2 (CA-driven stockpiles, dominion, market, power, maintenance).
Mirror of src/core/simulation/grid_layer.gd.

Processing is DOUBLE-BUFFERED: all reads come from GameState, all writes
go to local buffers, then buffers are swapped atomically at the end.

PROJECT: GDTLancer
MODULE: core/simulation/grid_layer.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 3: Grid Layer)

SPECIE INJECTION (TRUTH_SIMULATION-GRAPH §8.1):
  Every station spawns with STATION_INITIAL_SPECIE units of commodity_specie,
  debited from hidden_resources (Axiom 1 safe).  This prevents the liquidity
  deadlock where miners cannot sell ore because stations start with 0 currency.
  Constraint: STATION_INITIAL_SPECIE > avg_cargo * avg_ore_price.
"""

import copy
import random
from autoload.game_state import GameState
from database.registry.template_data import LOCATIONS, FACTIONS
from core.simulation import ca_rules
from autoload import constants


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
                    overflow = -new_val
                    commodities[commodity_id] = 0.0
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
                        if remaining_overflow > 0.0:
                            hidden = buf_hidden_resources.get(sector_id, {})
                            hidden["mineral_density"] = hidden.get("mineral_density", 0.0) + remaining_overflow
                    else:
                        hidden = buf_hidden_resources.get(sector_id, {})
                        hidden["mineral_density"] = hidden.get("mineral_density", 0.0) + overflow
                else:
                    commodities[commodity_id] = new_val

        # 2h. Stockpile Consumption (population sink)
        for sector_id in state.world_topology:
            market = buf_market.get(sector_id, {})
            pop_density = market.get("population_density", 1.0)

            consumption_result = ca_rules.stockpile_consumption_step(
                sector_id, buf_stockpiles[sector_id], pop_density, config,
            )
            buf_stockpiles[sector_id] = consumption_result["new_stockpiles"]

            # Entropy tax → per-type hostile pools (Axiom 1)
            entropy_matter = consumption_result["matter_to_hostile_pool"]
            state.hostile_pools["drones"]["reserve"] += entropy_matter * 0.7
            state.hostile_pools["aliens"]["reserve"] += entropy_matter * 0.3

            # Waste → hidden_resources (Axiom 1)
            matter_hidden = consumption_result["matter_to_hidden"]
            if matter_hidden > 0.0:
                hid = buf_hidden_resources.get(sector_id, {})
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
        """Seed grid stockpiles from template data.

        SPECIE INJECTION (TRUTH_SIMULATION-GRAPH §8.1):
        Each station receives STATION_INITIAL_SPECIE units of commodity_specie,
        debited from hidden_resources (Axiom 1 safe).  This prevents the
        liquidity deadlock where no trades can occur at tick 0.
        """
        state.grid_stockpiles.clear()
        specie_per_station = constants.STATION_INITIAL_SPECIE

        for location_id, loc in LOCATIONS.items():
            commodity_stockpiles = {}
            market_inv = loc.get("market_inventory", {})
            for commodity_id, entry in market_inv.items():
                commodity_stockpiles[commodity_id] = float(entry.get("quantity", 0))

            # --- Specie Injection (Axiom 1 safe) ---
            # Debit from hidden_resources → stockpile commodity_specie
            if specie_per_station > 0.0:
                commodity_stockpiles["commodity_specie"] = (
                    commodity_stockpiles.get("commodity_specie", 0.0) + specie_per_station
                )
                # Debit from hidden_resources mineral pool (Axiom 1)
                hidden = state.world_hidden_resources.get(location_id, {})
                current_hidden_mineral = hidden.get("mineral_density", 0.0)
                debit = min(specie_per_station, current_hidden_mineral)
                hidden["mineral_density"] = current_hidden_mineral - debit
                # If hidden mineral insufficient, debit from propellant
                remainder = specie_per_station - debit
                if remainder > 0.0:
                    current_hidden_prop = hidden.get("propellant_sources", 0.0)
                    prop_debit = min(remainder, current_hidden_prop)
                    hidden["propellant_sources"] = current_hidden_prop - prop_debit

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
            # Also seed price delta for commodity_specie (always present after injection)
            if "commodity_specie" not in price_deltas:
                price_deltas["commodity_specie"] = 0.0

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

            matter_dust = entropy_result.get("matter_to_dust", 0.0)
            if matter_dust > 0.0:
                target = buf_hidden_resources if buf_hidden_resources is not None else state.world_hidden_resources
                if sector_id in target:
                    target[sector_id]["mineral_density"] = (
                        target[sector_id].get("mineral_density", 0.0) + matter_dust
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
        """Check each sector for colony level upgrade/downgrade."""
        upgrade_frac = config.get("colony_upgrade_stockpile_fraction", 0.6)
        upgrade_sec = config.get("colony_upgrade_security_min", 0.5)
        upgrade_ticks = config.get("colony_upgrade_ticks_required", 200)
        downgrade_frac = config.get("colony_downgrade_stockpile_fraction", 0.1)
        downgrade_sec = config.get("colony_downgrade_security_min", 0.2)
        downgrade_ticks = config.get("colony_downgrade_ticks_required", 300)

        levels = constants.COLONY_LEVELS

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
            total += wreck.get("wreck_integrity", 0.0)

        for htype_pool in state.hostile_pools.values():
            total += htype_pool.get("reserve", 0.0)
            total += htype_pool.get("body_mass", 0.0)

        for char_uid, inv in state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        return total
