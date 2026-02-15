"""
GDTLancer World Layer — Layer 1 (static topology, hazards, resource potential).
Mirror of src/core/simulation/world_layer.gd.

The World Layer is STATIC after initialization — read-only at runtime.
Defines: topology (sector graph), hazards, finite resource potential.

PROJECT: GDTLancer
MODULE: core/simulation/world_layer.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 2: Entity Graph — World Layer)
"""

import random
import copy
from autoload.game_state import GameState
from database.registry.template_data import LOCATIONS, FACTIONS
from autoload import constants


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
