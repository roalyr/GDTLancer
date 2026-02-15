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
            population_density = current_market.get("population_density", 1.0)

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

        # Axiom 1 assertion
        matter_after = self._calculate_current_matter(state)
        drift = abs(matter_after - matter_before)
        tolerance = config.get("axiom1_tolerance", 0.01)
        if drift > tolerance:
            print(
                f"GridLayer: AXIOM 1 VIOLATION! Matter drift: {drift:.4f} "
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

        for char_uid, inv in state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        return total
